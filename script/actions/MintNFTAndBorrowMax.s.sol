// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import {ERC721} from "solmate/tokens/ERC721.sol";
import {ReservoirOracleUnderwriter, ReservoirOracle} from "src/core/ReservoirOracleUnderwriter.sol";
import {TickMath} from "fullrange/libraries/TickMath.sol";

import {ILendingStrategy} from "src/interfaces/ILendingStrategy.sol";
import {LendingStrategy} from "src/core/LendingStrategy.sol";
import {Base} from "script/actions/Base.s.sol";

abstract contract MintableERC721 is ERC721 {
    function mint(address to) external virtual;
}

contract MintNFTAndBorrowMax is Base {
    MintableERC721 nft = MintableERC721(0x8232c5Fd480C2a74d2f25d3362f262fF3511CE49);
    // check next Id here https://goerli.etherscan.io/token/0x8232c5Fd480C2a74d2f25d3362f262fF3511CE49
    uint256 tokenId = 20;
    uint256 oraclePrice = 3e20;

    function run() public {
        // expected to mint tokenId
        // vm.startBroadcast();
        // nft.mint(deployer);
        // vm.stopBroadcast();

        _openMaxLoanAndSwap(deployer);
    }

    function _openMaxLoanAndSwap(address borrower) internal {
        ILendingStrategy.OnERC721ReceivedArgs memory safeTransferReceivedArgs = ILendingStrategy.OnERC721ReceivedArgs({
            mintDebtOrProceedsTo: borrower,
            minOut: 1,
            debt: strategy.maxDebt(oraclePrice) - 2,
            sqrtPriceLimitX96: _maxSqrtPriceLimit(true),
            oracleInfo: _getOracleInfoForCollateral(address(nft), oraclePrice)
        });
        vm.startBroadcast();
        nft.safeTransferFrom(borrower, address(strategy), tokenId, abi.encode(safeTransferReceivedArgs));
    }

    function _maxSqrtPriceLimit(bool sellingPAPR) internal view returns (uint160) {
        if (sellingPAPR) {
            return !strategy.token0IsUnderlying() ? TickMath.MIN_SQRT_RATIO + 1 : TickMath.MAX_SQRT_RATIO - 1;
        } else {
            return strategy.token0IsUnderlying() ? TickMath.MIN_SQRT_RATIO + 1 : TickMath.MAX_SQRT_RATIO - 1;
        }
    }
}
