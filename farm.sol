// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

contract FarmingContract is Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    IERC20 public rewardToken; // Token A
    IERC20 public stakingToken; // Token B

    struct StakingInfo {
        uint256 amount;
        uint256 rewardDebt;
    }

    uint256 public totalStaked;
    uint256 public rewardPerTokenStored;
    uint256 public lastUpdateTime;
    uint256 public rewardRate;

    mapping(address => StakingInfo) public stakers;

    event Staked(address indexed user, uint256 amount);
    event Withdrawn(address indexed user, uint256 amount);
    event RewardPaid(address indexed user, uint256 reward, uint256 rewardAmount);

    constructor(address _rewardToken, address _stakingToken) {
        rewardToken = IERC20(_rewardToken);
        stakingToken = IERC20(_stakingToken);
    }

    modifier updateReward(address account) {
        rewardPerTokenStored = rewardPerToken();
        lastUpdateTime = block.timestamp;
        if (account != address(0)) {
            stakers[account].rewardDebt = rewardPerTokenStored;
        }
        _;
    }

    function setRewardRate(uint256 _rewardRate) external onlyOwner {
        rewardRate = _rewardRate;
    }

    function initializeRewardDistribution(uint256 rewardAmount, uint256 duration) external onlyOwner {
        require(rewardAmount > 0 && duration > 0, "Invalid input");
        uint256 balance = rewardToken.balanceOf(address(this));
        require(balance >= rewardAmount, "Insufficient reward balance");
        rewardRate = rewardAmount / duration;
    }

    function rewardPerToken() public view returns (uint256) {
        if (totalStaked == 0) {
            return rewardPerTokenStored;
        }
        return rewardPerTokenStored + (block.timestamp - lastUpdateTime) * rewardRate / totalStaked;
    }

    function earned(address account) public view returns (uint256) {
        return (stakers[account].amount * (rewardPerToken() - stakers[account].rewardDebt)) / 1e18;
    }

    function stake(uint256 amount) external updateReward(msg.sender) nonReentrant {
        require(amount > 0, "Cannot stake 0");
        totalStaked += amount;
        stakers[msg.sender].amount += amount;
        stakingToken.safeTransferFrom(msg.sender, address(this), amount);
        emit Staked(msg.sender, amount);
    }

    function withdraw(uint256 amount) external updateReward(msg.sender) nonReentrant {
        require(amount > 0, "Cannot withdraw 0");
        totalStaked -= amount;
        stakers[msg.sender].amount -= amount;
        stakingToken.safeTransfer(msg.sender, amount);
        emit Withdrawn(msg.sender, amount);
    }

    function getReward() external updateReward(msg.sender) nonReentrant {
        uint256 reward = earned(msg.sender);
        if (reward > 0) {
            stakers[msg.sender].rewardDebt = 0;
            uint256 rewardAmount = rewardToken.balanceOf(address(this));
            if (rewardAmount > reward) {
                rewardAmount = reward;
            }
            rewardToken.safeTransfer(msg.sender, rewardAmount);
            emit RewardPaid(msg.sender, reward, rewardAmount);
        }
    }

    function exit() external nonReentrant {
        withdraw(stakers[msg.sender].amount);
        getReward();
    }

    function adminDepositRewards(uint256 amount) external onlyOwner {
        rewardToken.safeTransferFrom(msg.sender, address(this), amount);
    }
}
