// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import {ERC721} from "solmate/tokens/ERC721.sol";

/// @notice An implementation of solmate ER721
/// @dev "Test" is the name of token
/// @dev "TEST" is the symbol of the token
contract TestERC721 is ERC721("Test", "TEST") {
    /// @notice Returns the URI of a given token.
    /// @param id The ID of the token.
    /// @return The URI of a given token
    function tokenURI(
        uint256 id
    ) public view override returns (string memory) {}

    /// @notice mint Test ERC721 token
    /// @param to address of the recipient
    /// @param id The id of the token to be minted
    function mint(address to, uint256 id) external {
        _mint(to, id);
    }
}
