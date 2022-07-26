const { expect, assert } = require("chai");
const { ethers } = require("hardhat");
const { utils } = ethers;
const { wethAddress, osqthAddress, usdcAddress } = require("./common");
const {
    mineSomeBlocks,
    resetFork,
    logBlock,
    getAndApprove2,
    getERC20Balance,
    getWETH,
    getOSQTH,
    getUSDC,
} = require("./helpers");
const { hardhatDeploy, deploymentParams } = require("./deploy");
const { BigNumber } = require("ethers");

describe.only("Macro test mainnet", function () {
    let swaper, depositor1, depositor2, depositor3, keeper, governance, swapAmount;
    it("Should set actors", async function () {
        const signers = await ethers.getSigners();
        governance = signers[0];
        depositor1 = signers[7];
        keeper = signers[8];
        swaper = signers[9];
        depositor2 = signers[10];
        depositor3 = signers[11];
    });

    let Vault, VaultAuction, VaultMath, VaultTreasury, VaultStorage, tx;
    it("Should deploy contract", async function () {
        await resetFork(15173789);

        const params = [...deploymentParams];
        deploymentParams[6] = "10000";
        [Vault, VaultAuction, VaultMath, VaultTreasury, VaultStorage] = await hardhatDeploy(governance, params);
        await logBlock();

        const ContractHelper = await ethers.getContractFactory("V3Helper");
        contractHelper = await ContractHelper.deploy();
        await contractHelper.deployed();
    });

    const presets = {
        depositor1: {
            wethInput: "19987318809022169042",
            usdcInput: "15374822619",
            osqthInput: "113434930214010428403",
        },
        depositor2: {
            wethInput: "29987318809025550479",
            usdcInput: "23067111297",
            osqthInput: "170188380388050211866",
        },
        depositor3: {
            wethInput: "25443723573225622250",
            usdcInput: "11532228170",
            osqthInput: "194008074778513958331",
        },
        keeper: {
            wethInput: BigNumber.from("46420453093069060030").add(BigNumber.from("7611641957027153635")).toString(),
            usdcInput: BigNumber.from("35170786530").add(BigNumber.from("6086663569")).toString(),
            osqthInput: BigNumber.from("226662623566831825098").add(BigNumber.from("38536032101104376335")).toString(),
        },
    };
    it("preset", async function () {
        await getAndApprove2(
            keeper,
            VaultAuction.address,
            presets.keeper.wethInput,
            presets.keeper.usdcInput,
            presets.keeper.osqthInput
        );
        await getAndApprove2(
            depositor1,
            Vault.address,
            presets.depositor1.wethInput,
            presets.depositor1.usdcInput,
            presets.depositor1.osqthInput
        );
        await getAndApprove2(
            depositor2,
            Vault.address,
            presets.depositor2.wethInput,
            presets.depositor2.usdcInput,
            presets.depositor2.osqthInput
        );
        await getAndApprove2(
            depositor3,
            Vault.address,
            presets.depositor3.wethInput,
            presets.depositor3.usdcInput,
            presets.depositor3.osqthInput
        );
    });

    it("deposit1", async function () {
        tx = await Vault.connect(depositor1).deposit(
            "17630456391863397407",
            "29892919002",
            "33072912443025954753",
            depositor1.address,
            "0",
            "0",
            "0"
        );
        await tx.wait();

        // State
        const userEthBalanceAfterDeposit = await getERC20Balance(depositor1.address, wethAddress);
        const userUsdcBalanceAfterDeposit = await getERC20Balance(depositor1.address, usdcAddress);
        const userOsqthBalanceAfterDeposit = await getERC20Balance(depositor1.address, osqthAddress);
        const userShareAfterDeposit = await getERC20Balance(depositor1.address, Vault.address);

        console.log("> userEthBalanceAfterDeposit %s", userEthBalanceAfterDeposit);
        console.log("> userUsdcBalanceAfterDeposit %s", userUsdcBalanceAfterDeposit);
        console.log("> userOsqthBalanceAfterDeposit %s", userOsqthBalanceAfterDeposit);
        console.log("> userShareAfterDeposit", userShareAfterDeposit);
    });

    it("withdraw1 -> No liquidity", async function () {
        await expect(Vault.connect(depositor1).withdraw("19974637618044338084", "0", "0", "0")).to.be.revertedWith(
            "C6"
        );
    });

    it("deposit2", async function () {
        tx = await Vault.connect(depositor2).deposit(
            "37630456391863397407",
            "29892919002",
            "33072912443025954753",
            depositor2.address,
            "0",
            "0",
            "0"
        );
        await tx.wait();

        // State
        const userEthBalanceAfterDeposit = await getERC20Balance(depositor2.address, wethAddress);
        const userUsdcBalanceAfterDeposit = await getERC20Balance(depositor2.address, usdcAddress);
        const userOsqthBalanceAfterDeposit = await getERC20Balance(depositor2.address, osqthAddress);
        const userShareAfterDeposit = await getERC20Balance(depositor2.address, Vault.address);

        console.log("> userEthBalanceAfterDeposit %s", userEthBalanceAfterDeposit);
        console.log("> userUsdcBalanceAfterDeposit %s", userUsdcBalanceAfterDeposit);
        console.log("> userOsqthBalanceAfterDeposit %s", userOsqthBalanceAfterDeposit);
        console.log("> userShareAfterDeposit", userShareAfterDeposit);
    });

    it("swap", async function () {
        await mineSomeBlocks(2216);

        swapAmount = utils.parseUnits("100", 18).toString();
        await getWETH(swapAmount, contractHelper.address);
        console.log("> WETH before swap:", await getERC20Balance(contractHelper.address, wethAddress));
        console.log("> USDC before swap:", await getERC20Balance(contractHelper.address, usdcAddress));
        tx = await contractHelper.connect(swaper).swapWETH_USDC(swapAmount);
        await tx.wait();
        console.log("> WETH after swap:", await getERC20Balance(contractHelper.address, wethAddress));
        console.log("> USDC after swap:", await getERC20Balance(contractHelper.address, usdcAddress));

        await mineSomeBlocks(554);

        swapAmount = utils.parseUnits("40", 18).toString();
        await getOSQTH(swapAmount, contractHelper.address, "0x5d296b8de19a3c134efafde57beedad4a1b76334");
        console.log("> OSQTH before swap:", await getERC20Balance(contractHelper.address, osqthAddress));
        console.log("> WETH before swap:", await getERC20Balance(contractHelper.address, wethAddress));
        tx = await contractHelper.connect(swaper).swapOSQTH_WETH(swapAmount);
        await tx.wait();
        console.log("> OSQTH before swap:", await getERC20Balance(contractHelper.address, osqthAddress));
        console.log("> WETH before swap:", await getERC20Balance(contractHelper.address, wethAddress));

        await mineSomeBlocks(83622);
    });

    it("rebalance iterative with real rebalance", async () => {
        const log = {};
        const MockRebalancer = await ethers.getContractFactory("MockRebalancerA");
        mockRebalancer = await MockRebalancer.deploy();
        await mockRebalancer.deployed();

        await mineSomeBlocks(600);

        let succeded = false;
        for (let i = 0; i < 60; i++) {
            console.log(">", i);
            try {
                const arbTx = await mockRebalancer.rebalance();
                await arbTx.wait();
                // succeded = true;
                // const prices = await VaultMath.getPrices();
                // console.log("> Prices:", prices);
            } catch (err) {
                if (err.message == `VM Exception while processing transaction: reverted with reason string 'STF'`) {
                    log[i] = "STF";
                    console.error("STF");
                }
                if (err.message == `VM Exception while processing transaction: reverted with reason string 'Success'`) {
                    console.error("Success");
                    succeded = true;
                    log[i] = "Success";
                } else {
                    console.error(err.message);
                    log[i] = err.message;
                }
            }

            await mineSomeBlocks(10);
        }
        assert(succeded, "No successful test found");
        console.log(log);
    }).timeout(1000000);

    // it("rebalance with flash loan", async () => {
    //     const MockRebalancerA = await ethers.getContractFactory("MockRebalancerA");
    //     mockRebalancer = await MockRebalancerA.deploy();
    //     await mockRebalancer.deployed();

    //     await mineSomeBlocks(83069);

    //     const arbTx = await mockRebalancer.rebalance();
    //     await arbTx.wait();
    // });

    // it("rebalance iterative", async () => {
    //     const testHolder = {};
    //     const MockRebalancerB = await ethers.getContractFactory("MockRebalancerB");
    //     mockRebalancer = await MockRebalancerB.deploy();
    //     await mockRebalancer.deployed();

    //     await mineSomeBlocks(83069);

    //     for (let i = 0; i < 60; i++) {
    //         // const arbTx = await mockRebalancer.rebalance();
    //         // await arbTx.wait();
    //         const res = (await mockRebalancer.rebalance()).toString();
    //         if (!testHolder[res]) testHolder[res] = 0;
    //         testHolder[res]++;
    //         await mineSomeBlocks(10);
    //     }
    //     console.log(testHolder);
    // }).timeout(1000000);

    // it("rebalance", async function () {
    //     const keeperEthBalanceBeforeRebalance = await getERC20Balance(keeper.address, wethAddress);
    //     const keeperUsdcBalanceBeforeRebalance = await getERC20Balance(keeper.address, usdcAddress);
    //     const keeperOsqthBalanceBeforeRebalance = await getERC20Balance(keeper.address, osqthAddress);
    //     console.log("> Keeper ETH balance before rebalance %s", keeperEthBalanceBeforeRebalance);
    //     console.log("> Keeper USDC balance before rebalance %s", keeperUsdcBalanceBeforeRebalance);
    //     console.log("> Keeper oSQTH balance before rebalance %s", keeperOsqthBalanceBeforeRebalance);

    //     tx = await VaultAuction.connect(keeper).timeRebalance(
    //         keeper.address,
    //         "525269035909074323",
    //         "20549790205",
    //         "22598046098622284218"
    //     );
    //     await tx.wait();

    //     const ethAmountK = await getERC20Balance(keeper.address, wethAddress);
    //     const usdcAmountK = await getERC20Balance(keeper.address, usdcAddress);
    //     const osqthAmountK = await getERC20Balance(keeper.address, osqthAddress);
    //     console.log("> Keeper ETH balance after rebalance %s", ethAmountK);
    //     console.log("> Keeper USDC balance after rebalance %s", usdcAmountK);
    //     console.log("> Keeper oSQTH balance after rebalance %s", osqthAmountK);

    //     const amount = await VaultMath.getTotalAmounts();
    //     console.log("> Total amounts:", amount);
    // });

    // it("deposit3", async function () {
    //     tx = await Vault.connect(depositor3).deposit(
    //         "27630456391863397407",
    //         "29892919002",
    //         "33072912443025954753",
    //         depositor3.address,
    //         "0",
    //         "0",
    //         "0"
    //     );
    //     await tx.wait();

    //     // State
    //     const userEthBalanceAfterDeposit = await getERC20Balance(depositor3.address, wethAddress);
    //     const userUsdcBalanceAfterDeposit = await getERC20Balance(depositor3.address, usdcAddress);
    //     const userOsqthBalanceAfterDeposit = await getERC20Balance(depositor3.address, osqthAddress);
    //     const userShareAfterDeposit = await getERC20Balance(depositor3.address, Vault.address);

    //     console.log("> userEthBalanceAfterDeposit %s", userEthBalanceAfterDeposit);
    //     console.log("> userUsdcBalanceAfterDeposit %s", userUsdcBalanceAfterDeposit);
    //     console.log("> userOsqthBalanceAfterDeposit %s", userOsqthBalanceAfterDeposit);
    //     console.log("> userShareAfterDeposit", userShareAfterDeposit);
    // });

    // it("withdraw2", async function () {
    //     tx = await Vault.connect(depositor2).withdraw(
    //         await getERC20Balance(depositor2.address, Vault.address),
    //         "0",
    //         "0",
    //         "0"
    //     );
    //     await tx.wait();

    //     // State
    //     const userEthBalanceAfterWithdraw = await getERC20Balance(depositor2.address, wethAddress);
    //     const userUsdcBalanceAfterWithdraw = await getERC20Balance(depositor2.address, usdcAddress);
    //     const userOsqthBalanceAfterWithdraw = await getERC20Balance(depositor2.address, osqthAddress);
    //     const userShareAfterWithdraw = await getERC20Balance(depositor2.address, Vault.address);
    //     console.log("> userEthBalanceAfterWithdraw %s", userEthBalanceAfterWithdraw);
    //     console.log("> userUsdcBalanceAfterWithdraw %s", userUsdcBalanceAfterWithdraw);
    //     console.log("> userOsqthBalanceAfterWithdraw %s", userOsqthBalanceAfterWithdraw);
    //     console.log("> userShareAfterWithdraw", userShareAfterWithdraw);
    // });

    // it("swap", async function () {
    //     await mineSomeBlocks(2216);

    //     swapAmount = utils.parseUnits("1000000", 6).toString();
    //     await getUSDC(swapAmount, contractHelper.address);
    //     console.log("> WETH before swap:", await getERC20Balance(contractHelper.address, wethAddress));
    //     console.log("> USDC before swap:", await getERC20Balance(contractHelper.address, usdcAddress));
    //     tx = await contractHelper.connect(swaper).swapUSDC_WETH(swapAmount);
    //     await tx.wait();
    //     console.log("> WETH after swap:", await getERC20Balance(contractHelper.address, wethAddress));
    //     console.log("> USDC after swap:", await getERC20Balance(contractHelper.address, usdcAddress));

    //     await mineSomeBlocks(554);

    //     swapAmount = utils.parseUnits("100", 18).toString();
    //     await getWETH(swapAmount, contractHelper.address);
    //     console.log("> OSQTH before swap:", await getERC20Balance(contractHelper.address, osqthAddress));
    //     console.log("> WETH before swap:", await getERC20Balance(contractHelper.address, wethAddress));
    //     tx = await contractHelper.connect(swaper).swapWETH_OSQTH(swapAmount);
    //     await tx.wait();
    //     console.log("> OSQTH before swap:", await getERC20Balance(contractHelper.address, osqthAddress));
    //     console.log("> WETH before swap:", await getERC20Balance(contractHelper.address, wethAddress));

    //     await mineSomeBlocks(554);
    // });

    // it("rebalance", async function () {
    //     const keeperEthBalanceBeforeRebalance = await getERC20Balance(keeper.address, wethAddress);
    //     const keeperUsdcBalanceBeforeRebalance = await getERC20Balance(keeper.address, usdcAddress);
    //     const keeperOsqthBalanceBeforeRebalance = await getERC20Balance(keeper.address, osqthAddress);
    //     console.log("> Keeper ETH balance before rebalance %s", keeperEthBalanceBeforeRebalance);
    //     console.log("> Keeper USDC balance before rebalance %s", keeperUsdcBalanceBeforeRebalance);
    //     console.log("> Keeper oSQTH balance before rebalance %s", keeperOsqthBalanceBeforeRebalance);

    //     const AuctionParamsBefore = await VaultAuction.connect(keeper).callStatic.getAuctionParams("14487789");
    //     console.log("AuctionParamsBefore %s", AuctionParamsBefore);

    //     tx = await VaultAuction.connect(keeper).timeRebalance(keeper.address, "0", "0", "0");
    //     await tx.wait();

    //     const ethAmountK = await getERC20Balance(keeper.address, wethAddress);
    //     const usdcAmountK = await getERC20Balance(keeper.address, usdcAddress);
    //     const osqthAmountK = await getERC20Balance(keeper.address, osqthAddress);
    //     console.log("> Keeper ETH balance after rebalance %s", ethAmountK);
    //     console.log("> Keeper USDC balance after rebalance %s", usdcAmountK);
    //     console.log("> Keeper oSQTH balance after rebalance %s", osqthAmountK);

    //     const amount = await VaultMath.getTotalAmounts();
    //     console.log("> Total amounts:", amount);

    //     const AuctionParamsAfter = await VaultAuction.connect(keeper).callStatic.getAuctionParams("14487789");
    //     console.log("AuctionParamsAfter %s", AuctionParamsAfter);
    // });

    // it("withdraw1", async function () {
    //     tx = await Vault.connect(depositor1).withdraw(
    //         await getERC20Balance(depositor1.address, Vault.address),
    //         "0",
    //         "0",
    //         "0"
    //     );
    //     await tx.wait();

    //     // State
    //     const userEthBalanceAfterWithdraw = await getERC20Balance(depositor1.address, wethAddress);
    //     const userUsdcBalanceAfterWithdraw = await getERC20Balance(depositor1.address, usdcAddress);
    //     const userOsqthBalanceAfterWithdraw = await getERC20Balance(depositor1.address, osqthAddress);
    //     const userShareAfterWithdraw = await getERC20Balance(depositor1.address, Vault.address);
    //     console.log("> userEthBalanceAfterWithdraw %s", userEthBalanceAfterWithdraw);
    //     console.log("> userUsdcBalanceAfterWithdraw %s", userUsdcBalanceAfterWithdraw);
    //     console.log("> userOsqthBalanceAfterWithdraw %s", userOsqthBalanceAfterWithdraw);
    //     console.log("> userShareAfterWithdraw", userShareAfterWithdraw);
    // });

    // it("withdraw3", async function () {
    //     tx = await Vault.connect(depositor3).withdraw(
    //         await getERC20Balance(depositor3.address, Vault.address),
    //         "0",
    //         "0",
    //         "0"
    //     );
    //     await tx.wait();

    //     // State
    //     const userEthBalanceAfterWithdraw = await getERC20Balance(depositor3.address, wethAddress);
    //     const userUsdcBalanceAfterWithdraw = await getERC20Balance(depositor3.address, usdcAddress);
    //     const userOsqthBalanceAfterWithdraw = await getERC20Balance(depositor3.address, osqthAddress);
    //     const userShareAfterWithdraw = await getERC20Balance(depositor3.address, Vault.address);
    //     console.log("> userEthBalanceAfterWithdraw %s", userEthBalanceAfterWithdraw);
    //     console.log("> userUsdcBalanceAfterWithdraw %s", userUsdcBalanceAfterWithdraw);
    //     console.log("> userOsqthBalanceAfterWithdraw %s", userOsqthBalanceAfterWithdraw);
    //     console.log("> userShareAfterWithdraw", userShareAfterWithdraw);
    // });
});
