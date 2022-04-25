// SPDX-License-Identifier: Unlicense

pragma solidity =0.8.4;
pragma abicoder v2;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface IVaultTreasury {
    function burn(
        address pool,
        int24 tickLower,
        int24 tickUpper
    ) external;

    function collect(
        address pool,
        int24 tickLower,
        int24 tickUpper,
        uint128 liquidity
    ) external returns (uint256 collect0, uint256 collect1);

    function mintLiquidity(
        address pool,
        int24 tickLower,
        int24 tickUpper,
        uint128 liquidity
    ) external;

    function transfer(
        IERC20 token,
        address recipient,
        uint256 amount
    ) external;
}
