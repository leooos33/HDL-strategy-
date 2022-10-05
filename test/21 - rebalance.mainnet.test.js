const { expect, assert } = require("chai");
const { ethers } = require("hardhat");
const { utils } = ethers;
const {
    wethAddress,
    osqthAddress,
    usdcAddress,
    _vaultAuctionAddress,
    _vaultMathAddress,
    _biggestOSqthHolder,
    _rebalancerBigAddress,
    _governanceAddress,
} = require("./common");
const {
    mineSomeBlocks,
    resetFork,
    getERC20Balance,
    getUSDC,
    getOSQTH,
    getWETH,
    logBlock,
    getERC20Allowance,
    approveERC20,
} = require("./helpers");

describe.skip("Rebalance test mainnet", function () {
    let tx, receipt, Rebalancer, MyContract;
    let actor;
    let actorAddress = _governanceAddress;

    it("Should deploy contract", async function () {
        await resetFork(15681149 - 10);
        // 	15379702 <- add 150 or 6
        // 	15376522 <- add 200 or 6
        //  15373344 <- working
        //  15373161 <- working

        await hre.network.provider.request({
            method: "hardhat_impersonateAccount",
            params: [actorAddress],
        });

        actor = await ethers.getSigner(actorAddress);
        console.log("actor:", actor.address);

        MyContract = await ethers.getContractFactory("VaultAuction");
        VaultAuction = await MyContract.attach(_vaultAuctionAddress);

        MyContract = await ethers.getContractFactory("VaultMath");
        VaultMath = await MyContract.attach(_vaultMathAddress);

        //----- choose rebalancer -----

        // MyContract = await ethers.getContractFactory("BigRebalancer");
        // Rebalancer = await MyContract.attach(_rebalancerBigAddress);

        // MyContract = await ethers.getContractFactory("Rebalancer");
        // Rebalancer = await MyContract.attach("0x09b1937d89646b7745377f0fcc8604c179c06af5");

        MyContract = await ethers.getContractFactory("BigRebalancer");
        Rebalancer = await MyContract.deploy();
        await Rebalancer.deployed();

        //----- choose rebalancer -----

        console.log("Owner:", await Rebalancer.owner());
        console.log("addressAuction:", await Rebalancer.addressAuction());
        console.log("addressMath:", await Rebalancer.addressMath());
    });

    it("mine some blocks", async function () {
        await mineSomeBlocks(1665368779 - 15681149 + 400);
        await logBlock();
        console.log(await VaultMath.isTimeRebalance());
    });

    it("aditional actions", async function () {
        this.skip();

        // console.log(await VaultAuction.getAuctionParams("1660983213"));
        // return;

        //----- Approves -----

        // const swapRouter = "0xE592427A0AEce92De3Edee1F18E0157C05861564";
        // const euler = "0x27182842E098f60e3D576794A5bFFb0777E025d3";
        // const addressAuction = "0x399dD7Fd6EF179Af39b67cE38821107d36678b5D";
        // const addressMath = "0xDF374d19021831E785212F00837B5709820AA769";

        // console.log(await getERC20Allowance(Rebalancer.address, addressMath, wethAddress));
        // console.log(await getERC20Allowance(Rebalancer.address, addressMath, osqthAddress));
        // console.log(await getERC20Allowance(Rebalancer.address, addressMath, usdcAddress));
    });

    it("rebalance with BigRebalancer", async function () {
        // this.skip();

        //-- clean contracts
        // const [owner, randomChad] = await ethers.getSigners();
        // await owner.sendTransaction({
        //     to: actor.address,
        //     value: ethers.utils.parseEther("1.0"),
        // });

        // tx = await Rebalancer.connect(actor).collectProtocol(
        //     await getERC20Balance(Rebalancer.address, wethAddress),
        //     await getERC20Balance(Rebalancer.address, usdcAddress),
        //     await getERC20Balance(Rebalancer.address, osqthAddress),
        //     actor.address
        // );
        // await tx.wait();

        // await transferAll(actor, randomChad.address, wethAddress);
        // await transferAll(actor, randomChad.address, usdcAddress);
        // await transferAll(actor, randomChad.address, osqthAddress);

        // //-- clean contracts

        // await getUSDC(3007733 + 10 + 1041, Rebalancer.address);

        // console.log("> Rebalancer WETH %s", await getERC20Balance(Rebalancer.address, wethAddress));
        // console.log("> Rebalancer USDC %s", await getERC20Balance(Rebalancer.address, usdcAddress));
        // console.log("> Rebalancer oSQTH %s", await getERC20Balance(Rebalancer.address, osqthAddress));

        // console.log("> actor WETH %s", await getERC20Balance(actor.address, wethAddress));
        // console.log("> actor USDC %s", await getERC20Balance(actor.address, usdcAddress));
        // console.log("> actor oSQTH %s", await getERC20Balance(actor.address, osqthAddress));

        // tx = await Rebalancer.connect(actor).rebalance(0);
        tx = await Rebalancer.connect(actor).rebalance(2,  1665368779 + 400);

        receipt = await tx.wait();
        console.log("> Gas used rebalance + fl: %s", receipt.gasUsed);

        console.log("> Rebalancer WETH %s", await getERC20Balance(Rebalancer.address, wethAddress));
        console.log("> Rebalancer USDC %s", await getERC20Balance(Rebalancer.address, usdcAddress));
        console.log("> Rebalancer oSQTH %s", await getERC20Balance(Rebalancer.address, osqthAddress));

        console.log("> actor WETH %s", await getERC20Balance(actor.address, wethAddress));
        console.log("> actor USDC %s", await getERC20Balance(actor.address, usdcAddress));
        console.log("> actor oSQTH %s", await getERC20Balance(actor.address, osqthAddress));
    });

    it("rebalance manual using private liquidity", async function () {
        this.skip();

        //-- clean contracts
        const [owner, randomChad] = await ethers.getSigners();
        await owner.sendTransaction({
            to: actor.address,
            value: ethers.utils.parseEther("1.0"),
        });

        tx = await Rebalancer.connect(actor).collectProtocol(
            await getERC20Balance(Rebalancer.address, wethAddress),
            await getERC20Balance(Rebalancer.address, usdcAddress),
            await getERC20Balance(Rebalancer.address, osqthAddress),
            actor.address
        );
        await tx.wait();

        await transferAll(actor, randomChad.address, wethAddress);
        await transferAll(actor, randomChad.address, usdcAddress);
        await transferAll(actor, randomChad.address, osqthAddress);

        //? Deposit liquidity for rebalance
        const amount = 3007733 + 2000;
        await getUSDC(amount, actor.address, "0x94c96dfe7d81628446bebf068461b4f728ed8670");

        await approveERC20(actor, VaultAuction.address, amount, usdcAddress);

        res = await VaultMath.connect(actor).isTimeRebalance();
        // console.log(">", res);
        res = await VaultAuction.getAuctionParams(1660598164);
        console.log(">", res[0].sub(res[3]).toString());
        console.log(">", res[1].sub(res[4]).toString());
        console.log(">", res[2].sub(res[5]).toString());

        console.log("> actor WETH %s", await getERC20Balance(actor.address, wethAddress));
        console.log("> actor USDC %s", await getERC20Balance(actor.address, usdcAddress));
        console.log("> actor USDC %s", await getERC20Allowance(actor.address, VaultAuction.address, usdcAddress));
        console.log("> actor oSQTH %s", await getERC20Balance(actor.address, osqthAddress));

        tx = await VaultAuction.connect(actor).timeRebalance(actor.address, 0, 0, 0);
        await tx.wait();

        console.log("> actor WETH %s", await getERC20Balance(actor.address, wethAddress));
        console.log("> actor USDC %s", await getERC20Balance(actor.address, usdcAddress));
        console.log("> actor oSQTH %s", await getERC20Balance(actor.address, osqthAddress));
    });

    const transferAll = async (from, to, token) => {
        const ERC20 = await ethers.getContractAt("IWETH", token);
        await ERC20.connect(from).transfer(to, await getERC20Balance(from.address, token));
    };
});
