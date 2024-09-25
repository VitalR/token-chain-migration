// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {Test, stdError, console2} from "@forge-std/Test.sol";

import {CrossChainSwap, Ownable} from "src/CrossChainSwap.sol";
import {CrossChainVesting} from "src/CrossChainVesting.sol";
import {ArtcoinBEP20} from "src/token/ArtcoinBEP20.sol";
import {Artcoin} from "src/token/ArtcoinERC20.sol";
import {LZEndpointMock} from "lib/solidity-examples/contracts/lzApp/mocks/LZEndpointMock.sol";
import {MockERC20} from "test/mocks/MockERC20.sol";
import {MockERC20FailedMint} from "test/mocks/MockERC20FailedMint.sol";
import {Constants} from "src/libs/Constants.sol";
import {Enums} from "src/libs/Enums.sol";
import {Errors} from "src/libs/Errors.sol";

contract CrossChainVestingSwapUnitTest is Test {
    CrossChainSwap crossChainSwap;
    CrossChainVesting vesting;
    ArtcoinBEP20 artcoinBEP20;
    Artcoin artcoinERC20;
    LZEndpointMock bnbLzEndpoint;
    LZEndpointMock polLzEndpoint;

    address owner;
    uint256 startTime;
    uint256 vestingAmount;
    uint256 vestingAmountWithBonusOp1;
    uint256 vestingAmountWithBonusOp2;
    uint32 swapCloseTime;

    uint16 bnbLzChainId;
    uint16 polLzChainId;

    Enums.SwapOptions swapOP;

    event VestingCreated(address indexed holder, uint256 indexed swappedAmount, Enums.SwapOptions swapOption);
    event TokensReleased(
        address indexed sender, address indexed beneficiary, uint256 indexed releasedAmount, uint256 fee
    );
    event TokensClaimed(address indexed sender, address indexed beneficiary, uint256 indexed claimedAmount);
    event TokensSwapped(address indexed sender, uint256 indexed swappedAmount);
    event FeeReceiverUpdated(address feeReceiver);
    event PlatformFeeUpdated(uint256 fee);
    event SwapCloseTimeUpdated(uint32 newSwapCloseTime);
    event ClaimOpenSet(bool claimIsOpen);
    event ExcessTokensWithdrawn(address indexed owner, address indexed receiver, uint256 amount, uint256 timestamp);

    function setUp() public {
        bnbLzChainId = 10102;
        polLzChainId = 10267;

        vestingAmount = 5000 ether;
        vestingAmountWithBonusOp1 = vestingAmount + (vestingAmount * 25_00) / Constants.MAX_BPS;
        vestingAmountWithBonusOp2 = vestingAmount + (vestingAmount * 50_00) / Constants.MAX_BPS;

        owner = makeAddr("owner");

        artcoinERC20 = new Artcoin(owner);
        bnbLzEndpoint = new LZEndpointMock(bnbLzChainId);
        polLzEndpoint = new LZEndpointMock(polLzChainId);
        artcoinBEP20 = new ArtcoinBEP20("MockART", "MockART");
        crossChainSwap = new CrossChainSwap(address(owner), address(artcoinBEP20), address(bnbLzEndpoint), polLzChainId);

        swapCloseTime = uint32(block.timestamp + 1 days);
        vesting = new CrossChainVesting(
            address(owner),
            address(artcoinERC20),
            address(polLzEndpoint),
            bnbLzChainId,
            25_00,
            50_00,
            address(owner),
            swapCloseTime
        );
        bnbLzEndpoint.setDestLzEndpoint(address(vesting), address(polLzEndpoint));
        polLzEndpoint.setDestLzEndpoint(address(crossChainSwap), address(bnbLzEndpoint));
    }

    function test_setUpState() public view {
        assertEq(address(vesting.artcoin()), address(artcoinERC20));
        assertEq(address(vesting.endpoint()), address(polLzEndpoint));
        assertEq(address(vesting.owner()), address(owner));
        assertEq(address(vesting.feeReceiver()), address(owner));
        assertEq(vesting.platformFee(), 5_00);
        (uint16 swapBonusOp1, uint16 swapBonusOp2) = vesting.defaultBonuses();
        assertEq(swapBonusOp1, 25_00);
        assertEq(swapBonusOp2, 50_00);
        assertEq(vesting.swapCloseTime(), swapCloseTime);
        assertEq(vesting.totalRequiredTokens(), 0);
    }

    function test_setUp_crossChainParams() public {
        // Polygon Amoy (Testnet)
        uint16 endpointId = 10102;
        address lzEndpoint = 0x55370E0fBB5f5b8dAeD978BA1c075a499eB107B8;
        vesting = new CrossChainVesting(
            address(owner),
            address(artcoinERC20),
            address(lzEndpoint),
            bnbLzChainId,
            25_00,
            50_00,
            address(owner),
            swapCloseTime
        );
        // crossChainSwap = new CrossChainSwap(address(owner), address(artcoinBEP20), address(lzEndpoint), 0);
        assertEq(address(vesting.endpoint()), address(lzEndpoint));
        assertEq(vesting.srcChainId(), endpointId);
    }

    function test_setUpState_revert() public {
        vm.expectRevert(Errors.ZeroAddressProvided.selector);
        CrossChainVesting vesting2 = new CrossChainVesting(
            address(owner),
            address(0),
            address(polLzEndpoint),
            polLzChainId,
            25_00,
            50_00,
            address(owner),
            swapCloseTime
        );
        vm.expectRevert(Errors.ZeroAddressProvided.selector);
        vesting2 = new CrossChainVesting(
            address(owner), address(artcoinBEP20), address(0), polLzChainId, 25_00, 50_00, address(owner), swapCloseTime
        );
        vm.expectRevert(); // OwnableInvalidOwner(0x0000000000000000000000000000000000000000)
        vesting2 = new CrossChainVesting(
            address(0),
            address(artcoinBEP20),
            address(polLzEndpoint),
            polLzChainId,
            25_00,
            50_00,
            address(owner),
            swapCloseTime
        );
        vm.expectRevert();
        vesting2 = new CrossChainVesting(
            address(0), address(0), address(0), polLzChainId, 25_00, 50_00, address(owner), swapCloseTime
        );
        vm.expectRevert();
        vesting2 = new CrossChainVesting(
            address(owner), address(0), address(polLzEndpoint), polLzChainId, 25_00, 50_00, address(0), swapCloseTime
        );
        vm.expectRevert(Errors.FeeTooHigh.selector);
        vesting2 = new CrossChainVesting(
            address(owner),
            address(artcoinBEP20),
            address(polLzEndpoint),
            polLzChainId,
            101_00,
            50_00,
            address(owner),
            swapCloseTime
        );
        vm.expectRevert(Errors.FeeTooHigh.selector);
        vesting2 = new CrossChainVesting(
            address(owner),
            address(artcoinBEP20),
            address(polLzEndpoint),
            polLzChainId,
            25_00,
            101_00,
            address(owner),
            swapCloseTime
        );
        vm.expectRevert(Errors.FeeTooHigh.selector);
        vesting2 = new CrossChainVesting(
            address(owner),
            address(artcoinBEP20),
            address(polLzEndpoint),
            polLzChainId,
            101_00,
            101_00,
            address(owner),
            swapCloseTime
        );
    }

    function test_setTrustedRemoteAddress() public {
        // Start by assuming no trust is established.
        assertFalse(vesting.isTrustedRemote(bnbLzChainId, abi.encodePacked(address(crossChainSwap), address(vesting))));

        address notOwner = makeAddr("notOwner");
        vm.prank(notOwner);
        vm.expectRevert(); // OwnableUnauthorizedAccount(account)
        vesting.setTrustedRemoteAddress(polLzChainId, abi.encodePacked(address(vesting)));

        vm.startPrank(owner);
        // Establish trust from Vesting contract to Swap contract
        vesting.setTrustedRemoteAddress(bnbLzChainId, abi.encodePacked(address(crossChainSwap)));
        assertTrue(vesting.isTrustedRemote(bnbLzChainId, abi.encodePacked(address(crossChainSwap), address(vesting))));

        // Ensure that the remote address is correctly stored and retrievable
        bytes memory trustedRemote = vesting.trustedRemoteLookup(bnbLzChainId);
        assertTrue(trustedRemote.length > 0);

        // Similarly, establish trust from Swap contract to Vesting contract
        crossChainSwap.setTrustedRemoteAddress(polLzChainId, abi.encodePacked(address(vesting)));
        vm.stopPrank();
    }

    // Helper
    function estimateLzSendFees(address sender, uint256 amount, Enums.SwapOptions swapOp)
        public
        view
        returns (uint256)
    {
        // uint256 balance = artcoinBEP20.balanceOf(owner);
        bytes memory payload = abi.encode(sender, amount, swapOp);
        uint256 nativeFee = crossChainSwap.estimateLzSendFees(payload);
        return nativeFee;
    }

    function createSwap(Enums.SwapOptions swapOp) public {
        setSwapWindow();
        test_setTrustedRemoteAddress();
        vm.prank(owner);
        artcoinBEP20.claim();
        assertEq(artcoinBEP20.balanceOf(owner), 5000 ether);
        uint256 userBalance = artcoinBEP20.balanceOf(owner);

        vm.deal(owner, 1 ether);
        vm.startPrank(owner);
        artcoinBEP20.approve(address(crossChainSwap), 5000 ether);
        uint256 lzFee = estimateLzSendFees(owner, userBalance, swapOp);
        vm.expectEmit(true, true, true, true);
        emit VestingCreated(owner, 5000 ether, swapOp);
        crossChainSwap.swap{value: lzFee}(swapOp);
        assertEq(artcoinBEP20.balanceOf(owner), 0);
        startTime = block.timestamp;
        vm.stopPrank();
    }

    function setSwapWindow() public {
        vm.startPrank(owner);
        crossChainSwap.setSwapWindow(uint128(block.timestamp), uint128(swapCloseTime));
        vm.stopPrank();
    }

    // Function to calculate the first 4 bytes of the hash of "UntrustedSourceAddress()"
    function test_getErrorSignature() public pure returns (bytes4) {
        return bytes4(keccak256("UntrustedSourceAddress()"));
    }

    function test_vestingCreated_option1() public {
        Enums.SwapOptions swapOp = Enums.SwapOptions.OPTION1;
        createSwap(swapOp);
        vm.prank(owner);
        uint256 indexVesting = vesting.getVestingCount();
        assertEq(indexVesting, 1);
        // uint256 vestingAmount = 100 ether + (100 ether * 25_00) / Constants.MAX_BPS;
        (
            uint256 cliff,
            uint256 duration,
            uint256 start,
            uint256 totalAmount,
            uint256 totalAmountWithBonus,
            uint256 released,
            uint256 bonusPercentage,
            uint256 index,
            Enums.SwapOptions swapOP_
        ) = vesting.vestings(owner, --indexVesting);
        assertEq(cliff, swapCloseTime + Constants.SECONDS_PER_HALF_YEAR);
        assertEq(duration, Constants.SECONDS_PER_YEAR);
        assertEq(start, swapCloseTime);
        assertEq(totalAmount, vestingAmount);
        assertEq(totalAmountWithBonus, vestingAmountWithBonusOp1);
        assertEq(released, 0);
        assertEq(bonusPercentage, 25_00);
        assertEq(indexVesting, index);
        assertEq(uint256(swapOP_), 0);

        vm.prank(owner);
        CrossChainVesting.VestingSchedule memory vestingInfo = vesting.getVestingByIndex(index);
        assertEq(vestingInfo.cliff, swapCloseTime + Constants.SECONDS_PER_HALF_YEAR);
        assertEq(vestingInfo.duration, Constants.SECONDS_PER_YEAR);
        assertEq(vestingInfo.start, swapCloseTime);
        assertEq(vestingInfo.totalAmount, vestingAmount);
        assertEq(vestingInfo.totalAmountWithBonus, vestingAmountWithBonusOp1);
        assertEq(vestingInfo.released, 0);
        assertEq(vestingInfo.bonusPercentage, 25_00);
        assertEq(vestingInfo.index, 0);

        assertEq(vesting.totalRequiredTokens(), vestingAmountWithBonusOp1);
    }

    function test_vestingCreated_option2() public {
        Enums.SwapOptions swapOp = Enums.SwapOptions.OPTION2;
        createSwap(swapOp);
        vm.prank(owner);
        uint256 indexVesting = vesting.getVestingCount();
        assertEq(indexVesting, 1);
        // uint256 vestingAmount = 100 ether + (100 ether * 50_00) / Constants.MAX_BPS;
        (
            uint256 cliff,
            uint256 duration,
            uint256 start,
            uint256 totalAmount,
            uint256 totalAmountWithBonus,
            uint256 released,
            uint256 bonusPercentage,
            uint256 index,
            Enums.SwapOptions swapOP_
        ) = vesting.vestings(owner, --indexVesting);
        assertEq(cliff, swapCloseTime + Constants.SECONDS_PER_YEAR);
        assertEq(duration, Constants.SECONDS_PER_YEAR_AND_HALF);
        assertEq(start, swapCloseTime);
        assertEq(totalAmount, vestingAmount);
        assertEq(totalAmountWithBonus, vestingAmountWithBonusOp2);
        assertEq(released, 0);
        assertEq(bonusPercentage, 50_00);
        assertEq(uint256(swapOP_), 1);

        vm.prank(owner);
        CrossChainVesting.VestingSchedule memory vestingInfo = vesting.getVestingByIndex(index);
        assertEq(vestingInfo.cliff, swapCloseTime + Constants.SECONDS_PER_YEAR);
        assertEq(vestingInfo.duration, Constants.SECONDS_PER_YEAR_AND_HALF);
        assertEq(vestingInfo.start, swapCloseTime);
        assertEq(vestingInfo.totalAmount, vestingAmount);
        assertEq(vestingInfo.totalAmountWithBonus, vestingAmountWithBonusOp2);
        assertEq(vestingInfo.released, 0);
        assertEq(vestingInfo.bonusPercentage, 50_00);

        assertEq(vesting.totalRequiredTokens(), vestingAmountWithBonusOp2);
    }

    function test_vestedAmount_option1_noVesting() public {
        test_vestingCreated_option1();
        vm.prank(address(this)); // user without vesting schedule
        vm.expectRevert(); //panic: array out-of-bounds access (0x32)
        uint256 amountToRelease = vesting.vestedAmount(address(this), 0);
        assertEq(amountToRelease, 0);
    }

    function test_vestedAmount_option1_beforeCliff() public {
        test_vestingCreated_option1();
        skip(startTime + 90 days); // Move forward 3 months (before cliff)
        vm.prank(owner);
        uint256 indexVesting = vesting.getVestingCount();
        assertEq(indexVesting, 1);
        (
            uint256 cliff,
            uint256 duration,
            uint256 start,
            uint256 totalAmount,
            uint256 totalAmountWithBonus,
            uint256 released,
            uint256 bonusPercentage,
            uint256 index,
        ) = vesting.vestings(owner, --indexVesting);
        assertEq(cliff, swapCloseTime + Constants.SECONDS_PER_HALF_YEAR);
        assertEq(duration, Constants.SECONDS_PER_YEAR);
        assertEq(start, swapCloseTime);
        assertEq(totalAmount, vestingAmount);
        assertEq(totalAmountWithBonus, vestingAmountWithBonusOp1);
        assertEq(released, 0);
        assertEq(bonusPercentage, 25_00);
        assertEq(indexVesting, index);
        assertEq(vesting.vestedAmount(owner, index), 0);
    }

    function test_vestedAmount_option1_afterCliff() public {
        test_vestingCreated_option1();
        skip(startTime + 180 days); // Move forward 6 months (cliff)
        vm.prank(owner);
        uint256 indexVesting = vesting.getVestingCount();
        assertEq(indexVesting, 1);
        (
            uint256 cliff,
            uint256 duration,
            uint256 start,
            uint256 totalAmount,
            uint256 totalAmountWithBonus,
            uint256 released,
            uint256 bonusPercentage,
            uint256 index,
        ) = vesting.vestings(owner, --indexVesting);
        assertEq(cliff, swapCloseTime + Constants.SECONDS_PER_HALF_YEAR);
        assertEq(duration, Constants.SECONDS_PER_YEAR);
        assertEq(start, swapCloseTime);
        assertEq(totalAmount, vestingAmount);
        assertEq(totalAmountWithBonus, vestingAmountWithBonusOp1);
        assertEq(released, 0);
        assertEq(bonusPercentage, 25_00);
        assertEq(indexVesting, index);
        assertEq(vesting.vestedAmount(owner, index), 0);
    }

    function test_vestedAmount_option1_duringVesting() public {
        // Ensure vesting schedule is created
        test_vestingCreated_option1();

        // Move forward 9 months (6 months cliff + 3 months vesting period)
        // swapCloseTime = uint32(block.timestamp + 1 days); => + 1 days
        uint256 nineMonths = 1 days + Constants.SECONDS_PER_HALF_YEAR + Constants.SECONDS_PER_THREE_MONTHS;
        skip(nineMonths);

        // Perform the calculation
        vm.prank(owner);
        uint256 indexVesting = vesting.getVestingCount();
        uint256 vested = vesting.vestedAmount(owner, --indexVesting);

        // Expected vested amount (vestingAmount * proportion of time elapsed in vesting period)
        uint256 elapsedTime = Constants.SECONDS_PER_THREE_MONTHS; // Only 3 months of vesting period
        // Calculate the vesting period in seconds (6 months linear vesting)
        uint256 vestingPeriod = Constants.SECONDS_PER_HALF_YEAR;
        // Calculate the expected vested amount (linear vesting for the elapsed time)
        uint256 expectedVested = vestingAmount * elapsedTime / vestingPeriod;

        // Expected bonus amount (bonus applies proportionally over the vesting period)
        uint256 expectedBonus = (vestingAmount * 25_00 / Constants.MAX_BPS) * elapsedTime / vestingPeriod;

        // Assert the calculated vested amount matches expected vested + bonus
        uint256 expectedTotal = expectedVested + expectedBonus;

        // Define a small tolerance for rounding errors
        uint256 tolerance = 1e17; // 0.1 token in wei

        console2.log("test::Elapsed Time: ", elapsedTime);
        console2.log("test::Vesting Period: ", vestingPeriod);
        console2.log("test::Expected Vested: ", expectedVested);
        console2.log("test::Expected Bonus: ", expectedBonus);
        console2.log("test::Total Expected: ", expectedTotal);
        console2.log("test::Vested: ", vested);

        // Assert the calculated vested amount matches expected vested + bonus within the tolerance
        assertApproxEqAbs(vested, expectedTotal, tolerance);

        assertEq(vested, expectedTotal);
    }

    function test_vestedAmount_option1_afterFullVesting() public {
        test_vestingCreated_option1();

        // Move forward 12 months (6 months cliff + 6 months vesting period)
        uint256 twelveMonths = 1 days + Constants.SECONDS_PER_HALF_YEAR + Constants.SECONDS_PER_HALF_YEAR;
        skip(twelveMonths);

        vm.prank(owner);
        uint256 indexVesting = vesting.getVestingCount();
        uint256 vested = vesting.vestedAmount(owner, --indexVesting);

        // Expected vested amount should be the full amount plus the bonus after the full vesting period
        uint256 expectedVested = vestingAmount;
        uint256 expectedBonus = vestingAmount * 25_00 / Constants.MAX_BPS;
        uint256 expectedTotal = expectedVested + expectedBonus;

        console2.log("test::Expected Vested: ", expectedVested);
        console2.log("test::Expected Bonus: ", expectedBonus);
        console2.log("test::Total Expected: ", expectedTotal);
        console2.log("test::Vested: ", vested);

        // Assert the calculated vested amount matches expected vested + bonus
        assertEq(vested, expectedTotal);
    }

    function test_vestedAmount_option1_afterExtraTime() public {
        test_vestingCreated_option1();

        // Move forward 15 months (6 months cliff + 6 months vesting period + 3 extra months)
        uint256 fifteenMonths = 1 days + Constants.SECONDS_PER_HALF_YEAR + Constants.SECONDS_PER_HALF_YEAR
            + Constants.SECONDS_PER_THREE_MONTHS;
        skip(fifteenMonths);

        vm.prank(owner);
        uint256 indexVesting = vesting.getVestingCount();
        uint256 vested = vesting.vestedAmount(owner, --indexVesting);

        // Expected vested amount should be the full amount plus the bonus after the full vesting period
        uint256 expectedVested = vestingAmount;
        uint256 expectedBonus = vestingAmount * 25_00 / Constants.MAX_BPS;
        uint256 expectedTotal = expectedVested + expectedBonus;

        console2.log("test::Expected Vested: ", expectedVested);
        console2.log("test::Expected Bonus: ", expectedBonus);
        console2.log("test::Total Expected: ", expectedTotal);
        console2.log("test::Vested: ", vested);

        // Assert the calculated vested amount matches expected vested + bonus
        assertEq(vested, expectedTotal);
    }

    function test_vestedAmount_option2_noVesting() public {
        test_vestingCreated_option2();
        vm.prank(address(this)); // user without vesting schedule
        vm.expectRevert(); //panic: array out-of-bounds access (0x32)
        uint256 amountToRelease = vesting.vestedAmount(address(this), 0);
        assertEq(amountToRelease, 0);
    }

    function test_vestedAmount_option2_beforeCliff() public {
        test_vestingCreated_option2();
        skip(startTime + 90 days); // Move forward 3 months (before cliff)
        vm.prank(owner);
        uint256 indexVesting = vesting.getVestingCount();
        assertEq(indexVesting, 1);
        (
            uint256 cliff,
            uint256 duration,
            uint256 start,
            uint256 totalAmount,
            uint256 totalAmountWithBonus,
            uint256 released,
            uint256 bonusPercentage,
            uint256 index,
        ) = vesting.vestings(owner, --indexVesting);
        assertEq(cliff, swapCloseTime + Constants.SECONDS_PER_YEAR);
        assertEq(duration, Constants.SECONDS_PER_YEAR_AND_HALF);
        assertEq(start, swapCloseTime);
        assertEq(totalAmount, vestingAmount);
        assertEq(totalAmountWithBonus, vestingAmountWithBonusOp2);
        assertEq(released, 0);
        assertEq(bonusPercentage, 50_00);
        assertEq(indexVesting, index);
        assertEq(vesting.vestedAmount(owner, index), 0);
    }

    function test_vestedAmount_option2_afterCliff() public {
        test_vestingCreated_option2();
        skip(startTime + 180 days); // Move forward 6 months (cliff)
        vm.prank(owner);
        assertEq(vesting.vestedAmount(owner, 0), 0);
    }

    function test_vestedAmount_option2_duringVesting() public {
        // Ensure vesting schedule is created
        test_vestingCreated_option2();

        // Move forward 15 months (12 months cliff + 3 months vesting period)
        uint256 fifteenMonths = 1 days + Constants.SECONDS_PER_YEAR + Constants.SECONDS_PER_THREE_MONTHS;
        skip(fifteenMonths);

        // Perform the calculation
        vm.prank(owner);
        uint256 indexVesting = vesting.getVestingCount();
        uint256 vested = vesting.vestedAmount(owner, --indexVesting);

        // Expected vested amount (vestingAmount * proportion of time elapsed in vesting period)
        uint256 elapsedTime = Constants.SECONDS_PER_THREE_MONTHS; // Only 3 months of vesting period
        // Calculate the vesting period in seconds (6 months linear vesting)
        uint256 vestingPeriod = Constants.SECONDS_PER_HALF_YEAR;
        // Calculate the expected vested amount (linear vesting for the elapsed time)
        uint256 expectedVested = vestingAmount * elapsedTime / vestingPeriod;

        // Expected bonus amount (bonus applies proportionally over the vesting period)
        uint256 expectedBonus = (vestingAmount * 50_00 / Constants.MAX_BPS) * elapsedTime / vestingPeriod;

        // Assert the calculated vested amount matches expected vested + bonus
        uint256 expectedTotal = expectedVested + expectedBonus;

        // Define a small tolerance for rounding errors
        uint256 tolerance = 1e17; // 0.1 token in wei

        console2.log("test::Elapsed Time: ", elapsedTime);
        console2.log("test::Vesting Period: ", vestingPeriod);
        console2.log("test::Expected Vested: ", expectedVested);
        console2.log("test::Expected Bonus: ", expectedBonus);
        console2.log("test::Total Expected: ", expectedTotal);
        console2.log("test::Vested: ", vested);

        // Assert the calculated vested amount matches expected vested + bonus within the tolerance
        assertApproxEqAbs(vested, expectedTotal, tolerance);

        assertEq(vested, expectedTotal);
    }

    function test_vestedAmount_option2_afterFullVesting() public {
        test_vestingCreated_option2();

        // Move forward 18 months (12 months cliff + 6 months vesting period)
        uint256 eighteenMonths = 1 days + Constants.SECONDS_PER_YEAR + Constants.SECONDS_PER_HALF_YEAR;
        skip(eighteenMonths);

        vm.prank(owner);
        uint256 indexVesting = vesting.getVestingCount();
        uint256 vested = vesting.vestedAmount(owner, --indexVesting);

        // Expected vested amount should be the full amount plus the bonus after the full vesting period
        uint256 expectedVested = vestingAmount;
        uint256 expectedBonus = vestingAmount * 50_00 / Constants.MAX_BPS;
        uint256 expectedTotal = expectedVested + expectedBonus;

        console2.log("test::Expected Vested: ", expectedVested);
        console2.log("test::Expected Bonus: ", expectedBonus);
        console2.log("test::Total Expected: ", expectedTotal);
        console2.log("test::Vested: ", vested);

        // Assert the calculated vested amount matches expected vested + bonus
        assertEq(vested, expectedTotal);
    }

    function test_vestedAmount_option2_afterExtraTime() public {
        test_vestingCreated_option2();

        // Move forward 21 months (12 months cliff + 6 months vesting period + 3 extra months)
        uint256 twentyFirstMonths =
            1 days + Constants.SECONDS_PER_YEAR + Constants.SECONDS_PER_HALF_YEAR + Constants.SECONDS_PER_THREE_MONTHS;
        skip(twentyFirstMonths);

        vm.prank(owner);
        uint256 indexVesting = vesting.getVestingCount();
        uint256 vested = vesting.vestedAmount(owner, --indexVesting);

        // Expected vested amount should be the full amount plus the bonus after the full vesting period
        uint256 expectedVested = vestingAmount;
        uint256 expectedBonus = vestingAmount * 50_00 / Constants.MAX_BPS;
        uint256 expectedTotal = expectedVested + expectedBonus;

        console2.log("test::Expected Vested: ", expectedVested);
        console2.log("test::Expected Bonus: ", expectedBonus);
        console2.log("test::Total Expected: ", expectedTotal);
        console2.log("test::Vested: ", vested);

        // Assert the calculated vested amount matches expected vested + bonus
        assertEq(vested, expectedTotal);
    }

    // helper test
    function test_tokenAllocation() public {
        assertEq(artcoinERC20.balanceOf(address(vesting)), 0);
        vm.prank(owner);
        artcoinERC20.mint(address(vesting), vestingAmountWithBonusOp1 + vestingAmountWithBonusOp2);
        assertEq(artcoinERC20.balanceOf(address(vesting)), vestingAmountWithBonusOp1 + vestingAmountWithBonusOp2);
    }

    function test_release_afterFullVesting() public {
        test_vestedAmount_option1_afterFullVesting();
        test_tokenAllocation();
        vm.startPrank(owner);
        uint256 index = vesting.getVestingCount();
        uint256 vested = vesting.vestedAmount(owner, --index);
        assertEq(vested, vestingAmountWithBonusOp1);
        assertEq(artcoinERC20.balanceOf(owner), 0);
        uint256 fee = vested * 5_00 / Constants.MAX_BPS;
        uint256 amountAfterFee = vested - fee;
        vm.expectEmit(true, true, true, true);
        emit TokensReleased(owner, owner, amountAfterFee, fee);
        vesting.release(owner, index);
        assertEq(artcoinERC20.balanceOf(owner), amountAfterFee + fee);
        vm.stopPrank();
    }

    function test_release_reverts() public {
        test_vestedAmount_option1_afterFullVesting();
        vm.startPrank(owner);
        uint256 index = vesting.getVestingCount();
        uint256 vested = vesting.vestedAmount(owner, --index);
        assertEq(vested, vestingAmountWithBonusOp1);
        assertEq(artcoinERC20.balanceOf(owner), 0);
        vm.expectRevert(); //Unauthorized()
        vesting.release(owner, index);
        assertEq(artcoinERC20.balanceOf(owner), 0);
    }

    function test_release_to_beneficiary() public {
        test_vestedAmount_option1_afterFullVesting();
        test_tokenAllocation();
        vm.startPrank(owner);
        uint256 index = vesting.getVestingCount();
        uint256 vested = vesting.vestedAmount(owner, --index);
        assertEq(vested, vestingAmountWithBonusOp1);
        assertEq(artcoinERC20.balanceOf(address(this)), 0);
        uint256 fee = vested * 5_00 / Constants.MAX_BPS;
        uint256 amountAfterFee = vested - fee;
        vesting.release(address(this), index);
        assertEq(artcoinERC20.balanceOf(address(this)), amountAfterFee);
        assertEq(artcoinERC20.balanceOf(owner), fee);
        vm.stopPrank();
    }

    function test_release_beforeCliff() public {
        test_vestedAmount_option1_beforeCliff();
        vm.startPrank(owner);
        assertEq(artcoinERC20.balanceOf(owner), 0);
        assertEq(vesting.vestedAmount(owner, 0), 0);
        vm.expectRevert(Errors.NoTokensToRelease.selector);
        vesting.release(owner, 0);
        assertEq(artcoinERC20.balanceOf(owner), 0);
        vm.stopPrank();
    }

    function test_release_afterCliff() public {
        test_vestedAmount_option1_afterCliff();
        vm.startPrank(owner);
        assertEq(artcoinERC20.balanceOf(owner), 0);
        assertEq(vesting.vestedAmount(owner, 0), 0);
        vm.expectRevert(Errors.NoTokensToRelease.selector);
        vesting.release(owner, 0);
        assertEq(artcoinERC20.balanceOf(owner), 0);
        vm.stopPrank();
    }

    function test_release_duringVesting() public {
        test_vestedAmount_option1_duringVesting();
        (,,, uint256 totalAmount, uint256 totalAmountWithBonus, uint256 released,,,) = vesting.vestings(owner, 0);
        assertEq(totalAmount, vestingAmount);
        assertEq(totalAmountWithBonus, vestingAmountWithBonusOp1);
        assertEq(released, 0);
        assertEq(artcoinERC20.balanceOf(owner), 0);
        assertEq(artcoinERC20.balanceOf(address(this)), 0);
        test_tokenAllocation();
        vm.startPrank(owner);
        uint256 vested = vesting.vestedAmount(owner, 0);
        uint256 fee = (vested * vesting.platformFee()) / Constants.MAX_BPS;
        uint256 amountAfterFee = vested - fee;
        vesting.release(address(this), 0);
        assertEq(artcoinERC20.balanceOf(owner), fee);
        assertEq(artcoinERC20.balanceOf(address(this)), amountAfterFee);
        (,,, totalAmount, totalAmountWithBonus, released,,,) = vesting.vestings(owner, 0);
        assertEq(totalAmount, vestingAmount);
        assertEq(totalAmountWithBonus, vestingAmountWithBonusOp1);
        assertEq(released, vested);
        vm.stopPrank();
    }

    function test_release_duringVesting_and_afterFullVesting() public {
        test_vestedAmount_option2_duringVesting();
        (, uint256 duration,, uint256 totalAmount, uint256 totalAmountWithBonus, uint256 released,,,) =
            vesting.vestings(owner, 0);
        assertEq(totalAmount, vestingAmount);
        assertEq(totalAmountWithBonus, vestingAmountWithBonusOp2);
        assertEq(released, 0);
        assertEq(artcoinERC20.balanceOf(owner), 0);
        assertEq(artcoinERC20.balanceOf(address(this)), 0);
        test_tokenAllocation();
        vm.startPrank(owner);
        uint256 vested = vesting.vestedAmount(owner, 0);
        uint256 fee = (vested * vesting.platformFee()) / Constants.MAX_BPS;
        uint256 amountAfterFee = vested - fee;
        vesting.release(address(this), 0);
        assertEq(artcoinERC20.balanceOf(owner), fee);
        assertEq(artcoinERC20.balanceOf(address(this)), amountAfterFee);
        (, duration,, totalAmount, totalAmountWithBonus, released,,,) = vesting.vestings(owner, 0);
        assertEq(totalAmount, vestingAmount);
        assertEq(totalAmountWithBonus, vestingAmountWithBonusOp2);
        assertEq(released, vested);

        skip(duration);
        uint256 vestedAfterFullVesting = vesting.vestedAmount(owner, 0);
        assertEq(vestedAfterFullVesting, totalAmountWithBonus);
        uint256 releasableAmount = vestedAfterFullVesting - vested;
        uint256 feeForLeftTokens = (releasableAmount * vesting.platformFee()) / Constants.MAX_BPS;
        uint256 amountAfterFeeLeftTokens = releasableAmount - feeForLeftTokens;
        vesting.release(address(this), 0);
        assertEq(artcoinERC20.balanceOf(owner), fee + feeForLeftTokens);
        assertEq(artcoinERC20.balanceOf(address(this)), amountAfterFee + amountAfterFeeLeftTokens);
        (,,, totalAmount, totalAmountWithBonus, released,,,) = vesting.vestings(owner, 0);
        assertEq(totalAmount, vestingAmount);
        assertEq(totalAmountWithBonus, vestingAmountWithBonusOp2);
        assertEq(released, vestingAmountWithBonusOp2);

        skip(2 weeks);
        vestedAfterFullVesting = vesting.vestedAmount(owner, 0);
        vm.expectRevert(Errors.NoTokensToRelease.selector);
        vesting.release(address(this), 0);
        assertEq(artcoinERC20.balanceOf(owner), fee + feeForLeftTokens);
        assertEq(artcoinERC20.balanceOf(address(this)), amountAfterFee + amountAfterFeeLeftTokens);
    }

    // function test_release_reverts_MintFailed() public {
    //     // this test has it's own setup
    //     MockERC20FailedMint mockERC20failed = new MockERC20FailedMint();
    //     CrossChainVesting vesting2 = new CrossChainVesting(
    //         address(owner),
    //         address(mockERC20failed),
    //         address(polLzEndpoint),
    //         bnbLzChainId,
    //         25_00,
    //         50_00,
    //         address(owner),
    //         swapCloseTime
    //     );
    //     crossChainSwap =
    //         new CrossChainSwap(address(owner), address(artcoinBEP20), address(bnbLzEndpoint), polLzChainId);
    //     bnbLzEndpoint.setDestLzEndpoint(address(vesting2), address(polLzEndpoint));
    //     polLzEndpoint.setDestLzEndpoint(address(crossChainSwap), address(bnbLzEndpoint));

    //     setSwapWindow();

    //     vm.startPrank(owner);
    //     crossChainSwap.setTrustedRemoteAddress(polLzChainId, abi.encodePacked(address(vesting2)));
    //     assertTrue(
    //         crossChainSwap.isTrustedRemote(polLzChainId, abi.encodePacked(address(vesting2), address(crossChainSwap)))
    //     );
    //     vesting2.setTrustedRemoteAddress(bnbLzChainId, abi.encodePacked(address(crossChainSwap)));
    //     assertTrue(vesting2.isTrustedRemote(bnbLzChainId, abi.encodePacked(address(crossChainSwap), address(vesting2))));
    //     vm.stopPrank();

    //     vm.startPrank(owner);
    //     vm.deal(owner, 1 ether);
    //     // mockERC20failed.claim();
    //     assertEq(artcoinBEP20.balanceOf(owner), 5000 ether);
    //     artcoinBEP20.approve(address(crossChainSwap), 5000 ether);
    //     Enums.SwapOptions swapOp = Enums.SwapOptions.OPTION1;
    //     crossChainSwap.swap{value: 1.42e16}(swapOp);
    //     assertEq(artcoinBEP20.balanceOf(owner), 0 ether);

    //     // Move forward 12 months (6 months cliff + 6 months vesting period)
    //     uint256 twelveMonths = 1 days + Constants.SECONDS_PER_HALF_YEAR + Constants.SECONDS_PER_HALF_YEAR;
    //     skip(twelveMonths);

    //     uint256 vested = vesting2.vestedAmount(owner, 0);
    //     assertGt(vested, 0);

    //     vm.expectRevert(Errors.MintFailed.selector); //Errors.MintFailed()
    //     vesting2.release(owner, 0);

    //     vm.stopPrank();
    // }

    function test_updateFeeReceiver() public {
        assertEq(vesting.feeReceiver(), address(owner));
        vm.prank(address(this));
        vm.expectRevert(); //OwnableUnauthorizedAccount
        vesting.updateFeeReceiver(address(this));
        vm.startPrank(owner);
        vm.expectRevert(Errors.ZeroAddressProvided.selector);
        vesting.updateFeeReceiver(address(0));
        vm.expectEmit(true, true, true, true);
        emit FeeReceiverUpdated(address(0xABCD));
        vesting.updateFeeReceiver(address(0xABCD));
        assertEq(vesting.feeReceiver(), address(0xABCD));
        vm.stopPrank();
    }

    function test_updatePlatformFee() public {
        assertEq(vesting.platformFee(), 5_00);
        vm.prank(address(this));
        vm.expectRevert(); //OwnableUnauthorizedAccount
        vesting.updatePlatformFee(10_00);
        vm.startPrank(owner);
        vm.expectRevert(Errors.FeeTooHigh.selector);
        vesting.updatePlatformFee(51_00);
        vm.expectEmit(true, true, true, true);
        emit PlatformFeeUpdated(0);
        vesting.updatePlatformFee(0);
        assertEq(vesting.platformFee(), 0);
        vesting.updatePlatformFee(50_00);
        assertEq(vesting.platformFee(), 50_00);
        vm.stopPrank();
    }

    function test_nonblockingLzReceive_reverts() public {
        CrossChainVesting vesting2 = new CrossChainVesting(
            address(owner),
            address(artcoinERC20),
            address(polLzEndpoint),
            bnbLzChainId,
            25_00,
            50_00,
            address(owner),
            swapCloseTime
        );
        CrossChainSwap crossChainSwap2 =
            new CrossChainSwap(address(owner), address(artcoinBEP20), address(bnbLzEndpoint), polLzChainId);
        bnbLzEndpoint.setDestLzEndpoint(address(vesting2), address(polLzEndpoint));
        polLzEndpoint.setDestLzEndpoint(address(crossChainSwap2), address(bnbLzEndpoint));

        vm.startPrank(owner);
        crossChainSwap2.setSwapWindow(uint128(block.timestamp), swapCloseTime);
        crossChainSwap2.setTrustedRemoteAddress(polLzChainId, abi.encodePacked(address(vesting2)));
        assertTrue(
            crossChainSwap2.isTrustedRemote(polLzChainId, abi.encodePacked(address(vesting2), address(crossChainSwap2)))
        );
        // vesting2.setTrustedRemoteAddress(bnbLzChainId, abi.encodePacked(address(crossChainSwap2)));
        // assertTrue(vesting2.isTrustedRemote(bnbLzChainId, abi.encodePacked(address(crossChainSwap2), address(vesting2))));
        vm.stopPrank();

        vm.startPrank(owner);
        vm.deal(owner, 1 ether);
        artcoinBEP20.claim();
        assertEq(artcoinBEP20.balanceOf(owner), 5000 ether);
        artcoinBEP20.approve(address(crossChainSwap2), 5000 ether);
        Enums.SwapOptions swapOp = Enums.SwapOptions.OPTION1;
        crossChainSwap2.swap{value: 1.42e16}(swapOp);
        assertEq(artcoinBEP20.balanceOf(owner), 0 ether);
    }

    function test_createAndReleaseVestingOption1And2() public {
        vm.prank(owner);
        crossChainSwap.updateMinSwapThreshold(2500 ether);
        assertEq(artcoinBEP20.balanceOf(owner), 0 ether);

        setSwapWindow();
        test_setTrustedRemoteAddress();

        Enums.SwapOptions swapOp1 = Enums.SwapOptions.OPTION1;
        Enums.SwapOptions swapOp2 = Enums.SwapOptions.OPTION2;

        // createSwap(swapOp1);
        vm.deal(owner, 1 ether);
        vm.startPrank(owner);
        artcoinBEP20.claim();
        assertEq(artcoinBEP20.balanceOf(owner), 5000 ether);
        artcoinBEP20.approve(address(crossChainSwap), 5000 ether);
        uint256 lzFee = estimateLzSendFees(owner, 2500 ether, swapOp1);

        // Check allowance before calling swapAmount
        uint256 allowance = artcoinBEP20.allowance(owner, address(crossChainSwap));
        assertEq(allowance, 5000 ether);

        crossChainSwap.swapAmount{value: lzFee}(2500 ether, swapOp1);

        // Check balance after calling swapAmount
        uint256 balanceAfter = artcoinBEP20.balanceOf(owner);
        assertEq(balanceAfter, 2500 ether);
        startTime = block.timestamp;
        vm.stopPrank();

        // createSwap(swapOp2);
        vm.startPrank(owner);
        lzFee = estimateLzSendFees(owner, 2500 ether, swapOp2);

        crossChainSwap.swap{value: lzFee}(swapOp2);

        assertEq(artcoinBEP20.balanceOf(owner), 0);
        // startTime = block.timestamp;
        vm.stopPrank();

        vm.startPrank(owner);
        uint256 vestingCount = vesting.getVestingCount();
        assertEq(vestingCount, 2);

        CrossChainVesting.VestingSchedule[] memory schedules = vesting.getVestings();
        assertEq(schedules.length, 2);
        CrossChainVesting.VestingSchedule[] memory unreleasedSchedules = vesting.getUnreleasedVestings();
        assertEq(schedules.length, 2);

        vestingAmount = 2500 ether;
        vestingAmountWithBonusOp1 = vestingAmount + (vestingAmount * 25_00) / Constants.MAX_BPS;
        vestingAmountWithBonusOp2 = vestingAmount + (vestingAmount * 50_00) / Constants.MAX_BPS;

        // Check first vesting schedule (Option 1)
        CrossChainVesting.VestingSchedule memory vestingInfo1 = vesting.getVestingByIndex(0);
        assertEq(vestingInfo1.cliff, swapCloseTime + Constants.SECONDS_PER_HALF_YEAR);
        assertEq(vestingInfo1.duration, Constants.SECONDS_PER_YEAR);
        assertEq(vestingInfo1.start, swapCloseTime);
        assertEq(vestingInfo1.totalAmount, vestingAmount);
        assertEq(vestingInfo1.totalAmountWithBonus, vestingAmountWithBonusOp1);
        assertEq(vestingInfo1.released, 0);
        assertEq(vestingInfo1.bonusPercentage, 25_00);
        assertEq(uint256(vestingInfo1.swapOption), 0);

        // Check second vesting schedule (Option 2)
        CrossChainVesting.VestingSchedule memory vestingInfo2 = vesting.getVestingByIndex(1);
        assertEq(vestingInfo2.cliff, swapCloseTime + Constants.SECONDS_PER_YEAR);
        assertEq(vestingInfo2.duration, Constants.SECONDS_PER_YEAR_AND_HALF);
        assertEq(vestingInfo2.start, swapCloseTime);
        assertEq(vestingInfo2.totalAmount, vestingAmount);
        assertEq(vestingInfo2.totalAmountWithBonus, vestingAmountWithBonusOp2);
        assertEq(vestingInfo2.released, 0);
        assertEq(vestingInfo2.bonusPercentage, 50_00);
        assertEq(uint256(vestingInfo2.swapOption), 1);
        vm.stopPrank();

        test_tokenAllocation();

        // Fast-forward time to after the vesting period for both options
        vm.warp(swapCloseTime + Constants.SECONDS_PER_YEAR_AND_HALF + 1);

        vm.startPrank(owner);
        // Release vested tokens for Option 1
        uint256 vested1 = vesting.vestedAmount(owner, 0);
        uint256 fee1 = vested1 * 5_00 / Constants.MAX_BPS;
        uint256 amountAfterFee1 = vested1 - fee1;
        vm.expectEmit(true, true, true, true);
        emit TokensReleased(owner, owner, amountAfterFee1, fee1);
        vesting.release(owner, 0);
        assertEq(artcoinERC20.balanceOf(owner), amountAfterFee1 + fee1);

        schedules = vesting.getVestings();
        assertEq(schedules.length, 2);
        unreleasedSchedules = vesting.getUnreleasedVestings();
        assertEq(unreleasedSchedules.length, 1);

        // // Release vested tokens for Option 2
        uint256 vested2 = vesting.vestedAmount(owner, 1);
        uint256 fee2 = vested2 * 5_00 / Constants.MAX_BPS;
        uint256 amountAfterFee2 = vested2 - fee2;
        vm.expectEmit(true, true, true, true);
        emit TokensReleased(owner, owner, amountAfterFee2, fee2);
        vesting.release(owner, 1);
        assertEq(artcoinERC20.balanceOf(owner), amountAfterFee1 + fee1 + amountAfterFee2 + fee2);

        schedules = vesting.getVestings();
        assertEq(schedules.length, 2);
        unreleasedSchedules = vesting.getUnreleasedVestings();
        assertEq(unreleasedSchedules.length, 0);
        vm.stopPrank();
    }

    function test_createAndReleaseVestingOption_1_2_3() public {
        vm.prank(owner);
        crossChainSwap.updateMinSwapThreshold(1000 ether);
        assertEq(artcoinBEP20.balanceOf(owner), 0 ether);

        setSwapWindow();
        test_setTrustedRemoteAddress();

        Enums.SwapOptions swapOp1 = Enums.SwapOptions.OPTION1;
        Enums.SwapOptions swapOp2 = Enums.SwapOptions.OPTION2;
        Enums.SwapOptions swapOp3 = Enums.SwapOptions.OPTION3;

        // createSwap(swapOp1);
        vm.deal(owner, 1 ether);
        vm.startPrank(owner);
        artcoinBEP20.claim();
        assertEq(artcoinBEP20.balanceOf(owner), 5000 ether);
        artcoinBEP20.approve(address(crossChainSwap), 5000 ether);

        uint256 lzFeeOp3 = estimateLzSendFees(owner, 1000 ether, swapOp3);
        uint256 lzFee = estimateLzSendFees(owner, 2500 ether, swapOp1);

        // Check allowance before calling swapAmount
        uint256 allowance = artcoinBEP20.allowance(owner, address(crossChainSwap));
        assertEq(allowance, 5000 ether);

        crossChainSwap.swapAmount{value: lzFeeOp3}(1000 ether, swapOp3);
        crossChainSwap.swapAmount{value: lzFee}(2000 ether, swapOp1);

        // Check balance after calling swapAmount
        uint256 balanceAfter = artcoinBEP20.balanceOf(owner);
        assertEq(balanceAfter, 2000 ether);
        startTime = block.timestamp;
        vm.stopPrank();

        // createSwap(swapOp2);
        vm.startPrank(owner);
        lzFee = estimateLzSendFees(owner, 2000 ether, swapOp2);

        crossChainSwap.swap{value: lzFee}(swapOp2);

        assertEq(artcoinBEP20.balanceOf(owner), 0);
        // startTime = block.timestamp;
        vm.stopPrank();

        assertEq(crossChainSwap.totalSwappedAmount(swapOp1), 2000 ether);
        assertEq(crossChainSwap.totalSwappedAmount(swapOp2), 2000 ether);
        assertEq(crossChainSwap.totalSwappedAmount(swapOp3), 1000 ether);

        vm.startPrank(owner);
        uint256 vestingCount = vesting.getVestingCount();
        assertEq(vestingCount, 2);

        CrossChainVesting.VestingSchedule[] memory schedules = vesting.getVestings();
        assertEq(schedules.length, 2);
        CrossChainVesting.VestingSchedule[] memory unreleasedSchedules = vesting.getUnreleasedVestings();
        assertEq(schedules.length, 2);

        uint256 swapAmount = 1000 ether;
        vestingAmount = 2000 ether;
        vestingAmountWithBonusOp1 = vestingAmount + (vestingAmount * 25_00) / Constants.MAX_BPS;
        vestingAmountWithBonusOp2 = vestingAmount + (vestingAmount * 50_00) / Constants.MAX_BPS;

        assertEq(vesting.totalRequiredTokens(), vestingAmountWithBonusOp1 + vestingAmountWithBonusOp2 + swapAmount);

        // Check first vesting schedule (Option 1)
        CrossChainVesting.VestingSchedule memory vestingInfo1 = vesting.getVestingByIndex(0);
        assertEq(vestingInfo1.cliff, swapCloseTime + Constants.SECONDS_PER_HALF_YEAR);
        assertEq(vestingInfo1.duration, Constants.SECONDS_PER_YEAR);
        assertEq(vestingInfo1.start, swapCloseTime);
        assertEq(vestingInfo1.totalAmount, vestingAmount);
        assertEq(vestingInfo1.totalAmountWithBonus, vestingAmountWithBonusOp1);
        assertEq(vestingInfo1.released, 0);
        assertEq(vestingInfo1.bonusPercentage, 25_00);
        assertEq(uint256(vestingInfo1.swapOption), 0);

        // Check second vesting schedule (Option 2)
        CrossChainVesting.VestingSchedule memory vestingInfo2 = vesting.getVestingByIndex(1);
        assertEq(vestingInfo2.cliff, swapCloseTime + Constants.SECONDS_PER_YEAR);
        assertEq(vestingInfo2.duration, Constants.SECONDS_PER_YEAR_AND_HALF);
        assertEq(vestingInfo2.start, swapCloseTime);
        assertEq(vestingInfo2.totalAmount, vestingAmount);
        assertEq(vestingInfo2.totalAmountWithBonus, vestingAmountWithBonusOp2);
        assertEq(vestingInfo2.released, 0);
        assertEq(vestingInfo2.bonusPercentage, 50_00);
        assertEq(uint256(vestingInfo2.swapOption), 1);
        vm.stopPrank();

        // token allocation
        vm.startPrank(owner);
        artcoinERC20.mint(address(vesting), vestingAmountWithBonusOp1 + vestingAmountWithBonusOp2 + swapAmount);
        assertEq(
            artcoinERC20.balanceOf(address(vesting)), vestingAmountWithBonusOp1 + vestingAmountWithBonusOp2 + swapAmount
        );

        vesting.setClaimOpen();
        vm.warp(swapCloseTime);
        vm.expectEmit(true, true, true, true);
        emit TokensClaimed(owner, owner, swapAmount);
        vesting.claim(owner);
        assertEq(artcoinERC20.balanceOf(owner), swapAmount);

        // Fast-forward time to after the vesting period for both options
        vm.warp(Constants.SECONDS_PER_YEAR_AND_HALF + 1);

        // vm.startPrank(owner);
        // Release vested tokens for Option 1
        uint256 vested1 = vesting.vestedAmount(owner, 0);
        uint256 fee1 = vested1 * 5_00 / Constants.MAX_BPS;
        uint256 amountAfterFee1 = vested1 - fee1;
        vm.expectEmit(true, true, true, true);
        emit TokensReleased(owner, owner, amountAfterFee1, fee1);
        vesting.release(owner, 0);
        assertEq(artcoinERC20.balanceOf(owner), swapAmount + amountAfterFee1 + fee1);

        schedules = vesting.getVestings();
        assertEq(schedules.length, 2);
        unreleasedSchedules = vesting.getUnreleasedVestings();
        assertEq(unreleasedSchedules.length, 1);

        skip(1 weeks);
        // // Release vested tokens for Option 2
        uint256 vested2 = vesting.vestedAmount(owner, 1);
        uint256 fee2 = vested2 * 5_00 / Constants.MAX_BPS;
        uint256 amountAfterFee2 = vested2 - fee2;
        vm.expectEmit(true, true, true, true);
        emit TokensReleased(owner, owner, amountAfterFee2, fee2);
        vesting.release(owner, 1);
        assertEq(artcoinERC20.balanceOf(owner), swapAmount + amountAfterFee1 + fee1 + amountAfterFee2 + fee2);

        schedules = vesting.getVestings();
        assertEq(schedules.length, 2);
        unreleasedSchedules = vesting.getUnreleasedVestings();
        assertEq(unreleasedSchedules.length, 0);
        vm.stopPrank();
    }

    function test_claim_and_setClaimOpen() public {
        assertEq(artcoinBEP20.balanceOf(owner), 0 ether);
        setSwapWindow();
        test_setTrustedRemoteAddress();
        Enums.SwapOptions swapOp3 = Enums.SwapOptions.OPTION3;
        vm.deal(owner, 1 ether);
        vm.startPrank(owner);
        artcoinBEP20.claim();
        uint256 amountToSwap = artcoinBEP20.balanceOf(owner);
        assertEq(artcoinBEP20.balanceOf(owner), 5000 ether);
        artcoinBEP20.approve(address(crossChainSwap), amountToSwap);
        uint256 lzFeeOp3 = estimateLzSendFees(owner, amountToSwap, swapOp3);
        uint256 allowance = artcoinBEP20.allowance(owner, address(crossChainSwap));
        assertEq(allowance, amountToSwap);
        crossChainSwap.swapAmount{value: lzFeeOp3}(amountToSwap, swapOp3);
        assertEq(crossChainSwap.totalSwappedAmount(swapOp3), amountToSwap);
        assertEq(artcoinBEP20.balanceOf(owner), 0 ether);
        assertEq(vesting.totalRequiredTokens(), amountToSwap);
        assertEq(vesting.option3SwappedAmounts(owner), amountToSwap);

        artcoinERC20.mint(address(vesting), amountToSwap);
        assertEq(artcoinERC20.balanceOf(address(vesting)), amountToSwap);

        vm.expectRevert(Errors.InitialClaimNotStartedYet.selector);
        vesting.claim(owner);

        vm.warp(swapCloseTime);
        vm.expectRevert(Errors.InitialClaimNotStartedYet.selector);
        vesting.claim(owner);
        vm.stopPrank();

        vm.prank(address(this));
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, address(this)));
        vesting.setClaimOpen();

        assertFalse(vesting.claimIsOpen());
        vm.prank(owner);
        vm.expectEmit(true, true, true, true);
        emit ClaimOpenSet(true);
        vesting.setClaimOpen();
        assertTrue(vesting.claimIsOpen());

        vm.prank(address(this));
        vm.expectRevert(Errors.NoTokensToClaim.selector);
        vesting.claim(owner);

        vm.prank(owner);
        vm.expectEmit(true, true, true, true);
        emit TokensClaimed(owner, owner, amountToSwap);
        vesting.claim(owner);
        assertEq(artcoinERC20.balanceOf(owner), amountToSwap);
        assertEq(artcoinERC20.balanceOf(address(vesting)), 0);
        assertEq(vesting.option3SwappedAmounts(owner), 0);
    }

    function test_withdrawExcessTokens() public {
        vm.prank(owner);
        crossChainSwap.updateMinSwapThreshold(1000 ether);
        assertEq(artcoinBEP20.balanceOf(owner), 0 ether);

        setSwapWindow();
        test_setTrustedRemoteAddress();

        Enums.SwapOptions swapOp1 = Enums.SwapOptions.OPTION1;
        Enums.SwapOptions swapOp2 = Enums.SwapOptions.OPTION2;
        Enums.SwapOptions swapOp3 = Enums.SwapOptions.OPTION3;

        vm.deal(owner, 1 ether);
        vm.startPrank(owner);
        artcoinBEP20.claim();
        assertEq(artcoinBEP20.balanceOf(owner), 5000 ether);
        artcoinBEP20.approve(address(crossChainSwap), 5000 ether);
        uint256 lzFee = estimateLzSendFees(owner, 1000 ether, swapOp1);
        uint256 allowance = artcoinBEP20.allowance(owner, address(crossChainSwap));
        assertEq(allowance, 5000 ether);

        crossChainSwap.swapAmount{value: lzFee}(1000 ether, swapOp3);
        crossChainSwap.swapAmount{value: lzFee}(1000 ether, swapOp1);

        // Check balance after calling swapAmount
        uint256 balanceAfter = artcoinBEP20.balanceOf(owner);
        assertEq(balanceAfter, 3000 ether);
        startTime = block.timestamp;
        vm.stopPrank();

        vm.startPrank(owner);
        lzFee = estimateLzSendFees(owner, 1000 ether, swapOp2);
        crossChainSwap.swapAmount{value: lzFee}(1000 ether, swapOp2);
        assertEq(artcoinBEP20.balanceOf(owner), 2000 ether);
        vm.stopPrank();

        assertEq(crossChainSwap.totalSwappedAmount(swapOp1), 1000 ether);
        assertEq(crossChainSwap.totalSwappedAmount(swapOp2), 1000 ether);
        assertEq(crossChainSwap.totalSwappedAmount(swapOp3), 1000 ether);

        uint256 swapAmount = 1000 ether;
        vestingAmount = 1000 ether;
        vestingAmountWithBonusOp1 = vestingAmount + (vestingAmount * 25_00) / Constants.MAX_BPS;
        vestingAmountWithBonusOp2 = vestingAmount + (vestingAmount * 50_00) / Constants.MAX_BPS;

        assertEq(vesting.totalRequiredTokens(), vestingAmountWithBonusOp1 + vestingAmountWithBonusOp2 + swapAmount);

        // token allocation
        vm.startPrank(owner);
        artcoinERC20.mint(
            address(vesting), vestingAmountWithBonusOp1 + vestingAmountWithBonusOp2 + swapAmount + 2500 ether
        );
        assertEq(
            artcoinERC20.balanceOf(address(vesting)),
            vestingAmountWithBonusOp1 + vestingAmountWithBonusOp2 + swapAmount + 2500 ether
        );

        address receiver = makeAddr("receiver");
        vesting.withdrawExcessTokens(receiver, 500 ether);
        assertEq(artcoinERC20.balanceOf(receiver), 500 ether);

        vesting.setClaimOpen();
        vm.warp(swapCloseTime);
        vesting.claim(owner);
        assertEq(artcoinERC20.balanceOf(owner), swapAmount);
        assertEq(
            artcoinERC20.balanceOf(address(vesting)), vestingAmountWithBonusOp1 + vestingAmountWithBonusOp2 + 2000 ether
        );

        vm.warp(Constants.SECONDS_PER_YEAR_AND_HALF + 1);
        vesting.release(owner, 0);
        assertEq(artcoinERC20.balanceOf(address(vesting)), vestingAmountWithBonusOp2 + 2000 ether);

        skip(1 weeks);
        vesting.release(owner, 1);
        assertEq(artcoinERC20.balanceOf(address(vesting)), 2000 ether);

        vm.expectRevert(Errors.RequestedAmountExceedsAvailableExcess.selector);
        vesting.withdrawExcessTokens(receiver, 2500 ether);

        vm.expectEmit(true, true, true, true);
        emit ExcessTokensWithdrawn(owner, receiver, 2000 ether, block.timestamp);
        vesting.withdrawExcessTokens(receiver, 2000 ether);
        assertEq(artcoinERC20.balanceOf(address(receiver)), 2500 ether);
        assertEq(artcoinERC20.balanceOf(address(vesting)), 0);

        vm.expectRevert(Errors.NoExcessTokensAvailableForWithdrawal.selector);
        vesting.withdrawExcessTokens(receiver, 2000 ether);
        vm.stopPrank();
    }

    function test_transferOwnership2Step() public {
        assertTrue(vesting.owner() == owner);
        address newOwner = makeAddr("newOwner");
        // Step 1: Owner initiates the ownership transfer
        vm.startPrank(owner);
        vesting.transferOwnership(newOwner);

        // New owner should not have ownership yet
        assertFalse(vesting.owner() == newOwner);

        // Unauthorized address tries to accept ownership
        vm.stopPrank();
        vm.prank(address(this));
        // vm.expectRevert("Ownable2Step: caller is not the pending owner");
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, address(this))); //OwnableUnauthorizedAccount()
        vesting.acceptOwnership();

        // Another account tries to initiate the ownership transfer
        vm.prank(address(this));
        // vm.expectRevert("Ownable: caller is not the owner");
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, address(this))); //OwnableUnauthorizedAccount()
        vesting.transferOwnership(newOwner);

        // Step 2: New owner accepts the ownership transfer
        vm.startPrank(newOwner);
        vesting.acceptOwnership();

        // New owner should now be the owner
        assertEq(vesting.owner(), newOwner);

        // Check that previous owner cannot transfer ownership anymore
        vm.stopPrank();
        vm.prank(owner);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, address(owner))); //OwnableUnauthorizedAccount()
        vesting.transferOwnership(owner);
    }

    function test_updateSwapCloseTime() public {
        // Ensure initial state is as expected
        assertEq(vesting.swapCloseTime(), swapCloseTime);

        // Attempt to call the function as a non-owner, should revert
        vm.prank(address(this));
        vm.expectRevert(); // OwnableUnauthorizedAccount
        vesting.updateSwapCloseTime(0);

        // Call the function as the owner, updating the swapCloseTime to a specific value
        uint32 newSwapCloseTime = uint32(block.timestamp + 1 weeks);
        vm.startPrank(owner);
        vm.expectEmit(true, true, true, true);
        emit SwapCloseTimeUpdated(newSwapCloseTime);
        vesting.updateSwapCloseTime(newSwapCloseTime);
        assertEq(vesting.swapCloseTime(), newSwapCloseTime);

        // Call the function as the owner, updating the swapCloseTime to the current block timestamp
        vm.expectEmit(true, true, true, true);
        emit SwapCloseTimeUpdated(uint32(block.timestamp));
        vesting.updateSwapCloseTime(0);
        assertEq(vesting.swapCloseTime(), uint32(block.timestamp));
        vm.stopPrank();
    }
}
