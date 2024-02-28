// SPDX-License-Identifier: MIT License
pragma solidity ^0.8.20;

import {TANGEngine} from "src/TANGEngine.sol";
import {TangStableCoin} from "src/TangStableCoin.sol";
import {ChainLinkDataEnum} from "src/ChainLinkDataEnum.sol";
import {ChainLinkConfig,NetWorkingChainLinkPriceFeed} from "./ChainLinkConfig.s.sol";
import {NetWorkingConfig,NetWorking} from "./NetWorkingConfig.s.sol";
import {Script} from "forge-std/Script.sol";


contract DeployTangStable is Script{

    TANGEngine public tangEngine;
    TangStableCoin public tangStableCoin;
    ChainLinkConfig public chainLinkConfig;
    NetWorkingConfig public netWorkingConfig;
    address[] public tokensContractddress;
    address[] public tokensPriceDataFeed;

    function run() public returns(TANGEngine, TangStableCoin,NetWorkingChainLinkPriceFeed memory,NetWorking memory) {
        chainLinkConfig = new ChainLinkConfig();
        netWorkingConfig = new NetWorkingConfig();
        tokensContractddress = new address[](2);
        tokensPriceDataFeed = new address[](2);
        
        NetWorkingChainLinkPriceFeed memory chainLinkPriceFeed = chainLinkConfig.getActiveChainlinkPriceFeed();
        NetWorking memory netWorking = netWorkingConfig.getActiveNetWorking();
        
        tokensContractddress[uint256(ChainLinkDataEnum.PriceDataFeed.BTC_USD)] = chainLinkPriceFeed.addressWBTC;
        tokensContractddress[uint256(ChainLinkDataEnum.PriceDataFeed.ETH_USD)] = chainLinkPriceFeed.addressWETH;
        tokensPriceDataFeed[uint256(ChainLinkDataEnum.PriceDataFeed.BTC_USD)] = chainLinkPriceFeed.priceFeedBTC2USD;
        tokensPriceDataFeed[uint256(ChainLinkDataEnum.PriceDataFeed.ETH_USD)] = chainLinkPriceFeed.priceFeedETH2USD;

        vm.startBroadcast(netWorking.privateKey);
        tangStableCoin = new TangStableCoin("TangStableCoin", "TANG");
        tangEngine = new TANGEngine(address(tangStableCoin), tokensContractddress,tokensPriceDataFeed);
        tangStableCoin.transferOwnership(address(tangEngine));
        vm.stopBroadcast();

        return (tangEngine, tangStableCoin,chainLinkPriceFeed,netWorking);
    }

}