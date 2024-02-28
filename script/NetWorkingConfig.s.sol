// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity 0.8.20;

import {Script,console} from "forge-std/Script.sol";

struct NetWorking {
    uint256 privateKey;
    address walletAddress;
}

contract NetWorkingConfig is Script {

    NetWorking public activeNetWorking;

    constructor() {
        if (block.chainid == 11155111) {
            activeNetWorking = getSepoliaNetWorking();

        } else if (block.chainid == 31337) {
            activeNetWorking = getAnvilNetWorking();
        }
    }

    function getSepoliaNetWorking() private view returns (NetWorking memory) {
        NetWorking memory sepoliaNetWorking = NetWorking({
            privateKey: vm.envUint("SEPOLIA_WALLET_KEY"),
            walletAddress: vm.envAddress("SEPOLIA_WALLET")
        });
        return sepoliaNetWorking;
    }

    function getAnvilNetWorking() private view returns (NetWorking memory) {
        NetWorking memory anvilNetWorking = NetWorking({
            privateKey: vm.envUint("ANVIL_WALLET_KEY"),
            walletAddress: vm.envAddress("ANVIL_WALLET")
        });
        return anvilNetWorking;
    }

    function getActiveNetWorking() public view returns (NetWorking memory) {
        return activeNetWorking;
    }

} 