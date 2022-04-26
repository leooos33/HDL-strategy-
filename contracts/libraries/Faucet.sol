// SPDX-License-Identifier: Unlicense

pragma solidity =0.8.4;
pragma abicoder v2;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {IRegistry} from "../interfaces/IRegistry.sol";
import {IVaultMath} from "../interfaces/IVaultMath.sol";
import {IVaultTreasury} from "../interfaces/IVaultTreasury.sol";
import {IVault} from "../interfaces/IVault.sol";

interface IFaucet {
    function updateComponents() external;
}

contract Faucet is IFaucet {
    address public immutable registry;
    address public vault;
    address public vaultMath;
    address public vaultTreasury;

    constructor(address _registry) {
        registry = _registry;
    }

    function updateComponents() public override {
        (vault, vaultMath, vaultTreasury) = IRegistry(registry).getComponents();
    }
}
