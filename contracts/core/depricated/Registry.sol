// SPDX-License-Identifier: Unlicense

pragma solidity =0.8.4;
pragma abicoder v2;

// import {IRegistry} from "../interfaces/IRegistry.sol";
// import {IVaultMath} from "../interfaces/IVaultMath.sol";
// import {IVaultTreasury} from "../interfaces/IVaultTreasury.sol";
// import {IVault} from "../interfaces/IVault.sol";

// import {Vault} from "./Vault.sol";
// import {VaultMath} from "./VaultMath.sol";
// import {VaultTreasury} from "./VaultTreasury.sol";

// import "hardhat/console.sol";

// contract Registry is IRegistry {
//     constructor(
//         uint256 _cap,
//         uint256 _rebalanceTimeThreshold,
//         uint256 _rebalancePriceThreshold,
//         uint256 _auctionTime,
//         uint256 _minPriceMultiplier,
//         uint256 _maxPriceMultiplier,
//         uint256 _protocolFee,
//         int24 _maxTDEthUsdc,
//         int24 _maxTDOsqthEth
//     ) {
//         governance = msg.sender;

//         address _governance = governance;
//         _governance = address(this); //TODO: remove on main

//         // console.log(_governance);

//         Vault _vault = new Vault(
//             _cap,
//             _rebalanceTimeThreshold,
//             _rebalancePriceThreshold,
//             _auctionTime,
//             _minPriceMultiplier,
//             _maxPriceMultiplier,
//             _protocolFee,
//             _maxTDEthUsdc,
//             _maxTDOsqthEth,
//             _governance
//         );
//         vault = address(_vault);

//         VaultMath _vaultMath = new VaultMath(
//             _cap,
//             _rebalanceTimeThreshold,
//             _rebalancePriceThreshold,
//             _auctionTime,
//             _minPriceMultiplier,
//             _maxPriceMultiplier,
//             _protocolFee,
//             _maxTDEthUsdc,
//             _maxTDOsqthEth,
//             _governance
//         );
//         vaultMath = address(_vaultMath);

//         VaultTreasury _vaultTreasury = new VaultTreasury();
//         _vaultTreasury.addKeeper(vaultMath);
//         _vaultTreasury.addKeeper(vault);
//         vaultTreasury = address(_vaultTreasury);
//     }

//     function updateComponents() external {
//         IVault(vault).updateComponents();
//         IVaultMath(vaultMath).updateComponents();
//     }

//     //@dev governance
//     address public governance;
//     address vault;
//     address vaultTreasury;
//     address vaultMath;

//     function getComponents()
//         external
//         view
//         override
//         returns (
//             address,
//             address,
//             address
//         )
//     {
//         return (vault, vaultMath, vaultTreasury);
//     }

//     //TODO: remove on main
//     function deposit(
//         uint256 _amountEth,
//         uint256 _amountUsdc,
//         uint256 _amountOsqth,
//         address to,
//         uint256 _amountEthMin,
//         uint256 _amountUsdcMin,
//         uint256 _amountOsqthMin
//     ) external returns (uint256) {
//         return
//             IVault(vault).deposit(
//                 _amountEth,
//                 _amountUsdc,
//                 _amountOsqth,
//                 to,
//                 _amountEthMin,
//                 _amountUsdcMin,
//                 _amountOsqthMin
//             );
//     }

//     //TODO: remove on main
//     function withdraw(
//         uint256 shares,
//         uint256 amountEthMin,
//         uint256 amountUsdcMin,
//         uint256 amountOsqthMin
//     ) external {
//         return IVault(vault).withdraw(shares, amountEthMin, amountUsdcMin, amountOsqthMin);
//     }

//     //TODO: remove on main
//     function _calcSharesAndAmounts(
//         uint256 _amountEth,
//         uint256 _amountUsdc,
//         uint256 _amountOsqth
//     )
//         public
//         view
//         returns (
//             uint256,
//             uint256,
//             uint256,
//             uint256
//         )
//     {
//         return IVaultMath(vaultMath)._calcSharesAndAmounts(_amountEth, _amountUsdc, _amountOsqth);
//     }
// }
