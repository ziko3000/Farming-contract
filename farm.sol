// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

/**
 * @title FarmingContract
 * @dev This contract allows users to stake tokens and earn rewards.
 */
contract FarmingContract is Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    // The token users receive as a reward for staking.
    IERC20 public rewardToken;

    // The token users stake to participate in the farming program.
    IERC20 public stakingToken;

    // Struct to hold details about the user's staking and rewards.
    struct StakingInfo {
        uint256 amount;        // The amount of tokens staked by the user.
        uint256 rewardDebt;    // The rewards that the user has claimed so far.
    }

    // Total amount of tokens staked in the contract by all users.
    uint256 public totalStaked;

    // The reward per token staked, updated during each operation.
    uint256 public rewardPerTokenStored;

    // The last timestamp when the rewards were last updated.
    uint256 public lastUpdateTime;

    // The rate at which rewards are distributed per token, per second.
    uint256 public rewardRate;

    // Flag to track if the reward distribution has been initialized.
    bool public rewardInitialized = false;

    // Maps each user's address to their staking and reward information.
    mapping(address => StakingInfo) public stakers;

    event Staked(address indexed user, uint256 amount);
    event Withdrawn(address indexed user, uint256 amount);
    event RewardPaid(address indexed user, uint256 reward);

    /**
     * @notice Constructs the `FarmingContract` contract.
     * @param _rewardToken The address of the reward token.
     * @param _stakingToken The address of the staking token.
     */
    constructor(address _rewardToken, address _stakingToken) {
        rewardToken = IERC20(_rewardToken);
        stakingToken = IERC20(_stakingToken);
    }

    /**
     * @notice Update the reward for a given account. This must be called whenever the balance of the staker is changed.
     * @param account The address of the account to update.
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
     * @notice Sets the rate of reward distribution.
     * @dev Only callable by the contract owner.
     * @param _rewardRate The new rate at which rewards will be distributed.
     */
    function setRewardRate(uint256 _rewardRate) external onlyOwner {
        rewardRate = _rewardRate;
    }

    /**
     * @notice Initializes the reward distribution mechanism.
     * @dev Can only be called once by the contract owner.
     * @param rewardAmount The total amount of rewards to distribute.
     * @param duration The time over which the rewards will be distributed.
     */
    function initializeRewardDistribution(uint256 rewardAmount, uint256 duration) external onlyOwner {
        // Ensure rewards have not been initialized before.
        require(!rewardInitialized, "Reward already initialized");

        // Ensure reward amount and duration are valid.
        require(rewardAmount > 0, "Invalid reward amount");
        require(duration > 0, "Invalid duration");

        // Ensure the contract has enough rewards to distribute.
        uint256 balance = rewardToken.balanceOf(address(this));
        require(balance >= rewardAmount, "Insufficient reward balance");

        rewardRate = rewardAmount / duration;
        rewardInitialized = true;
    }

    /**
     * @notice Calculate the current reward per staked token.
     * @return The reward amount per token staked.
     */
    function rewardPerToken() public view returns (uint256) {
        if (totalStaked == 0) {
            return rewardPerTokenStored;
        }
        return rewardPerTokenStored + (block.timestamp - lastUpdateTime) * rewardRate / totalStaked;
    }

    /**
     * @notice Calculate the amount of rewards earned by an account.
     * @param account The address of the staking account.
     * @return The amount of rewards earned by the account.
     */
    function earned(address account) public view returns (uint256) {
        return (stakers[account].amount * (rewardPerToken() - stakers[account].rewardDebt)) / 1e18;
    }

    /**
     * @notice Stake a specific amount of tokens to earn rewards.
     * @param amount The amount of tokens to stake.
     */
    function stake(uint256 amount) external updateReward(msg.sender) nonReentrant {
        // Ensure the staking amount is greater than zero.
        require(amount > 0, "Cannot stake 0");

        totalStaked += amount;
        stakers[msg.sender].amount += amount;

        // Use SafeERC20 to ensure a safe token transfer.
        stakingToken.safeTransferFrom(msg.sender, address(this), amount);

        emit Staked(msg.sender, amount);
    }

    /**
     * @notice Withdraw staked tokens and stop earning rewards on them.
     * @param amount The amount of tokens to withdraw.
     */
    function withdraw(uint256 amount) public updateReward(msg.sender) nonReentrant {
        // Ensure the withdrawal amount is greater than zero.
        require(amount > 0, "Cannot withdraw 0");

        totalStaked -= amount;
        stakers[msg.sender].amount -= amount;

        // Use SafeERC20 to ensure a safe token transfer.
        stakingToken.safeTransfer(msg.sender, amount);

        emit Withdrawn(msg.sender, amount);
    }

    /**
     * @notice Claim the rewards earned so far.
     */
    function getReward() public updateReward(msg.sender) nonReentrant {
        uint256 reward = earned(msg.sender);

        // Ensure the user has rewards to claim.
        if (reward > 0) {
            uint256 rewardAmount = rewardToken.balanceOf(address(this));
            
            // In case the contract doesn't have enough rewards, adjust to the maximum possible.
            if (rewardAmount < reward) {
                reward = rewardAmount;
            }

            stakers[msg.sender].rewardDebt += reward;

            // Use SafeERC20 to ensure a safe token transfer.
            rewardToken.safeTransfer(msg.sender, reward);

            emit RewardPaid(msg.sender, reward);
        }
    }

    /**
     * @notice Withdraw all staked tokens and claim all rewards.
     */
    function exit() external nonReentrant {
        withdraw(stakers[msg.sender].amount);
        getReward();
    }

    /**
     * @notice Allows the owner to deposit additional reward tokens into the contract.
     * @param amount The amount of reward tokens to deposit.
     */
   

    function adminDepositRewards(uint256 amount) external onlyOwner {
        rewardToken.safeTransferFrom(msg.sender, address(this), amount);
    }
}
