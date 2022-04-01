// SPDX-License-Identifier: Unlicense

pragma solidity ^0.6.6;
pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts/math/Math.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "@uniswap/v3-core/contracts/libraries/TickMath.sol";

import "./VaultParams.sol";
import "../libraries/StrategyMath.sol";

import "hardhat/console.sol";

contract VaultMathTest is VaultParams {
    // using SafeMath for uint256;
    using StrategyMath for uint256;

    struct SharesInfo {
        uint256 totalSupply;
        uint256 _amountEth;
        uint256 _amountUsdc;
        uint256 _amountOsqth;
        uint256 osqthEthPrice;
        uint256 ethUsdcPrice;
        uint256 usdcAmount;
        uint256 ethAmount;
        uint256 osqthAmount;
    }

    constructor(
        uint256 _cap,
        uint256 _rebalanceTimeThreshold,
        uint256 _rebalancePriceThreshold,
        uint256 _auctionTime,
        uint256 _minPriceMultiplier,
        uint256 _maxPriceMultiplier,
        uint256 _targetEthShare,
        uint256 _targetUsdcShare,
        uint256 _targetOsqthShare
    )
        public
        VaultParams(
            _cap,
            _rebalanceTimeThreshold,
            _rebalancePriceThreshold,
            _auctionTime,
            _minPriceMultiplier,
            _maxPriceMultiplier,
            _targetEthShare,
            _targetUsdcShare,
            _targetOsqthShare
        )
    {}

    function _calcSharesAndAmounts(SharesInfo memory params)
        public
        view
        returns (
            uint256,
            uint256,
            uint256,
            uint256
        )
    {
        uint256 depositorValue = (
            params._amountOsqth.mul(params.ethUsdcPrice).mul(params.osqthEthPrice).div(uint256(1e36))
        ).add((params._amountUsdc.mul(uint256(1e12)))).add((params._amountEth.mul(params.ethUsdcPrice).div(1e18)));
        console.log("depositorValue: %s", depositorValue);

        if (params.totalSupply == 0) {
            return (
                depositorValue,
                // depositorValue.mul(targetEthShare).div(ethUsdcPrice),
                // depositorValue.mul(targetUsdcShare),
                // depositorValue.mul(targetOsqthShare).div(osqthEthPrice.mul(ethUsdcPrice))
                depositorValue.mul(targetEthShare.div(uint256(1e18))).div(params.ethUsdcPrice),
                depositorValue.mul(targetUsdcShare.div(uint256(1e18))),
                depositorValue.mul(targetOsqthShare.div(uint256(1e18))).div(
                    params.osqthEthPrice.mul(params.ethUsdcPrice)
                )
            );
        } else {
            uint256 osqthValue = params.osqthAmount.mul(params.ethUsdcPrice).mul(params.osqthEthPrice).div(1e36);
            uint256 usdcValue = params.usdcAmount.mul(uint256(1e12));
            uint256 ethValue = params.ethAmount.mul(params.ethUsdcPrice).div(uint256(1e18));
            // console.log("osqthValue %s", osqthValue);
            // console.log("usdcValue %s", usdcValue);
            // console.log("ethValue %s", ethValue);

            uint256 totalValue = osqthValue.add(usdcValue).add(ethValue);
            console.log("totalValue: %s", totalValue);

            uint256 depositorShare = depositorValue / (depositorValue + totalValue);
            console.log("depositorShare: %s", depositorShare);

            // console.log(
            //     "share2: %s",
            //     params.totalSupply.mul(depositorValue.div(totalValue.add(depositorValue))).div(
            //         uint256(1e18).sub(depositorValue.div(totalValue.add(depositorValue)))
            //     )
            // );

            // return (
            //     params.totalSupply.mul(depositorShare).div(uint256(1e18).sub(depositorShare)),
            //     depositorShare.mul(params.ethAmount).div(uint256(1e18).sub(depositorShare)),
            //     depositorShare.mul(params.usdcAmount).div(uint256(1e18).sub(depositorShare)),
            //     depositorShare.mul(params.osqthAmount).div(uint256(1e18).sub(depositorShare))
            // );
            return (0, 0, 0, 0);
        }
    }
}
