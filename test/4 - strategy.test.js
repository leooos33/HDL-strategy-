const { expect, assert } = require("chai");
const { ethers } = require("hardhat");
const { wethAddress, osqthAddress, usdcAddress } = require("./common");
const { assertWP, getAndApprove, getERC20Balance, resetFork } = require("./helpers");
const { hardhatDeploy, deploymentParams } = require('./deploy');

describe("Strategy deposit", function () {
    let governance, depositor;
    it("Should set actors", async function () {
        const signers = await ethers.getSigners();
        governance = signers[5];
        depositor = signers[6];
    });

    let Vault, VaultMath, VaultTreasury, tx;
    it("Should deploy contract", async function () {
        await resetFork();

        const params = [...deploymentParams];
        params[6] = "1000";

        [Vault, VaultMath, VaultTreasury] = await hardhatDeploy(governance, params);
    });

    it("deposit", async function () {
        const amount = await VaultMath
            .connect(depositor)
            ._calcSharesAndAmounts("19855700000000000000", "41326682043", "17933300000000000000");
        console.log("amount", amount);

        const wethInput = amount[1].toString();
        const usdcInput = amount[2].toString();
        const osqthInput = amount[3].toString();

        await getAndApprove(depositor, Vault.address, wethInput, usdcInput, osqthInput);

        // Balances
        expect(await getERC20Balance(depositor.address, wethAddress)).to.equal(wethInput);
        expect(await getERC20Balance(depositor.address, usdcAddress)).to.equal(usdcInput);
        expect(await getERC20Balance(depositor.address, osqthAddress)).to.equal(osqthInput);

        tx = await Vault
            .connect(depositor)
            .deposit(wethInput, usdcInput, osqthInput, depositor.address, "0", "0", "0");
        await tx.wait();

        // Balances
        expect(await getERC20Balance(depositor.address, wethAddress)).to.equal("85300624");
        expect(await getERC20Balance(depositor.address, usdcAddress)).to.equal("0");
        expect(await getERC20Balance(depositor.address, osqthAddress)).to.equal("156615292");

        // Balances
        assert(assertWP(await getERC20Balance(VaultTreasury.address, wethAddress), wethInput, 8, 18), "test");
        assert(assertWP(await getERC20Balance(VaultTreasury.address, usdcAddress), usdcInput, 6, 6), "test");
        assert(assertWP(await getERC20Balance(VaultTreasury.address, osqthAddress), osqthInput, 8, 18), "test");

        // Shares
        expect(await getERC20Balance(depositor.address, Vault.address)).to.equal("124867437697927036272825");
    });

    it("withdraw", async function () {
        // Shares
        expect(await getERC20Balance(depositor.address, Vault.address)).to.equal("124867437697927036272825");

        // Balances
        expect(await getERC20Balance(depositor.address, wethAddress)).to.equal("85300624");
        expect(await getERC20Balance(depositor.address, usdcAddress)).to.equal("0");
        expect(await getERC20Balance(depositor.address, osqthAddress)).to.equal("156615292");

        // Balances
        expect(await getERC20Balance(VaultTreasury.address, wethAddress)).to.equal("18703086612656391443");
        expect(await getERC20Balance(VaultTreasury.address, usdcAddress)).to.equal("30406438208");
        expect(await getERC20Balance(VaultTreasury.address, osqthAddress)).to.equal("34339600759708327238");

        tx = await Vault.connect(depositor).withdraw("124867437697927036272825", "0", "0", "0");
        await tx.wait();

        // Balances
        expect(await getERC20Balance(depositor.address, wethAddress)).to.equal("18703086612741692067");
        expect(await getERC20Balance(depositor.address, usdcAddress)).to.equal("30406438207");
        expect(await getERC20Balance(depositor.address, osqthAddress)).to.equal("34339600759864942530");

        // Balances
        expect(await getERC20Balance(VaultTreasury.address, wethAddress)).to.equal("0");
        expect(await getERC20Balance(VaultTreasury.address, usdcAddress)).to.equal("1");
        expect(await getERC20Balance(VaultTreasury.address, osqthAddress)).to.equal("0");

        // Shares
        expect(await getERC20Balance(depositor.address, Vault.address)).to.equal("0");
    });
});
