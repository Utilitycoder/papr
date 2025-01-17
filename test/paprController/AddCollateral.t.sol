// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.17;

import {BasePaprControllerTest} from "./BasePaprController.ft.sol";
import {IPaprController} from "../../src/interfaces/IPaprController.sol";
import {ERC721, TestERC721} from "../mocks/TestERC721.sol";

contract AddCollateralTest is BasePaprControllerTest {
    event AddCollateral(address indexed account, ERC721 indexed collateralAddress, uint256 indexed tokenId);

    function testAddCollateralUpdatesCollateralOwnerCorrectly() public {
        _addCollateral();
        assertEq(controller.collateralOwner(collateral.addr, collateral.id), borrower);
    }
    /// @notice Test adding collateral emits the necessary event
    function testAddCollateralEmitsAddCollateral() public {
        vm.startPrank(borrower);
        nft.approve(address(controller), collateralId);
        IPaprController.Collateral[] memory c = new IPaprController.Collateral[](1);
        c[0] = collateral;
        vm.expectEmit(true, true, true, false);
        emit AddCollateral(borrower, collateral.addr, collateral.id);
        controller.addCollateral(c);
    }

    /// @notice test that adding collateral increases count in vault
    function testAddCollateralIncreasesCountInVault() public {
        uint256 beforeCount = controller.vaultInfo(borrower, collateral.addr).count;
        _addCollateral();
        assertEq(beforeCount + 1, controller.vaultInfo(borrower, collateral.addr).count);
    }

    /// @notice Test that adding collateral fails if invalid NFT is added
    function testAddCollateralFailsIfInvalidCollateral() public {
        TestERC721 invalidNFT = new TestERC721();
        vm.startPrank(borrower);
        nft.approve(address(controller), collateralId);
        vm.expectRevert(IPaprController.InvalidCollateral.selector);
        IPaprController.Collateral[] memory c = new IPaprController.Collateral[](1);
        c[0] = IPaprController.Collateral(ERC721(address(invalidNFT)), 1);
        controller.addCollateral(c);
    }

    /// @notice Add NFT as collateral
    function _addCollateral() internal {
        vm.startPrank(borrower);
        nft.approve(address(controller), collateralId);
        IPaprController.Collateral[] memory c = new IPaprController.Collateral[](1);
        c[0] = collateral;
        controller.addCollateral(c);
    }
}
