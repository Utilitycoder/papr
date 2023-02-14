// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.17;

import {TickMath} from "fullrange/libraries/TickMath.sol";

import {BasePaprControllerTest} from "./BasePaprController.ft.sol";
import {IPaprController} from "../../src/interfaces/IPaprController.sol";
import {UniswapHelpers} from "../../src/libraries/UniswapHelpers.sol";

contract BuyAndReduceDebt is BasePaprControllerTest {
    /// @notice  
    function testBuyAndReduceSendsSwapProceedsToCaller() public {
        safeTransferReceivedArgs.swapParams = IPaprController.SwapParams({
            amount: debt,
            minOut: 1,
            sqrtPriceLimitX96: _maxSqrtPriceLimit({sellingPAPR: true}),
            swapFeeTo: address(0),
            deadline: block.timestamp,
            swapFeeBips: 0
        });
        vm.prank(borrower);
        // Transfer collateral from borrower to the controller
        nft.safeTransferFrom(borrower, address(controller), collateralId, abi.encode(safeTransferReceivedArgs));
        // pick a payer who DOES not have papr. Tx would revert if papr wasn't sent to them
        address payer = address(333);
        uint256 startBalance = 1e18;
        underlying.mint(payer, startBalance);
        IPaprController.SwapParams memory swapParams = IPaprController.SwapParams({
            amount: startBalance,
            minOut: 1,
            sqrtPriceLimitX96: _maxSqrtPriceLimit({sellingPAPR: false}),
            swapFeeTo: address(0),
            deadline: block.timestamp,
            swapFeeBips: 0
        });
        vm.startPrank(payer);
        controller.underlying().approve(address(controller), startBalance);
        controller.buyAndReduceDebt(borrower, collateral.addr, swapParams);
        // sanity check the payer spent something
        assertLt(controller.underlying().balanceOf(payer), startBalance);
    }

    function testBuyAndReduceOnlyPaysDebtIfExcess() public {
        safeTransferReceivedArgs.swapParams = IPaprController.SwapParams({
            amount: 1e16,
            minOut: 1,
            sqrtPriceLimitX96: _maxSqrtPriceLimit({sellingPAPR: true}),
            swapFeeTo: address(0),
            deadline: block.timestamp,
            swapFeeBips: 0
        });
        vm.prank(borrower);
        nft.safeTransferFrom(borrower, address(controller), collateralId, abi.encode(safeTransferReceivedArgs));
        // add more papr to uniswap pool so we can get out more than borrower has in debt
        nft.mint(address(0xb0b), 2);
        safeTransferReceivedArgs.swapParams.amount = 1e18;
        vm.prank(address(0xb0b));
        nft.safeTransferFrom(address(0xb0b), address(controller), 2, abi.encode(safeTransferReceivedArgs));

        address payer = address(333);
        uint256 startBalance = 2e18;
        underlying.mint(payer, startBalance);
        IPaprController.SwapParams memory swapParams = IPaprController.SwapParams({
            amount: startBalance,
            minOut: 1e17,
            sqrtPriceLimitX96: _maxSqrtPriceLimit({sellingPAPR: false}),
            swapFeeTo: address(0),
            deadline: block.timestamp,
            swapFeeBips: 0
        });
        vm.startPrank(payer);
        controller.underlying().approve(address(controller), startBalance);
        uint256 out = controller.buyAndReduceDebt(borrower, collateral.addr, swapParams);
        assertEq(controller.papr().balanceOf(payer), out - 1e16);
    }

    function testBuyAndReduceDebtReducesDebt() public {
        vm.startPrank(borrower);
        nft.approve(address(controller), collateralId);
        IPaprController.Collateral[] memory c = new IPaprController.Collateral[](1);
        c[0] = collateral;
        controller.addCollateral(c);
        IPaprController.SwapParams memory swapParams = IPaprController.SwapParams({
            amount: debt,
            minOut: 982507,
            sqrtPriceLimitX96: _maxSqrtPriceLimit({sellingPAPR: true}),
            swapFeeTo: address(0),
            deadline: block.timestamp,
            swapFeeBips: 0
        });
        uint256 underlyingOut = controller.increaseDebtAndSell(borrower, collateral.addr, swapParams, oracleInfo);
        IPaprController.VaultInfo memory vaultInfo = controller.vaultInfo(borrower, collateral.addr);
        assertEq(vaultInfo.debt, debt);
        assertEq(underlyingOut, underlying.balanceOf(borrower));
        assertEq(0, underlying.balanceOf(address(controller)));
        // ensure has enough balance to pay the amount + the fee
        uint256 safeAmount = underlyingOut / 2;
        uint256 feeBips = 100;
        uint256 fee = safeAmount * feeBips / 1e4;
        underlying.approve(address(controller), underlyingOut);
        swapParams = IPaprController.SwapParams({
            amount: safeAmount,
            minOut: 1,
            sqrtPriceLimitX96: _maxSqrtPriceLimit({sellingPAPR: false}),
            swapFeeTo: address(5),
            deadline: block.timestamp,
            swapFeeBips: feeBips
        });
        uint256 debtPaid = controller.buyAndReduceDebt(borrower, collateral.addr, swapParams);
        assertGt(debtPaid, 0);
        vaultInfo = controller.vaultInfo(borrower, collateral.addr);
        assertEq(vaultInfo.debt, debt - debtPaid);
        assertEq(underlying.balanceOf(swapParams.swapFeeTo), fee);
    }

    function testBuyAndReduceDebtRevertsIfMinOutTooLittle() public {
        vm.startPrank(borrower);
        nft.approve(address(controller), collateralId);
        IPaprController.Collateral[] memory c = new IPaprController.Collateral[](1);
        c[0] = collateral;
        controller.addCollateral(c);
        IPaprController.SwapParams memory swapParams = IPaprController.SwapParams({
            amount: debt,
            minOut: 982507,
            sqrtPriceLimitX96: _maxSqrtPriceLimit({sellingPAPR: true}),
            swapFeeTo: address(0),
            deadline: block.timestamp,
            swapFeeBips: 0
        });
        uint256 underlyingOut = controller.increaseDebtAndSell(borrower, collateral.addr, swapParams, oracleInfo);
        underlying.approve(address(controller), underlyingOut);
        uint160 priceLimit = _maxSqrtPriceLimit({sellingPAPR: false});
        uint256 out = quoter.quoteExactInputSingle({
            tokenIn: address(underlying),
            tokenOut: address(controller.papr()),
            fee: 10000,
            amountIn: underlyingOut,
            sqrtPriceLimitX96: priceLimit
        });
        vm.expectRevert(abi.encodeWithSelector(UniswapHelpers.TooLittleOut.selector, out, out + 1));
        swapParams = IPaprController.SwapParams({
            amount: underlyingOut,
            minOut: out + 1,
            sqrtPriceLimitX96: priceLimit,
            swapFeeTo: address(0),
            deadline: block.timestamp,
            swapFeeBips: 0
        });
        uint256 debtPaid = controller.buyAndReduceDebt(borrower, collateral.addr, swapParams);
    }
}
