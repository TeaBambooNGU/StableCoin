// SPDX-License-Identifier: MIT License
pragma solidity ^0.8.20;

import {TangStableCoin} from "./TangStableCoin.sol";
import {AggregatorV3Interface} from "chainlink-brownie-contracts/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {ChainLinkDataEnum} from "./ChainLinkDataEnum.sol";

contract TANGEngine is ReentrancyGuard{

    error TANGEngine_TokensContractddressLengthNotMatch();
    error TANGEngine_TokenNotSupported();
    error TANGEngine_InfficientBalance();
    error TANGEngine_TokenValueNotEnough();
    error TANGEngine_HealthFactorBad();

    address[] public s_tokensContractddress;
    mapping (address tokenAddress => address tokenPriceDataFeedAddress)  public s_tokensPriceDataFeed;
    TangStableCoin public s_tangStableCoin;
    // 用户抵押的资产
    mapping (address account => mapping (address tokenAddress => uint tokenAmount)) public s_userTokenBalance;
    // 用户已经兑换的稳定币数量
    mapping (address account => uint256 totalSupplyTANG) s_userTotalSupplyTANG;

    uint256 public constant PRICE_DATA_FEED_DECIMALS = 10e8;
    uint256 public constant LIQUIDATION_RATIO = 150;
    uint256 public constant LIQUIDATION_PRECISION = 100;

    event TANGEngine_HealthFactorNotGOOD(uint256 indexed tangStableCoinValue, uint256  indexed tokenBTCValue, uint256 indexed tokenETHValue);
    event TANGEngine_DepositToken(address account, address indexed token, uint256 indexed amount);
    event TANGEngine_MintTangStableCoin(address indexed account, uint256 indexed amount);

    
    constructor(address tangStableCoin, address[] memory tokensContractddress,address[] memory tokensPriceDataFeed) {
        if(tokensContractddress.length != tokensPriceDataFeed.length){
            revert TANGEngine_TokensContractddressLengthNotMatch();
        }
        for (uint i = 0; i < tokensContractddress.length; i++) {
            s_tokensPriceDataFeed[tokensContractddress[i]] = tokensPriceDataFeed[i];
        }
        s_tangStableCoin = TangStableCoin(tangStableCoin);
    }

    modifier checkTokenParam(address token, uint256 amount) {
        if(s_tokensPriceDataFeed[token] == address(0)){
            revert TANGEngine_TokenNotSupported();
        }
        if(IERC20(token).balanceOf(msg.sender) < amount){
            revert TANGEngine_InfficientBalance();
        }
        _;
    }

    // 质押BTC/ETH 获得 稳定币 TangStableToken
    function depositAndGetTANG(address token, uint256 amount, uint256 tangAmount) external checkTokenParam(token,amount) nonReentrant {
        
        IERC20(token).transferFrom(msg.sender, address(this), amount);
        s_userTokenBalance[msg.sender][token] += amount;

        _checkIsCanRedeemCollateralForTANG(tangAmount);
        
        s_userTotalSupplyTANG[msg.sender] += tangAmount;
        s_tangStableCoin.mint(msg.sender, tangAmount);

        emit TANGEngine_DepositToken(msg.sender, token, amount);
        emit TANGEngine_MintTangStableCoin(msg.sender, tangAmount);

    }
    // 单纯质押BTC/ETH
    function deposit(address token, uint256 amount) external checkTokenParam(token,amount){
        IERC20(token).transferFrom(msg.sender, address(this), amount);
        s_userTokenBalance[msg.sender][token] += amount;
        emit TANGEngine_DepositToken(msg.sender, token, amount);
    }
    
    // 根据自己的质押物兑换稳定币
    function redeemCollateralForTANG(uint256 tangAmount) external nonReentrant {

        _checkIsCanRedeemCollateralForTANG(tangAmount);

        s_userTotalSupplyTANG[msg.sender] += tangAmount;
        s_tangStableCoin.mint(msg.sender, tangAmount);
        //不抵押只兑换 校验一下系统整体稳定性
        bool good = _checkHealthFactorIsGood();
        if(!good){
            revert TANGEngine_HealthFactorBad();
        }

        emit TANGEngine_MintTangStableCoin(msg.sender, tangAmount);
    }

    //校验能否根据现有资产兑换指定数量的稳定币
    function _checkIsCanRedeemCollateralForTANG(uint256 tangAmount) internal view {
        if((tangAmount + s_userTotalSupplyTANG[msg.sender] * LIQUIDATION_RATIO) / LIQUIDATION_PRECISION >=  _getCollateralValue(msg.sender)){
            revert TANGEngine_TokenValueNotEnough();
        }
    }

    //获得用户的抵押物价值
    function _getCollateralValue(address account) internal view returns (uint256){
        address[] memory tokensContractddress = s_tokensContractddress;
        uint256 btcValue = _getTokenValue(tokensContractddress[uint256(ChainLinkDataEnum.PriceDataFeed.BTC_USD)],s_userTokenBalance[account][tokensContractddress[uint256(ChainLinkDataEnum.PriceDataFeed.BTC_USD)]]);
        uint256 ethValue = _getTokenValue(tokensContractddress[uint256(ChainLinkDataEnum.PriceDataFeed.ETH_USD)],s_userTokenBalance[account][tokensContractddress[uint256(ChainLinkDataEnum.PriceDataFeed.ETH_USD)]]);
        return btcValue + ethValue;
    }
    //校验稳定币系统的健康系数
    function _checkHealthFactorIsGood() internal returns (bool){
        // 省gas
        address[] memory tokensContractddress = s_tokensContractddress;
        uint256 tokenBTCValue = _getTokenValue(tokensContractddress[uint256(ChainLinkDataEnum.PriceDataFeed.BTC_USD)],IERC20(tokensContractddress[0]).balanceOf(address(this)));
        uint256 tokenETHValue = _getTokenValue(tokensContractddress[uint256(ChainLinkDataEnum.PriceDataFeed.ETH_USD)],IERC20(tokensContractddress[1]).balanceOf(address(this)));
        uint256 tangStableCoinValue = s_tangStableCoin.totalSupply();

        if( ((tangStableCoinValue * LIQUIDATION_RATIO) / LIQUIDATION_PRECISION) >= (tokenBTCValue + tokenETHValue)){
            emit TANGEngine_HealthFactorNotGOOD (tangStableCoinValue, tokenBTCValue,tokenETHValue);
            return false;
        }else {
            return true;
        }

    }

    function _getTokenValue(address token, uint256 amount) internal view returns (uint256){
        AggregatorV3Interface priceFeed = AggregatorV3Interface(s_tokensPriceDataFeed[token]);
        (,int price,,,) = priceFeed.latestRoundData();
        uint256 tokenValue = (amount * uint256(price)) / PRICE_DATA_FEED_DECIMALS;
        return tokenValue;
    }



}