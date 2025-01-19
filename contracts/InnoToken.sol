// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";

contract InnoToken is ERC20, Ownable, Pausable {
    mapping(address => bool) public isEarlyAccessUser;
    uint256 public constant EARLY_ACCESS_SUPPLY = 1000000 * 10**18; // 1 million tokens
    uint256 public constant MAX_SUPPLY = 100000000 * 10**18; // 100 million tokens
    uint256 public totalMinted;
    
    event EarlyAccessGranted(address indexed user, uint256 amount);
    
    constructor() ERC20("Inno Research Token", "INNO") {
        _mint(msg.sender, 10000000 * 10**18); // Initial supply of 10 million tokens
        totalMinted = 10000000 * 10**18;
    }
    
    function grantEarlyAccess(address user) external onlyOwner whenNotPaused {
        require(!isEarlyAccessUser[user], "Already has early access");
        require(totalMinted + EARLY_ACCESS_SUPPLY <= MAX_SUPPLY, "Max supply exceeded");
        
        isEarlyAccessUser[user] = true;
        _mint(user, EARLY_ACCESS_SUPPLY);
        totalMinted += EARLY_ACCESS_SUPPLY;
        
        emit EarlyAccessGranted(user, EARLY_ACCESS_SUPPLY);
    }
    
    function burn(uint256 amount) external whenNotPaused {
        _burn(msg.sender, amount);
        totalMinted -= amount;
    }
    
    function pause() external onlyOwner {
        _pause();
    }
    
    function unpause() external onlyOwner {
        _unpause();
    }
    
    // Override transfer functions to check for pause state
    function transfer(address to, uint256 amount) public override whenNotPaused returns (bool) {
        return super.transfer(to, amount);
    }
    
    function transferFrom(address from, address to, uint256 amount) public override whenNotPaused returns (bool) {
        return super.transferFrom(from, to, amount);
    }
}
