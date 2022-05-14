// SPDX-License-Identifier: Unlicense

pragma solidity =0.8.4;
pragma abicoder v2;

import {ReentrancyGuard} from "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import {IVault} from "../interfaces/IVault.sol";
import {IVaultMath} from "../interfaces/IVaultMath.sol";
import {IVaultTreasury} from "../interfaces/IVaultTreasury.sol";

import {SharedEvents} from "../libraries/SharedEvents.sol";
import {Constants} from "../libraries/Constants.sol";
import {PRBMathUD60x18} from "../libraries/math/PRBMathUD60x18.sol";

import {VaultAuction} from "./VaultAuction.sol";

import "hardhat/console.sol";

contract Vault is IVault, IERC20, ERC20, ReentrancyGuard, VaultAuction {
    using PRBMathUD60x18 for uint256;
    using SafeERC20 for IERC20;

    address public governance;

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
        int24 _maxTDOsqthEth,
        address _governance
    )
        ERC20("Hedging DL", "HDL")
        VaultAuction(
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
    {
        governance = _governance;
    }

    function setGovernance(address _governance) external onlyGovernance {
        governance = _governance;
    }

    modifier onlyGovernance() {
        require(msg.sender == governance, "governance");
        _;
    }

    function deposit(
        uint256 _amountEth,
        uint256 _amountUsdc,
        uint256 _amountOsqth,
        address to,
        uint256 _amountEthMin,
        uint256 _amountUsdcMin,
        uint256 _amountOsqthMin
    ) external override nonReentrant returns (uint256) {
        require(_amountEth > 0 || (_amountUsdc > 0 || _amountOsqth > 0), "ZA"); //Zero amount
        require(to != address(0) && to != address(this), "WA"); //Wrong address

        //Poke positions so vault's current holdings are up to date
        IVaultMath(vaultMath)._pokeEthUsdc();
        IVaultMath(vaultMath)._pokeEthOsqth();

        //Calculate shares to mint
        (uint256 _shares, uint256 amountEth, uint256 amountUsdc, uint256 amountOsqth) = IVaultMath(vaultMath)
            ._calcSharesAndAmounts(_amountEth, _amountUsdc, _amountOsqth, totalSupply());

        require(amountEth >= _amountEthMin, "Amount ETH min");
        require(amountUsdc >= _amountUsdcMin, "Amount USDC min");
        require(amountOsqth >= _amountOsqthMin, "Amount oSQTH min");

        //Pull in tokens
        if (amountEth > 0) Constants.weth.transferFrom(msg.sender, vaultTreasury, amountEth);
        if (amountUsdc > 0) Constants.usdc.transferFrom(msg.sender, vaultTreasury, amountUsdc);
        if (amountOsqth > 0) Constants.osqth.transferFrom(msg.sender, vaultTreasury, amountOsqth);

        //Mint shares to user
        _mint(to, _shares);
        //Check deposit cap
        require(totalSupply() <= IVaultMath(vaultMath).getCap(), "Cap is reached");

        emit SharedEvents.Deposit(to, _shares);
        return _shares;
    }

    /**
    @notice withdraws tokens in proportion to the vault's holdings.
    @dev provide strategy tokens, returns set of wETH, USDC, and oSQTH
    @param shares shares burned by sender
    @param amountEthMin revert if resulting amount of wETH is smaller than this
    @param amountUsdcMin revert if resulting amount of USDC is smaller than this
    @param amountOsqthMin revert if resulting amount of oSQTH is smaller than this
    */
    function withdraw(
        uint256 shares,
        uint256 amountEthMin,
        uint256 amountUsdcMin,
        uint256 amountOsqthMin
    ) external override nonReentrant {
        require(shares > 0, "0");

        uint256 totalSupply = totalSupply();

        //Burn shares
        _burn(msg.sender, shares);

        //Get token amounts to withdraw
        (uint256 amountEth, uint256 amountUsdc, uint256 amountOsqth) = IVaultMath(vaultMath)._getWithdrawAmounts(
            shares,
            totalSupply
        );

        require(amountEth >= amountEthMin, "amountEthMin");
        require(amountUsdc >= amountUsdcMin, "amountUsdcMin");
        require(amountOsqth >= amountOsqthMin, "amountOsqthMin");

        //send tokens to user
        if (amountEth > 0) IVaultTreasury(vaultTreasury).transfer(Constants.weth, msg.sender, amountEth);
        if (amountUsdc > 0) IVaultTreasury(vaultTreasury).transfer(Constants.usdc, msg.sender, amountUsdc);
        if (amountOsqth > 0) IVaultTreasury(vaultTreasury).transfer(Constants.osqth, msg.sender, amountOsqth);

        emit SharedEvents.Withdraw(msg.sender, shares, amountEth, amountUsdc, amountOsqth);
    }

    /**
     * @notice Used to collect accumulated protocol fees.
     * @param amountEth amount of wETH to withdraw
     * @param amountUsdc amount of USDC to withdraw
     * @param amountOsqth amount of oSQTH to withdraw
     * @param to recipient address
     */
    function collectProtocol(
        uint256 amountEth,
        uint256 amountUsdc,
        uint256 amountOsqth,
        address to
    ) external override nonReentrant onlyGovernance {
        IVaultMath(vaultMath).updateAccruedFees(amountUsdc, amountEth, amountOsqth);

        if (amountUsdc > 0) IVaultTreasury(vaultTreasury).transfer(Constants.usdc, to, amountUsdc);
        if (amountEth > 0) IVaultTreasury(vaultTreasury).transfer(Constants.weth, to, amountEth);
        if (amountOsqth > 0) IVaultTreasury(vaultTreasury).transfer(Constants.osqth, to, amountOsqth);
    }
}
