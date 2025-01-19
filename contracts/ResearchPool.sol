// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./InnoToken.sol";
import "./ProjectStorage.sol";

contract ResearchPool is ReentrancyGuard, Pausable, Ownable {
    InnoToken public innoToken;
    ProjectStorage public projectStorage;

    struct ResearchRequest {
        uint256 projectId;      // Reference to ProjectStorage project
        uint256 rewardAmount;
        uint256 minVotingPower;
        uint256 votingEndTime;
        bool isActive;
        bool isFunded;
        mapping(address => bool) hasVoted;
        uint256 positiveVotes;
        uint256 negativeVotes;
    }

    mapping(uint256 => ResearchRequest) public requests;
    uint256 public requestCount;
    uint256 public minRewardAmount;
    uint256 public votingPeriod;

    event RequestCreated(uint256 indexed requestId, uint256 indexed projectId, uint256 rewardAmount);
    event VoteCast(uint256 indexed requestId, address indexed voter, bool support);
    event RequestFunded(uint256 indexed requestId, uint256 rewardAmount);
    event MinRewardAmountUpdated(uint256 newAmount);
    event VotingPeriodUpdated(uint256 newPeriod);

    constructor(
        address _innoToken,
        address _projectStorage,
        uint256 _minRewardAmount,
        uint256 _votingPeriod
    ) {
        innoToken = InnoToken(_innoToken);
        projectStorage = ProjectStorage(_projectStorage);
        minRewardAmount = _minRewardAmount;
        votingPeriod = _votingPeriod;
        requestCount = 0;
    }

    function createRequest(
        string memory title,
        string memory description,
        string memory ipfsHash,
        uint256 rewardAmount,
        uint256 minVotingPower
    ) external whenNotPaused nonReentrant returns (uint256) {
        require(rewardAmount >= minRewardAmount, "Reward too low");
        require(innoToken.balanceOf(msg.sender) >= rewardAmount, "Insufficient balance");
        require(minVotingPower > 0, "Invalid voting power requirement");

        // Create project in storage
        uint256 projectId = projectStorage.createProject(
            title,
            description,
            ipfsHash,
            rewardAmount,
            votingPeriod
        );

        // Create research request
        uint256 requestId = requestCount++;
        ResearchRequest storage request = requests[requestId];
        request.projectId = projectId;
        request.rewardAmount = rewardAmount;
        request.minVotingPower = minVotingPower;
        request.votingEndTime = block.timestamp + votingPeriod;
        request.isActive = true;
        request.isFunded = false;

        // Transfer tokens to contract
        require(innoToken.transferFrom(msg.sender, address(this), rewardAmount), "Transfer failed");

        emit RequestCreated(requestId, projectId, rewardAmount);
        return requestId;
    }

    function castVote(uint256 requestId, bool support) external whenNotPaused nonReentrant {
        ResearchRequest storage request = requests[requestId];
        require(request.isActive, "Request not active");
        require(block.timestamp < request.votingEndTime, "Voting ended");
        require(!request.hasVoted[msg.sender], "Already voted");
        require(innoToken.balanceOf(msg.sender) >= request.minVotingPower, "Insufficient voting power");

        request.hasVoted[msg.sender] = true;
        if (support) {
            request.positiveVotes++;
        } else {
            request.negativeVotes++;
        }

        emit VoteCast(requestId, msg.sender, support);
    }

    function finalizeRequest(uint256 requestId) external whenNotPaused nonReentrant {
        ResearchRequest storage request = requests[requestId];
        require(request.isActive, "Request not active");
        require(block.timestamp >= request.votingEndTime, "Voting not ended");
        require(!request.isFunded, "Already funded");

        request.isActive = false;
        
        if (request.positiveVotes > request.negativeVotes) {
            request.isFunded = true;
            require(innoToken.transfer(msg.sender, request.rewardAmount), "Transfer failed");
            emit RequestFunded(requestId, request.rewardAmount);
        } else {
            // Return funds to creator
            address creator = projectStorage.getProjectCreator(request.projectId);
            require(innoToken.transfer(creator, request.rewardAmount), "Transfer failed");
        }
    }

    function updateMinRewardAmount(uint256 newAmount) external onlyOwner {
        minRewardAmount = newAmount;
        emit MinRewardAmountUpdated(newAmount);
    }

    function updateVotingPeriod(uint256 newPeriod) external onlyOwner {
        votingPeriod = newPeriod;
        emit VotingPeriodUpdated(newPeriod);
    }

    function getVoteCounts(uint256 requestId) external view returns (uint256 positive, uint256 negative) {
        ResearchRequest storage request = requests[requestId];
        return (request.positiveVotes, request.negativeVotes);
    }

    function hasVoted(uint256 requestId, address voter) external view returns (bool) {
        return requests[requestId].hasVoted[voter];
    }

    function pause() external onlyOwner {
        _pause();
    }

    function unpause() external onlyOwner {
        _unpause();
    }
}
