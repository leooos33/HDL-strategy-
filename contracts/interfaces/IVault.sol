// SPDX-License-Identifier: Unlicense

pragma solidity =0.8.4;

import "../libraries/Faucet.sol";

interface IVault is IFaucet {
    function deposit(
        uint256,
        uint256,
        uint256,
        address,
        uint256,
        uint256,
        uint256
    ) external returns (uint256);

    function withdraw(
        uint256,
        uint256,
        uint256,
        uint256
    ) external;
}

interface IAuction {
    function timeRebalance(
        address,
        uint256,
        uint256,
        uint256
    ) external;

    // function getTotalAmounts() external view returns (uint256, uint256);
}
