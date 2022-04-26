const { expect, assert } = require("chai");
const { ethers } = require("hardhat");
const { wethAddress, osqthAddress, usdcAddress } = require("./common");
const { utils } = ethers;
const { resetFork, getWETH, getUSDC, getERC20Balance, getAndApprove, assertWP } = require("./helpers");
const { hardhatDeploy, deploymentParams, deployContract } = require('./deploy');

describe.only("Strategy rebalance sell", function () {

    let swaper, depositor, keeper, governance;
    it("Should set actors", async function () {
        const signers = await ethers.getSigners();
        governance = signers[5];
        depositor = signers[6];
        depositor = signers[7];
        keeper = signers[8];
        swaper = signers[9];
    });

    let Vault, VaultMath, VaultTreasury, contractHelper, tx;
    it("Should deploy contract", async function () {
        await resetFork();

        [Vault, VaultMath, VaultTreasury] = await hardhatDeploy(governance, deploymentParams);

        contractHelper = await deployContract("V3Helper", []);
    });

    const wethInputR = "2651960034925336940";
    const usdcInputR = "34328438697";
    const osqthInputR = "13136856056157859843";
    it("preset", async function () {
        tx = await VaultMath.connect(keeper).setTimeAtLastRebalance(1648646662);
        await tx.wait();

        tx = await VaultMath.connect(keeper).setEthPriceAtLastRebalance("3391393578000000000000");
        await tx.wait();

        await getAndApprove(keeper, Vault.address, wethInputR, usdcInputR, osqthInputR);
    });

    it("deposit", async function () {
        const wethInput = "18702958066838460455";
        const usdcInput = "30406229225";
        const osqthInput = "34339364744543638154";

        await getAndApprove(depositor, Vault.address, wethInput, usdcInput, osqthInput);

        // Balances
        expect(await getERC20Balance(depositor.address, wethAddress)).to.equal(wethInput);
        expect(await getERC20Balance(depositor.address, usdcAddress)).to.equal(usdcInput);
        expect(await getERC20Balance(depositor.address, osqthAddress)).to.equal(osqthInput);

        tx = await Vault
            .connect(depositor)
            .deposit("18410690015258689749", "32743712092", "32849750909396941650", depositor.address, "0", "0", "0");
        await tx.wait();

        // Balances
        expect(await getERC20Balance(depositor.address, wethAddress)).to.equal("0");
        expect(await getERC20Balance(depositor.address, usdcAddress)).to.equal("0");
        expect(await getERC20Balance(depositor.address, osqthAddress)).to.equal("0");

        // Shares
        expect(await getERC20Balance(depositor.address, Vault.address)).to.equal("124866579487341572537626");
    });

    it("swap", async function () {
        const swaper = (await ethers.getSigners())[6];

        const testAmount = utils.parseUnits("1000", 18).toString();
        console.log(testAmount);

        await getWETH(testAmount, contractHelper.address);

        // Balances
        expect(await getERC20Balance(contractHelper.address, usdcAddress)).to.equal("0");
        expect(await getERC20Balance(contractHelper.address, wethAddress)).to.equal(testAmount);

        amount = await contractHelper.connect(swaper).getTwap();
        // console.log(amount);

        tx = await contractHelper.connect(swaper).swap(testAmount);
        await tx.wait();

        for (const i of Array(6)) {
            await hre.network.provider.request({
                method: "evm_mine",
            });
        }

        amount = await contractHelper.connect(swaper).getTwap();
        // console.log(amount);

        // Balances
        expect(await getERC20Balance(contractHelper.address, wethAddress)).to.equal("0");
        expect(await getERC20Balance(contractHelper.address, usdcAddress)).to.equal("3369149847107");
    });

    it("rebalance", async function () {
        const wethInput = wethInputR;
        const usdcInput = usdcInputR;
        const osqthInput = osqthInputR;

        // Balances
        expect(await getERC20Balance(keeper.address, wethAddress)).to.equal(wethInput);
        expect(await getERC20Balance(keeper.address, usdcAddress)).to.equal(usdcInput);
        expect(await getERC20Balance(keeper.address, osqthAddress)).to.equal(osqthInput);

        console.log(await VaultMath._getTotalAmounts());

        tx = await Vault.connect(keeper).timeRebalance(keeper.address, wethInput, usdcInput, osqthInput);
        await tx.wait();

        // Balances
        expect(await getERC20Balance(keeper.address, wethAddress)).to.equal("0");
        expect(await getERC20Balance(keeper.address, usdcAddress)).to.equal("0");
        expect(await getERC20Balance(keeper.address, osqthAddress)).to.equal("47476220800701497987");

        const amount = await VaultMath._getTotalAmounts();
        console.log(amount);
        expect(amount[0].toString()).to.equal("21354918000000000009");
        expect(amount[1].toString()).to.equal("64734667921");
        expect(amount[2].toString()).to.equal("10");//21202509000000000009//TODO
    });

    // it("swap", async function () {
    //     const swaper = (await ethers.getSigners())[6];

    //     const testAmount = utils.parseUnits("10", 12).toString();
    //     console.log(testAmount);

    //     await getUSDC(testAmount, contractHelper.address);

    //     // Balances
    //     expect(await getERC20Balance(contractHelper.address, usdcAddress)).to.equal("13369149847107");
    //     expect(await getERC20Balance(contractHelper.address, wethAddress)).to.equal("0");

    //     // amount = await contractHelper.connect(swaper).getTwapR();
    //     // console.log(amount);

    //     tx = await contractHelper.connect(swaper).swapR(testAmount);
    //     await tx.wait();

    //     for (const i of Array(6)) {
    //         await hre.network.provider.request({
    //             method: "evm_mine",
    //         });
    //     }

    //     // amount = await contractHelper.connect(swaper).getTwapR();
    //     // console.log(amount);

    //     // Balances
    //     expect(await getERC20Balance(contractHelper.address, wethAddress)).to.equal("2932051110438643869477");
    //     expect(await getERC20Balance(contractHelper.address, usdcAddress)).to.equal("3369149847107");
    // });

    // it("withdraw", async function () {
    //     // Shares
    //     expect(await getERC20Balance(depositor.address, Vault.address)).to.equal("124866579487341572537626");

    //     tx = await Vault.connect(depositor).withdraw("124866579487341572537626", "0", "0", "0");
    //     await tx.wait();

    //     // Balances
    //     assert(assertWP(await getERC20Balance(depositor.address, wethAddress), "21354918101763797393", 16, 18), "test");
    //     assert(assertWP(await getERC20Balance(depositor.address, usdcAddress), "64734667920", 4, 6), "test");
    //     assert(
    //         assertWP(await getERC20Balance(depositor.address, osqthAddress), "10", 16, 18),
    //         "test"
    //     );
    //     //21202508688385778328//TODO

    //     const amount = await VaultMath._getTotalAmounts();
    //     console.log(amount);
    //     expect(amount[0].toString()).to.equal("1");
    //     expect(amount[1].toString()).to.equal("1");
    //     expect(amount[2].toString()).to.equal("0");
    // });
});
