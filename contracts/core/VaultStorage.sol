// SPDX-License-Identifier: Unlicense

pragma solidity =0.8.4;

import {IUniswapV3Pool} from "@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol";

import {IVaultStorage} from "../interfaces/IVaultStorage.sol";

import {Constants} from "../libraries/Constants.sol";
import {Faucet} from "../libraries/Faucet.sol";
import {SharedEvents} from "../libraries/SharedEvents.sol";
import "hardhat/console.sol";

contract VaultStorage is IVaultStorage, Faucet {
    //@dev Uniswap pools tick spacing
    int24 public immutable override tickSpacing;

    //@dev twap period to use for rebalance calculations
    uint32 public override twapPeriod = 420 seconds;

    //@dev max amount of wETH that strategy accept for deposit
    uint256 public override cap;

    //@dev lower and upper ticks in Uniswap pools
    // Removed
    int24 public override orderEthUsdcLower;
    int24 public override orderEthUsdcUpper;
    int24 public override orderOsqthEthLower;
    int24 public override orderOsqthEthUpper;

    //@dev timestamp when last rebalance executed
    uint256 public override timeAtLastRebalance;

    //@dev ETH/USDC price when last rebalance executed
    uint256 public override ethPriceAtLastRebalance;

    //@dev implied volatility when last rebalance executed
    uint256 public override ivAtLastRebalance;

    //@dev time difference to trigger a hedge (seconds)
    uint256 public override rebalanceTimeThreshold;
    uint256 public override rebalancePriceThreshold;

    //@dev iv adjustment parameter
    uint256 public override adjParam = 83000000000000000;

    //@dev ticks thresholds for boundaries calculation
    //values for tests
    int24 public override baseThreshold = 1440;

    //@dev protocol fee expressed as multiple of 1e-6
    uint256 public override protocolFee;

    //@dev accrued fees
    uint256 public override accruedFeesEth;
    uint256 public override accruedFeesUsdc;
    uint256 public override accruedFeesOsqth;

    //@dev total value
    uint256 public totalValue;

    //@dev rebalance auction duration (seconds)
    uint256 public override auctionTime;

    //@dev start auction price multiplier for rebalance buy auction and reserve price for rebalance sell auction (scaled 1e18)
    uint256 public override minPriceMultiplier;
    uint256 public override maxPriceMultiplier;
    //@dev max TWAP deviation for EthUsdc price in ticks
    int24 public override maxTDEthUsdc;
    //@dev max TWAP deviation for oSqthEth price in ticks
    int24 public override maxTDOsqthEth;

    bool public override isSystemPaused = false;

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
        int24 _maxTDOsqthEth
    ) Faucet() {
        cap = _cap;

        protocolFee = _protocolFee;

        tickSpacing = IUniswapV3Pool(Constants.poolEthOsqth).tickSpacing();
        // tickSpacing = 0; //TODO: change me back on robsten
        rebalanceTimeThreshold = _rebalanceTimeThreshold;
        rebalancePriceThreshold = _rebalancePriceThreshold;

        auctionTime = _auctionTime;
        minPriceMultiplier = _minPriceMultiplier;
        maxPriceMultiplier = _maxPriceMultiplier;

        timeAtLastRebalance = 0;
        ivAtLastRebalance = 0;
        maxTDEthUsdc = _maxTDEthUsdc;
        maxTDOsqthEth = _maxTDOsqthEth;
    }

    /**
     * @notice owner can set the strategy cap in USD terms
     * @dev deposits are rejected if it would put the strategy above the cap amount
     * @param _cap the maximum strategy collateral in USD, checked on deposits
     */
    function setCap(uint256 _cap) external onlyGovernance {
        cap = _cap;
    }

    /**
     * @notice owner can set the protocol fee expressed as multiple of 1e-6
     * @param _protocolFee the protocol fee, scaled by 1e18
     */
    function setProtocolFee(uint256 _protocolFee) external onlyGovernance {
        protocolFee = _protocolFee;
    }

    /**
     * @notice owner can set the hedge time threshold in seconds that determines how often the strategy can be hedged
     * @param _rebalanceTimeThreshold the rebalance time threshold, in seconds
     */
    function setRebalanceTimeThreshold(uint256 _rebalanceTimeThreshold) external onlyGovernance {
        rebalanceTimeThreshold = _rebalanceTimeThreshold;
    }

    /**
     * @notice owner can set the hedge time threshold in percent, scaled by 1e18 that determines the deviation in EthUsdc price that can trigger a rebalance
     * @param _rebalancePriceThreshold the hedge price threshold, in percent, scaled by 1e18
     */
    function setRebalancePriceThreshold(uint256 _rebalancePriceThreshold) external onlyGovernance {
        rebalancePriceThreshold = _rebalancePriceThreshold;
    }

    /**
     * @notice owner can set the base threshold for boundaries calculation
     * @param _baseThreshold the rebalance time threshold, in ticks
     */
    function setBaseThreshold(int24 _baseThreshold) external onlyGovernance {
        baseThreshold = _baseThreshold;
    }

    /**
     * @notice owner can set the base threshold for boundaries calculation
     * @param _adjParam the iv adjustment parameter
     */
    function setAdjParam(uint256 _adjParam) external onlyGovernance {
        adjParam = _adjParam;
    }

    /**
     * @notice owner can set the auction time, in seconds, that a hedge auction runs for
     * @param _auctionTime the length of the hedge auction in seconds
     */
    function setAuctionTime(uint256 _auctionTime) external onlyGovernance {
        auctionTime = _auctionTime;
    }

    /**
     * @notice owner can set the min price multiplier in a percentage scaled by 1e18 (95e16 is 95%)
     * @param _minPriceMultiplier the min price multiplier, a percentage, scaled by 1e18
     */
    function setMinPriceMultiplier(uint256 _minPriceMultiplier) external onlyGovernance {
        minPriceMultiplier = _minPriceMultiplier;
    }

    /**
     * @notice owner can set the max price multiplier in a percentage scaled by 1e18 (105e15 is 105%)
     * @param _maxPriceMultiplier the max price multiplier, a percentage, scaled by 1e18
     */
    function setMaxPriceMultiplier(uint256 _maxPriceMultiplier) external onlyGovernance {
        maxPriceMultiplier = _maxPriceMultiplier;
    }

    function setSnapshot(
        int24 _orderEthUsdcLower,
        int24 _orderEthUsdcUpper,
        int24 _orderOsqthEthLower,
        int24 _orderOsqthEthUpper,
        uint256 _timeAtLastRebalance,
        uint256 _ivAtLastRebalance,
        uint256 _totalValue,
        uint256 _ethPriceAtLastRebalance
    ) public override onlyVault {
        orderEthUsdcLower = _orderEthUsdcLower;
        orderEthUsdcUpper = _orderEthUsdcUpper;
        orderOsqthEthLower = _orderOsqthEthLower;
        orderOsqthEthUpper = _orderOsqthEthUpper;
        timeAtLastRebalance = _timeAtLastRebalance;
        ivAtLastRebalance = _ivAtLastRebalance;
        totalValue = _totalValue;
        ethPriceAtLastRebalance = _ethPriceAtLastRebalance;
    }

    function setAccruedFeesEth(uint256 _accruedFeesEth) external override onlyMath {
        accruedFeesEth = _accruedFeesEth;
    }

    function setAccruedFeesUsdc(uint256 _accruedFeesUsdc) external override onlyMath {
        accruedFeesUsdc = _accruedFeesUsdc;
    }

    function setAccruedFeesOsqth(uint256 _accruedFeesOsqth) external override onlyMath {
        accruedFeesOsqth = _accruedFeesOsqth;
    }

    function updateAccruedFees(
        uint256 amountEth,
        uint256 amountUsdc,
        uint256 amountOsqth
    ) external override onlyVault {
        accruedFeesUsdc = accruedFeesUsdc - amountUsdc;
        accruedFeesEth = accruedFeesEth - amountEth;
        accruedFeesOsqth = accruedFeesOsqth - amountOsqth;
    }

    function setParamsBeforeDeposit(
        uint256 _timeAtLastRebalance,
        uint256 _ivAtLastRebalance,
        uint256 _ethPriceAtLastRebalance
    ) public override onlyVault {
        timeAtLastRebalance = _timeAtLastRebalance;
        ivAtLastRebalance = _ivAtLastRebalance;
        ethPriceAtLastRebalance = _ethPriceAtLastRebalance;
    }

    function setPause(bool _pause) external onlyGovernance {
        isSystemPaused = _pause;

        emit SharedEvents.Paused(_pause);
    }

    /**
     * Used to for unit testing
     */
    // TODO: remove on main
    function setTimeAtLastRebalance(uint256 _timeAtLastRebalance) public onlyGovernance {
        timeAtLastRebalance = _timeAtLastRebalance;
    }

    /**
     * Used to for unit testing
     */
    // TODO: remove on main
    function setIvAtLastRebalance(uint256 _ivAtLastRebalance) public onlyGovernance {
        ivAtLastRebalance = _ivAtLastRebalance;
    }

    /**
     * Used to for unit testing
     */
    // TODO: remove on main
    function setEthPriceAtLastRebalance(uint256 _ethPriceAtLastRebalance) public onlyGovernance {
        ethPriceAtLastRebalance = _ethPriceAtLastRebalance;
    }
}
