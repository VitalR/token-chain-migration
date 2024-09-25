// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {NonblockingLzApp, Ownable, ILayerZeroEndpoint} from "@layerzero-contracts/lzApp/NonblockingLzApp.sol";
import {Ownable2Step} from "@openzeppelin/access/Ownable2Step.sol";
import {ReentrancyGuard} from "@solbase/utils/ReentrancyGuard.sol";
import {SafeTransferLib} from "@solbase/utils/SafeTransferLib.sol";

import {Constants} from "src/libs/Constants.sol";
import {Enums} from "src/libs/Enums.sol";
import {Errors} from "src/libs/Errors.sol";
import {IBEP20} from "src/token/IBEP20.sol";
import {Pausable} from "src/libs/Pausable.sol";

/// @title CrossChainSwap
/// @notice A contract for swapping Artcoin tokens across different blockchains using LayerZero.
contract CrossChainSwap is Ownable2Step, NonblockingLzApp, Pausable, ReentrancyGuard {
    /// @notice The Artcoin BEP20 token contract.
    IBEP20 public immutable artcoinBEP20;

    /// @notice The minimum amount of tokens required to perform a swap.
    /// @dev Set initially to 5000 philcoins to ensure swaps meet economic thresholds for processing.
    uint256 public minSwapThreshold;

    /// @notice Start time for the swap period.
    uint128 public swapStartTime;

    /// @notice End time for the swap period.
    uint128 public swapEndTime;

    /// @notice The LayerZero endpoint instance.
    ILayerZeroEndpoint public immutable endpoint;

    /// @notice The destination chain ID for cross-chain swaps.
    uint16 public immutable destChainId;

    /// @notice Mapping to track total swapped amounts for each swap option.
    mapping(Enums.SwapOptions => uint256) public totalSwappedAmount;

    /// @notice Emitted when the minimum swap threshold is updated.
    /// @param newThreshold The new minimum swap threshold.
    event MinSwapThresholdUpdated(uint256 newThreshold);

    /// @notice Emitted when the swap window is set.
    /// @param startTime The start time of the swap window.
    /// @param endTime The end time of the swap window.
    event SwapWindowSet(uint128 startTime, uint128 endTime);

    /// @notice Emitted when a trusted remote address is set.
    /// @param remoteChainId The chain ID of the remote chain.
    /// @param remoteAddress The address of the trusted contract on the remote chain.
    event TrustedRemoteAddressSet(uint16 remoteChainId, address remoteAddress);

    /// @notice Emitted when tokens are swapped and the total swapped amount is updated.
    /// @param swapper The address of the user performing the swap.
    /// @param amount The amount of tokens swapped in this transaction.
    /// @param swapOption The swap option chosen by the user (e.g., OPTION1 or OPTION2).
    /// @param totalSwapped The updated total amount of tokens swapped for the selected swap option.
    event TokensSwapped(address indexed swapper, uint256 amount, Enums.SwapOptions swapOption, uint256 totalSwapped);

    /// @notice Initializes the contract.
    /// @param _owner The owner of the contract.
    /// @param _artcoinBEP20 The Artcoin BEP20 token contract address.
    /// @param _lzEndpoint The LayerZero endpoint address.
    /// @param _destChainId The destination chain ID for cross-chain swaps.
    constructor(address _owner, address _artcoinBEP20, address _lzEndpoint, uint16 _destChainId)
        Ownable2Step()
        NonblockingLzApp(_lzEndpoint)
        Ownable(_owner)
    {
        if (_owner == address(0) || _artcoinBEP20 == address(0) || _lzEndpoint == address(0)) {
            revert Errors.ZeroAddressProvided();
        }

        if (_lzEndpoint == 0x6EDCE65403992e310A62460808c4b910D972f10f) {
            endpoint = ILayerZeroEndpoint(_lzEndpoint); // BNB Lz Endpoint
            destChainId = 40267; // Polygon Lz destChainId
        } else {
            endpoint = ILayerZeroEndpoint(_lzEndpoint);
            destChainId = _destChainId;
        }

        artcoinBEP20 = IBEP20(_artcoinBEP20);
        minSwapThreshold = 5000 ether;
    }

    /// @notice Swaps the entire balance of Artcoin tokens of the caller to the destination chain.
    /// @param _swapOp The swap option selected.
    function swap(Enums.SwapOptions _swapOp) external payable whenNotPaused nonReentrant {
        if (swapStartTime == 0 || swapEndTime == 0) revert Errors.SwapTimesNotSet();
        if (uint128(block.timestamp) < swapStartTime || uint128(block.timestamp) > swapEndTime) {
            revert Errors.SwapPeriodNotActive();
        }

        uint256 balance = artcoinBEP20.balanceOf(msg.sender);
        if (balance == 0) revert Errors.NothingToSwap();
        if (balance < minSwapThreshold) revert Errors.AmountBelowMinimumSwapThreshold();

        _swap(balance, _swapOp);
    }

    /// @notice Swaps a specified amount of Artcoin tokens of the caller to the destination chain.
    /// @param _amountToSwap The amount of tokens to swap.
    /// @param _swapOp The swap option selected.
    function swapAmount(uint256 _amountToSwap, Enums.SwapOptions _swapOp) external payable whenNotPaused nonReentrant {
        if (swapStartTime == 0 || swapEndTime == 0) revert Errors.SwapTimesNotSet();
        if (uint128(block.timestamp) < swapStartTime || uint128(block.timestamp) > swapEndTime) {
            revert Errors.SwapPeriodNotActive();
        }

        uint256 balance = artcoinBEP20.balanceOf(msg.sender);
        if (balance == 0) revert Errors.NothingToSwap();
        if (_amountToSwap > balance) revert Errors.InsufficientAmountToSwap();
        if (_amountToSwap < minSwapThreshold) revert Errors.AmountBelowMinimumSwapThreshold();

        _swap(_amountToSwap, _swapOp);
    }

    /// @notice Internal function to handle the token swap logic.
    /// @param _amountToSwap The amount of tokens to swap.
    /// @param _swapOp The swap option selected.
    function _swap(uint256 _amountToSwap, Enums.SwapOptions _swapOp) private {
        SafeTransferLib.safeTransferFrom(address(artcoinBEP20), msg.sender, Constants.DEAD_ADDRESS, _amountToSwap);

        totalSwappedAmount[_swapOp] += _amountToSwap;

        emit TokensSwapped(msg.sender, _amountToSwap, _swapOp, totalSwappedAmount[_swapOp]);

        bytes memory payload = abi.encode(msg.sender, _amountToSwap, _swapOp);
        _lzSend(destChainId, payload, payable(msg.sender), address(0), bytes(""), msg.value);
    }

    /// @notice Handles incoming messages from LayerZero.
    /// @param _srcChainId The source chain ID.
    /// @param _srcAddress The source address on the source chain.
    /// @param _nonce The message nonce.
    /// @param _payload The message payload.
    function _nonblockingLzReceive(uint16 _srcChainId, bytes memory _srcAddress, uint64 _nonce, bytes memory _payload)
        internal
        pure
        override
    {
        (_srcChainId, _srcAddress, _nonce, _payload);
        // Purposefully empty if no incoming messages are expected
        revert("No incoming data expected.");
    }

    /// @notice Estimates the fees required for sending a LayerZero message.
    /// @param _payload The message payload.
    /// @return nativeFee The estimated native fee for the message.
    function estimateLzSendFees(bytes memory _payload) external view returns (uint256 nativeFee) {
        (nativeFee,) = endpoint.estimateFees(destChainId, address(this), _payload, false, "");
        return nativeFee;
    }

    /// @notice Updates the minimum swap threshold.
    /// @dev Can only be called by the contract owner. Used to adjust the economic threshold for swaps.
    /// @param _newThreshold The new minimum amount of tokens required to perform a swap, specified in wei.
    function updateMinSwapThreshold(uint256 _newThreshold) external onlyOwner {
        if (_newThreshold == 0) revert Errors.NeedsMoreThanZero();
        minSwapThreshold = _newThreshold;
        emit MinSwapThresholdUpdated(_newThreshold);
    }

    /// @notice Sets the start and end times for the swap period.
    /// @param _startTime The Unix timestamp for the start of the swap period.
    /// @param _endTime The Unix timestamp for the end of the swap period.
    /// @dev The start time must be before the end time.
    function setSwapWindow(uint128 _startTime, uint128 _endTime) external onlyOwner {
        if (_startTime >= _endTime) revert Errors.StartTimeMustBeBeforeEndTime();
        if (_endTime <= block.timestamp) revert Errors.EndTimeInPast();
        swapStartTime = _startTime;
        swapEndTime = _endTime;
        emit SwapWindowSet(_startTime, _endTime);
    }

    /// @notice Pauses the contract, preventing new swaps from being processed.
    function pause() public onlyOwner {
        _pause();
    }

    /// @notice Unpauses the contract, allowing new swaps to be processed.
    function unpause() public onlyOwner {
        _unpause();
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
