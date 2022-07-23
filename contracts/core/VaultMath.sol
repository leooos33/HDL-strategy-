// SPDX-License-Identifier: Unlicense

pragma solidity =0.8.4;
pragma abicoder v2;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import {IUniswapV3Pool} from "@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol";

import {IVaultTreasury} from "../interfaces/IVaultTreasury.sol";
import {IVaultStorage} from "../interfaces/IVaultStorage.sol";
import {IVaultMath} from "../interfaces/IVaultMath.sol";

import {SharedEvents} from "../libraries/SharedEvents.sol";
import {Constants} from "../libraries/Constants.sol";
import {PRBMathUD60x18} from "../libraries/math/PRBMathUD60x18.sol";
import {Faucet} from "../libraries/Faucet.sol";
import {IUniswapMath} from "../libraries/uniswap/IUniswapMath.sol";

import "hardhat/console.sol";

contract VaultMath is ReentrancyGuard, Faucet {
    using PRBMathUD60x18 for uint256;
    using SafeERC20 for IERC20;

    /**
     * @notice strategy constructor
     */
    constructor() Faucet() {}

    /**
     * @notice Calculates the vault's total holdings of token0 and token1 - in
     * other words, how much of each token the vault would hold if it withdrew
     * all its liquidity from Uniswap.
     */
    function getTotalAmounts()
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
            IVaultStorage(vaultStorage).orderEthUsdcLower(),
            IVaultStorage(vaultStorage).orderEthUsdcUpper()
        );

        (uint256 amountWeth1, uint256 osqthAmount) = _getPositionAmounts(
            Constants.poolEthOsqth,
            IVaultStorage(vaultStorage).orderOsqthEthLower(),
            IVaultStorage(vaultStorage).orderOsqthEthUpper()
        );

        return (
            _getBalance(Constants.weth).add(amountWeth0).add(amountWeth1).sub(
                IVaultStorage(vaultStorage).accruedFeesEth()
            ),
            _getBalance(Constants.usdc).add(usdcAmount).sub(IVaultStorage(vaultStorage).accruedFeesUsdc()),
            _getBalance(Constants.osqth).add(osqthAmount).sub(IVaultStorage(vaultStorage).accruedFeesOsqth())
        );
    }

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

        uint256 oneMinusFee = uint256(1e6).sub(IVaultStorage(vaultStorage).protocolFee());

        uint256 total0;
        if (pool == Constants.poolEthUsdc) {
            total0 = amount0.add(uint256(tokensOwed0).mul(oneMinusFee).div(1e30));
        } else {
            total0 = amount0.add(uint256(tokensOwed0).mul(oneMinusFee).div(1e30));
        }

        return (total0, amount1.add(uint256(tokensOwed1).mul(oneMinusFee).div(1e30)));
    }

    /// @dev Withdraws share of liquidity in a range from Uniswap pool.
    function burnLiquidityShare(
        address pool,
        int24 tickLower,
        int24 tickUpper,
        uint256 shares,
        uint256 totalSupply
    ) external onlyVault returns (uint256 amount0, uint256 amount1) {
        (uint128 totalLiquidity, , , , ) = IVaultTreasury(vaultTreasury).position(pool, tickLower, tickUpper);

        uint256 liquidity = uint256(totalLiquidity).mul(shares).div(totalSupply);

        if (liquidity > 0) {
            (uint256 burned0, uint256 burned1, uint256 fees0, uint256 fees1) = burnAndCollect(
                pool,
                tickLower,
                tickUpper,
                _toUint128(liquidity)
            );

            amount0 = burned0.add(fees0.mul(shares).div(totalSupply));
            amount1 = burned1.add(fees1.mul(shares).div(totalSupply));
        }
    }

    /// @dev Withdraws liquidity from a range and collects all fees in the process.
    function burnAndCollect(
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

        uint256 protocolFee = IVaultStorage(vaultStorage).protocolFee();

        if (protocolFee > 0) {
            feesToVault0 = collect0.sub(burned0);
            feesToVault1 = collect1.sub(burned1);

            uint256 feesToProtocol0 = feesToVault0.div(protocolFee).div(1e34);
            uint256 feesToProtocol1 = feesToVault1.div(protocolFee).div(1e34);

            feesToVault0 = feesToVault0.sub(feesToProtocol0);
            feesToVault1 = feesToVault1.sub(feesToProtocol1);

            if (pool == Constants.poolEthUsdc) {
                IVaultStorage(vaultStorage).setAccruedFeesUsdc(
                    IVaultStorage(vaultStorage).accruedFeesUsdc().add(feesToProtocol0)
                );

                IVaultStorage(vaultStorage).setAccruedFeesEth(
                    IVaultStorage(vaultStorage).accruedFeesEth().add(feesToProtocol1)
                );
            } else if (pool == Constants.poolEthOsqth) {
                IVaultStorage(vaultStorage).setAccruedFeesEth(
                    IVaultStorage(vaultStorage).accruedFeesEth().add(feesToProtocol0)
                );

                IVaultStorage(vaultStorage).setAccruedFeesOsqth(
                    IVaultStorage(vaultStorage).accruedFeesOsqth().add(feesToProtocol1)
                );
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
        uint256 auctionTriggerTime = IVaultStorage(vaultStorage).timeAtLastRebalance().add(
            IVaultStorage(vaultStorage).rebalanceTimeThreshold()
        );

        console.log("block.timestamp: %s", block.timestamp);
        console.log("auctionTriggerTime: %s", auctionTriggerTime);

        return (block.timestamp >= auctionTriggerTime, auctionTriggerTime);
    }

    // TODO: make me internal on mainnet
    /**
     * @notice check if hedging based on price threshold is allowed
     * @param _auctionTriggerTime timestamp when auction started
     * @return true if hedging is allowed
     */
    function _isPriceRebalance(uint256 _auctionTriggerTime) public view returns (bool) {
        if (_auctionTriggerTime < IVaultStorage(vaultStorage).timeAtLastRebalance()) return false;
        uint32 secondsToTrigger = uint32(block.timestamp - _auctionTriggerTime);
        uint256 ethUsdcPriceAtTrigger = Constants.oracle.getHistoricalTwap(
            Constants.poolEthUsdc,
            address(Constants.weth),
            address(Constants.usdc),
            secondsToTrigger + IVaultStorage(vaultStorage).twapPeriod(),
            secondsToTrigger
        );

        uint256 cachedRatio = ethUsdcPriceAtTrigger.div(IVaultStorage(vaultStorage).ethPriceAtLastRebalance());
        uint256 priceTreshold = cachedRatio > 1e18 ? (cachedRatio).sub(1e18) : uint256(1e18).sub(cachedRatio);
        return priceTreshold >= IVaultStorage(vaultStorage).rebalancePriceThreshold();
    }

    /**
     * @notice calculate token price from tick
     * @param tick tick that need to be converted to price
     * @return token price
     */
    function getPriceFromTick(int24 tick) public view returns (uint256) {
        uint160 sqrtRatioAtTick = IUniswapMath(uniswapMath).getSqrtRatioAtTick(tick);
        //const = 2^192
        return
            (uint256(sqrtRatioAtTick)).pow(uint256(2e18)).mul(1e36).div(
                6277101735386680763835789423207666416102355444464034512896
            );
    }

    /**
     * @notice calculate auction price multiplier
     * @param _auctionTriggerTime timestamp when auction started
     * @return priceMultiplier
     */
    function getPriceMultiplier(uint256 _auctionTriggerTime) external view returns (uint256) {
        uint256 maxPriceMultiplier = IVaultStorage(vaultStorage).maxPriceMultiplier();
        uint256 minPriceMultiplier = IVaultStorage(vaultStorage).minPriceMultiplier();
        uint256 auctionTime = IVaultStorage(vaultStorage).auctionTime();

        uint256 auctionCompletionRatio = block.timestamp.sub(_auctionTriggerTime) >= auctionTime
            ? 1e18
            : (block.timestamp.sub(_auctionTriggerTime)).div(auctionTime);

        return minPriceMultiplier.add(auctionCompletionRatio.mul(maxPriceMultiplier.sub(minPriceMultiplier)));
    }

    function getPrices() public view returns (uint256 ethUsdcPrice, uint256 osqthEthPrice) {
        //Get current prices in ticks
        (, int24 ethUsdcTick, , , , , ) = IUniswapV3Pool(Constants.poolEthUsdc).slot0();
        (, int24 osqthEthTick, , , , , ) = IUniswapV3Pool(Constants.poolEthOsqth).slot0();

        //Get twap in ticks
        (int24 twapEthUsdc, int24 twapOsqthEth) = _getTwap();

        //Check twap deviation
        int24 deviation0 = ethUsdcTick > twapEthUsdc ? ethUsdcTick - twapEthUsdc : twapEthUsdc - ethUsdcTick;
        int24 deviation1 = osqthEthTick > twapOsqthEth ? osqthEthTick - twapOsqthEth : twapOsqthEth - osqthEthTick;

        require(
            deviation0 <= IVaultStorage(vaultStorage).maxTDEthUsdc() ||
                deviation1 <= IVaultStorage(vaultStorage).maxTDOsqthEth(),
            "Max TWAP Deviation"
        );

        ethUsdcPrice = uint256(1e30).div(getPriceFromTick(ethUsdcTick));
        osqthEthPrice = uint256(1e18).div(getPriceFromTick(osqthEthTick));
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
            IUniswapMath(uniswapMath).getLiquidityForAmounts(
                sqrtRatioX96,
                IUniswapMath(uniswapMath).getSqrtRatioAtTick(tickLower),
                IUniswapMath(uniswapMath).getSqrtRatioAtTick(tickUpper),
                amount0,
                amount1
            );
    }

    /// @dev Fetches time-weighted average price in ticks from Uniswap pool.
    function _getTwap() internal view returns (int24, int24) {
        uint32 _twapPeriod = IVaultStorage(vaultStorage).twapPeriod();
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

    function getLiquidityForValue(
        uint256 v,
        uint256 p,
        uint256 pH,
        uint256 pL,
        uint256 digits
    ) external pure returns (uint128) {
        return _toUint128(v.div((p.sqrt()).mul(2e18) - pL.sqrt() - p.div(pH.sqrt())).mul(digits));
    }

    /**
     * @notice calculate value in ETH terms
     */
    function getValue(
        uint256 amountEth,
        uint256 amountUsdc,
        uint256 amountOsqth,
        uint256 ethUsdcPrice,
        uint256 osqthEthPrice
    ) external pure returns (uint256) {
        return (amountEth + amountOsqth.mul(osqthEthPrice) + amountUsdc.mul(1e30).div(ethUsdcPrice));
    }

    function getIV() external view returns (uint256) {
        uint32 _twapPeriod = IVaultStorage(vaultStorage).twapPeriod();

        return
            (
                (
                    (
                        (Constants.osqthController.getDenormalizedMark(_twapPeriod)).div(
                            Constants.osqthController.getIndex(_twapPeriod)
                        )
                    ).ln()
                ).mul(20857142857142857142)
            ).sqrt();
    }

    /// @dev Casts uint256 to uint128 with overflow check.
    function _toUint128(uint256 x) internal pure returns (uint128) {
        assert(x <= type(uint128).max);
        return uint128(x);
    }
}
