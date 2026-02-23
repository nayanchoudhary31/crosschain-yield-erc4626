// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity 0.8.30;

import {Script, console} from "forge-std/Script.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {MockUSDC} from "../src/mocks/MockUSDC.sol";
import {YieldVault} from "../src/vault/YieldVault.sol";
import {IERC20} from "@openzeppelin/contracts/interfaces/IERC20.sol";

contract Deploy is Script {
    uint256 public constant DEPOSIT_CAP = 1;

    function run() public {
        
        vm.startBroadcast();

        MockUSDC usdc = new MockUSDC();
        YieldVault implementation = new YieldVault();

        bytes memory initData = abi.encodeCall(
            YieldVault.initialize,
            (IERC20(usdc), DEPOSIT_CAP)
        );

        ERC1967Proxy proxy = new ERC1967Proxy(
            address(implementation),
            initData
        );

        vm.stopBroadcast();

        console.log("Implementation:", address(implementation));
        console.log("Proxy:", address(proxy));
    }
}
