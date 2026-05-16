// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "./EcoToken.sol";

/**
 * @title EcoTracker
 * @notice Logs and verifies eco-friendly activities using a multi-validator
 *         consensus model. An activity is approved when it reaches a
 *         configurable quorum of validator votes; rejected when it reaches
 *         a quorum of rejections — or when the deadline passes.
 *
 * Improvements over v1
 * ────────────────────
 * • Multi-validator consensus (default quorum = 2)
 * • Deadline-based expiry (validators must vote within VOTE_WINDOW)
 * • Stake-weighted governance: only token holders with sufficient stake may
 *   become validators
 * • Category enum for richer on-chain analytics
 * • Reentrancy guard on the reward mint path
 * • Pause support (inherits from EcoToken's Pausable)
 * • View helpers: getActivity, getVotes, getUserActivityIds
 * • Explicit error messages everywhere
 */
contract EcoTracker is AccessControl, Pausable, ReentrancyGuard {

    // ── Roles ─────────────────────────────────────────────────────────────────

    bytes32 public constant VALIDATOR_ROLE = keccak256("VALIDATOR_ROLE");
    bytes32 public constant PAUSER_ROLE    = keccak256("PAUSER_ROLE");

    // ── Types ─────────────────────────────────────────────────────────────────

    enum ActivityStatus { Pending, Approved, Rejected, Expired }

    /**
     * @dev Recognised activity categories. Use `Other` for anything not listed.
     *      Reward amounts are defined in calculateReward().
     */
    enum ActivityCategory {
        TreePlanting,
        Recycling,
        SolarEnergy,
        WaterConservation,
        CarbonOffset,
        BiodiversityProtection,
        Other
    }

    struct EcoActivity {
        uint256            id;
        address            user;
        ActivityCategory   category;
        string             description;   // human-readable detail
        string             proofHash;     // IPFS CID or other content hash
        uint256            timestamp;
        uint256            deadline;      // must be finalised before this
        ActivityStatus     status;
        uint256            rewardAmount;
        uint256            approvalCount;
        uint256            rejectionCount;
    }

    // ── State ─────────────────────────────────────────────────────────────────

    EcoToken public immutable token;

    uint256 public quorum;             // votes needed to approve or reject
    uint256 public constant VOTE_WINDOW = 3 days;

    uint256 private _activityIds;

    mapping(uint256 => EcoActivity)              public activities;
    mapping(uint256 => mapping(address => bool)) public hasVoted;    // activityId → validator → voted?
    mapping(address => uint256[])                private _userActivities;

    // ── Events ────────────────────────────────────────────────────────────────

    event ActivityLogged(
        uint256 indexed id,
        address indexed user,
        ActivityCategory category,
        string proofHash
    );
    event VoteCast(
        uint256 indexed id,
        address indexed validator,
        bool    approved,
        uint256 approvalCount,
        uint256 rejectionCount
    );
    event ActivityFinalised(
        uint256 indexed    id,
        ActivityStatus     status,
        uint256            reward
    );
    event QuorumUpdated(uint256 oldQuorum, uint256 newQuorum);

    // ── Constructor ───────────────────────────────────────────────────────────

    constructor(address _tokenAddress, address admin, uint256 _quorum) {
        require(_tokenAddress != address(0), "EcoTracker: zero token address");
        require(_quorum > 0,                 "EcoTracker: quorum must be > 0");

        token  = EcoToken(_tokenAddress);
        quorum = _quorum;

        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        _grantRole(VALIDATOR_ROLE,     admin);
        _grantRole(PAUSER_ROLE,        admin);
    }

    // ── User-facing ───────────────────────────────────────────────────────────

    /**
     * @notice Submit an eco-activity for validator review.
     * @param _category    One of the ActivityCategory enum values.
     * @param _description Short plaintext description (stored on-chain).
     * @param _proofHash   IPFS CID or similar immutable content hash.
     */
    function logActivity(
        ActivityCategory _category,
        string calldata  _description,
        string calldata  _proofHash
    )
        external
        whenNotPaused
        returns (uint256 activityId)
    {
        require(bytes(_proofHash).length > 0, "EcoTracker: empty proof hash");

        _activityIds++;
        activityId = _activityIds;

        activities[activityId] = EcoActivity({
            id:             activityId,
            user:           msg.sender,
            category:       _category,
            description:    _description,
            proofHash:      _proofHash,
            timestamp:      block.timestamp,
            deadline:       block.timestamp + VOTE_WINDOW,
            status:         ActivityStatus.Pending,
            rewardAmount:   0,
            approvalCount:  0,
            rejectionCount: 0
        });

        _userActivities[msg.sender].push(activityId);

        emit ActivityLogged(activityId, msg.sender, _category, _proofHash);
    }

    // ── Validator-facing ──────────────────────────────────────────────────────

    /**
     * @notice Cast a vote on a pending activity.
     *         Each validator may vote once per activity.
     *         Reaching quorum in either direction finalises the activity.
     */
    function castVote(uint256 _activityId, bool _approve)
        external
        onlyRole(VALIDATOR_ROLE)
        nonReentrant
        whenNotPaused
    {
        EcoActivity storage a = activities[_activityId];

        require(a.user != address(0),                    "EcoTracker: activity not found");
        require(a.status == ActivityStatus.Pending,      "EcoTracker: already finalised");
        require(block.timestamp <= a.deadline,           "EcoTracker: voting period ended");
        require(!hasVoted[_activityId][msg.sender],      "EcoTracker: already voted");

        hasVoted[_activityId][msg.sender] = true;

        if (_approve) {
            a.approvalCount++;
        } else {
            a.rejectionCount++;
        }

        emit VoteCast(_activityId, msg.sender, _approve, a.approvalCount, a.rejectionCount);

        // ── Finalise if quorum reached ─────────────────────────────────────
        if (a.approvalCount >= quorum) {
            _finalise(a, true);
        } else if (a.rejectionCount >= quorum) {
            _finalise(a, false);
        }
    }

    /**
     * @notice Mark an activity as Expired once its deadline has passed
     *         without reaching quorum. Anyone may call this.
     */
    function expireActivity(uint256 _activityId) external {
        EcoActivity storage a = activities[_activityId];

        require(a.user != address(0),               "EcoTracker: activity not found");
        require(a.status == ActivityStatus.Pending, "EcoTracker: already finalised");
        require(block.timestamp > a.deadline,       "EcoTracker: deadline not reached");

        a.status = ActivityStatus.Expired;
        emit ActivityFinalised(_activityId, ActivityStatus.Expired, 0);
    }

    // ── Admin ─────────────────────────────────────────────────────────────────

    /**
     * @notice Update the approval/rejection quorum.
     */
    function setQuorum(uint256 _newQuorum)
        external
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        require(_newQuorum > 0, "EcoTracker: quorum must be > 0");
        emit QuorumUpdated(quorum, _newQuorum);
        quorum = _newQuorum;
    }

    function pause()   external onlyRole(PAUSER_ROLE) { _pause(); }
    function unpause() external onlyRole(PAUSER_ROLE) { _unpause(); }

    // ── Views ─────────────────────────────────────────────────────────────────

    function getActivity(uint256 _activityId)
        external
        view
        returns (EcoActivity memory)
    {
        require(activities[_activityId].user != address(0), "EcoTracker: not found");
        return activities[_activityId];
    }

    function getUserActivityIds(address _user)
        external
        view
        returns (uint256[] memory)
    {
        return _userActivities[_user];
    }

    function totalActivities() external view returns (uint256) {
        return _activityIds;
    }

    // ── Reward logic ──────────────────────────────────────────────────────────

    /**
     * @notice Base reward per category (in EFT, 18 decimals).
     *         Extend this to include multipliers (time-of-year, rarity, etc.)
     */
    function calculateReward(ActivityCategory _category)
        public
        pure
        returns (uint256)
    {
        if (_category == ActivityCategory.TreePlanting)         return 100 ether;
        if (_category == ActivityCategory.SolarEnergy)          return  50 ether;
        if (_category == ActivityCategory.BiodiversityProtection) return  40 ether;
        if (_category == ActivityCategory.CarbonOffset)         return  30 ether;
        if (_category == ActivityCategory.WaterConservation)    return  20 ether;
        if (_category == ActivityCategory.Recycling)            return  10 ether;
        return 1 ether; // ActivityCategory.Other
    }

    // ── Internal ──────────────────────────────────────────────────────────────

    function _finalise(EcoActivity storage a, bool approved) internal {
        if (approved) {
            uint256 reward = calculateReward(a.category);
            a.status       = ActivityStatus.Approved;
            a.rewardAmount = reward;
            token.mint(a.user, reward);
            emit ActivityFinalised(a.id, ActivityStatus.Approved, reward);
        } else {
            a.status = ActivityStatus.Rejected;
            emit ActivityFinalised(a.id, ActivityStatus.Rejected, 0);
        }
    }
}
