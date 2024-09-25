// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {NonblockingLzApp, Ownable, ILayerZeroEndpoint} from "@layerzero-contracts/lzApp/NonblockingLzApp.sol";
import {Ownable2Step} from "@openzeppelin/access/Ownable2Step.sol";
import {ReentrancyGuard} from "@solbase/utils/ReentrancyGuard.sol";
import {SafeTransferLib} from "@solbase/utils/SafeTransferLib.sol";

import {Constants} from "src/libs/Constants.sol";
import {Enums} from "src/libs/Enums.sol";
import {Errors} from "src/libs/Errors.sol";
import {Artcoin} from "src/token/ArtcoinERC20.sol";

/// @title CrossChainVesting
/// @notice A contract for managing vesting schedules for Artcoin tokens across different blockchains using LayerZero.
contract CrossChainVesting is Ownable2Step, NonblockingLzApp, ReentrancyGuard {
    /// @notice The Artcoin token contract.
    Artcoin public immutable artcoin;

    /// @notice Tracks the total amount of tokens required to cover all vesting schedules and claims.
    /// @dev This variable is updated when tokens are vested or claimed, ensuring only excess tokens can be withdrawn.
    uint256 public totalRequiredTokens;

    /// @notice Address where collected fees are sent.
    address public feeReceiver;

    /// @notice Platform fee in basis points (bps).
    uint256 public platformFee;

    /// @notice The LayerZero endpoint instance.
    ILayerZeroEndpoint public immutable endpoint;

    /// @notice The source chain ID for cross-chain vesting.
    uint16 public immutable srcChainId;

    /// @notice The time when swap period ends.
    uint32 public swapCloseTime;

    /// @notice Indicates whether the claim period is open or not.
    bool public claimIsOpen;

    /// @notice Structure to hold swap bonuses.
    struct SwapBonuses {
        uint16 swapBonusOp1;
        uint16 swapBonusOp2;
    }

    /// @notice Default swap bonuses for different options.
    SwapBonuses public defaultBonuses;

    /// @notice Structure to hold vesting schedule information.
    struct VestingSchedule {
        uint32 cliff; // The duration (in seconds) before tokens start to vest.
        uint32 duration; // The total duration of the vesting period, including the cliff.
        uint32 start; // The start time of the vesting schedule.
        uint256 totalAmount; // The total amount of tokens to be vested.
        uint256 totalAmountWithBonus; // The total amount of tokens to be released at the end of the vesting, including the bonus.
        uint256 released; // The amount of tokens already released.
        uint16 bonusPercentage; // The bonus percentage to be applied after the cliff period.
        uint16 index; // The index of the vesting schedule.
        Enums.SwapOptions swapOption; // The swap option selected during swapping.
    }

    /// @notice Mapping of beneficiary addresses to their vesting schedules.
    mapping(address beneficiary => VestingSchedule[]) public vestings; // Allow multiple vesting schedules

    /// @notice Mapping to track the total amount swapped by users for OPTION3 (1:1 swap without vesting).
    mapping(address beneficiary => uint256 swappedAmount) public option3SwappedAmounts;

    /// @notice Emitted when a trusted remote address is set.
    /// @param remoteChainId The chain ID of the remote chain.
    /// @param remoteAddress The address of the trusted contract on the remote chain.
    event TrustedRemoteAddressSet(uint16 remoteChainId, address remoteAddress);

    /// @notice Emitted when a vesting schedule is created.
    /// @param holder The address of the holder.
    /// @param swappedAmount The amount of tokens swapped.
    /// @param swapOption The swap option selected.
    event VestingCreated(address indexed holder, uint256 indexed swappedAmount, Enums.SwapOptions swapOption);

    /// @notice Emitted when tokens are released.
    /// @param sender The address of the sender.
    /// @param beneficiary The address of the beneficiary.
    /// @param releasedAmount The amount of tokens released.
    /// @param feeAmount The amount of tokens transferred to the fee receiver.
    event TokensReleased(
        address indexed sender, address indexed beneficiary, uint256 indexed releasedAmount, uint256 feeAmount
    );

    /// @notice Emitted when tokens are claimed.
    /// @param sender The address of the sender.
    /// @param beneficiary The address of the beneficiary.
    /// @param claimedAmount The amount of tokens claimed.
    event TokensClaimed(address indexed sender, address indexed beneficiary, uint256 indexed claimedAmount);

    /// @notice Emitted when tokens are swapped.
    /// @param sender The address of the sender.
    /// @param swappedAmount The amount of tokens swapped.
    event TokensSwapped(address indexed sender, uint256 indexed swappedAmount);

    /// @notice Emitted when the fee receiver address is updated.
    /// @param feeReceiver The new fee receiver address.
    event FeeReceiverUpdated(address feeReceiver);

    /// @notice Emitted when the platform fee is updated.
    /// @param fee The new platform fee.
    event PlatformFeeUpdated(uint256 fee);

    /// @notice Emitted when the swap close time is updated.
    /// @param newSwapCloseTime The new swap close time.
    event SwapCloseTimeUpdated(uint32 newSwapCloseTime);

    /// @notice Emitted when the claim period is opened by the contract owner.
    /// @param claimIsOpen The boolean value indicating whether the claim period is open.
    event ClaimOpenSet(bool claimIsOpen);

    /// @notice Emitted when the owner withdraws excess tokens.
    /// @param owner The address of the contract owner who initiated the withdrawal.
    /// @param receiver The address receiving the excess tokens.
    /// @param amount The amount of tokens withdrawn.
    /// @param timestamp The time when the withdrawal occurred.
    event ExcessTokensWithdrawn(address indexed owner, address indexed receiver, uint256 amount, uint256 timestamp);

    /// @notice Initializes the contract.
    /// @param _owner The owner of the contract.
    /// @param _artcoin The Artcoin token contract address.
    /// @param _lzEndpoint The LayerZero endpoint address.
    /// @param _srcChainId The source chain ID for cross-chain vesting.
    /// @param _swapBonusOp1 The swap bonus for option 1.
    /// @param _swapBonusOp2 The swap bonus for option 2.
    /// @param _feeReceiver The address to receive the platform fees.
    /// @param _swapCloseTime The time when swap period ends.
    constructor(
        address _owner,
        address _artcoin,
        address _lzEndpoint,
        uint16 _srcChainId,
        uint16 _swapBonusOp1,
        uint16 _swapBonusOp2,
        address _feeReceiver,
        uint32 _swapCloseTime
    ) Ownable2Step() NonblockingLzApp(_lzEndpoint) Ownable(_owner) {
        if (_owner == address(0) || _artcoin == address(0) || _lzEndpoint == address(0) || _feeReceiver == address(0)) {
            revert Errors.ZeroAddressProvided();
        }
        if (_swapBonusOp1 > Constants.MAX_BPS || _swapBonusOp2 > Constants.MAX_BPS) revert Errors.FeeTooHigh();

        artcoin = Artcoin(_artcoin);
        feeReceiver = _feeReceiver;
        platformFee = 5_00; // 5% - default platform fee

        if (_lzEndpoint == 0x6EDCE65403992e310A62460808c4b910D972f10f) {
            //0x55370E0fBB5f5b8dAeD978BA1c075a499eB107B8
            endpoint = ILayerZeroEndpoint(_lzEndpoint); // Polygon Lz Endpoint
            srcChainId = 10102; // Binance Chain _srcChainId
        } else {
            endpoint = ILayerZeroEndpoint(_lzEndpoint);
            srcChainId = _srcChainId;
        }

        defaultBonuses = SwapBonuses({swapBonusOp1: _swapBonusOp1, swapBonusOp2: _swapBonusOp2});

        if (_swapCloseTime == 0) {
            swapCloseTime = uint32(block.timestamp);
        } else {
            swapCloseTime = _swapCloseTime;
        }
    }

    /// @notice Handles incoming messages from LayerZero.
    /// @param _srcChainId The source chain ID.
    /// @param _srcAddress The source address on the source chain.
    /// @param _nonce The message nonce.
    /// @param _payload The message payload.
    function _nonblockingLzReceive(uint16 _srcChainId, bytes memory _srcAddress, uint64 _nonce, bytes memory _payload)
        internal
        override
    {
        (_srcChainId, _srcAddress, _nonce);
        (address account, uint256 amount, Enums.SwapOptions swapOp) =
            abi.decode(_payload, (address, uint256, Enums.SwapOptions));

        if (swapOp == Enums.SwapOptions.OPTION3) {
            // Track the user's swapped amount but don't create vesting schedule
            option3SwappedAmounts[account] += amount;
            totalRequiredTokens += amount;
            emit TokensSwapped(account, amount);
        } else {
            _createVestingSchedule(account, amount, swapOp);
        }
    }

    /// @notice Creates a vesting schedule for a beneficiary.
    /// @param _beneficiary The address of the beneficiary.
    /// @param _amount The amount of tokens to be vested.
    /// @param _swapOp The swap option selected.
    function _createVestingSchedule(address _beneficiary, uint256 _amount, Enums.SwapOptions _swapOp) internal {
        // No checks for input data since they were validated on CrossChainSwap side
        uint16 index = uint16(vestings[_beneficiary].length); // Use the length of the array as the index

        VestingSchedule memory V;
        V.start = swapCloseTime; // Vesting starts after the swap period ends
        V.released = 0;
        V.totalAmount = _amount;
        V.index = index;
        V.swapOption = _swapOp; // Store the swap option chosen by the user

        if (_swapOp == Enums.SwapOptions.OPTION1) {
            V.cliff = uint32(swapCloseTime + Constants.SECONDS_PER_HALF_YEAR); // Cliff period is 6 months (in seconds)
            V.duration = uint32(Constants.SECONDS_PER_YEAR); // Vesting duration is 12 months (in seconds)
            V.totalAmountWithBonus = _amount + (_amount * defaultBonuses.swapBonusOp1) / Constants.MAX_BPS;
            V.bonusPercentage = uint16(defaultBonuses.swapBonusOp1); // Bonus percentage is 25%
        } else if (_swapOp == Enums.SwapOptions.OPTION2) {
            V.cliff = uint32(swapCloseTime + Constants.SECONDS_PER_YEAR);
            V.duration = uint32(Constants.SECONDS_PER_YEAR_AND_HALF);
            V.totalAmountWithBonus = _amount + (_amount * defaultBonuses.swapBonusOp2) / Constants.MAX_BPS;
            V.bonusPercentage = uint16(defaultBonuses.swapBonusOp2);
        } else {
            revert Errors.UnsupportedSwapOption();
        }

        // Update total amount with bonus across all users
        totalRequiredTokens += V.totalAmountWithBonus;

        vestings[_beneficiary].push(V); // Store the vesting schedule for the beneficiary

        emit VestingCreated(_beneficiary, _amount, _swapOp);
    }

    /// @notice Allows a user to claim their tokens after the claim period has started.
    /// @dev The claim can only be processed if the claim period is open and the swapCloseTime has passed.
    ///      The function checks the user's swapped amount for OPTION3, clears it, and transfers the tokens.
    /// @param _beneficiary The address of the beneficiary claiming the tokens.
    function claim(address _beneficiary) external nonReentrant {
        if (uint32(block.timestamp) < swapCloseTime || !claimIsOpen) revert Errors.InitialClaimNotStartedYet();

        uint256 swappedAmount = option3SwappedAmounts[msg.sender];
        if (swappedAmount == 0) revert Errors.NoTokensToClaim();

        // Clear the swapped amount to prevent reentrancy or double claims
        option3SwappedAmounts[msg.sender] = 0;

        totalRequiredTokens -= swappedAmount;

        SafeTransferLib.safeTransfer(address(artcoin), _beneficiary, swappedAmount);

        emit TokensClaimed(msg.sender, _beneficiary, swappedAmount);
    }

    /// @notice Releases vested tokens for a beneficiary.
    /// @param _beneficiary The address of the beneficiary.
    /// @param _index The index of the vesting schedule.
    function release(address _beneficiary, uint256 _index) external nonReentrant {
        VestingSchedule storage V = vestings[msg.sender][_index];

        uint256 vested = vestedAmount(msg.sender, _index);
        uint256 unreleased = vested - V.released;

        if (unreleased == 0) revert Errors.NoTokensToRelease();

        V.released += unreleased;

        totalRequiredTokens -= unreleased;

        uint256 fee = (unreleased * platformFee) / Constants.MAX_BPS;
        uint256 amountAfterFee = unreleased - fee;

        SafeTransferLib.safeTransfer(address(artcoin), _beneficiary, amountAfterFee);
        SafeTransferLib.safeTransfer(address(artcoin), feeReceiver, fee);

        emit TokensReleased(msg.sender, _beneficiary, amountAfterFee, fee);
    }

    /// @notice Calculates the vested amount for a beneficiary.
    /// @param _beneficiary The address of the beneficiary.
    /// @param _index The index of the vesting schedule.
    /// @return The vested amount.
    function vestedAmount(address _beneficiary, uint256 _index) public view returns (uint256) {
        VestingSchedule memory V = vestings[_beneficiary][_index];

        if (block.timestamp < V.cliff) {
            return 0;
        } else if (block.timestamp >= V.duration + V.start) {
            return V.totalAmount + ((V.totalAmount * V.bonusPercentage) / Constants.MAX_BPS);
        } else {
            uint256 elapsedTime = block.timestamp - V.cliff;
            uint256 vestingPeriod = V.duration - (V.cliff - V.start);
            uint256 vested = (V.totalAmount * elapsedTime) / vestingPeriod;
            uint256 bonus = ((V.totalAmount * V.bonusPercentage) / Constants.MAX_BPS * elapsedTime) / vestingPeriod;
            return vested + bonus;
        }
    }

    /// @notice Returns all vesting schedules for the caller.
    /// @return The array of vesting schedules.
    function getVestings() external view returns (VestingSchedule[] memory) {
        uint256 count = vestings[msg.sender].length;
        VestingSchedule[] memory schedules = new VestingSchedule[](count);

        for (uint256 i; i < count; i++) {
            schedules[i] = vestings[msg.sender][i];
        }

        return schedules;
    }

    /// @notice Returns a specific vesting schedule by its index.
    /// @param index The index of the vesting schedule.
    /// @return The vesting schedule.
    function getVestingByIndex(uint256 index) external view returns (VestingSchedule memory) {
        return vestings[msg.sender][index];
    }

    /// @notice Returns all vesting schedules for the caller that have not been fully released yet.
    /// @return The array of vesting schedules.
    function getUnreleasedVestings() external view returns (VestingSchedule[] memory) {
        uint256 count = vestings[msg.sender].length;
        uint256 unreleasedCount;

        // Count the number of unreleased vesting schedules
        for (uint256 i = 0; i < count; i++) {
            if (vestings[msg.sender][i].released < vestings[msg.sender][i].totalAmountWithBonus) {
                unreleasedCount++;
            }
        }

        VestingSchedule[] memory unreleasedSchedules = new VestingSchedule[](unreleasedCount);
        uint256 index;

        // Populate the array with unreleased vesting schedules
        for (uint256 i = 0; i < count; i++) {
            if (vestings[msg.sender][i].released < vestings[msg.sender][i].totalAmountWithBonus) {
                unreleasedSchedules[index] = vestings[msg.sender][i];
                index++;
            }
        }

        return unreleasedSchedules;
    }

    /// @notice Returns the number of vesting schedules for a given beneficiary.
    /// @return The number of vesting schedules for the given beneficiary.
    function getVestingCount() external view returns (uint256) {
        return vestings[msg.sender].length;
    }

    /// @notice Updates the fee receiver address.
    /// @param _feeReceiver The new fee receiver address.
    function updateFeeReceiver(address _feeReceiver) external onlyOwner {
        if (_feeReceiver == address(0)) revert Errors.ZeroAddressProvided();
        feeReceiver = _feeReceiver;
        emit FeeReceiverUpdated(_feeReceiver);
    }

    /// @notice Updates the platform fee.
    /// @param _fee The new platform fee in basis points (bps).
    function updatePlatformFee(uint256 _fee) external onlyOwner {
        if (_fee > Constants.MAX_BPS / 2) revert Errors.FeeTooHigh();
        platformFee = _fee; // Can be zero
        emit PlatformFeeUpdated(_fee);
    }

    /// @notice Updates the swap close time.
    /// @dev Can only be called by the contract owner. If `_newSwapCloseTime` is zero, it sets the swap close time to the current block timestamp.
    /// @param _newSwapCloseTime The new swap close time as a UNIX timestamp.
    function updateSwapCloseTime(uint32 _newSwapCloseTime) external onlyOwner {
        if (_newSwapCloseTime == 0) {
            swapCloseTime = uint32(block.timestamp);
        } else {
            swapCloseTime = _newSwapCloseTime;
        }
        emit SwapCloseTimeUpdated(swapCloseTime);
    }

    /// @notice Opens the claim period to allow users to claim their tokens.
    /// @dev Only the contract owner can open the claim period by setting the `claimIsOpen` flag to true.
    function setClaimOpen() external onlyOwner {
        claimIsOpen = true;
        emit ClaimOpenSet(claimIsOpen);
    }

    /// @notice Withdraws excess tokens from the contract balance.
    /// @dev This function can only be called by the contract owner. It checks the contract's balance and allows the owner to withdraw any tokens that are not required for vesting or claims.
    /// @param _receiver The address to receive the withdrawn excess tokens.
    /// @param _amount The amount of tokens to withdraw.
    function withdrawExcessTokens(address _receiver, uint256 _amount) external onlyOwner nonReentrant {
        // Get the current contract balance
        uint256 contractBalance = artcoin.balanceOf(address(this));

        // Ensure there is an excess amount available for withdrawal
        if (contractBalance <= totalRequiredTokens) revert Errors.NoExcessTokensAvailableForWithdrawal();

        // Calculate the excess amount available for withdrawal
        uint256 excessAmount = contractBalance - totalRequiredTokens;
        if (_amount > excessAmount) revert Errors.RequestedAmountExceedsAvailableExcess();

        // Transfer the excess amount to the owner
        SafeTransferLib.safeTransfer(address(artcoin), _receiver, _amount);

        emit ExcessTokensWithdrawn(msg.sender, _receiver, _amount, block.timestamp);
    }

    /// @notice Transfers ownership of the contract to a new account (`newOwner`).
    /// @dev This internal function is an override of `_transferOwnership` from `Ownable` and `Ownable2Step`.
    /// @param newOwner The address of the new owner.
    function _transferOwnership(address newOwner) internal override(Ownable, Ownable2Step) {
        Ownable2Step._transferOwnership(newOwner);
    }

    /// @notice Transfers ownership of the contract to a new account (`newOwner`).
    /// @dev This function is an override of `transferOwnership` from `Ownable` and `Ownable2Step`.
    /// @param newOwner The address of the new owner.
    function transferOwnership(address newOwner) public override(Ownable, Ownable2Step) onlyOwner {
        Ownable2Step.transferOwnership(newOwner);
    }
}
