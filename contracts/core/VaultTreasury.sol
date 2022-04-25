// SPDX-License-Identifier: Unlicense

pragma solidity =0.8.4;
pragma abicoder v2;

import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {ReentrancyGuard} from "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import {IUniswapV3MintCallback} from "@uniswap/v3-core/contracts/interfaces/callback/IUniswapV3MintCallback.sol";
import {IUniswapV3Pool} from "@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol";

// import {IVaultTreasury} from "../interfaces/IVaultTreasury.sol";
import {SharedEvents} from "../libraries/SharedEvents.sol";
import {Constants} from "../libraries/Constants.sol";

import "hardhat/console.sol";

contract VaultTreasury is ReentrancyGuard, IUniswapV3MintCallback {
    using SafeERC20 for IERC20;

    mapping(address => bool) keepers;

    constructor() {
        keepers[msg.sender] = true;
    }

    function burn(
        address pool,
        int24 tickLower,
        int24 tickUpper
    ) external onlyKeepers {
        IUniswapV3Pool(pool).burn(tickLower, tickUpper, 0);
    }

    function collect(
        address pool,
        int24 tickLower,
        int24 tickUpper
    ) external onlyKeepers returns (uint256 collect0, uint256 collect1) {
        address recipient = address(this);

        (collect0, collect1) = IUniswapV3Pool(pool).collect(
            recipient,
            tickLower,
            tickUpper,
            type(uint128).max,
            type(uint128).max
        );
    }

    function mintLiquidity(
        address pool,
        int24 tickLower,
        int24 tickUpper,
        uint128 liquidity
    ) external onlyKeepers {
        if (liquidity > 0) {
            address token0 = pool == Constants.poolEthUsdc ? address(Constants.usdc) : address(Constants.weth);
            address token1 = pool == Constants.poolEthUsdc ? address(Constants.weth) : address(Constants.osqth);
            bytes memory params = abi.encode(pool, token0, token1);

            IUniswapV3Pool(pool).mint(address(this), tickLower, tickUpper, liquidity, params);
        }
    }

    function transfer(
        IERC20 token,
        address recipient,
        uint256 amount
    ) external onlyKeepers {
        token.transfer(recipient, amount);
    }

    function uniswapV3MintCallback(
        uint256 amount0Owed,
        uint256 amount1Owed,
        bytes calldata data
    ) external override {
        (address pool, address token0, address token1) = abi.decode(data, (address, address, address));

        require(msg.sender == pool);
        if (amount0Owed > 0) IERC20(token0).safeTransfer(msg.sender, amount0Owed);
        if (amount1Owed > 0) IERC20(token1).safeTransfer(msg.sender, amount1Owed);
    }

    function addKeeper(address _address) public onlyKeepers {
        keepers[_address] = true;
    }

    modifier onlyKeepers() {
        require(keepers[msg.sender], "keeper");
        _;
    }
}
