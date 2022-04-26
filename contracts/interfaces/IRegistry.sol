// SPDX-License-Identifier: Unlicense

pragma solidity =0.8.4;
pragma abicoder v2;

import "./IVault.sol";
import "./IVaultTreasury.sol";
import "./IVaultTreasury.sol";
import "./IVaultMath.sol";

interface IRegistry {
    function getGovernance() external view returns (address);

    function getComponents()
        external
        view
        returns (
            address,
            address,
            address
        );
}
