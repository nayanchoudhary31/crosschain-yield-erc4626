// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity 0.8.30;

import {Test} from "forge-std/Test.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {YieldVault, PausableUpgradeable} from "../src/vault/YieldVault.sol";
import {YieldVaultV1} from "../src/vault/YieldVaultV1.sol";
import {Upgrades} from "openzeppelin-foundry-upgrades/Upgrades.sol";
import {MockUSDC} from "../src/mocks/MockUSDC.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ERC4626Upgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC4626Upgradeable.sol";
import {IAccessControl} from "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";

contract YieldVaultTest is Test {
    YieldVault public vault;
    MockUSDC public usdc;
    address public admin;
    address public user;
    address public alice;

    uint256 public constant INITIAL_DEPOSIT_CAP = 100_000 * 1e18;
    uint256 public constant INITIAL_WITHDRAW_CAP = 100_000 * 1e18;

    uint256 public constant INITIAL_MINT = 10_000 * 1e18;

    event Paused(address account);
    event Unpaused(address account);
    event YieldAdded(uint256 amount);

    function setUp() public {
        usdc = new MockUSDC();
        admin = makeAddr("admin");
        user = makeAddr("user");
        alice = makeAddr("alice");

        vm.startPrank(admin);

        YieldVault implementation = new YieldVault();
        bytes memory initData = abi.encodeCall(
            YieldVault.initialize,
            (IERC20(usdc), INITIAL_DEPOSIT_CAP)
        );

        vault = YieldVault(
            address(new ERC1967Proxy(address(implementation), initData))
        );

        usdc.mint(admin, INITIAL_MINT);
        usdc.mint(user, INITIAL_MINT);
        usdc.mint(alice, INITIAL_MINT);

        vault.grantRole(vault.YIELD_ROLE(), alice);

        vm.stopPrank();
    }

    // Helper to approve and deposit
    function deposit(address caller, uint256 amount) internal {
        vm.startPrank(caller);
        usdc.approve(address(vault), amount);
        vault.deposit(amount, caller);
        vm.stopPrank();
    }

    function simulateYield(address caller, uint256 amount) internal {
        vm.startPrank(caller);
        usdc.approve(address(vault), amount);
        vault.simulateYield(amount);
        vm.stopPrank();
    }

    function test_Initialization() public view {
        assertEq(vault.name(), "Yield Vault Share");
        assertEq(vault.symbol(), "YVS");
        assertEq(address(vault.asset()), address(usdc));
        assertEq(vault.totalAssets(), 0);
        assertEq(vault.totalSupply(), 0);
        assertTrue(vault.hasRole(vault.DEFAULT_ADMIN_ROLE(), admin));
        assertTrue(vault.hasRole(vault.YIELD_ROLE(), admin));
    }

    function test_Deposit() public {
        uint256 depositAmount = 1000 * 1e18;
        deposit(user, depositAmount);

        assertEq(usdc.balanceOf(user), INITIAL_MINT - depositAmount);
        assertEq(usdc.balanceOf(address(vault)), depositAmount);
        assertEq(vault.balanceOf(user), depositAmount);
        assertEq(vault.totalAssets(), depositAmount);
        assertEq(vault.totalSupply(), depositAmount);
    }

    function test_RevertWhen_ZeroDeposit() public {
        vm.startPrank(user);
        usdc.approve(address(vault), 0);
        vm.expectRevert(YieldVault.ZeroAmount.selector);
        vault.deposit(0, user);
        vm.stopPrank();
    }

    function test_RevertWhen_DepositExceedsCap() public {
        uint256 depositAmount = INITIAL_DEPOSIT_CAP + 1;
        vm.startPrank(user);
        usdc.approve(address(vault), depositAmount);
        vm.expectRevert(YieldVault.DepositCapExceeded.selector);
        vault.deposit(depositAmount, user);
        vm.stopPrank();
    }

    function test_RevertWhen_DepositWhilePaused() public {
        vm.prank(admin);
        vault.pause();

        vm.startPrank(user);
        usdc.approve(address(vault), 100);
        vm.expectRevert(PausableUpgradeable.EnforcedPause.selector);
        vault.deposit(100, user);
        vm.stopPrank();
    }

    // ---------- Withdraw ----------
    function test_Withdraw() public {
        uint256 depositAmount = 1000 * 1e18;
        deposit(user, depositAmount);

        uint256 withdrawAmount = 500 * 1e18;
        vm.startPrank(user);
        uint256 shares = vault.withdraw(withdrawAmount, user, user);
        vm.stopPrank();

        assertEq(shares, withdrawAmount); // 1:1 rate initially
        assertEq(
            usdc.balanceOf(user),
            INITIAL_MINT - depositAmount + withdrawAmount
        );
        assertEq(
            usdc.balanceOf(address(vault)),
            depositAmount - withdrawAmount
        );
        assertEq(vault.balanceOf(user), depositAmount - withdrawAmount);
    }

    function test_RevertWhen_ZeroWithdraw() public {
        deposit(user, 1000 * 1e18);
        vm.startPrank(user);
        vm.expectRevert(YieldVault.ZeroAmount.selector);
        vault.withdraw(0, user, user);
        vm.stopPrank();
    }

    function test_RevertWhen_WithdrawExceedsBalance() public {
        deposit(user, 1000 * 1e18);

        uint256 excessive = 1001 * 1e18;
        uint256 maxWithdraw = vault.maxWithdraw(user); // = 1000e18

        vm.startPrank(user);
        vm.expectRevert(
            abi.encodeWithSelector(
                ERC4626Upgradeable.ERC4626ExceededMaxWithdraw.selector,
                user, // owner
                excessive, // assets (requested amount)
                maxWithdraw // max (allowed amount)
            )
        );
        vault.withdraw(excessive, user, user);
        vm.stopPrank();
    }

    function test_RevertWhen_WithdrawWhilePaused() public {
        deposit(user, 1000 * 1e18);

        vm.prank(admin);
        vault.pause();

        vm.startPrank(user);
        vm.expectRevert(PausableUpgradeable.EnforcedPause.selector);
        vault.withdraw(100, user, user);
        vm.stopPrank();
    }

    // ---------- Pause / Unpause ----------
    function test_PauseUnpause() public {
        // Initially not paused
        assertFalse(vault.paused());

        vm.prank(admin);
        vm.expectEmit(true, true, true, true);
        emit Paused(admin);
        vault.pause();
        assertTrue(vault.paused());

        // Deposit should be blocked
        vm.startPrank(user);
        usdc.approve(address(vault), 100);
        vm.expectRevert(PausableUpgradeable.EnforcedPause.selector);
        vault.deposit(100, user);
        vm.stopPrank();

        // Withdraw should be blocked
        vm.startPrank(user);
        vm.expectRevert(PausableUpgradeable.EnforcedPause.selector);
        vault.withdraw(100, user, user);
        vm.stopPrank();

        vm.prank(admin);
        vm.expectEmit(true, true, true, true);
        emit Unpaused(admin);
        vault.unpause();
        assertFalse(vault.paused());

        // Deposit should work again
        deposit(user, 100);
        assertEq(vault.balanceOf(user), 100);
    }

    function test_RevertWhen_NonAdminPauses() public {
        vm.startPrank(user);
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector,
                user,
                vault.DEFAULT_ADMIN_ROLE()
            )
        );
        vault.pause();
        vm.stopPrank();
    }

    function test_RevertWhen_NonAdminUnpauses() public {
        vm.startPrank(admin);
        vault.pause();
        vm.stopPrank();

        vm.startPrank(user);
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector,
                user,
                vault.DEFAULT_ADMIN_ROLE()
            )
        );
        vault.unpause();
        vm.stopPrank();
    }

    // ---------- Yield Simulation ----------
    function test_SimulateYield() public {
        deposit(user, 1000 * 1e18);

        uint256 yieldAmount = 500 * 1e18;
        // vm.expectEmit(true, true, true, true);
        // emit YieldAdded(yieldAmount);
        simulateYield(alice, yieldAmount);

        assertEq(usdc.balanceOf(alice), INITIAL_MINT - yieldAmount);
        assertEq(usdc.balanceOf(address(vault)), 1000 * 1e18 + yieldAmount);
        assertEq(vault.totalAssets(), 1500 * 1e18);
        assertEq(vault.totalSupply(), 1000 * 1e18);

        uint256 shareValue = vault.convertToAssets(1e18);

        uint256 expected = 1.5e18;
        assertApproxEqAbs(
            shareValue,
            expected,
            1,
            "Share value off by more than 1"
        );
    }

    function test_RevertWhen_ZeroYieldSimulated() public {
        vm.startPrank(alice);
        vm.expectRevert(YieldVault.ZeroAmount.selector);
        vault.simulateYield(0);
        vm.stopPrank();
    }

    function test_RevertWhen_NonYieldRoleSimulatesYield() public {
        uint256 amount = 1000 * 1e18;
        vm.startPrank(user);
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector,
                user,
                vault.YIELD_ROLE()
            )
        );
        vault.simulateYield(amount);
        vm.stopPrank();
    }

    function testVaultUpgrade() public {
        YieldVaultV1 newImpl = new YieldVaultV1();

        bytes memory initData = abi.encodeCall(
            YieldVaultV1.initializeV2,
            (INITIAL_WITHDRAW_CAP)
        );

        vm.startPrank(admin);
        vault.upgradeToAndCall(address(newImpl), initData);

        YieldVaultV1 vaultV1 = YieldVaultV1(address(vault));
        assertEq(vaultV1.getWithdrawCap(), INITIAL_WITHDRAW_CAP);
        vm.stopPrank();
    }
}
