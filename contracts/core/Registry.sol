// SPDX-License-Identifier: Unlicense

pragma solidity =0.8.4;
pragma abicoder v2;

import {ReentrancyGuard} from "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IVault, IAuction} from "../interfaces/IVault.sol";
import {IRegistry} from "../interfaces/IRegistry.sol";
import {SharedEvents} from "../libraries/SharedEvents.sol";
import {Constants} from "../libraries/Constants.sol";
import {PRBMathUD60x18} from "../libraries/math/PRBMathUD60x18.sol";
import {Vault} from "./Vault.sol";
import {VaultMath} from "./VaultMath.sol";

import "hardhat/console.sol";

contract Registry is IRegistry {
    constructor(
        uint256 _cap,
        uint256 _rebalanceTimeThreshold,
        uint256 _rebalancePriceThreshold,
        uint256 _auctionTime,
        uint256 _minPriceMultiplier,
        uint256 _maxPriceMultiplier,
        uint256 _protocolFee,
        int24 _maxTDEthUsdc,
        int24 _maxTDOsqthEth
    ) {
        governance = msg.sender;

        Vault _vault = new Vault(
            _cap,
            _rebalanceTimeThreshold,
            _rebalancePriceThreshold,
            _auctionTime,
            _minPriceMultiplier,
            _maxPriceMultiplier,
            _protocolFee,
            _maxTDEthUsdc,
            _maxTDOsqthEth
        );
        vault = address(_vault);

        VaultMath _vaultMath = new VaultMath(
            _cap,
            _rebalanceTimeThreshold,
            _rebalancePriceThreshold,
            _auctionTime,
            _minPriceMultiplier,
            _maxPriceMultiplier,
            _protocolFee,
            _maxTDEthUsdc,
            _maxTDOsqthEth,
            governance,
            vault
        );
        vaultMath = address(_vaultMath);

        VaultTreasury _vaultTreasury = new VaultTreasury();
        _vaultTreasury.addKeeper(vaultMath);
        _vaultTreasury.addKeeper(vault);

        vaultTreasury = address(_vaultTreasury);
    }

    //@dev governance
    address governance;
    address vault;
    address vaultTreasury;
    address vaultMath;

    function getGovernance() external view returns (address) {
        return governance;
    }

    function getVault() external view returns (address) {
        return vault;
    }

    function getVaultTreasury() external view returns (address) {
        return vaultTreasury;
    }

    function getVaultMath() external view returns (address) {
        return vaultMath;
    }
}
