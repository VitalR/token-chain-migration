// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {Test, stdError, console2} from "@forge-std/Test.sol";

import {CrossChainSwap, Ownable} from "src/CrossChainSwap.sol";
import {CrossChainVesting} from "src/CrossChainVesting.sol";
import {ArtcoinBEP20} from "src/token/ArtcoinBEP20.sol";
import {LZEndpointMock} from "lib/solidity-examples/contracts/lzApp/mocks/LZEndpointMock.sol";
import {MockERC20} from "test/mocks/MockERC20.sol";
import {Enums} from "src/libs/Enums.sol";
import {Errors} from "src/libs/Errors.sol";

contract CrossChainSwapUnitTest is Test {
    CrossChainSwap crossChainSwap;
    CrossChainVesting vesting;
    ArtcoinBEP20 artcoinBEP20;
    LZEndpointMock bnbLzEndpoint;
    LZEndpointMock polLzEndpoint;
    MockERC20 artcoinERC20;

    address owner;
    uint16 bnbLzChainId;
    uint16 polLzChainId;
    Enums.SwapOptions swapOP;

    event TrustedRemoteAddressSet(uint16 remoteChainId, address remoteAddress);
    event MinSwapThresholdUpdated(uint256 newThreshold);
    event SwapWindowSet(uint128 startTime, uint128 endTime);
    event Paused(address account);
    event Unpaused(address account);

    function setUp() public {
        bnbLzChainId = 10102;
        polLzChainId = 10267;
        swapOP = Enums.SwapOptions.OPTION1;

        owner = makeAddr("owner");

        artcoinERC20 = new MockERC20();
        bnbLzEndpoint = new LZEndpointMock(bnbLzChainId);
        polLzEndpoint = new LZEndpointMock(polLzChainId);
        artcoinBEP20 = new ArtcoinBEP20("MockART", "MockART");
        crossChainSwap = new CrossChainSwap(address(owner), address(artcoinBEP20), address(bnbLzEndpoint), polLzChainId);

        vesting = new CrossChainVesting(
            address(owner),
            address(artcoinERC20),
            address(polLzEndpoint),
            bnbLzChainId,
            25_00,
            50_00,
            address(owner),
            uint32(block.timestamp)
        );

        bnbLzEndpoint.setDestLzEndpoint(address(vesting), address(polLzEndpoint));
        polLzEndpoint.setDestLzEndpoint(address(crossChainSwap), address(bnbLzEndpoint));
    }

    function test_setUpState() public view {
        // assertEq(bnbLzEndpoint.mockChainId(), bnbLzChainId);
        assertEq(artcoinBEP20.name(), "MockART");
        assertEq(artcoinBEP20.symbol(), "MockART");
        assertEq(artcoinBEP20.totalSupply(), 0 ether);
        assertEq(artcoinBEP20.balanceOf(owner), 0 ether);
        assertEq(address(crossChainSwap.artcoinBEP20()), address(artcoinBEP20));
        assertEq(address(crossChainSwap.endpoint()), address(bnbLzEndpoint));
        assertEq(address(crossChainSwap.owner()), address(owner));
        assertEq(crossChainSwap.totalSwappedAmount(Enums.SwapOptions.OPTION1), 0 ether);
        assertEq(crossChainSwap.totalSwappedAmount(Enums.SwapOptions.OPTION2), 0 ether);
        assertEq(crossChainSwap.minSwapThreshold(), 5000 ether);
        assertEq(address(vesting.artcoin()), address(artcoinERC20));
        assertEq(address(vesting.endpoint()), address(polLzEndpoint));
        assertEq(address(vesting.owner()), address(owner));
        assertEq(address(vesting.feeReceiver()), address(owner));
    }

    function test_setUp_crossChainParams() public {
        // Binance Test Chain
        uint16 endpointId = 10267;
        address lzEndpoint = 0x6Fcb97553D41516Cb228ac03FdC8B9a0a9df04A1;
        crossChainSwap = new CrossChainSwap(address(owner), address(artcoinBEP20), address(lzEndpoint), endpointId);
        assertEq(address(crossChainSwap.endpoint()), address(lzEndpoint));
        assertEq(crossChainSwap.destChainId(), endpointId);
    }

    function test_setUpState_revert() public {
        vm.expectRevert(Errors.ZeroAddressProvided.selector);
        CrossChainSwap crossChainSwap2 =
            new CrossChainSwap(address(owner), address(0), address(polLzEndpoint), polLzChainId);
        vm.expectRevert(Errors.ZeroAddressProvided.selector);
        crossChainSwap2 = new CrossChainSwap(address(owner), address(artcoinBEP20), address(0), polLzChainId);
        vm.expectRevert(); // OwnableInvalidOwner(0x0000000000000000000000000000000000000000)
        crossChainSwap2 = new CrossChainSwap(address(0), address(artcoinBEP20), address(polLzEndpoint), polLzChainId);
        vm.expectRevert();
        crossChainSwap2 = new CrossChainSwap(address(0), address(0), address(0), polLzChainId);
    }

    function test_setTrustedRemoteAddress() public {
        assertFalse(
            crossChainSwap.isTrustedRemote(polLzChainId, abi.encodePacked(address(vesting), address(crossChainSwap)))
        );
        address notOwner = makeAddr("notOwner");
        vm.prank(notOwner);
        vm.expectRevert(); // OwnableUnauthorizedAccount(account)
        crossChainSwap.setTrustedRemoteAddress(polLzChainId, abi.encodePacked(address(vesting)));

        vm.startPrank(owner);
        // vm.expectRevert(Errors.ZeroAddressProvided.selector);
        // crossChainSwap.setTrustedRemoteAddress(polLzChainId, address(0));
        // emit TrustedRemoteAddressSet(polLzChainId, address(vesting));
        // crossChainSwap.setTrustedRemoteAddress(polLzChainId, address(vesting));
        crossChainSwap.setTrustedRemoteAddress(polLzChainId, abi.encodePacked(address(vesting)));
        assertTrue(
            crossChainSwap.isTrustedRemote(polLzChainId, abi.encodePacked(address(vesting), address(crossChainSwap)))
        );
        // set trusted for receiver to avoid - "LzApp: invalid source sending contract"
        vesting.setTrustedRemoteAddress(bnbLzChainId, abi.encodePacked(address(crossChainSwap)));
        assertTrue(vesting.isTrustedRemote(bnbLzChainId, abi.encodePacked(address(crossChainSwap), address(vesting))));

        bytes memory trustedRemote = crossChainSwap.trustedRemoteLookup(polLzChainId);
        assertTrue(trustedRemote.length > 0);

        vm.stopPrank();
    }

    function test_swap() public {
        test_setSwapWindow();
        test_setTrustedRemoteAddress();
        vm.startPrank(owner);
        artcoinBEP20.claim();
        artcoinBEP20.claim();
        assertEq(artcoinBEP20.balanceOf(owner), 10000 ether);
        vm.deal(owner, 1 ether);
        artcoinBEP20.approve(address(crossChainSwap), 10000 ether);
        crossChainSwap.swap{value: 1.42e16}(swapOP);
        assertEq(artcoinBEP20.balanceOf(owner), 0 ether);
        assertEq(crossChainSwap.totalSwappedAmount(Enums.SwapOptions.OPTION1), 10000 ether);
        vm.stopPrank();
    }

    function test_swap_revert() public {
        test_setSwapWindow();
        address notPhlHolder = makeAddr("notPhlHolder");
        vm.deal(notPhlHolder, 0.5 ether);
        vm.prank(notPhlHolder);
        vm.expectRevert(Errors.NothingToSwap.selector);
        crossChainSwap.swap{value: 1.42e16}(swapOP);

        vm.deal(owner, 1 ether);
        vm.startPrank(owner);
        artcoinBEP20.claim();
        artcoinBEP20.claim();
        artcoinBEP20.approve(address(crossChainSwap), 10000 ether);
        vm.expectRevert("LzApp: destination chain is not a trusted source");
        crossChainSwap.swap{value: 1.42e16}(swapOP);
        vm.stopPrank();

        test_setTrustedRemoteAddress();
        vm.startPrank(owner);
        artcoinBEP20.transfer(address(this), 5001 ether);
        assertEq(artcoinBEP20.balanceOf(owner), 4999 ether);
        vm.expectRevert(Errors.AmountBelowMinimumSwapThreshold.selector);
        crossChainSwap.swap{value: 1.42e16}(swapOP);
        vm.stopPrank();
    }

    function test_swapAmount() public {
        test_setSwapWindow();
        test_setTrustedRemoteAddress();
        assertEq(artcoinBEP20.balanceOf(owner), 0 ether);
        vm.deal(owner, 1 ether);
        vm.startPrank(owner);
        artcoinBEP20.claim();
        artcoinBEP20.claim();
        assertEq(artcoinBEP20.balanceOf(owner), 10000 ether);
        artcoinBEP20.approve(address(crossChainSwap), 10000 ether);
        crossChainSwap.swapAmount{value: 1.42e16}(5000 ether, swapOP);
        assertEq(artcoinBEP20.balanceOf(owner), 5000 ether);
        swapOP = Enums.SwapOptions.OPTION2;
        crossChainSwap.swapAmount{value: 1.42e16}(5000 ether, swapOP);
        assertEq(artcoinBEP20.balanceOf(owner), 0 ether);
        assertEq(crossChainSwap.totalSwappedAmount(Enums.SwapOptions.OPTION1), 5000 ether);
        assertEq(crossChainSwap.totalSwappedAmount(Enums.SwapOptions.OPTION2), 5000 ether);
        vm.stopPrank();
    }

    function test_swapAmount_reverts() public {
        test_setSwapWindow();
        address notPhlHolder = makeAddr("notPhlHolder");
        vm.deal(notPhlHolder, 0.5 ether);
        vm.prank(notPhlHolder);
        vm.expectRevert(Errors.NothingToSwap.selector);
        crossChainSwap.swapAmount{value: 1.42e16}(0.5 ether, swapOP);

        vm.deal(owner, 1 ether);
        vm.startPrank(owner);
        artcoinBEP20.claim();
        artcoinBEP20.approve(address(crossChainSwap), 5000 ether);
        vm.expectRevert("LzApp: destination chain is not a trusted source");
        crossChainSwap.swapAmount{value: 1.42e16}(5000 ether, swapOP);
        vm.stopPrank();

        test_setTrustedRemoteAddress();
        assertEq(artcoinBEP20.balanceOf(owner), 5000 ether);
        vm.deal(owner, 1 ether);
        vm.startPrank(owner);
        artcoinBEP20.approve(address(crossChainSwap), 5000 ether);
        vm.expectRevert(Errors.InsufficientAmountToSwap.selector);
        crossChainSwap.swapAmount{value: 1.42e16}(10001 ether, swapOP);
        vm.expectRevert(Errors.AmountBelowMinimumSwapThreshold.selector);
        crossChainSwap.swapAmount{value: 1.42e16}(4999 ether, swapOP);
        vm.stopPrank();
    }

    function test_swapAmount_Op3() public {
        test_setSwapWindow();
        test_setTrustedRemoteAddress();
        assertEq(artcoinBEP20.balanceOf(owner), 0 ether);
        swapOP = Enums.SwapOptions.OPTION3;
        vm.deal(owner, 1 ether);
        vm.startPrank(owner);
        artcoinBEP20.claim();
        artcoinBEP20.claim();
        assertEq(artcoinBEP20.balanceOf(owner), 10000 ether);
        artcoinBEP20.approve(address(crossChainSwap), 10000 ether);
        crossChainSwap.swapAmount{value: 1.42e16}(10000 ether, swapOP);
        assertEq(artcoinBEP20.balanceOf(owner), 0 ether);
        assertEq(crossChainSwap.totalSwappedAmount(Enums.SwapOptions.OPTION3), 10000 ether);
        vm.stopPrank();
    }

    function test_estimateLzSendFees() public view {
        uint256 balance = artcoinBEP20.balanceOf(owner);
        bytes memory payload = abi.encode(owner, balance);
        uint256 nativeFee = crossChainSwap.estimateLzSendFees(payload);
        // console2.log("nativeFee", nativeFee);
        assertGt(nativeFee, 0);
    }

    function test_pause_unpause() public {
        assertFalse(crossChainSwap.paused());
        address notOwner = makeAddr("notOwner");
        vm.prank(notOwner);
        vm.expectRevert(); //Ownable.OwnableUnauthorizedAccount.selector
        crossChainSwap.pause();
        assertFalse(crossChainSwap.paused());
        vm.startPrank(owner);
        vm.expectEmit(true, false, false, true);
        emit Paused(address(owner));
        crossChainSwap.pause();
        assertTrue(crossChainSwap.paused());
        vm.expectRevert(); //Pausable__Paused()
        crossChainSwap.swap{value: 1.42e16}(swapOP);
        vm.stopPrank();
        vm.prank(notOwner);
        vm.expectRevert(); //Ownable.OwnableUnauthorizedAccount.selector
        crossChainSwap.unpause();
        assertTrue(crossChainSwap.paused());
        vm.prank(owner);
        vm.expectEmit(true, false, false, true);
        emit Unpaused(address(owner));
        crossChainSwap.unpause();
        assertFalse(crossChainSwap.paused());
    }

    function test_updateMinSwapThreshold() public {
        assertEq(crossChainSwap.minSwapThreshold(), 5000 ether);
        vm.prank(address(this));
        vm.expectRevert(); // OwnableUnauthorizedAccount
        crossChainSwap.updateMinSwapThreshold(0);
        vm.startPrank(owner);
        vm.expectRevert(Errors.NeedsMoreThanZero.selector);
        crossChainSwap.updateMinSwapThreshold(0);
        vm.startPrank(owner);
        vm.expectEmit(true, true, true, true);
        emit MinSwapThresholdUpdated(1000 ether);
        crossChainSwap.updateMinSwapThreshold(1000 ether);
        assertEq(crossChainSwap.minSwapThreshold(), 1000 ether);
    }

    function test_setSwapWindow() public {
        assertEq(crossChainSwap.swapStartTime(), 0);
        assertEq(crossChainSwap.swapEndTime(), 0);

        address notOwner = makeAddr("notOwner");
        vm.prank(notOwner);
        vm.expectRevert(); //Ownable.OwnableUnauthorizedAccount.selector
        crossChainSwap.setSwapWindow(uint128(block.timestamp), uint128(block.timestamp + 1 days));

        skip(2 weeks);
        vm.startPrank(owner);
        uint128 currentTimestamp = uint128(block.timestamp);
        vm.expectRevert(Errors.EndTimeInPast.selector);
        crossChainSwap.setSwapWindow(currentTimestamp - 1 days, currentTimestamp);

        vm.expectRevert(Errors.EndTimeInPast.selector);
        crossChainSwap.setSwapWindow(currentTimestamp - 2 days, currentTimestamp - 1 days);

        vm.expectRevert(Errors.StartTimeMustBeBeforeEndTime.selector);
        crossChainSwap.setSwapWindow(uint128(block.timestamp + 1 days), uint128(block.timestamp) + 1);

        // vm.expectEmit(true, true, true, true);
        // emit SwapWindowSet(uint128(block.timestamp), uint128(block.timestamp + 1 days));
        crossChainSwap.setSwapWindow(uint128(block.timestamp), uint128(block.timestamp + 1 days));
        assertEq(crossChainSwap.swapStartTime(), uint128(block.timestamp));
        assertEq(crossChainSwap.swapEndTime(), uint128(block.timestamp + 1 days));

        skip(2 weeks);
        uint128 newStartTimeInPast = uint128(block.timestamp - 1 days);
        uint128 newEndTime = uint128(block.timestamp + 10 days);
        crossChainSwap.setSwapWindow(newStartTimeInPast, newEndTime);
        assertEq(crossChainSwap.swapStartTime(), newStartTimeInPast);
        assertEq(crossChainSwap.swapEndTime(), newEndTime);
        vm.stopPrank();
    }
}
