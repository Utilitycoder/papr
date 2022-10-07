// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";

import {ERC20} from "solmate/tokens/ERC20.sol";
import {TickMath} from "fullrange/libraries/TickMath.sol";

import {LendingStrategy} from "src/core/LendingStrategy.sol";
import {Underwriter} from "src/core/Underwriter.sol";
import {ILendingStrategy} from "src/interfaces/ILendingStrategy.sol";
import {IUnderwriter} from "src/interfaces/IUnderwriter.sol";
import {TestERC721} from "test/mocks/TestERC721.sol";
import {TestERC20} from "test/mocks/TestERC20.sol";
import {MainnetForking} from "test/base/MainnetForking.sol";
import {UniswapForking} from "test/base/UniswapForking.sol";
import {OracleTest} from "test/base/OracleTest.sol";
import {INonfungiblePositionManager} from "test/mocks/uniswap/INonfungiblePositionManager.sol";

contract BaseLendingStrategyTest is MainnetForking, UniswapForking, OracleTest {
    TestERC721 nft = new TestERC721();
    TestERC20 underlying = new TestERC20();
    LendingStrategy strategy;
    IUnderwriter underwriter;

    uint256 collateralId = 1;
    address borrower = address(1);
    uint24 feeTier = 10000;

    ILendingStrategy.OnERC721ReceivedArgs safeTransferReceivedArgs;

    // global args for safe transfer receive data
    uint256 vaultId;
    uint256 vaultNonce;
    uint256 minOut;
    uint256 debt = 1e18;
    uint160 sqrtPriceLimitX96;
    IUnderwriter.OracleInfo oracleInfo = getOracleInfoForCollateral(address(nft), address(underlying));

    //
    function setUp() public {
        strategy = new LendingStrategy("PUNKs Loans", "PL", 0.1e18, 0.5e18, 2e18, 0.8e18, underlying);
        underwriter = new Underwriter(oracleAddress);

        strategy.claimOwnership();
        strategy.setUnderwriter(underwriter);
        ILendingStrategy.SetAllowedCollateralArg[] memory args = new ILendingStrategy.SetAllowedCollateralArg[](1);
        args[0] = ILendingStrategy.SetAllowedCollateralArg(address(nft), true);
        strategy.setAllowedCollateral(args);
        nft.mint(borrower, collateralId);
        vm.prank(borrower);
        nft.approve(address(strategy), collateralId);

        _provideLiquidityAtOneToOne();
        _populateOnReceivedArgs();
    }

    function _provideLiquidityAtOneToOne() internal {
        uint256 amount = 1e19;
        uint256 token0Amount;
        uint256 token1Amount;
        int24 tickLower;
        int24 tickUpper;

        if (strategy.token0IsUnderlying()) {
            token0Amount = amount;
            tickUpper = 200;
        } else {
            token1Amount = amount;
            tickLower = -200;
        }

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
        safeTransferReceivedArgs = ILendingStrategy.OnERC721ReceivedArgs({
            vaultNonce: vaultNonce,
            mintVaultTo: borrower,
            mintDebtOrProceedsTo: borrower,
            minOut: minOut,
            debt: debt,
            sqrtPriceLimitX96: _viableSqrtPriceLimit({sellingPAPR: true}),
            oracleInfo: oracleInfo
        });
    }

    function _viableSqrtPriceLimit(bool sellingPAPR) internal returns (uint160) {
        (uint160 sqrtPrice,,,,,,) = strategy.pool().slot0();
        int24 tick = TickMath.getTickAtSqrtRatio(sqrtPrice);

        if (sellingPAPR) {
            strategy.token0IsUnderlying() ? tick += 1 : tick -= 1;
        } else {
            strategy.token0IsUnderlying() ? tick -= 1 : tick += 1;
        }

        return TickMath.getSqrtRatioAtTick(tick);
    }

    function _maxSqrtPriceLimit(bool sellingPAPR) internal returns (uint160) {
        if (sellingPAPR) {
            return !strategy.token0IsUnderlying() ? TickMath.MIN_SQRT_RATIO + 1 : TickMath.MAX_SQRT_RATIO - 1;
        } else {
            return strategy.token0IsUnderlying() ? TickMath.MIN_SQRT_RATIO + 1 : TickMath.MAX_SQRT_RATIO - 1;
        }
    }
}
