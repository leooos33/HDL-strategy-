const { ethers } = require("hardhat");
const { utils } = ethers;
const { BigNumber } = require("ethers");

const governance = "0x14dc79964da2c08b23698b3d3cc7ca32193d9955"; // ACCOUNT #7 in hardhat

const deploymentParams = [
    utils.parseUnits("4000000000000", 18),
    BigNumber.from("10"),
    utils.parseUnits("0.05", 18),
    BigNumber.from("10"),
    BigNumber.from("950000000000000000"),
    BigNumber.from("1050000000000000000"),
    BigNumber.from("0"),
    BigNumber.from("1000"),
    BigNumber.from("1000"),
];

const hardhatDeploy = async (governance, params) => {
    const UniswapMath = await deployContract("UniswapMath", []);

    const Vault = await deployContract("Vault", []);
    const VaultAuction = await deployContract("VaultAuction", []);
    const VaultMath = await deployContract("VaultMath", []);
    const VaultTreasury = await deployContract("VaultTreasury", []);
    const VaultStorage = await deployContract("VaultStorage", params);

    const arguments = [
        UniswapMath.address,
        Vault.address,
        VaultAuction.address,
        VaultMath.address,
        VaultTreasury.address,
        VaultStorage.address,
        governance,
    ];
    console.log("UniswapMath:", arguments[0]);
    console.log("Vault:", arguments[1]);
    console.log("VaultAuction:", arguments[2]);
    console.log("VaultMath:", arguments[3]);
    console.log("VaultTreasury:", arguments[4]);
    console.log("VaultStorage:", arguments[5]);

    let tx;

    tx = await Vault.setComponents(...arguments);
    await tx.wait();

    tx = await VaultAuction.setComponents(...arguments);
    await tx.wait();

    tx = await VaultMath.setComponents(...arguments);
    await tx.wait();

    tx = await VaultTreasury.setComponents(...arguments);
    await tx.wait();

    tx = await VaultStorage.setComponents(...arguments);
    await tx.wait();
};

const deployContract = async (name, params, deploy = true) => {
    const Contract = await ethers.getContractFactory(name);
    let contract = await Contract.deploy(...params);
    if (deploy) {
        await contract.deployed();
    }
    return contract;
};

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
hardhatDeploy(governance, deploymentParams).catch((error) => {
    console.error(error);
    process.exitCode = 1;
});

//Link https://www.google.com/search?q=deploy+harhat+on+mainnet&oq=deploy+harhat+on+mainnet&aqs=chrome..69i57j33i10i160.4040j0j7&sourceid=chrome&ie=UTF-8#kpvalbx=_pfvXYtSVEqiF9u8Pj-ax0Ag14