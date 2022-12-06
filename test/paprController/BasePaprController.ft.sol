// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";

import {ERC20} from "solmate/tokens/ERC20.sol";
import {TickMath} from "fullrange/libraries/TickMath.sol";

import {PaprController} from "src/PaprController.sol";
import {ReservoirOracleUnderwriter} from "src/ReservoirOracleUnderwriter.sol";
import {IPaprController} from "src/interfaces/IPaprController.sol";
import {ReservoirOracleUnderwriter} from "src/ReservoirOracleUnderwriter.sol";
import {TestERC721} from "test/mocks/TestERC721.sol";
import {TestERC20} from "test/mocks/TestERC20.sol";
import {MainnetForking} from "test/base/MainnetForking.sol";
import {UniswapForking} from "test/base/UniswapForking.sol";
import {OracleTest} from "test/base/OracleTest.sol";
import {INonfungiblePositionManager} from "test/mocks/uniswap/INonfungiblePositionManager.sol";

contract BasePaprControllerTest is MainnetForking, UniswapForking, OracleTest {
    TestERC721 nft = new TestERC721();
    TestERC20 underlying = new TestERC20();
    PaprController strategy;

    uint256 collateralId = 1;
    IPaprController.Collateral collateral = IPaprController.Collateral({id: collateralId, addr: nft});
    address borrower = address(1);
    uint24 feeTier = 10000;

    IPaprController.OnERC721ReceivedArgs safeTransferReceivedArgs;

    // global args for safe transfer receive data
    uint256 minOut;
    uint256 debt = 1e18;
    uint160 sqrtPriceLimitX96;
    ReservoirOracleUnderwriter.OracleInfo oracleInfo;

    //
    function setUp() public virtual {
        strategy = new PaprController(
            "PUNKs Loans",
            "PL",
            0.5e18,
            2e18,
            0.8e18,
            underlying,
            oracleAddress
        );

        strategy.claimOwnership();
        IPaprController.CollateralAllowedConfig[] memory args = new IPaprController.CollateralAllowedConfig[](1);
        args[0] = IPaprController.CollateralAllowedConfig(address(nft), true);
        strategy.setAllowedCollateral(args);
        nft.mint(borrower, collateralId);
        vm.prank(borrower);
        nft.approve(address(strategy), collateralId);

        oracleInfo = _getOracleInfoForCollateral(nft, underlying);
        _provideLiquidityAtOneToOne();
        _populateOnReceivedArgs();
    }

    function _provideLiquidityAtOneToOne() internal {
        uint256 amount = 1e19;
        uint256 token0Amount;
        uint256 token1Amount;
        (, int24 currentTick,,,,,) = strategy.pool().slot0();
        int24 tickLower = currentTick;
        int24 tickUpper = currentTick;

        if (strategy.token0IsUnderlying()) {
            token0Amount = amount;
            tickLower += 200;
            tickUpper += 400;
        } else {
            token1Amount = amount;
            tickUpper -= 200;
            tickLower -= 400;
        }
        // make ticks align to correct spacing
        tickLower = tickLower / 200 * 200;
        tickUpper = tickUpper / 200 * 200;

        underlying.approve(address(positionManager), amount);
        underlying.mint(address(this), amount);

        INonfungiblePositionManager.MintParams memory mintParams = INonfungiblePositionManager.MintParams(
            strategy.pool().token0(),
            strategy.pool().token1(),
            feeTier,
            tickLower,
            tickUpper,
            token0Amount,
            token1Amount,
            0,
            0,
            address(this),
            block.timestamp + 1
        );

        positionManager.mint(mintParams);
    }

    function _populateOnReceivedArgs() internal {
        safeTransferReceivedArgs = IPaprController.OnERC721ReceivedArgs({
            mintDebtOrProceedsTo: borrower,
            minOut: minOut,
            debt: debt,
            sqrtPriceLimitX96: _viableSqrtPriceLimit({sellingPAPR: true}),
            oracleInfo: oracleInfo
        });
    }

    function _openMaxLoanAndSwap() internal {
        safeTransferReceivedArgs.debt = strategy.maxDebt(oraclePrice) - 2;
        safeTransferReceivedArgs.minOut = 1;
        safeTransferReceivedArgs.sqrtPriceLimitX96 = _maxSqrtPriceLimit(true);
        vm.prank(borrower);
        nft.safeTransferFrom(borrower, address(strategy), collateralId, abi.encode(safeTransferReceivedArgs));
    }

    function _makeMaxLoanLiquidatable() internal {
        vm.warp(block.timestamp + 1 days);
        // update oracle signature
        oracleInfo = _getOracleInfoForCollateral(nft, underlying);
    }

    function _viableSqrtPriceLimit(bool sellingPAPR) internal view returns (uint160) {
        (uint160 sqrtPrice,,,,,,) = strategy.pool().slot0();
        int24 tick = TickMath.getTickAtSqrtRatio(sqrtPrice);

        if (sellingPAPR) {
            strategy.token0IsUnderlying() ? tick += 1 : tick -= 1;
        } else {
            strategy.token0IsUnderlying() ? tick -= 1 : tick += 1;
        }

        return TickMath.getSqrtRatioAtTick(tick);
    }

    function _maxSqrtPriceLimit(bool sellingPAPR) internal view returns (uint160) {
        if (sellingPAPR) {
            return !strategy.token0IsUnderlying() ? TickMath.MIN_SQRT_RATIO + 1 : TickMath.MAX_SQRT_RATIO - 1;
        } else {
            return strategy.token0IsUnderlying() ? TickMath.MIN_SQRT_RATIO + 1 : TickMath.MAX_SQRT_RATIO - 1;
        }
    }
}