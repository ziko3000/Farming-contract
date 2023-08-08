// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract FarmingContract {
    address public admin;
    uint256 public totalDeposited;
    uint256 public tokenARate;  // tokens A per second per token B
    mapping(address => uint256) public balancesB;
    mapping(address => uint256) public lastUpdateTime;
    mapping(address => uint256) public rewards;

    constructor() {
        admin = msg.sender;
    }

    modifier onlyAdmin() {
        require(msg.sender == admin, "Only admin can call this function");
        _;
    }

    function depositTokenA(uint256 amount) external onlyAdmin {
        // Logic for depositing token A
        // You should have a function to transfer tokens into this contract
        // This example assumes ERC20 tokens
    }

    function setTokenARate(uint256 rate) external onlyAdmin {
        tokenARate = rate;
    }

    function depositTokenB(uint256 amount) external {
        updateReward(msg.sender);
        // Logic for depositing token B
        // This example assumes ERC20 tokens
        balancesB[msg.sender] += amount;
        totalDeposited += amount;
    }

    function withdraw() external {
        updateReward(msg.sender);
        uint256 reward = rewards[msg.sender];
        rewards[msg.sender] = 0;
        uint256 deposited = balancesB[msg.sender];
        balancesB[msg.sender] = 0;
        totalDeposited -= deposited;
        // Transfer reward and deposited amount to the user
    }

    function updateReward(address user) internal {
        if (totalDeposited == 0) return;
        uint256 rewardPending = (block.timestamp - lastUpdateTime[user]) * tokenARate * balancesB[user] / totalDeposited;
        rewards[user] += rewardPending;
        lastUpdateTime[user] = block.timestamp;
    }
}
