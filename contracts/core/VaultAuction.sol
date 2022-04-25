// SPDX-License-Identifier: Unlicense

pragma solidity =0.8.4;
pragma abicoder v2;

import {IAuction} from "../interfaces/IVault.sol";
import {IRegistry} from "../interfaces/IRegistry.sol";
import {SharedEvents} from "../libraries/SharedEvents.sol";
import {Constants} from "../libraries/Constants.sol";
import {VaultMath} from "./VaultMath.sol";
import {VaultTreasury} from "./VaultTreasury.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/security/ReentrancyGuard.sol";

import {PRBMathUD60x18} from "../libraries/math/PRBMathUD60x18.sol";

import "hardhat/console.sol";

contract VaultAuction is IAuction, ReentrancyGuard {
    using PRBMathUD60x18 for uint256;

    /**
     * @notice strategy constructor
       @param _cap max amount of wETH that strategy accepts for deposits
       @param _rebalanceTimeThreshold rebalance time threshold (seconds)
       @param _rebalancePriceThreshold rebalance price threshold (0.05*1e18 = 5%)
       @param _auctionTime auction duration (seconds)
       @param _minPriceMultiplier minimum auction price multiplier (0.95*1e18 = min auction price is 95% of twap)
       @param _maxPriceMultiplier maximum auction price multiplier (1.05*1e18 = max auction price is 105% of twap)
     */
    constructor(
        uint256 _cap,
        uint256 _rebalanceTimeThreshold,
        uint256 _rebalancePriceThreshold,
        uint256 _auctionTime,
        uint256 _minPriceMultiplier,
        uint256 _maxPriceMultiplier,
        uint256 _protocolFee,
        int24 _maxTDEthUsdc,
        int24 _maxTDOsqthEth,
        address _governance
    ) {
        registry = IRegistry(msg.sender);
    }

    IRegistry public registry;

    /**
     * @notice strategy rebalancing based on time threshold
     * @dev need to attach msg.value if buying oSQTH
     * @param keeper keeper address
     * @param amountEth amount of wETH to buy (strategy sell wETH both in sell and buy auction)
     * @param amountUsdc amount of USDC to buy or sell (depending if price increased or decreased)
     * @param amountOsqth amount of oSQTH to buy or sell (depending if price increased or decreased)
     */
    function timeRebalance(
        address keeper,
        uint256 amountEth,
        uint256 amountUsdc,
        uint256 amountOsqth
    ) external override nonReentrant {
        //check if rebalancing based on time threshold is allowed
        (bool isTimeRebalanceAllowed, uint256 auctionTriggerTime) = registry.getVaultMath().isTimeRebalance();

        require(isTimeRebalanceAllowed, "Time rebalance not allowed");

        _rebalance(keeper, auctionTriggerTime, amountEth, amountUsdc, amountOsqth);

        emit SharedEvents.TimeRebalance(keeper, auctionTriggerTime, amountEth, amountUsdc, amountOsqth);
    }

    /** TODO
     * @notice strategy rebalancing based on price threshold
     * @dev need to attach msg.value if buying oSQTH
     * @param keeper keeper address
     * @param _auctionTriggerTime the time when the price deviation threshold was exceeded and when the auction started
     * @param _amountEth amount of wETH to buy (strategy sell wETH both in sell and buy auction)
     * @param _amountUsdc amount of USDC to buy or sell (depending if price increased or decreased)
     * @param _amountOsqth amount of oSQTH to buy or sell (depending if price increased or decreased)
     */
    function priceRebalance(
        address keeper,
        uint256 _auctionTriggerTime,
        uint256 _amountEth,
        uint256 _amountUsdc,
        uint256 _amountOsqth
    ) external nonReentrant {
        //check if rebalancing based on price threshold is allowed
        require(registry.getVaultMath()._isPriceRebalance(_auctionTriggerTime), "Price rebalance not allowed");

        _rebalance(keeper, _auctionTriggerTime, _amountEth, _amountUsdc, _amountOsqth);

        emit SharedEvents.PriceRebalance(keeper, _amountEth, _amountUsdc, _amountOsqth);
    }

    /**
     * @notice rebalancing function to adjust proportion of tokens
     * @param keeper keeper address
     * @param _auctionTriggerTime timestamp when auction started
     * @param _amountEth amount of wETH to buy (strategy sell wETH both in sell and buy auction)
     * @param _amountUsdc amount of USDC to buy or sell (depending if price increased or decreased)
     * @param _amountOsqth amount of oSQTH to buy or sell (depending if price increased or decreased)
     */
    function _rebalance(
        address keeper,
        uint256 _auctionTriggerTime,
        uint256 _amountEth,
        uint256 _amountUsdc,
        uint256 _amountOsqth
    ) internal {
        Constants.AuctionParams memory params = registry.getVaultMath()._getAuctionParams(_auctionTriggerTime);

        _executeAuction(keeper, params);

        emit SharedEvents.Rebalance(keeper, params.deltaEth, params.deltaUsdc, params.deltaOsqth);
    }

    /**
     * @notice execute auction based on the parameters calculated
     * @dev withdraw all liquidity from the positions
     * @dev pull in tokens from keeper
     * @dev sell excess tokens to sender
     * @dev place new positions in eth:usdc and osqth:eth pool
     */
    function _executeAuction(address _keeper, Constants.AuctionParams memory params) internal {
        uint128 liquidityEthUsdc = registry.getVaultMath()._positionLiquidityEthUsdc();
        uint128 liquidityOsqthEth = registry.getVaultMath()._positionLiquidityEthOsqth();

        registry.getVaultMath()._burnAndCollect(
            Constants.poolEthUsdc,
            params.boundaries.ethUsdcLower,
            params.boundaries.ethUsdcUpper,
            liquidityEthUsdc
        );

        registry.getVaultMath()._burnAndCollect(
            Constants.poolEthOsqth,
            params.boundaries.osqthEthLower,
            params.boundaries.osqthEthUpper,
            liquidityOsqthEth
        );

        if (params.isPriceInc) {
            //pull in tokens from sender
            Constants.osqth.transferFrom(_keeper, address(registry.getVaultTreasury()), params.deltaOsqth.add(10));
            registry.getVaultTreasury().transfer(Constants.usdc, _keeper, params.deltaUsdc.sub(10));
            registry.getVaultTreasury().transfer(Constants.weth, _keeper, params.deltaEth.sub(10));
        } else {
            Constants.weth.transferFrom(_keeper, address(registry.getVaultTreasury()), params.deltaEth.add(10));
            Constants.usdc.transferFrom(_keeper, address(registry.getVaultTreasury()), params.deltaUsdc.add(10));
            registry.getVaultTreasury().transfer(Constants.osqth, _keeper, params.deltaOsqth.sub(10));
        }

        registry.getVaultTreasury()._mintLiquidity(
            Constants.poolEthUsdc,
            params.boundaries.ethUsdcLower,
            params.boundaries.ethUsdcUpper,
            params.liquidityEthUsdc
        );

        registry.getVaultTreasury()._mintLiquidity(
            Constants.poolEthOsqth,
            params.boundaries.osqthEthLower,
            params.boundaries.osqthEthUpper,
            params.liquidityOsqthEth
        );

        registry.getVaultMath().setTotalAmountsBoundaries(
            params.boundaries.ethUsdcLower,
            params.boundaries.ethUsdcUpper,
            params.boundaries.osqthEthLower,
            params.boundaries.osqthEthUpper
        );
    }
}
