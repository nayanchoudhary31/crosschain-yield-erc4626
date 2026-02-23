// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity 0.8.30;

import {Script, console} from "forge-std/Script.sol";
import {YieldVaultV1} from "../src/vault/YieldVaultV1.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

contract UpgradeToken is Script {
    uint256 public constant INITIAL_WITHDRAW_CAP = 100_000 * 1e18;

    function run() public {
        address proxy = vm.envAddress("PROXY_ADDRESS");

        vm.startBroadcast();

        // Deploy new implementation
        YieldVaultV1 newImplementation = new YieldVaultV1();

        // Create the calldata

        bytes memory initData = abi.encodeCall(YieldVaultV1.initializeV2, (INITIAL_WITHDRAW_CAP));

        // Upgrade proxy to new implementation
        UUPSUpgradeable(proxy).upgradeToAndCall(address(newImplementation), initData);

        vm.stopBroadcast();

        console.log("New implementation:", address(newImplementation));
        console.log("Upgraded proxy:", proxy);
    }
}
