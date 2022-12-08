// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {TickMath} from "fullrange/libraries/TickMath.sol";

import {BasePaprControllerTest} from "test/paprController/BasePaprController.ft.sol";
import {IPaprController} from "src/interfaces/IPaprController.sol";
import {PaprController} from "src/PaprController.sol";

contract BuyAndReduceDebt is BasePaprControllerTest {
    function testBuyAndReduceDebtReducesDebt() public {
        vm.startPrank(borrower);
        nft.approve(address(controller), collateralId);
        controller.addCollateral(IPaprController.Collateral(nft, collateralId));
        uint256 underlyingOut = controller.mintAndSellDebt(
            collateral.addr, debt, 982507, _maxSqrtPriceLimit({sellingPAPR: true}), borrower, address(0), 0, oracleInfo
        );
        IPaprController.VaultInfo memory vaultInfo = controller.vaultInfo(borrower, collateral.addr);
        assertEq(vaultInfo.debt, debt);
        assertEq(underlyingOut, underlying.balanceOf(borrower));
        underlying.approve(address(controller), underlyingOut);
        uint256 debtPaid = controller.buyAndReduceDebt(
            borrower, collateral.addr, underlyingOut, 1, _maxSqrtPriceLimit({sellingPAPR: false}), borrower
        );
        assertGt(debtPaid, 0);
        vaultInfo = controller.vaultInfo(borrower, collateral.addr);
        assertEq(vaultInfo.debt, debt - debtPaid);
    }

    function testBuyAndReduceDebtRevertsIfMinOutTooLittle() public {
        vm.startPrank(borrower);
        nft.approve(address(controller), collateralId);
        controller.addCollateral(collateral);
        uint256 underlyingOut = controller.mintAndSellDebt(
            collateral.addr, debt, 982507, _maxSqrtPriceLimit({sellingPAPR: true}), borrower, address(0), 0, oracleInfo
        );
        underlying.approve(address(controller), underlyingOut);
        uint160 priceLimit = _maxSqrtPriceLimit({sellingPAPR: false});
        uint256 out = quoter.quoteExactInputSingle({
            tokenIn: address(underlying),
            tokenOut: address(controller.papr()),
            fee: 10000,
            amountIn: underlyingOut,
            sqrtPriceLimitX96: priceLimit
        });
        vm.expectRevert(abi.encodeWithSelector(IPaprController.TooLittleOut.selector, out, out + 1));
        uint256 debtPaid = controller.buyAndReduceDebt(
            borrower, collateral.addr, underlyingOut, out + 1, priceLimit, address(borrower)
        );
    }

    function testMintAndSellDebt() public {
        vm.startPrank(borrower);
        nft.approve(address(controller), collateralId);
        controller.addCollateral(collateral);
        address feeTo = address(5);
        uint256 feeBips = 100;
        uint256 underlyingOut = controller.mintAndSellDebt(
            collateral.addr, debt, 982507, _maxSqrtPriceLimit({sellingPAPR: true}), borrower, feeTo, feeBips, oracleInfo
        );
        uint256 fee = underlyingOut * 100 / 1e4;
        assertEq(underlying.balanceOf(feeTo), fee);
        assertEq(underlying.balanceOf(borrower), underlyingOut - fee);
        // underlying.approve(address(controller), underlyingOut);
        // uint160 priceLimit = _maxSqrtPriceLimit({sellingPAPR: false});
        // uint256 out = quoter.quoteExactInputSingle({
        //     tokenIn: address(underlying),
        //     tokenOut: address(controller.papr()),
        //     fee: 10000,
        //     amountIn: underlyingOut,
        //     sqrtPriceLimitX96: priceLimit
        // });
        // vm.expectRevert(abi.encodeWithSelector(IPaprController.TooLittleOut.selector, out, out + 1));
        // uint256 debtPaid = controller.buyAndReduceDebt(
        //     borrower, collateral.addr, underlyingOut, out + 1, priceLimit, address(borrower)
        // );
    }
}
