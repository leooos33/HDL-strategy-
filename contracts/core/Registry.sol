// SPDX-License-Identifier: Unlicense

pragma solidity =0.8.4;
pragma abicoder v2;

import {IRegistry} from "../interfaces/IRegistry.sol";
import {Vault} from "./Vault.sol";
import {VaultMath} from "./VaultMath.sol";
import {VaultTreasury} from "./VaultTreasury.sol";

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
            _maxTDOsqthEth,
            governance
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
            governance
        );
        vaultMath = address(_vaultMath);

        VaultTreasury _vaultTreasury = new VaultTreasury();
        _vaultTreasury.addKeeper(vaultMath);
        _vaultTreasury.addKeeper(vault);
        vaultTreasury = address(_vaultTreasury);

        _vault.updateComponents();
        _vaultMath.updateComponents();
    }

    //@dev governance
    address governance;
    address vault;
    address vaultTreasury;
    address vaultMath;

    function getGovernance() external view override returns (address) {
        return governance;
    }

    function getComponents()
        external
        view
        override
        returns (
            address,
            address,
            address
        )
    {
        return (vault, vaultMath, vaultTreasury);
    }
}
