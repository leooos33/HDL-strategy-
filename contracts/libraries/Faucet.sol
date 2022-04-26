// SPDX-License-Identifier: Unlicense

pragma solidity =0.8.4;
pragma abicoder v2;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

// import {IRegistry} from "../interfaces/IRegistry.sol";

interface IFaucet {
    // function updateComponents() external;
    function setComponents(
        address,
        address,
        address
    ) external;
}

contract Faucet is IFaucet {
    address public immutable registry;
    address public vault;
    address public vaultMath;
    address public vaultTreasury;

    constructor(address _registry) {
        registry = _registry;
    }

    // function updateComponents() public override {
    //     (vault, vaultMath, vaultTreasury) = IRegistry(registry).getComponents();
    // }

    function setComponents(
        address _vault,
        address _vaultMath,
        address _vaultTreasury
    ) public override {
        (vault, vaultMath, vaultTreasury) = (_vault, _vaultMath, _vaultTreasury);
    }
}
