const { ethers, network } = require("hardhat");
const { utils, BigNumber } = ethers;
const csv = require('csvtojson');
const path = require('path');
const { wethAddress, usdcAddress, osqthAddress } = require('../common');

const gasToSend = 100812679875357878208;

async function getToken(amount, account, tokenAddress, accountHolder) {
    await hre.network.provider.request({
        method: "hardhat_impersonateAccount",
        params: [accountHolder],
    });

    const signer = await ethers.getSigner(accountHolder);

    const ERC20 = await ethers.getContractAt('IWETH', tokenAddress);

    // console.log((await ERC20.balanceOf(signer.address)).toString());

    await network.provider.send("hardhat_setBalance", [
        signer.address,
        toHexdigital(gasToSend)
    ]);

    await ERC20.connect(signer).transfer(account, amount);
    // console.log((await ERC20.balanceOf(account)).toString());

    await network.provider.request({
        method: "hardhat_stopImpersonatingAccount",
        params: [accountHolder],
    });
}

async function getWETH(amount, account) {
    const wethAccountHolder = "0x2f0b23f53734252bda2277357e97e1517d6b042a";
    getToken(amount, account, wethAddress, wethAccountHolder);
}

async function getUSDC(amount, account) {
    const usdcAccountHolder = "0x2e6907a0ce523ccb5532ffea2e411df1eee26607";
    getToken(amount, account, usdcAddress, usdcAccountHolder);
}

async function getOSQTH(amount, account) {
    const osqthAccountHolder = "0x94b86a218264c7c424c1476160d675a05ecb0b3d";
    getToken(amount, account, osqthAddress, osqthAccountHolder);
}

const toHexdigital = (amount) => {
    return "0x" + (amount).toString(16);
}

const getERC20Balance = async (account, tokenAddress) => {
    const ERC20 = await ethers.getContractAt('IWETH', tokenAddress);
    return (await ERC20.balanceOf(account)).toString();
}

const approveERC20 = async (owner, account, amount, tokenAddress) => {
    const ERC20 = await ethers.getContractAt('IWETH', tokenAddress);
    await ERC20.connect(owner).approve(account, amount);
}

const getERC20Allowance = async (owner, spender, tokenAddress) => {
    const ERC20 = await ethers.getContractAt('IWETH', tokenAddress);
    return (await ERC20.allowance(owner, spender)).toString();
}

const loadTestDataset = async (name) => {
    const csvFilePath = path.join(__dirname, '../ds/', `${name}.csv`);
    const array = await csv().fromFile(csvFilePath);
    return array;
}

const toWEIS = (value, num = 18) => {
    // let [a, b] = value.split('.');
    // value = a + Math(b
    return utils.parseUnits(Number(value).toFixed(num), num).toString();
}

module.exports = {
    toWEIS,
    getOSQTH,
    approveERC20,
    getUSDC,
    getWETH,
    toHexdigital,
    getERC20Allowance,
    loadTestDataset,
    getERC20Balance,
}