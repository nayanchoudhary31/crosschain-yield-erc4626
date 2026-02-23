// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {
    ERC4626Upgradeable,
    Initializable
} from "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC4626Upgradeable.sol";
import {AccessControlUpgradeable} from "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import {PausableUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import {ReentrancyGuardTransient} from "@openzeppelin/contracts/utils/ReentrancyGuardTransient.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {IERC20, SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

/**
 * @title YieldVault
 * @notice ERC-4626 vault that accepts deposits (e.g., mock USDC), mints shares, and allows withdrawals.
 *         Features a deposit cap, emergency pause, role-based access, and UUPS upgradeability.
 *         A special YIELD_ROLE can simulate yield by depositing assets without minting shares,
 *         increasing the value of existing shares.
 * @dev Uses OpenZeppelin upgradeable contracts, SafeERC20, custom errors, and reentrancy protection.
 *      Deposit cap prevents unbounded growth; all state changes emit events.
 */
contract YieldVault is
    Initializable,
    ERC4626Upgradeable,
    UUPSUpgradeable,
    AccessControlUpgradeable,
    PausableUpgradeable,
    ReentrancyGuardTransient
{
    using SafeERC20 for IERC20;

    /**
     * @notice Role that allows calling `simulateYield` to deposit assets without minting shares.
     */
    bytes32 public constant YIELD_ROLE = keccak256("YIELD_ROLE");

    /**
     * @notice Maximum total assets the vault can hold. Set by admin; checked on deposit.
     */
    uint256 internal depositCap;

    // -------- Errors --------
    error ZeroAmount(); // When a required amount is zero
    error DepositCapExceeded(); // When deposit would exceed the cap
    error VaultPaused(); // When action is attempted while paused

    // -------- Events --------
    event YieldAdded(uint256 amount); // Emitted when yield is simulated
    event DepositCapUpdated(uint256 newCap); // Emitted when deposit cap changes

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    /**
     * @notice Initializes the vault with the underlying asset and a deposit cap.
     * @param asset_ The ERC20 token used for deposits/withdrawals (e.g., mock USDC).
     * @param cap_   Initial maximum total assets allowed.
     */
    function initialize(IERC20 asset_, uint256 cap_) public initializer {
        __ERC20_init("Yield Vault Share", "YVS");
        __ERC4626_init(asset_);
        __AccessControl_init();
        __Pausable_init();
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(YIELD_ROLE, msg.sender);
        depositCap = cap_;
    }

    // ---------- Upgrade ----------
    /**
     * @notice Authorizes an upgrade – only the default admin can call.
     */
    function _authorizeUpgrade(address) internal override onlyRole(DEFAULT_ADMIN_ROLE) {}

    // ---------- Admin ----------
    /**
     * @notice Pauses deposits and withdrawals. Only admin.
     */
    function pause() external onlyRole(DEFAULT_ADMIN_ROLE) {
        _pause();
    }

    /**
     * @notice Unpauses the vault. Only admin.
     */
    function unpause() external onlyRole(DEFAULT_ADMIN_ROLE) {
        _unpause();
    }

    /**
     * @notice Updates the deposit cap. Only admin.
     * @param newCap New maximum total assets.
     */
    function updateCap(uint256 newCap) external onlyRole(DEFAULT_ADMIN_ROLE) {
        depositCap = newCap;
        emit DepositCapUpdated(newCap);
    }

    /**
     * @notice Simulates yield by transferring assets into the vault without minting shares.
     *         Only callable by YIELD_ROLE.
     * @param amount Amount of underlying to transfer.
     */
    function simulateYield(uint256 amount) external onlyRole(YIELD_ROLE) {
        if (amount == 0) revert ZeroAmount();
        IERC20(asset()).safeTransferFrom(msg.sender, address(this), amount);
        emit YieldAdded(amount);
    }

    // ---------- ERC4626 Overrides ----------
    /**
     * @notice Deposits assets and mints shares. Reverts if paused, zero amount, or cap exceeded.
     */
    function deposit(uint256 assets, address receiver)
        public
        virtual
        override
        nonReentrant
        whenNotPaused
        returns (uint256)
    {
        if (assets == 0) revert ZeroAmount();
        if (totalAssets() + assets > depositCap) revert DepositCapExceeded();
        return super.deposit(assets, receiver);
    }

    /**
     * @notice Withdraws assets and burns shares. Reverts if paused or zero amount.
     */
    function withdraw(uint256 assets, address receiver, address owner)
        public
        virtual
        override
        nonReentrant
        whenNotPaused
        returns (uint256)
    {
        if (assets == 0) revert ZeroAmount();
        return super.withdraw(assets, receiver, owner);
    }

    // Storage gap for future upgrades
    uint256[50] private __gap;
}
