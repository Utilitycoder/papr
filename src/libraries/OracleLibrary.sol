// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity >=0.8.0;

import {IUniswapV3Pool} from "v3-core/contracts/interfaces/IUniswapV3Pool.sol";
import {TickMath} from "fullrange/libraries/TickMath.sol";
import {FullMath} from "fullrange/libraries/FullMath.sol";

library OracleLibrary {
    /// from https://github.com/Uniswap/v3-periphery/blob/main/contracts/libraries/OracleLibrary.sol#L49
    function getQuoteAtTick(int24 tick, uint128 baseAmount, address baseToken, address quoteToken)
        internal
        pure
        returns (uint256 quoteAmount)
    {
        unchecked {
            uint160 sqrtRatioX96 = TickMath.getSqrtRatioAtTick(tick);

            // Calculate quoteAmount with better precision if it doesn't overflow when multiplied by itself
            if (sqrtRatioX96 <= type(uint128).max) {
                uint256 ratioX192 = uint256(sqrtRatioX96) * sqrtRatioX96;
                quoteAmount = baseToken < quoteToken
                    ? FullMath.mulDiv(ratioX192, baseAmount, 1 << 192)
                    : FullMath.mulDiv(1 << 192, baseAmount, ratioX192);
            } else {
                uint256 ratioX128 = FullMath.mulDiv(sqrtRatioX96, sqrtRatioX96, 1 << 64);
                quoteAmount = baseToken < quoteToken
                    ? FullMath.mulDiv(ratioX128, baseAmount, 1 << 128)
                    : FullMath.mulDiv(1 << 128, baseAmount, ratioX128);
            }
        }
    }

    function timeWeightedAverageTick(int56 startTick, int56 endTick, int56 twapDuration)
        internal
        view
        returns (int24 timeWeightedAverageTick)
    {
        require(twapDuration != 0, 'BP');

        unchecked{
            int56 delta = endTick - startTick;

            timeWeightedAverageTick = int24(delta / twapDuration);

            // Always round to negative infinity
            if (delta < 0 && (delta % (twapDuration) != 0)) {
                timeWeightedAverageTick--;
            }

            return timeWeightedAverageTick;
        }
    }

    function latestCumulativeTick(IUniswapV3Pool pool) internal view returns (int56) {
        uint32[] memory secondAgos = new uint32[](1);
        secondAgos[0] = 0;
        (int56[] memory tickCumulatives,) = pool.observe(secondAgos);
        return tickCumulatives[0];
    }
}
