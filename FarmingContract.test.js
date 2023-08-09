import { ethers, waffle } from "hardhat";
import { expect } from "chai";
import { parseEther } from "ethers/lib/utils";

const { deployContract } = waffle;

describe("FarmingContract", () => {
    let stakingToken, rewardToken, farming, owner, user1, user2;

    beforeEach(async () => {
        [owner, user1, user2] = await ethers.getSigners();

        const MockERC20 = await ethers.getContractFactory("MockERC20");
        stakingToken = await MockERC20.deploy("StakingToken", "STK", parseEther("1000000"));
        rewardToken = await MockERC20.deploy("RewardToken", "RTK", parseEther("1000000"));

        const FarmingContract = await ethers.getContractFactory("FarmingContract");
        farming = await FarmingContract.deploy(rewardToken.address, stakingToken.address);

        await rewardToken.transfer(farming.address, parseEther("1000"));
    });

    it("should allow users to stake tokens", async () => {
        await stakingToken.transfer(user1.address, parseEther("100"));
        await stakingToken.connect(user1).approve(farming.address, parseEther("100"));
        await farming.connect(user1).stake(parseEther("50"));

        const userInfo = await farming.stakers(user1.address);
        expect(userInfo.amount.toString()).to.equal(parseEther("50").toString());
    });

    it("should distribute rewards", async () => {
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
    it("should allow users to withdraw staked tokens", async () => {
        await stakingToken.transfer(user1.address, parseEther("100"));
        await stakingToken.connect(user1).approve(farming.address, parseEther("100"));
        await farming.connect(user1).stake(parseEther("50"));

        await farming.connect(user1).withdraw(parseEther("25"));

        const userInfo = await farming.stakers(user1.address);
        expect(userInfo.amount.toString()).to.equal(parseEther("25").toString());
    });

    it("should allow users to exit (withdraw all and get reward)", async () => {
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

    it("should allow owner to deposit rewards", async () => {
        await rewardToken.transfer(owner.address, parseEther("500"));
        await rewardToken.connect(owner).approve(farming.address, parseEther("500"));
        await farming.connect(owner).adminDepositRewards(parseEther("500"));

        const contractRewardBalance = await rewardToken.balanceOf(farming.address);
        expect(contractRewardBalance.toString()).to.equal(parseEther("1500").toString()); // 1000 initial + 500 added
    });

    it("should not allow non-owner to deposit rewards", async () => {
        await rewardToken.transfer(user2.address, parseEther("50"));
        await rewardToken.connect(user2).approve(farming.address, parseEther("50"));
        
        await expect(farming.connect(user2).adminDepositRewards(parseEther("50")))
            .to.be.revertedWith("Ownable: caller is not the owner");
    });

    it("should not allow staking more tokens than owned", async () => {
        await stakingToken.transfer(user1.address, parseEther("10"));
        await stakingToken.connect(user1).approve(farming.address, parseEther("100"));
        
        await expect(farming.connect(user1).stake(parseEther("50")))
            .to.be.revertedWith("ERC20: transfer amount exceeds balance");
    });
    // ... other tests

});
