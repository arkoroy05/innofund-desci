// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./InnoToken.sol";

contract PerkSystem is ReentrancyGuard, Pausable, Ownable {
    InnoToken public innoToken;

    struct Perk {
        string name;
        string description;
        uint256 requiredAmount;
        bool isStaking;
        uint256 stakingDuration;
        bool isActive;
    }

    struct UserStake {
        uint256 amount;
        uint256 startTime;
        uint256 endTime;
        bool isActive;
    }

    mapping(uint256 => Perk) public perks;
    mapping(address => mapping(uint256 => UserStake)) public userStakes;
    uint256 public perkCount;

    event PerkCreated(uint256 indexed perkId, string name, uint256 requiredAmount);
    event PerkUpdated(uint256 indexed perkId, string name, uint256 requiredAmount);
    event PerkDeactivated(uint256 indexed perkId);
    event StakeStarted(address indexed user, uint256 indexed perkId, uint256 amount);
    event StakeEnded(address indexed user, uint256 indexed perkId);

    constructor(address _innoToken) {
        innoToken = InnoToken(_innoToken);
        perkCount = 0;
    }

    function createPerk(
        string memory name,
        string memory description,
        uint256 requiredAmount,
        bool isStaking,
        uint256 stakingDuration
    ) external onlyOwner returns (uint256) {
        require(bytes(name).length > 0, "Empty name");
        require(requiredAmount > 0, "Invalid amount");
        if (isStaking) {
            require(stakingDuration > 0, "Invalid duration");
        }

        uint256 perkId = perkCount++;
        perks[perkId] = Perk({
            name: name,
            description: description,
            requiredAmount: requiredAmount,
            isStaking: isStaking,
            stakingDuration: stakingDuration,
            isActive: true
        });

        emit PerkCreated(perkId, name, requiredAmount);
        return perkId;
    }

    function updatePerk(
        uint256 perkId,
        string memory name,
        string memory description,
        uint256 requiredAmount,
        bool isStaking,
        uint256 stakingDuration
    ) external onlyOwner {
        require(perkId < perkCount, "Invalid perk ID");
        require(bytes(name).length > 0, "Empty name");
        require(requiredAmount > 0, "Invalid amount");
        if (isStaking) {
            require(stakingDuration > 0, "Invalid duration");
        }

        Perk storage perk = perks[perkId];
        require(perk.isActive, "Perk not active");

        perk.name = name;
        perk.description = description;
        perk.requiredAmount = requiredAmount;
        perk.isStaking = isStaking;
        perk.stakingDuration = stakingDuration;

        emit PerkUpdated(perkId, name, requiredAmount);
    }

    function deactivatePerk(uint256 perkId) external onlyOwner {
        require(perkId < perkCount, "Invalid perk ID");
        Perk storage perk = perks[perkId];
        require(perk.isActive, "Already deactivated");

        perk.isActive = false;
        emit PerkDeactivated(perkId);
    }

    function startStake(uint256 perkId) external whenNotPaused nonReentrant {
        require(perkId < perkCount, "Invalid perk ID");
        Perk storage perk = perks[perkId];
        require(perk.isActive, "Perk not active");
        require(perk.isStaking, "Not a staking perk");

        UserStake storage stake = userStakes[msg.sender][perkId];
        require(!stake.isActive, "Already staking");

        uint256 balance = innoToken.balanceOf(msg.sender);
        require(balance >= perk.requiredAmount, "Insufficient balance");

        require(innoToken.transferFrom(msg.sender, address(this), perk.requiredAmount), "Transfer failed");

        stake.amount = perk.requiredAmount;
        stake.startTime = block.timestamp;
        stake.endTime = block.timestamp + perk.stakingDuration;
        stake.isActive = true;

        emit StakeStarted(msg.sender, perkId, perk.requiredAmount);
    }

    function endStake(uint256 perkId) external whenNotPaused nonReentrant {
        UserStake storage stake = userStakes[msg.sender][perkId];
        require(stake.isActive, "No active stake");
        require(block.timestamp >= stake.endTime, "Staking period not over");

        require(innoToken.transfer(msg.sender, stake.amount), "Transfer failed");

        stake.isActive = false;
        emit StakeEnded(msg.sender, perkId);
    }

    function checkPerkEligibility(address user, uint256 perkId) external view returns (bool) {
        require(perkId < perkCount, "Invalid perk ID");
        Perk storage perk = perks[perkId];
        require(perk.isActive, "Perk not active");

        if (perk.isStaking) {
            UserStake storage stake = userStakes[user][perkId];
            return stake.isActive && block.timestamp < stake.endTime;
        } else {
            return innoToken.balanceOf(user) >= perk.requiredAmount;
        }
    }

    function pause() external onlyOwner {
        _pause();
    }

    function unpause() external onlyOwner {
        _unpause();
    }
}
