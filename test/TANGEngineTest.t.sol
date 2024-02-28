// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.20;
import {DeployTangStable} from "script/DeployTangStable.s.sol";
import {Test,console} from "forge-std/Test.sol";
import {TANGEngine,TangStableCoin} from "src/TANGEngine.sol";
import {ChainLinkConfig,NetWorkingChainLinkPriceFeed,WERC20Mock} from "script/ChainLinkConfig.s.sol";
import {NetWorkingConfig,NetWorking} from "script/NetWorkingConfig.s.sol";

contract TANGEngineTest is Test {

    TANGEngine public tangEngine;
    TangStableCoin public tangStableCoin;
    NetWorkingChainLinkPriceFeed public chainLinkPriceFeed;
    NetWorking public netWorking;

    function setUp() public {
        (tangEngine, tangStableCoin,chainLinkPriceFeed,netWorking) = new DeployTangStable().run();
       
    }

    function testGetTokenValue() public {

        uint256 btcValue = tangEngine.getTokenValue(chainLinkPriceFeed.addressWBTC,1000);
        uint256 ethValue = tangEngine.getTokenValue(chainLinkPriceFeed.addressWETH,1000);
        console.log("btcValue:", btcValue);
        console.log("ethValue:", ethValue);
        assertGt(btcValue, 0);
        assertGt(ethValue,0);

    }
}