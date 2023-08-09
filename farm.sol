// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

/**
 * @title FarmingContract
 * @dev A contract that allows users to stake tokens and earn rewards.
 */
contract FarmingContract is Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    // Token users receive as a reward for staking.
    IERC20 public rewardToken;

    // Token users stake to participate in the reward program.
    IERC20 public stakingToken;

    // Information about the staked tokens and rewards for each user.
    struct StakingInfo {
        uint256 amount;  // Amount of tokens staked by the user.
        uint256 rewardDebt;  // The reward debt the user has accumulated.
    }

    // Total tokens staked in the contract by all users.
    uint256 public totalStaked;

    // Stored reward per token. Used to calculate the user's reward.
    uint256 public rewardPerTokenStored;

    // Timestamp of the last reward update.
    uint256 public lastUpdateTime;

    // Rate at which the reward is distributed per token, per second.
    uint256 public rewardRate;

    // Flag indicating if the reward distribution has been initialized.
    bool public rewardInitialized = false;

    // Mapping from user address to their staking information.
    mapping(address => StakingInfo) public stakers;

    event Staked(address indexed user, uint256 amount);
    event Withdrawn(address indexed user, uint256 amount);
    event RewardPaid(address indexed user, uint256 reward);

    /**
     * @dev Contract constructor.
     * @param _rewardToken Address of the reward token.
     * @param _stakingToken Address of the staking token.
     */
    constructor(address _rewardToken, address _stakingToken) {
        rewardToken = IERC20(_rewardToken);
        stakingToken = IERC20(_stakingToken);
    }

    /**
     * @dev Modifier to update the reward of the given account.
     * @param account Address of the account whose reward needs updating.
     */
    modifier updateReward(address account) {
        rewardPerTokenStored = rewardPerToken();
        lastUpdateTime = block.timestamp;
        if (account != address(0)) {
            uint256 earnedReward = earned(account);
            stakers[account].rewardDebt = earnedReward;
        }
        _;
    }

    /**
     * @dev Sets the reward rate. Only callable by the owner.
     * @param _rewardRate New reward rate.
     */
    function setRewardRate(uint256 _rewardRate) external onlyOwner {
        rewardRate = _rewardRate;
    }

    /**
     * @dev Initializes the reward distribution rate and duration. Can only be called once.
     * @param rewardAmount Total reward amount to be distributed.
     * @param duration Duration over which the reward will be distributed.
     */
    function initializeRewardDistribution(uint256 rewardAmount, uint256 duration) external onlyOwner {
        require(!rewardInitialized, "Reward already initialized");
        require(rewardAmount > 0, "Invalid reward amount");
        require(duration > 0, "Invalid duration");
        uint256 balance = rewardToken.balanceOf(address(this));
        require(balance >= rewardAmount, "Insufficient reward balance");
        rewardRate = rewardAmount / duration;
        rewardInitialized = true;
    }

    /**
     * @dev Calculates the accumulated reward per token.
     * @return The current reward per token.
     */
    function rewardPerToken() public view returns (uint256) {
        if (totalStaked == 0) {
            return rewardPerTokenStored;
        }
        return rewardPerTokenStored + (block.timestamp - lastUpdateTime) * rewardRate / totalStaked;
    }

    /**
     * @dev Calculates the reward earned by the given account.
     * @param account Address of the account.
     * @return The reward earned by the account.
     */
    function earned(address account) public view returns (uint256) {
        return (stakers[account].amount * (rewardPerToken() - stakers[account].rewardDebt)) / 1e18;
    }

    /**
     * @dev Allows a user to stake a certain amount of tokens.
     * @param amount Amount of tokens to stake.
     */
    function stake(uint256 amount) external updateReward(msg.sender) nonReentrant {
        require(amount > 0, "Cannot stake 0");
        totalStaked += amount;
        stakers[msg.sender].amount += amount;
        stakingToken.safeTransferFrom(msg.sender, address(this), amount);
        emit Staked(msg.sender, amount);
    }

    /**
     * @dev Allows a user to withdraw a certain amount of their staked tokens.
     * @param amount Amount of tokens to withdraw.
     */
    function withdraw(uint256 amount) public updateReward(msg.sender) nonReentrant {
        require(amount > 0, "Cannot withdraw 0");
        totalStaked -= amount;
        stakers[msg.sender].amount -= amount;
        stakingToken.safeTransfer(msg.sender, amount);
        emit Withdrawn(msg.sender, amount);
    }

    /**
     * @dev Allows a user to claim their reward.
     */
    function getReward() public updateReward(msg.sender) nonReentrant {
        uint256 reward = earned(msg.sender);
        if (reward > 0) {
            uint256 rewardAmount = rewardToken.balanceOf(address(this));
            if (rewardAmount < reward) {
                reward = rewardAmount;  // Adjusting the reward to available amount
            }
            stakers[msg.sender].rewardDebt += reward;
            rewardToken.safeTransfer(msg.sender, reward);
            emit RewardPaid(msg.sender, reward);
        }
    }

    /**
     * @dev Allows a user to withdraw all their staked tokens and claim their reward.
     */
    function exit() external nonReentrant {
        withdraw(stakers[msg.sender].amount);
        getReward();
    }

    /**
     * @dev Allows the owner to deposit reward tokens into the contract.
     * @param amount Amount of reward tokens to deposit.
     */
    function adminDepositRewards(uint256 amount) external onlyOwner {
        rewardToken.safeTransferFrom(msg.sender, address(this), amount);
    }
}
