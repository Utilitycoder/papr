// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import {ERC20} from "solmate/tokens/ERC20.sol";

/// @notice An implementation of solmate ERC20
/// @dev "Test" is the name of token
/// @dev "TEST" is the symbol of the token
/// @dev 18 is decimal place of the token
contract TestERC20 is ERC20("Test", "TEST", 18) {
    
    /// @notice mint Test token
    /// @param to address of the recipient
    /// @param amount amounnt of token to be minted
    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }
}
