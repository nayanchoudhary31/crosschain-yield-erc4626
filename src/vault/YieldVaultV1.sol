// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity 0.8.30;

import {YieldVault} from "./YieldVault.sol";

/**
 * @title YieldVaultV1
 * @notice First upgrade to the YieldVault. Adds a per-transaction withdraw cap.
 *         The cap is set during upgrade via `initializeV2` and can be updated by admin.
 *         Also provides view functions to read both deposit and withdraw caps.
 * @dev Uses reinitializer(2) to safely set the new state variable. Inherits all original
 *      functionality and adds withdraw cap checks in the overridden `withdraw` function.
 */
/// @custom:oz-upgrades-from src/vault/YieldVault.sol:YieldVault
contract YieldVaultV1 is YieldVault {
    error WithdrawCapExceeded(); // Thrown when withdrawal exceeds cap

    event WithdrawCapUpdated(uint256 newCap); // Emitted when withdraw cap changes

    uint256 internal withdrawCap; // Maximum amount per withdrawal

    /**
     * @notice Initializes the vault V2 (reinitializer) – sets the withdraw cap.
     * @param withdrawCap_ The initial per‑transaction withdraw cap.
     */
    function initializeV2(uint256 withdrawCap_) public reinitializer(2) {
        withdrawCap = withdrawCap_;
        emit WithdrawCapUpdated(withdrawCap_);
    }

    /**
     * @notice Withdraws assets, but enforces a per‑transaction cap (if set).
     *         Reverts if assets exceeds withdrawCap.
     */
    function withdraw(uint256 assets, address receiver, address owner)
        public
        override
        nonReentrant
        whenNotPaused
        returns (uint256)
    {
        if (assets == 0) revert ZeroAmount();
        if (assets > withdrawCap) revert WithdrawCapExceeded();
        return super.withdraw(assets, receiver, owner);
    }

    /**
     * @notice Updates the withdraw cap. Only admin.
     * @param newCap_ New per‑transaction withdraw cap.
     */
    function updateWithdrawCap(uint256 newCap_) external onlyRole(DEFAULT_ADMIN_ROLE) {
        withdrawCap = newCap_;
        emit WithdrawCapUpdated(newCap_);
    }

    /// @notice Returns the current deposit cap (inherited from YieldVault).
    function getDepositCap() external view returns (uint256) {
        return depositCap;
    }

    /// @notice Returns the current withdraw cap.
    function getWithdrawCap() external view returns (uint256) {
        return withdrawCap;
    }
}
