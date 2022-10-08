process.exit(0); // Block file in order to not accidentally deploy

const { ethers } = require("hardhat");
const { _cheapRebalancerV2, _governanceAddressV2 } = require("../test/common/index");

const deposit = async () => {
    let MyContract = await ethers.getContractFactory("CheapRebalancer");
    const ChepRebalancer = await MyContract.attach(_cheapRebalancerV2);

    tx = await ChepRebalancer.returnGovernance(_governanceAddressV2);
};

deposit().catch((error) => {
    console.error(error);
    process.exitCode = 1;
});
