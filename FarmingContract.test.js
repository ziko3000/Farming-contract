import { ethers } from "hardhat";
import { expect } from "chai";
import { parseEther } from "ethers/lib/utils";

/**
 * @file This file contains tests for the FarmingContract.
 * @notice These tests validate the functionality of staking, rewards, and owner-based operations.
 */
describe("FarmingContract", function () {
    let stakingToken, rewardToken, farming, owner, user1, user2, user3;

    /**
     * @notice Run some shared setup before each of the tests.
     */
    beforeEach(async function () {
        [owner, user1, user2, user3] = await ethers.getSigners();

        // Deploy mock ERC20 for staking and rewards
        const MockERC20 = await ethers.getContractFactory("MockERC20");
        stakingToken = await MockERC20.deploy("StakingToken", "STK", parseEther("1000000"));
        rewardToken = await MockERC20.deploy("RewardToken", "RTK", parseEther("1000000"));

        // Deploy the farming contract
        const FarmingContract = await ethers.getContractFactory("FarmingContract");
        farming = await FarmingContract.deploy(rewardToken.address, stakingToken.address);

        // Transfer initial rewards to the farming contract
        await rewardToken.transfer(farming.address, parseEther("1000"));
    });

    /**
     * @notice Group of tests specifically for staking functionality.
     */
    describe("Staking", function() {
        it("allows users to stake tokens", async function () {
            await stakingToken.transfer(user1.address, parseEther("100"));
            await stakingToken.connect(user1).approve(farming.address, parseEther("100"));
            await farming.connect(user1).stake(parseEther("50"));

            const userInfo = await farming.stakers(user1.address);
            expect(userInfo.amount.toString()).to.equal(parseEther("50").toString());
        });

        it("does not allow staking more tokens than owned", async function () {
            await stakingToken.transfer(user1.address, parseEther("10"));
            await stakingToken.connect(user1).approve(farming.address, parseEther("100"));
            
            await expect(farming.connect(user1).stake(parseEther("50")))
                .to.be.revertedWith("ERC20: transfer amount exceeds balance");
        });
    });

    /**
     * @notice Group of tests for the rewards functionality.
     */
    describe("Rewards", function() {
        it("distributes rewards", async function () {
            await stakingToken.transfer(user1.address, parseEther("100"));
            await stakingToken.connect(user1).approve(farming.address, parseEther("100"));
            await farming.connect(user1).stake(parseEther("50"));
            await farming.initializeRewardDistribution(parseEther("500"), 604800);  // 1 week in seconds

            await ethers.provider.send("evm_increaseTime", [86400]); // Increase time by 1 day
            await ethers.provider.send("evm_mine"); // Mine the next block

            await farming.connect(user1).getReward();

            const rewardBalance = await rewardToken.balanceOf(user1.address);
            expect(rewardBalance).to.be.above(parseEther("0"));
        });

        it("allows users to exit (withdraw all and get reward)", async function () {
            await stakingToken.transfer(user1.address, parseEther("100"));
            await stakingToken.connect(user1).approve(farming.address, parseEther("100"));
            await farming.connect(user1).stake(parseEther("50"));
            await farming.initializeRewardDistribution(parseEther("500"), 604800);  // 1 week in seconds

            await ethers.provider.send("evm_increaseTime", [86400]); // Increase time by 1 day
            await ethers.provider.send("evm_mine"); // Mine the next block

            await farming.connect(user1).exit();

            const userInfo = await farming.stakers(user1.address);
            expect(userInfo.amount.toString()).to.equal(parseEther("0").toString());

            const rewardBalance = await rewardToken.balanceOf(user1.address);
            expect(rewardBalance).to.be.above(parseEther("0"));
        });

        it("does not allow non-owner to deposit rewards", async function () {
            await rewardToken.transfer(user2.address, parseEther("50"));
            await rewardToken.connect(user2).approve(farming.address, parseEther("50"));
            
            await expect(farming.connect(user2).adminDepositRewards(parseEther("50")))
                .to.be.revertedWith("Ownable: caller is not the owner");
        });
    });

// Group of tests for owner-specific functionalities.
    describe("Owner functions", function() {
        it("allows owner to deposit rewards", async function () {
            await rewardToken.transfer(owner.address, parseEther("500"));
            await rewardToken.connect(owner).approve(farming.address, parseEther("500"));
            await farming.connect(owner).adminDepositRewards(parseEther("500"));

            const contractRewardBalance = await rewardToken.balanceOf(farming.address);
            expect(contractRewardBalance.toString()).to.equal(parseEther("1500").toString()); // 1000 initial + 500 added
        });

    });

  
});
