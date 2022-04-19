// SPDX-License-Identifier: Unlicense

pragma solidity =0.8.4;
pragma abicoder v2;

import "../libraries/Constants.sol";

interface IPrbMathCalculus {
    function getTicks(uint256 aEthUsdcPrice, uint256 aOsqthEthPrice)
        external
        pure
        returns (
            uint160, // aEthUsdcTick
            uint160 //aOsqthEthTick
        );

    function getLiquidityForValue(
        uint256 v,
        uint256 p,
        uint256 pL,
        uint256 pH
    ) external pure returns (uint128);

    function getPriceFromTick(uint160 sqrtRatioAtTick) external pure returns (uint256);

    function getValue(
        uint256 amountEth,
        uint256 amountUsdc,
        uint256 amountOsqth,
        uint256 ethUsdcPrice,
        uint256 osqthEthPrice
    ) external view returns (uint256);
}
