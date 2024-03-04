// SPDX-License-Identifier: MIT LICENSE
pragma solidity ^0.8.20;

import {Test,console} from "forge-std/Test.sol";
import {TANGEngine, TangStableCoin,DeployTangStable} from "script/DeployTangStable.s.sol";
import {ChainLinkConfig,NetWorkingChainLinkPriceFeed,WERC20Mock} from "script/ChainLinkConfig.s.sol";
import {NetWorkingConfig,NetWorking} from "script/NetWorkingConfig.s.sol";
import {AggregatorV3Interface} from "chainlink-brownie-contracts/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";


contract ContinueOnRevertHandler is Test {
    TANGEngine tangEngine;
    TangStableCoin tangStableCoin;
    NetWorkingChainLinkPriceFeed chainLinkPriceFeed;
    NetWorking netWorking;
    WERC20Mock wbtc;
    WERC20Mock weth;
    address public user;

    constructor(address _tangEngine, address _tangStableCoin,address _weth ,address _wbtc) {
        tangEngine = TANGEngine(_tangEngine);
        tangStableCoin = TangStableCoin(_tangStableCoin);
        wbtc = WERC20Mock(payable(_wbtc));
        weth = WERC20Mock(payable(_weth));
        user = makeAddr("user");
    }

    function mintandDeposit(uint256 mintTokenWETHAmount,uint256 mintTokenWBTCAmount,uint256 depositAmount) public {
        vm.startPrank(user);
        weth.mint(user,mintTokenWETHAmount);
        wbtc.mint(user,mintTokenWBTCAmount);
        weth.approve(address(tangEngine),mintTokenWETHAmount);
        wbtc.approve(address(tangEngine),mintTokenWBTCAmount);
        tangEngine.deposit(address(wbtc),depositAmount);
        vm.stopPrank();
    }



    






}