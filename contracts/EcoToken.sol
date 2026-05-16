// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";

/**
 * @title EcoToken (EFT)
 * @notice ERC-20 token rewarded for verified eco-friendly activities.
 *         Supports staking to earn validator governance weight.
 */
contract EcoToken is ERC20, AccessControl, Pausable {

    bytes32 public constant DISTRIBUTOR_ROLE = keccak256("DISTRIBUTOR_ROLE");
    bytes32 public constant PAUSER_ROLE      = keccak256("PAUSER_ROLE");

    // ── Staking ──────────────────────────────────────────────────────────────

    struct StakeInfo {
        uint256 amount;
        uint256 since;   // block.timestamp when staked
    }

    mapping(address => StakeInfo) public stakes;
    uint256 public totalStaked;

    uint256 public constant LOCK_PERIOD = 7 days;

    event Staked(address indexed user, uint256 amount);
    event Unstaked(address indexed user, uint256 amount);

    // ─────────────────────────────────────────────────────────────────────────

    constructor(address admin) ERC20("EcoFriendly Token", "EFT") {
        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        _grantRole(PAUSER_ROLE, admin);
    }

    // ── Minting ───────────────────────────────────────────────────────────────

    /// @notice Mint tokens to a recipient (called by EcoTracker on reward).
    function mint(address to, uint256 amount)
        external
        onlyRole(DISTRIBUTOR_ROLE)
        whenNotPaused
    {
        _mint(to, amount);
    }

    // ── Staking ───────────────────────────────────────────────────────────────

    /**
     * @notice Stake tokens to accumulate governance weight.
     *         Staked tokens are locked for LOCK_PERIOD before unstaking.
     */
    function stake(uint256 amount) external whenNotPaused {
        require(amount > 0, "EcoToken: zero amount");
        require(balanceOf(msg.sender) >= amount, "EcoToken: insufficient balance");

        _transfer(msg.sender, address(this), amount);
        stakes[msg.sender].amount += amount;
        stakes[msg.sender].since   = block.timestamp;
        totalStaked += amount;

        emit Staked(msg.sender, amount);
    }

    /**
     * @notice Unstake tokens after the lock period.
     */
    function unstake(uint256 amount) external {
        StakeInfo storage s = stakes[msg.sender];
        require(s.amount >= amount, "EcoToken: insufficient stake");
        require(
            block.timestamp >= s.since + LOCK_PERIOD,
            "EcoToken: tokens still locked"
        );

        s.amount   -= amount;
        totalStaked -= amount;
        _transfer(address(this), msg.sender, amount);

        emit Unstaked(msg.sender, amount);
    }

    /**
     * @notice Governance weight = staked amount (linear).
     *         Extend this for quadratic or time-weighted voting if desired.
     */
    function governanceWeight(address user) external view returns (uint256) {
        return stakes[user].amount;
    }

    // ── Pause ─────────────────────────────────────────────────────────────────

    function pause()   external onlyRole(PAUSER_ROLE) { _pause(); }
    function unpause() external onlyRole(PAUSER_ROLE) { _unpause(); }

    // ── Overrides ─────────────────────────────────────────────────────────────

    function _update(address from, address to, uint256 value)
        internal
        override
        whenNotPaused
    {
        super._update(from, to, value);
    }
}
