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
    error TANGEngine_TANGBalanceNotEnough();
    error TANGEngine_InfficientBalance();
    error TANGEngine_TokenValueNotEnough();
    error TANGEngine_HealthFactorBad();
    error TANGEngine_InvalidAmount();
    error TANGEngine_RedeemCollateralTooMuch();

    address[] public s_tokensContractddress;
    mapping (address tokenAddress => address tokenPriceDataFeedAddress)  public s_tokensPriceDataFeed;
    TangStableCoin public s_tangStableCoin;
    // 用户抵押的资产
    mapping (address account => mapping (address tokenAddress => uint tokenAmount)) public s_userTokenBalance;
    // 用户已经兑换的稳定币数量
    mapping (address account => uint256 totalSupplyTANG) s_userTotalSupplyTANG;

    uint256 public constant PRICE_DATA_FEED_DECIMALS = 1e8;
    uint256 public constant LIQUIDATION_RATIO = 150;
    uint256 public constant LIQUIDATION_PRECISION = 100;

    event TANGEngine_HealthFactorNotGOOD(uint256 indexed tangStableCoinValue, uint256  indexed tokenBTCValue, uint256 indexed tokenETHValue);
    event TANGEngine_DepositToken(address account, address indexed token, uint256 indexed amount);
    event TANGEngine_MintTangStableCoin(address indexed account, uint256 indexed amount);
    event TANGEngine_RedeemCollateral(address account, address indexed token, uint256 indexed amount);
    event TANGEngine_BurnTANG(address indexed account, uint256 indexed amount);
    event TANGEngine_Liquidation(address indexed liquidator, address indexed targetAccount, address indexed tokenaddress, uint256 tokenAmount, uint256 tangDebt);

    
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

    modifier checkTANGParam(uint256 tangAmount) {
        if(tangAmount <= 0){
            revert TANGEngine_InvalidAmount();
        }
        if(tangAmount > s_tangStableCoin.balanceOf(msg.sender)){
            revert TANGEngine_TANGBalanceNotEnough();
        }
        _;
    }

    // 质押BTC/ETH 获得 稳定币 TangStableToken
    function depositAndGetTANG(address token, uint256 amount, uint256 tangAmount) external checkTokenParam(token,amount) nonReentrant {
        
        IERC20(token).transferFrom(msg.sender, address(this), amount);
        s_userTokenBalance[msg.sender][token] += amount;

        _checkIsCanMintTANG(msg.sender,tangAmount);
        
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

    // 用稳定币赎回抵押物
    function redeemCollateralForTANG(address tokenAddress, uint256 tangAmount) external checkTANGParam(tangAmount) nonReentrant {

        uint256 tokenAmount = _getTokenAmountWhenBurnTANG(tangAmount,tokenAddress);
        
        _burnTANG(msg.sender, tangAmount);
        //赎回抵押物
        IERC20(tokenAddress).transfer(msg.sender, tokenAmount);
        s_userTokenBalance[msg.sender][tokenAddress] -= tokenAmount;

        //赎回抵押物 需要校验一下系统整体稳定性
        bool good = _checkHealthFactorIsGood();
        if(!good){
            revert TANGEngine_HealthFactorBad();
        }
        emit TANGEngine_BurnTANG(msg.sender, tangAmount);
        emit TANGEngine_RedeemCollateral(msg.sender, tokenAddress, tokenAmount);

    }
    //单纯赎回抵押物
    function redeemCollateral(address tokenAddress, uint256 tokenAmount)  nonReentrant external {

        if(s_tokensPriceDataFeed[tokenAddress] == address(0)){
            revert TANGEngine_TokenNotSupported();
        }
        if(s_userTokenBalance[msg.sender][tokenAddress] < tokenAmount){
            revert TANGEngine_TokenValueNotEnough();
        }

        s_userTokenBalance[msg.sender][tokenAddress] -= tokenAmount;
        uint256 tokenValue = _getCollateralValue(msg.sender);

        if((s_userTotalSupplyTANG[msg.sender] * LIQUIDATION_RATIO) / LIQUIDATION_PRECISION >= tokenValue){
            revert TANGEngine_RedeemCollateralTooMuch();
        }
        IERC20(tokenAddress).transfer(msg.sender, tokenAmount);

        emit TANGEngine_RedeemCollateral(msg.sender, tokenAddress, tokenAmount);
    }

    //销毁用户自己的稳定币
    function burnTANG(uint256 tangAmount) external checkTANGParam(tangAmount) nonReentrant {
        _burnTANG(msg.sender, tangAmount);
        emit TANGEngine_BurnTANG(msg.sender, tangAmount);
    }

    //铸造稳定币
    function MintTANG(address account, uint256 tangAmount) external {
        _checkIsCanMintTANG(account,tangAmount);

        s_userTotalSupplyTANG[account] += tangAmount;
        s_tangStableCoin.mint(account, tangAmount);
        //不抵押只铸造 需要校验一下系统整体稳定性
        bool good = _checkHealthFactorIsGood();
        if(!good){
            revert TANGEngine_HealthFactorBad();
        }

        emit TANGEngine_MintTangStableCoin(account, tangAmount);
    }

    /**
     * 清算功能
     * @param account 被清算人的账户
     * @param tangDebt 清算者解决的稳定币债务(清算者自己提供的稳定币)
     * @param tokenAddress 清算的抵押资产
     */
    function liquidation(address account, uint256 tangDebt, address tokenAddress) external checkTANGParam(tangDebt) nonReentrant{

        uint256 tokenAmount = _getTokenAmountWhenBurnTANG(tangDebt,tokenAddress);
        _burnTANG(msg.sender, tangDebt);
        
        
        //将被清算者的抵押物 转给清算者
        if(s_userTokenBalance[account][tokenAddress] < tokenAmount){
            revert TANGEngine_TokenValueNotEnough();
        }
        
        s_userTokenBalance[account][tokenAddress] -= tokenAmount;
        IERC20(tokenAddress).transferFrom(address(this), msg.sender, tokenAmount);
        

        //清算完以后 需要校验一下系统整体稳定性
        bool good = _checkHealthFactorIsGood();
        if(!good){
            revert TANGEngine_HealthFactorBad();
        }

        emit TANGEngine_Liquidation(msg.sender, account, tokenAddress, tokenAmount, tangDebt);
    }



    function _burnTANG(address owner , uint256 tangAmount) internal {
        s_userTotalSupplyTANG[owner] -= tangAmount;
        s_tangStableCoin.burnFrom(owner, tangAmount);
    }
    /**
     * 计算销毁的稳定币能获得的抵押资产数量
     * @param tangAmount 销毁的稳定币数量(要偿还的债务)
     * @param tokenAddress 想获得的抵押资产
     */
    function _getTokenAmountWhenBurnTANG(uint256 tangAmount, address tokenAddress) internal view returns (uint256){
        uint256 tangValue = ( tangAmount * (LIQUIDATION_RATIO-LIQUIDATION_PRECISION)) / LIQUIDATION_PRECISION;

        AggregatorV3Interface priceFeed = AggregatorV3Interface(s_tokensPriceDataFeed[tokenAddress]);
        (,int price,,,) = priceFeed.latestRoundData();

        uint256 tokenAmount = (tangValue * PRICE_DATA_FEED_DECIMALS) / uint256(price);
        return tokenAmount;
    }


    /**
     * 校验能否根据用户现有抵押资产兑换指定数量的稳定币
     * @param account 用户地址
     * @param tangAmount 需要兑换的稳定币数量
     */
    function _checkIsCanMintTANG(address account, uint256 tangAmount) internal view {
        if((tangAmount + s_userTotalSupplyTANG[account] * LIQUIDATION_RATIO) / LIQUIDATION_PRECISION >=  _getCollateralValue(account)){
            revert TANGEngine_TokenValueNotEnough();
        }
    }

    // /**
    //  * 校验提供的稳定币数量能否赎回用户的抵押资产
    //  * @param account 用户地址
    //  * @param tangAmount 稳定币数量
    //  */
    // function _checkIsCanRedeemCollateralForTANG(address account, uint256 tangAmount) internal view {
    //     if((tangAmount * LIQUIDATION_RATIO) / LIQUIDATION_PRECISION >=  _getCollateralValue(account)){
    //         revert TANGEngine_TokenValueNotEnough();
    //     }
    // }

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

    function getTokenValue(address token, uint256 amount) external view returns (uint256){
        return _getTokenValue(token,amount);
    }



}