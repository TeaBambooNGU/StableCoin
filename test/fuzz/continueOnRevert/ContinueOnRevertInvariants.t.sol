// SPDX-License-Identifier: MIT LICENSE
pragma solidity ^0.8.20;

import {Test,console} from "forge-std/Test.sol";
import {StdInvariant} from "forge-std/StdInvariant.sol";
import {TANGEngine, TangStableCoin,DeployTangStable} from "script/DeployTangStable.s.sol";
import {ChainLinkConfig,NetWorkingChainLinkPriceFeed,WERC20Mock} from "script/ChainLinkConfig.s.sol";
import {NetWorkingConfig,NetWorking} from "script/NetWorkingConfig.s.sol";
import {AggregatorV3Interface} from "chainlink-brownie-contracts/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";
import {ContinueOnRevertHandler} from "./ContinueOnRevertHandler.t.sol";

contract ContinueOnRevertInvariants is StdInvariant, Test {

    TANGEngine tangEngine;
    TangStableCoin tangStableCoin;
    NetWorkingChainLinkPriceFeed chainLinkPriceFeed;
    NetWorking netWorking;
    ContinueOnRevertHandler continueOnRevertHandler;
    WERC20Mock wbtc;
    WERC20Mock weth;

    uint256 public constant STABLE_COIN_PRICE = 1e18;
    uint256 public constant FIX_TOKEN_DECIMAL = 1e18;

    modifier onlyInAnvil() {
        if(block.chainid != 31337){
            return;
        }  
        _;    
    }

    function setUp() public {
        (tangEngine, tangStableCoin,chainLinkPriceFeed,netWorking) = new DeployTangStable().run();
        wbtc = WERC20Mock(payable(chainLinkPriceFeed.addressWBTC));
        weth = WERC20Mock(payable(chainLinkPriceFeed.addressWETH));   

        if(block.chainid == 31337){
            continueOnRevertHandler = new ContinueOnRevertHandler(address(tangEngine), address(tangStableCoin),address(weth),address(wbtc));
            targetContract(address(continueOnRevertHandler));
        }
    }
    //不变量
    function invariant_depositValueMustBeGreaterThanTANGTatalSupply() public view onlyInAnvil {

        uint256 totalSupply = tangStableCoin.totalSupply();
        uint256 tangValue = (totalSupply * STABLE_COIN_PRICE)/FIX_TOKEN_DECIMAL;
        console.log("totalSupply = ", totalSupply);
        console.log("tangValue = ",tangValue);

        uint256 depositBTC = wbtc.balanceOf(address(tangEngine));
        uint256 depositWETH = weth.balanceOf(address(tangEngine));
        uint256 depositValue = tangEngine.getTokenValue(address(wbtc),depositBTC) + tangEngine.getTokenValue(address(weth),depositWETH);
        console.log("depositBTC = ",depositBTC);
        console.log("depositWETH = ",depositWETH);
        console.log("depositValue = ",depositValue);

        assert(depositValue >= tangValue);
  
    }


}
