const { expect, assert } = require("chai");
const { ethers } = require("hardhat");
const { wethAddress, osqthAddress, usdcAddress } = require("./common");
const { assertWP, getAndApprove, getERC20Balance, resetFork, logBlock } = require("./helpers");
const { hardhatDeploy, deploymentParams } = require("./deploy");

describe.only("Strategy deposit", function () {
    let depositor, governance;
    it("Should set actors", async function () {
        const signers = await ethers.getSigners();
        governance = signers[0];
        depositor = signers[6];
    });

    let Vault, VaultMath, VaultTreasury, tx;
    it("Should deploy contract", async function () {
        await resetFork();

        const params = [...deploymentParams];
        [Vault, VaultMath, VaultTreasury] = await hardhatDeploy(governance, params);
        await logBlock();
        //14487789 1648646654
    });

    it("deposit", async function () {
        await Vault.connect(depositor).calcSharesAndAmounts(
            "19855700000000000000",
            "41326682043",
            "17933300000000000000",
            "0"
        );
        const amount = [
            "124867437698496528921447",
            "18703086612741692067",
            "30406438208",
            "34339600759864942530",
        ];
        console.log(amount);

        const wethInput = amount[1];
        const usdcInput = amount[2];
        const osqthInput = amount[3];

        await getAndApprove(depositor, Vault.address, wethInput, usdcInput, osqthInput);

        // Balances
        expect(await getERC20Balance(depositor.address, wethAddress)).to.equal(wethInput);
        expect(await getERC20Balance(depositor.address, usdcAddress)).to.equal(usdcInput);
        expect(await getERC20Balance(depositor.address, osqthAddress)).to.equal(osqthInput);

        tx = await Vault.connect(depositor).deposit(wethInput, usdcInput, osqthInput, depositor.address, "0", "0", "0");
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

        // Shares
        expect(await getERC20Balance(depositor.address, Vault.address)).to.equal("0");
    });
});
