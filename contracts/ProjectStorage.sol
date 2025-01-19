// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/security/Pausable.sol";

contract ProjectStorage is AccessControl, ReentrancyGuard, Pausable {
    bytes32 public constant MANAGER_ROLE = keccak256("MANAGER_ROLE");
    
    struct Project {
        string title;
        string description;
        string ipfsHash;  // Main project content hash
        address creator;
        uint256 goalAmount;
        uint256 raisedAmount;
        uint256 deadline;
        bool isActive;
        string[] fileHashes;  // Array of IPFS hashes for project files
        string[] updates;     // Array of IPFS hashes for project updates
        mapping(address => uint256) contributions;
        mapping(address => bool) teamMembers;
        mapping(string => FileMetadata) files;
    }

    struct FileMetadata {
        string fileName;
        string fileType;
        uint256 uploadTime;
        string ipfsHash;
        bool isPublic;
    }

    struct UserProfile {
        string name;
        string bio;
        string avatarHash;
        string[] projects;
        mapping(string => bool) skills;
        uint256 reputation;
    }

    mapping(uint256 => Project) public projects;
    mapping(address => UserProfile) public userProfiles;
    mapping(address => uint256[]) public userProjects;
    uint256 public projectCount;

    event ProjectCreated(uint256 indexed projectId, address indexed creator, string title, uint256 goalAmount);
    event FileAdded(uint256 indexed projectId, string ipfsHash, string fileName);
    event ProjectUpdated(uint256 indexed projectId, string ipfsHash);
    event TeamMemberAdded(uint256 indexed projectId, address indexed member);
    event ContributionReceived(uint256 indexed projectId, address indexed contributor, uint256 amount);
    event ProfileUpdated(address indexed user, string name);

    constructor() {
        projectCount = 0;
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _setupRole(MANAGER_ROLE, msg.sender);
    }

    function createProject(
        string memory title,
        string memory description,
        string memory ipfsHash,
        uint256 goalAmount,
        uint256 duration
    ) external whenNotPaused nonReentrant returns (uint256) {
        require(bytes(title).length > 0, "Empty title");
        require(bytes(ipfsHash).length > 0, "Empty IPFS hash");
        require(goalAmount > 0, "Invalid goal amount");
        require(duration >= 1 days && duration <= 365 days, "Invalid duration");

        uint256 projectId = projectCount++;
        Project storage project = projects[projectId];
        project.title = title;
        project.description = description;
        project.ipfsHash = ipfsHash;
        project.creator = msg.sender;
        project.goalAmount = goalAmount;
        project.deadline = block.timestamp + duration;
        project.isActive = true;

        userProjects[msg.sender].push(projectId);
        userProfiles[msg.sender].projects.push(title);

        emit ProjectCreated(projectId, msg.sender, title, goalAmount);
        return projectId;
    }

    function addProjectFile(
        uint256 projectId,
        string memory fileName,
        string memory fileType,
        string memory ipfsHash,
        bool isPublic
    ) external whenNotPaused nonReentrant {
        Project storage project = projects[projectId];
        require(msg.sender == project.creator || project.teamMembers[msg.sender], "Not authorized");
        require(bytes(ipfsHash).length > 0, "Empty IPFS hash");

        project.fileHashes.push(ipfsHash);
        project.files[ipfsHash] = FileMetadata({
            fileName: fileName,
            fileType: fileType,
            uploadTime: block.timestamp,
            ipfsHash: ipfsHash,
            isPublic: isPublic
        });

        emit FileAdded(projectId, ipfsHash, fileName);
    }

    function addProjectUpdate(
        uint256 projectId,
        string memory ipfsHash
    ) external whenNotPaused nonReentrant {
        Project storage project = projects[projectId];
        require(msg.sender == project.creator || project.teamMembers[msg.sender] || hasRole(MANAGER_ROLE, msg.sender), "Not authorized");
        require(bytes(ipfsHash).length > 0, "Empty IPFS hash");

        project.updates.push(ipfsHash);
        emit ProjectUpdated(projectId, ipfsHash);
    }

    function addTeamMember(uint256 projectId, address member) external whenNotPaused {
        Project storage project = projects[projectId];
        require(msg.sender == project.creator || hasRole(MANAGER_ROLE, msg.sender), "Not authorized");
        require(!project.teamMembers[member], "Already team member");

        project.teamMembers[member] = true;
        emit TeamMemberAdded(projectId, member);
    }

    function contribute(uint256 projectId) external payable whenNotPaused nonReentrant {
        Project storage project = projects[projectId];
        require(project.isActive, "Project not active");
        require(block.timestamp < project.deadline, "Project deadline passed");

        project.contributions[msg.sender] += msg.value;
        project.raisedAmount += msg.value;
        emit ContributionReceived(projectId, msg.sender, msg.value);
    }

    function updateProfile(
        string memory name,
        string memory bio,
        string memory avatarHash
    ) external whenNotPaused {
        require(bytes(name).length > 0, "Empty name");
        
        UserProfile storage profile = userProfiles[msg.sender];
        profile.name = name;
        profile.bio = bio;
        if (bytes(avatarHash).length > 0) {
            profile.avatarHash = avatarHash;
        }

        emit ProfileUpdated(msg.sender, name);
    }

    function addSkill(string memory skill) external whenNotPaused {
        require(bytes(skill).length > 0, "Empty skill");
        userProfiles[msg.sender].skills[skill] = true;
    }

    function getProjectFiles(uint256 projectId) external view returns (string[] memory) {
        return projects[projectId].fileHashes;
    }

    function getProjectUpdates(uint256 projectId) external view returns (string[] memory) {
        return projects[projectId].updates;
    }

    function getUserProjects(address user) external view returns (uint256[] memory) {
        return userProjects[user];
    }

    function isTeamMember(uint256 projectId, address user) external view returns (bool) {
        return projects[projectId].teamMembers[user];
    }

    function getContribution(uint256 projectId, address user) external view returns (uint256) {
        return projects[projectId].contributions[user];
    }

    function getProjectCreator(uint256 projectId) external view returns (address) {
        return projects[projectId].creator;
    }

    function pause() external onlyRole(DEFAULT_ADMIN_ROLE) {
        _pause();
    }

    function unpause() external onlyRole(DEFAULT_ADMIN_ROLE) {
        _unpause();
    }
}
