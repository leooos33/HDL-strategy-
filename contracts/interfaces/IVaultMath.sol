// SPDX-License-Identifier: Unlicense

pragma solidity =0.8.4;
pragma abicoder v2;

interface IVaultMath {
    function _calcSharesAndAmounts(
        uint256 _amountEth,
        uint256 _amountUsdc,
        uint256 _amountOsqth
    )
        external
        returns (
            uint256,
            uint256,
            uint256,
            uint256
        );

    function _getWithdrawAmounts(uint256 shares, uint256 totalSupply)
        external
        returns (
            uint256,
            uint256,
            uint256
        );
}
