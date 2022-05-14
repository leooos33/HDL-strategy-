// SPDX-License-Identifier: Unlicense

pragma solidity =0.8.4;
pragma abicoder v2;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import {IUniswapV3Pool} from "@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol";

import {IVaultTreasury} from "../interfaces/IVaultTreasury.sol";

import {SharedEvents} from "../libraries/SharedEvents.sol";
import {Constants} from "../libraries/Constants.sol";
import {PRBMathUD60x18} from "../libraries/math/PRBMathUD60x18.sol";

import {VaultParams} from "./VaultParams.sol";

import "hardhat/console.sol";

contract VaultMath is VaultParams, ReentrancyGuard {
    using PRBMathUD60x18 for uint256;
    using SafeERC20 for IERC20;

    /**
     * @notice strategy constructor
       @param _cap max amount of wETH that strategy accepts for deposits
       @param _rebalanceTimeThreshold rebalance time threshold (seconds)
       @param _rebalancePriceThreshold rebalance price threshold (0.05*1e18 = 5%)
       @param _auctionTime auction duration (seconds)
       @param _minPriceMultiplier minimum auction price multiplier (0.95*1e18 = min auction price is 95% of twap)
       @param _maxPriceMultiplier maximum auction price multiplier (1.05*1e18 = max auction price is 105% of twap)
       @param _protocolFee Protocol fee expressed as multiple of 1e-6
       @param _maxTDEthUsdc max TWAP deviation for EthUsdc price in ticks
       @param _maxTDOsqthEth max TWAP deviation for OsqthEth price in ticks
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
    )
        VaultParams(
            _cap,
            _rebalanceTimeThreshold,
            _rebalancePriceThreshold,
            _auctionTime,
            _minPriceMultiplier,
            _maxPriceMultiplier,
            _protocolFee,
            _maxTDEthUsdc,
            _maxTDOsqthEth
        )
    {}

    function _pokeEthUsdc() external onlyVault {
        _poke(address(Constants.poolEthUsdc), orderEthUsdcLower, orderEthUsdcUpper);
    }

    function _pokeEthOsqth() external onlyVault {
        _poke(address(Constants.poolEthOsqth), orderOsqthEthLower, orderOsqthEthUpper);
    }

    /**
     * @dev Do zero-burns to poke a position on Uniswap so earned fees are
     * updated. Should be called if total amounts needs to include up-to-date
     * fees.
     * @param pool address of pool to poke
     * @param tickLower lower tick of the position
     * @param tickUpper upper tick of the position
     */
    function _poke(
        address pool,
        int24 tickLower,
        int24 tickUpper
    ) internal {
        (uint128 liquidity, , , , ) = IVaultTreasury(vaultTreasury).position(pool, tickLower, tickUpper);

        if (liquidity > 0) {
            IVaultTreasury(vaultTreasury).burn(pool, tickLower, tickUpper, 0);
        }
    }

    function _positionLiquidityEthUsdc() external view returns (uint128) {
        (uint128 liquidityEthUsdc, , , , ) = IVaultTreasury(vaultTreasury).position(
            Constants.poolEthUsdc,
            orderEthUsdcLower,
            orderEthUsdcUpper
        );
        return liquidityEthUsdc;
    }

    function _positionLiquidityEthOsqth() external view returns (uint128) {
        (uint128 liquidityEthOsqth, , , , ) = IVaultTreasury(vaultTreasury).position(
            Constants.poolEthOsqth,
            orderOsqthEthLower,
            orderOsqthEthUpper
        );
        return liquidityEthOsqth;
    }

    /**
     * @notice Calculate shares and token amounts for deposit
     * @param _amountEth desired amount of wETH to deposit
     * @param _amountUsdc desired amount of USDC to deposit
     * @param _amountOsqth desired amount of oSQTH to deposit
     * @return shares to mint
     * @return required amount of wETH to deposit
     * @return required amount of USDC to deposit
     * @return required amount of oSQTH to deposit
     */
    function _calcSharesAndAmounts(
        uint256 _amountEth,
        uint256 _amountUsdc,
        uint256 _amountOsqth,
        uint256 _totalSupply
    )
        public
        view
        returns (
            uint256,
            uint256,
            uint256,
            uint256
        )
    {
        //Get total amounts of token balances
        (uint256 ethAmount, uint256 usdcAmount, uint256 osqthAmount) = _getTotalAmounts();

        //Get current prices
        (uint256 ethUsdcPrice, uint256 osqthEthPrice) = _getPrices();

        //Calculate total depositor value
        uint256 depositorValue = _getValue(_amountEth, _amountUsdc, _amountOsqth, ethUsdcPrice, osqthEthPrice);

        if (_totalSupply == 0) {
            //deposit in a 50.79% eth, 24.35% usdc, 24.86% osqth proportion
            return (
                depositorValue,
                depositorValue.mul(507924136843192000).div(ethUsdcPrice),
                depositorValue.mul(243509747368953000).div(uint256(1e30)),
                depositorValue.mul(248566115787854000).div(osqthEthPrice).div(ethUsdcPrice)
            );
        } else {
            //Calculate total strategy value
            uint256 totalValue = _getValue(ethAmount, usdcAmount, osqthAmount, ethUsdcPrice, osqthEthPrice);

            return (
                _totalSupply.mul(depositorValue).div(totalValue),
                ethAmount.mul(depositorValue).div(totalValue),
                usdcAmount.mul(depositorValue).div(totalValue),
                osqthAmount.mul(depositorValue).div(totalValue)
            );
        }
    }

    /**
     * @notice Calculate tokens amounts to withdraw
     * @param shares amount of shares to burn
     * @param totalSupply current supply of shares
     * @return amount of wETH to withdraw
     * @return amount of USDC to withdraw
     * @return amount of oSQTH to withdraw
     */
    function _getWithdrawAmounts(uint256 shares, uint256 totalSupply)
        external
        onlyVault
        returns (
            uint256,
            uint256,
            uint256
        )
    {
        //Get unused token amounts (deposited, but yet not placed to pools)
        uint256 unusedAmountEth = (_getBalance(Constants.weth).sub(accruedFeesEth)).mul(shares).div(totalSupply);
        uint256 unusedAmountUsdc = (_getBalance(Constants.usdc).sub(accruedFeesUsdc)).mul(shares).div(totalSupply);
        uint256 unusedAmountOsqth = (_getBalance(Constants.osqth).sub(accruedFeesOsqth)).mul(shares).div(totalSupply);

        //withdraw user share of tokens from the lp positions in current proportion
        (uint256 amountUsdc, uint256 amountEth0) = _burnLiquidityShare(
            Constants.poolEthUsdc,
            orderEthUsdcLower,
            orderEthUsdcUpper,
            shares,
            totalSupply
        );
        (uint256 amountEth1, uint256 amountOsqth) = _burnLiquidityShare(
            Constants.poolEthOsqth,
            orderOsqthEthLower,
            orderOsqthEthUpper,
            shares,
            totalSupply
        );

        // Sum up total amounts owed to recipient
        return (
            unusedAmountEth.add(amountEth0).add(amountEth1),
            unusedAmountUsdc.add(amountUsdc),
            unusedAmountOsqth.add(amountOsqth)
        );
    }

    /**
     * @notice Calculates the vault's total holdings of token0 and token1 - in
     * other words, how much of each token the vault would hold if it withdrew
     * all its liquidity from Uniswap.
     */
    function _getTotalAmounts()
        public
        view
        returns (
            uint256,
            uint256,
            uint256
        )
    {
        (uint256 usdcAmount, uint256 amountWeth0) = _getPositionAmounts(
            Constants.poolEthUsdc,
            orderEthUsdcLower,
            orderEthUsdcUpper
        );

        (uint256 amountWeth1, uint256 osqthAmount) = _getPositionAmounts(
            Constants.poolEthOsqth,
            orderOsqthEthLower,
            orderOsqthEthUpper
        );

        return (
            _getBalance(Constants.weth).add(amountWeth0).add(amountWeth1).sub(accruedFeesEth),
            _getBalance(Constants.usdc).add(usdcAmount).sub(accruedFeesUsdc),
            _getBalance(Constants.osqth).add(osqthAmount).sub(accruedFeesOsqth)
        );
    }

    /**
     * @notice Amounts of token0 and token1 held in vault's position. Includes owed fees.
     * @dev Doesn't include fees accrued since last poke.
     */
    function _getPositionAmounts(
        address pool,
        int24 tickLower,
        int24 tickUpper
    ) internal view returns (uint256, uint256) {
        (uint128 liquidity, , , uint128 tokensOwed0, uint128 tokensOwed1) = IVaultTreasury(vaultTreasury).position(
            pool,
            tickLower,
            tickUpper
        );
        (uint256 amount0, uint256 amount1) = IVaultTreasury(vaultTreasury).amountsForLiquidity(
            pool,
            tickLower,
            tickUpper,
            liquidity
        );

        uint256 oneMinusFee = uint256(1e6).sub(protocolFee);

        uint256 total0;
        if (pool == Constants.poolEthUsdc) {
            total0 = (amount0.add(tokensOwed0)).mul(oneMinusFee.mul(1e30));
        } else {
            total0 = (amount0.add(tokensOwed0)).mul(oneMinusFee).div(1e6);
        }

        return (total0, (amount1.add(tokensOwed1)).mul(oneMinusFee).div(1e6));
    }

    /**
     * @notice current balance of a certain token
     */
    function _getBalance(IERC20 token) internal view returns (uint256) {
        return token.balanceOf(address(this));
    }

    /// @dev Withdraws share of liquidity in a range from Uniswap pool.
    function _burnLiquidityShare(
        address pool,
        int24 tickLower,
        int24 tickUpper,
        uint256 shares,
        uint256 totalSupply
    ) internal returns (uint256 amount0, uint256 amount1) {
        (uint128 totalLiquidity, , , , ) = IVaultTreasury(vaultTreasury).position(pool, tickLower, tickUpper);
        uint256 liquidity = uint256(totalLiquidity).mul(shares).div(totalSupply);

        if (liquidity > 0) {
            (uint256 burned0, uint256 burned1, uint256 fees0, uint256 fees1) = _burnAndCollect(
                pool,
                tickLower,
                tickUpper,
                _toUint128(liquidity)
            );

            //add share of fees
            amount0 = burned0.add(fees0.mul(shares).div(totalSupply));
            amount1 = burned1.add(fees1.mul(shares).div(totalSupply));
        }
    }

    /// @dev Withdraws liquidity from a range and collects all fees in the process.
    function _burnAndCollect(
        address pool,
        int24 tickLower,
        int24 tickUpper,
        uint128 liquidity
    )
        public
        onlyVault
        returns (
            uint256 burned0,
            uint256 burned1,
            uint256 feesToVault0,
            uint256 feesToVault1
        )
    {
        if (liquidity > 0) {
            (burned0, burned1) = IVaultTreasury(vaultTreasury).burn(pool, tickLower, tickUpper, liquidity);
        }

        (uint256 collect0, uint256 collect1) = IVaultTreasury(vaultTreasury).collect(pool, tickLower, tickUpper);

        feesToVault0 = collect0.sub(burned0);
        feesToVault1 = collect1.sub(burned1);

        //Account for protocol fee
        if (protocolFee > 0) {
            uint256 feesToProtocol0 = feesToVault0.mul(protocolFee).div(1e6);
            uint256 feesToProtocol1 = feesToVault1.mul(protocolFee).div(1e6);

            feesToVault0 = feesToVault0.sub(feesToProtocol0);
            feesToVault1 = feesToVault1.sub(feesToProtocol1);
            if (pool == Constants.poolEthUsdc) {
                accruedFeesUsdc = accruedFeesUsdc.add(feesToProtocol0);
                accruedFeesEth = accruedFeesEth.add(feesToProtocol1);
            } else if (pool == Constants.poolEthOsqth) {
                accruedFeesEth = accruedFeesEth.add(feesToProtocol0);
                accruedFeesOsqth = accruedFeesOsqth.add(feesToProtocol1);
            }

            emit SharedEvents.CollectFees(feesToVault0, feesToVault1, feesToProtocol0, feesToProtocol1);
        }
    }

    /**
     * @notice check if hedging based on time threshold is allowed
     * @return true if time hedging is allowed
     * @return auction trigger timestamp
     */
    function isTimeRebalance() public view returns (bool, uint256) {
        uint256 auctionTriggerTime = timeAtLastRebalance.add(rebalanceTimeThreshold);

        return (block.timestamp >= auctionTriggerTime, auctionTriggerTime);
    }

    // TODO: make me internal on mainnet
    /**
     * @notice check if hedging based on price threshold is allowed
     * @param _auctionTriggerTime timestamp when auction started
     * @return true if hedging is allowed
     */
    function _isPriceRebalance(uint256 _auctionTriggerTime) public view returns (bool) {
        if (_auctionTriggerTime < timeAtLastRebalance) return false;
        uint32 secondsToTrigger = uint32(block.timestamp - _auctionTriggerTime);
        uint256 ethUsdcPriceAtTrigger = Constants.oracle.getHistoricalTwap(
            Constants.poolEthUsdc,
            address(Constants.weth),
            address(Constants.usdc),
            secondsToTrigger + twapPeriod,
            secondsToTrigger
        );

        uint256 cachedRatio = ethUsdcPriceAtTrigger.div(ethPriceAtLastRebalance);
        uint256 priceTreshold = cachedRatio > 1e18 ? (cachedRatio).sub(1e18) : uint256(1e18).sub(cachedRatio);
        return priceTreshold >= rebalancePriceThreshold;
    }

    /**
     * @notice calculate token price from tick
     * @param tick tick that need to be converted to price
     * @return token price
     */
    function _getPriceFromTick(int24 tick) internal pure returns (uint256) {
        //const = 2^192
        uint256 const = 6277101735386680763835789423207666416102355444464034512896;

        uint160 sqrtRatioAtTick = Constants.uniswapMath.getSqrtRatioAtTick(tick);
        return (uint256(sqrtRatioAtTick)).pow(uint256(2e18)).mul(1e36).div(const);
    }

    /**
     * @notice calculate auction price multiplier
     * @param _auctionTriggerTime timestamp when auction started
     * @return priceMultiplier
     */
    function _getPriceMultiplier(uint256 _auctionTriggerTime) internal view returns (uint256) {
        uint256 auctionCompletionRatio = block.timestamp.sub(_auctionTriggerTime) >= auctionTime
            ? 1e18
            : (block.timestamp.sub(_auctionTriggerTime)).div(auctionTime);

        return minPriceMultiplier.add(auctionCompletionRatio.mul(maxPriceMultiplier.sub(minPriceMultiplier)));
    }

    /**
     * @notice calculate all auction parameters
     * @param _auctionTriggerTime timestamp when auction started
     */
    function _getAuctionParams(uint256 _auctionTriggerTime) external view returns (Constants.AuctionParams memory) {
        (uint256 ethUsdcPrice, uint256 osqthEthPrice) = _getPrices();

        uint256 priceMultiplier = _getPriceMultiplier(_auctionTriggerTime);

        //boundaries for auction prices (current price * multiplier)
        Constants.Boundaries memory boundaries = _getBoundaries(
            ethUsdcPrice.mul(priceMultiplier),
            osqthEthPrice.mul(priceMultiplier)
        );
        //Current strategy holdings
        (uint256 ethBalance, uint256 usdcBalance, uint256 osqthBalance) = _getTotalAmounts();

        //Value for LPing
        uint256 totalValue = _getValue(ethBalance, usdcBalance, osqthBalance, ethUsdcPrice, osqthEthPrice).mul(
            uint256(2e18) - priceMultiplier
        );

        //Value multiplier
        uint256 vm = priceMultiplier.mul(uint256(1e18)).div(priceMultiplier.add(uint256(1e18)));

        //Calculate liquidities
        uint128 liquidityEthUsdc = _getLiquidityForValue(
            totalValue.mul(vm),
            ethUsdcPrice,
            uint256(1e30).div(_getPriceFromTick(boundaries.ethUsdcUpper)),
            uint256(1e30).div(_getPriceFromTick(boundaries.ethUsdcLower)),
            1e12
        );

        uint128 liquidityOsqthEth = _getLiquidityForValue(
            totalValue.mul(uint256(1e18) - vm).div(ethUsdcPrice),
            osqthEthPrice,
            uint256(1e18).div(_getPriceFromTick(boundaries.osqthEthUpper)),
            uint256(1e18).div(_getPriceFromTick(boundaries.osqthEthLower)),
            1e18
        );

        //Calculate deltas that need to be exchanged with keeper
        (uint256 deltaEth, uint256 deltaUsdc, uint256 deltaOsqth) = _getDeltas(
            boundaries,
            liquidityEthUsdc,
            liquidityOsqthEth,
            ethBalance,
            usdcBalance,
            osqthBalance
        );

        return
            Constants.AuctionParams(
                priceMultiplier,
                deltaEth,
                deltaUsdc,
                deltaOsqth,
                boundaries,
                liquidityEthUsdc,
                liquidityOsqthEth
            );
    }

    /**
     * @notice function to get current tokens prices
     * @dev check for max twap deviation
     * @return ethUsdcPrice price
     * @return osqthEthPrice price
     */
    function _getPrices() internal view returns (uint256 ethUsdcPrice, uint256 osqthEthPrice) {
        //Get current prices in ticks
        int24 ethUsdcTick = _getTick(Constants.poolEthUsdc);
        int24 osqthEthTick = _getTick(Constants.poolEthOsqth);

        //Get twap in ticks
        (int24 twapEthUsdc, int24 twapOsqthEth) = _getTwap();

        //Check twap deviaiton
        int24 deviation0 = ethUsdcTick > twapEthUsdc ? ethUsdcTick - twapEthUsdc : twapEthUsdc - ethUsdcTick;
        int24 deviation1 = osqthEthTick > twapOsqthEth ? osqthEthTick - twapOsqthEth : twapOsqthEth - osqthEthTick;

        require(deviation0 <= maxTDEthUsdc || deviation1 <= maxTDOsqthEth, "Max TWAP Deviation");

        ethUsdcPrice = uint256(1e30).div(_getPriceFromTick(ethUsdcTick));
        osqthEthPrice = uint256(1e18).div(_getPriceFromTick(osqthEthTick));
    }

    /// @dev Fetches current price in ticks from Uniswap pool.
    function _getTick(address pool) internal view returns (int24 tick) {
        (, tick, , , , , ) = IUniswapV3Pool(pool).slot0();
    }

    /// @dev Wrapper around `LiquidityAmounts.getLiquidityForAmounts()`.
    function _liquidityForAmounts(
        address pool,
        int24 tickLower,
        int24 tickUpper,
        uint256 amount0,
        uint256 amount1
    ) internal view returns (uint128) {
        (uint160 sqrtRatioX96, , , , , , ) = IUniswapV3Pool(pool).slot0();

        return
            Constants.uniswapMath.getLiquidityForAmounts(
                sqrtRatioX96,
                Constants.uniswapMath.getSqrtRatioAtTick(tickLower),
                Constants.uniswapMath.getSqrtRatioAtTick(tickUpper),
                amount0,
                amount1
            );
    }

    /**
     * @notice calculate deltas that will be exchanged during auction
     * @param boundaries positions boundaries
     * @param liquidityEthUsdc target liquidity for ETH:USDC pool
     * @param liquidityOsqthEth target liquidity for oSQTH:ETH pool
     * @param ethBalance current wETH balance
     * @param usdcBalance current USDC balance
     * @param osqthBalance current oSQTH balance
     * @return deltaEth target wETH amount minus current wETH balance
     * @return deltaUsdc target USDC amount minus current USDC balance
     * @return deltaOsqth target oSQTH amount minus current oSQTH balance
     */
    function _getDeltas(
        Constants.Boundaries memory boundaries,
        uint128 liquidityEthUsdc,
        uint128 liquidityOsqthEth,
        uint256 ethBalance,
        uint256 usdcBalance,
        uint256 osqthBalance
    )
        internal
        view
        returns (
            uint256,
            uint256,
            uint256
        )
    {
        (uint256 ethAmount, uint256 usdcAmount, uint256 osqthAmount) = IVaultTreasury(vaultTreasury)
            .allAmountsForLiquidity(boundaries, liquidityEthUsdc, liquidityOsqthEth);

        return (ethBalance.suba(ethAmount), usdcBalance.suba(usdcAmount), osqthBalance.suba(osqthAmount));
    }

    /**
     * @notice calculate deltas that will be exchanged during auction
     * @param aEthUsdcPrice auction EthUsdc price
     * @param aOsqthEthPrice auction OsqthEth price
     */
    function _getBoundaries(uint256 aEthUsdcPrice, uint256 aOsqthEthPrice)
        internal
        view
        returns (Constants.Boundaries memory)
    {
        (uint160 _aEthUsdcTick, uint160 _aOsqthEthTick) = _getTicks(aEthUsdcPrice, aOsqthEthPrice);

        int24 aEthUsdcTick = Constants.uniswapMath.getTickAtSqrtRatio(_aEthUsdcTick);
        int24 aOsqthEthTick = Constants.uniswapMath.getTickAtSqrtRatio(_aOsqthEthTick);

        int24 tickFloorEthUsdc = _floor(aEthUsdcTick, tickSpacingEthUsdc);
        int24 tickFloorOsqthEth = _floor(aOsqthEthTick, tickSpacingOsqthEth);

        int24 tickCeilEthUsdc = tickFloorEthUsdc + tickSpacingEthUsdc;
        int24 tickCeilOsqthEth = tickFloorOsqthEth + tickSpacingOsqthEth;

        return
            Constants.Boundaries(
                tickFloorEthUsdc - ethUsdcThreshold,
                tickCeilEthUsdc + ethUsdcThreshold,
                tickFloorOsqthEth - osqthEthThreshold,
                tickCeilOsqthEth + osqthEthThreshold
            );
    }

    /**
     * @notice calculate deltas that will be exchanged during auction
     * @param aEthUsdcPrice auction EthUsdc price
     * @param aOsqthEthPrice auction oSqthEth price
     * @return tick for aEthUsdcPrice
     * @return tick for aOsqthEthPrice
     */
    function _getTicks(uint256 aEthUsdcPrice, uint256 aOsqthEthPrice) internal pure returns (uint160, uint160) {
        return (
            _toUint160(
                //sqrt(price)*2**96
                ((uint256(1e30).div(aEthUsdcPrice)).sqrt()).mul(79228162514264337593543950336)
            ),
            _toUint160(((uint256(1e18).div(aOsqthEthPrice)).sqrt()).mul(79228162514264337593543950336))
        );
    }

    /// @dev Fetches time-weighted average price in ticks from Uniswap pool.
    function _getTwap() internal view returns (int24, int24) {
        uint32 _twapPeriod = twapPeriod;
        uint32[] memory secondsAgo = new uint32[](2);
        secondsAgo[0] = _twapPeriod;
        secondsAgo[1] = 0;

        (int56[] memory tickCumulativesEthUsdc, ) = IUniswapV3Pool(Constants.poolEthUsdc).observe(secondsAgo);
        (int56[] memory tickCumulativesEthOsqth, ) = IUniswapV3Pool(Constants.poolEthOsqth).observe(secondsAgo);
        return (
            int24((tickCumulativesEthUsdc[1] - tickCumulativesEthUsdc[0]) / int56(uint56(_twapPeriod))),
            int24((tickCumulativesEthOsqth[1] - tickCumulativesEthOsqth[0]) / int56(uint56(_twapPeriod)))
        );
    }

    /**
     * @notice calculate liquidity from usd value
     * @param v value in usd terms
     * @param p current price
     * @param pL lower boundary price
     * @param pH upper boundary price
     * @param digits different pools requires different digits (stack too deep)
     * @return liquidity
     */
    function _getLiquidityForValue(
        uint256 v,
        uint256 p,
        uint256 pL,
        uint256 pH,
        uint256 digits
    ) internal pure returns (uint128) {
        return _toUint128(v.div((p.sqrt()).mul(2e18) - pL.sqrt() - p.div(pH.sqrt())).mul(digits));
    }

    function updateAccruedFees(
        uint256 amountEth,
        uint256 amountUsdc,
        uint256 amountOsqth
    ) external onlyVault {
        accruedFeesUsdc = accruedFeesUsdc.sub(amountUsdc);
        accruedFeesEth = accruedFeesEth.sub(amountEth);
        accruedFeesOsqth = accruedFeesOsqth.sub(amountOsqth);
    }

    /**
     * @notice calculate value in usd terms
     */
    function _getValue(
        uint256 amountEth,
        uint256 amountUsdc,
        uint256 amountOsqth,
        uint256 ethUsdcPrice,
        uint256 osqthEthPrice
    ) internal pure returns (uint256) {
        return (amountOsqth.mul(osqthEthPrice) + amountEth).mul(ethUsdcPrice) + amountUsdc.mul(1e30);
    }

    modifier onlyVault() {
        require(msg.sender == vault, "vault");
        _;
    }

    /// @dev Rounds tick down towards negative infinity so that it's a multiple
    /// of `tickSpacing`.
    function _floor(int24 tick, int24 tickSpacing) internal pure returns (int24) {
        int24 compressed = tick / tickSpacing;
        if (tick < 0 && tick % tickSpacing != 0) compressed--;
        return compressed * tickSpacing;
    }

    /// @dev Casts uint256 to uint128 with overflow check.
    function _toUint128(uint256 x) internal pure returns (uint128) {
        assert(x <= type(uint128).max);
        return uint128(x);
    }

    /// @dev Casts uint256 to uint160 with overflow check.
    function _toUint160(uint256 x) internal pure returns (uint160) {
        assert(x <= type(uint160).max);
        return uint160(x);
    }
}
