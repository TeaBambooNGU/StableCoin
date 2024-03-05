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
    // 最大抵押货币数量
    uint256 public constant MAX_DEPOSIT_SIZE = type(uint96).max;

    constructor(address _tangEngine, address _tangStableCoin,address _weth ,address _wbtc) {
        tangEngine = TANGEngine(_tangEngine);
        tangStableCoin = TangStableCoin(_tangStableCoin);
        wbtc = WERC20Mock(payable(_wbtc));
        weth = WERC20Mock(payable(_weth));
        user = makeAddr("user");
    }

    function mintandDeposit(uint256 _mintTokenWETHAmount,uint256 _mintTokenWBTCAmount,uint256 _depositAmount) public {
        uint256 mintTokenWETHAmount = bound(_mintTokenWETHAmount,0,MAX_DEPOSIT_SIZE);
        uint256 mintTokenWBTCAmount = bound(_mintTokenWBTCAmount,0,MAX_DEPOSIT_SIZE);
        uint256 depositAmountWbtc = bound(_depositAmount,0,MAX_DEPOSIT_SIZE);
        uint256 depositAmountWeth = bound(_depositAmount,0,MAX_DEPOSIT_SIZE);

        vm.startPrank(user);
        weth.mint(user,mintTokenWETHAmount);
        wbtc.mint(user,mintTokenWBTCAmount);
        weth.approve(address(tangEngine),mintTokenWETHAmount);
        wbtc.approve(address(tangEngine),mintTokenWBTCAmount);
        tangEngine.deposit(address(wbtc),depositAmountWbtc);
        tangEngine.deposit(address(weth),depositAmountWeth);
        vm.stopPrank();
    }

    function depositWBTCAndGetTANG(uint256 _mintTokenWBTCAmount,uint256 _getTANGAmount) public  {
        uint256 mintTokenWBTCAmount = bound(_mintTokenWBTCAmount,0,MAX_DEPOSIT_SIZE);
        uint256 getTANGAmount = bound(_getTANGAmount,0,MAX_DEPOSIT_SIZE);
        vm.prank(user);
        tangEngine.depositAndGetTANG(address(wbtc),mintTokenWBTCAmount,getTANGAmount);
    }

    function depositWETHAndGetTANG(uint256 _mintTokenWETHAmount,uint256 _getTANGAmount) public  {
        uint256 mintTokenWETHAmount = bound(_mintTokenWETHAmount,0,MAX_DEPOSIT_SIZE);
        uint256 getTANGAmount = bound(_getTANGAmount,0,MAX_DEPOSIT_SIZE);
        vm.prank(user);
        tangEngine.depositAndGetTANG(address(weth),mintTokenWETHAmount,getTANGAmount);
    }

    function redeemCollateralForTANG(uint256 _burnTANGAmount) public  {
        uint256 burnTANGAmount = bound(_burnTANGAmount,0,MAX_DEPOSIT_SIZE);
        vm.prank(user);
        tangEngine.redeemCollateralForTANG(address(wbtc),burnTANGAmount);
    }

    function testRedeemColleralWBTC(uint256 _mintTokenWBTCAmount) public  {
        uint256 mintTokenWBTCAmount = bound(_mintTokenWBTCAmount,0,MAX_DEPOSIT_SIZE);
        vm.prank(user);
        tangEngine.redeemCollateral(address(wbtc),mintTokenWBTCAmount);
    }

    function testRedeemColleralWETH(uint256 _mintTokenWETHAmount) public  {
        uint256 mintTokenWETHAmount = bound(_mintTokenWETHAmount,0,MAX_DEPOSIT_SIZE);
        vm.prank(user);
        tangEngine.redeemCollateral(address(wbtc),mintTokenWETHAmount);
    }

    function burnTANG(uint256 _getTANGAmount) public {
        uint256 getTANGAmount = bound(_getTANGAmount,0,MAX_DEPOSIT_SIZE);
        vm.prank(user);
        tangEngine.burnTANG(getTANGAmount);
    }

    function mintTANG(uint256 _getTANGAmount) public {
        uint256 getTANGAmount = bound(_getTANGAmount,0,MAX_DEPOSIT_SIZE);
        vm.prank(user);
        tangEngine.mintTANG(user,getTANGAmount);
    }

    function liquidation(uint256 _mintTokenWETHAmount,uint256 _mintTokenWBTCAmount,uint256 _getTANGAmount) public {
        uint256 getTANGAmount = bound(_getTANGAmount,0,MAX_DEPOSIT_SIZE);
        uint256 debtTANGAmount = bound(_getTANGAmount,0,MAX_DEPOSIT_SIZE);
        uint256 mintTokenWBTCAmount = bound(_mintTokenWBTCAmount,0,MAX_DEPOSIT_SIZE);
        uint256 mintTokenWETHAmount = bound(_mintTokenWETHAmount,0,MAX_DEPOSIT_SIZE);
        

        address user2 = makeAddr("user2");
        //给新的用户user2配置资产 
        vm.startPrank(user2);
        wbtc.mint(user2,mintTokenWBTCAmount);
        wbtc.approve(address(tangEngine),mintTokenWBTCAmount);
        weth.mint(user2,mintTokenWETHAmount);
        weth.approve(address(tangEngine),mintTokenWETHAmount);
        tangEngine.depositAndGetTANG(address(wbtc),mintTokenWBTCAmount,getTANGAmount);
        tangEngine.depositAndGetTANG(address(weth),mintTokenWETHAmount,getTANGAmount);
        vm.stopPrank();
        // user2 替 user1 进行清算
        vm.prank(user2);
        tangEngine.liquidation(user,debtTANGAmount,address(wbtc));
        tangEngine.liquidation(user,debtTANGAmount,address(weth));
    }





    






}