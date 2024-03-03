// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.20;
import {DeployTangStable} from "script/DeployTangStable.s.sol";
import {Test,console} from "forge-std/Test.sol";
import {TANGEngine,TangStableCoin} from "src/TANGEngine.sol";
import {ChainLinkConfig,NetWorkingChainLinkPriceFeed,WERC20Mock} from "script/ChainLinkConfig.s.sol";
import {NetWorkingConfig,NetWorking} from "script/NetWorkingConfig.s.sol";
import {AggregatorV3Interface} from "chainlink-brownie-contracts/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";


contract TANGEngineTest is Test {

    address public user;
    address public admin;

    TANGEngine public tangEngine;
    TangStableCoin public tangStableCoin;
    NetWorkingChainLinkPriceFeed public chainLinkPriceFeed;
    NetWorking public netWorking;
    WERC20Mock public wbtc;
    WERC20Mock public weth;

    
    uint256 public constant MINTED_TKOEN_AMOUNT = 1000e18;
    uint256 public constant GET_TANG_AMOUNT = 20000e18;
    uint256 public constant BURN_TANG_AMOUNT = 5000e18;

    uint256 public constant PRICE_DATA_FEED_DECIMALS = 1e8;
    uint256 public constant ADDITIONAL_PRICE_DATA_FEED_PRECISION = 1e10;
    uint256 public constant LIQUIDATION_RATIO = 150;
    uint256 public constant LIQUIDATION_PRECISION = 100;
    uint256 public constant LIQUIDATION_BONUS = 10;
    uint256 public constant MIN_HEALTH_FACTOR = 1e18;
    uint256 public constant FIX_TOKEN_DECIMAL = 1e18;
    uint256 public constant STABLE_COIN_PRICE = 1e18;

    event TANGEngine_DepositToken(address account, address indexed token, uint256 indexed amount);
    event TANGEngine_MintTangStableCoin(address indexed account, uint256 indexed amount);
    event TANGEngine_BurnTANG(address indexed account, uint256 indexed amount);
    event TANGEngine_RedeemCollateral(address account, address indexed token, uint256 indexed amount);
    event TANGEngine_Liquidation(address indexed liquidator, address indexed targetAccount, address indexed tokenaddress, uint256 tokenAmount, uint256 tangDebt);
    





    function setUp() public {
        (tangEngine, tangStableCoin,chainLinkPriceFeed,netWorking) = new DeployTangStable().run();
        admin = netWorking.walletAddress;
        user = makeAddr("user");

        weth = WERC20Mock(payable(chainLinkPriceFeed.addressWETH));
        wbtc = WERC20Mock(payable(chainLinkPriceFeed.addressWBTC));
    }

    modifier beforeDeposit() {
        vm.startPrank(user);
        weth.mint(user,MINTED_TKOEN_AMOUNT);
        wbtc.mint(user,MINTED_TKOEN_AMOUNT);
        weth.approve(address(tangEngine),MINTED_TKOEN_AMOUNT);
        wbtc.approve(address(tangEngine),MINTED_TKOEN_AMOUNT);
        vm.stopPrank();
        _;
    }

    function testGetTokenValue() public {

        uint256 btcValue = tangEngine.getTokenValue(chainLinkPriceFeed.addressWBTC,1000 ether);
        uint256 ethValue = tangEngine.getTokenValue(chainLinkPriceFeed.addressWETH,1000 ether);
        console.log("btcValue:", btcValue);
        console.log("ethValue:", ethValue);
        assertGt(btcValue/1e18, 0);
        assertGt(ethValue/1e18,0);

    }

    function testDepositBTC() public beforeDeposit {
        vm.startPrank(user);
        tangEngine.deposit(address(wbtc),MINTED_TKOEN_AMOUNT);
        uint256 tokenBalance  = tangEngine.getUserCollateralAmount(user,address(wbtc));
        assertEq(tokenBalance,MINTED_TKOEN_AMOUNT);
        vm.stopPrank();
        
    }

    function testDepositTokenNotEnough() public beforeDeposit {
        vm.expectRevert(TANGEngine.TANGEngine_InfficientBalance.selector);
        tangEngine.deposit(address(weth),BURN_TANG_AMOUNT);
    }

    function testDepositWETHAndGetTANG() public beforeDeposit {
        vm.expectEmit();
        emit TANGEngine_DepositToken(user, address(weth), MINTED_TKOEN_AMOUNT);
        emit TANGEngine_MintTangStableCoin(user, GET_TANG_AMOUNT);
        vm.prank(user);
        tangEngine.depositAndGetTANG(address(weth),MINTED_TKOEN_AMOUNT,GET_TANG_AMOUNT);
        
    }

    function testGetCollateralValue() public beforeDeposit {
        testDepositBTC();
        uint256 value = tangEngine.getCollateralValue(user);
        console.log("user CollateralValue=",value);
        AggregatorV3Interface v3Aggregator = AggregatorV3Interface(chainLinkPriceFeed.priceFeedBTC2USD);
        (,int price,,,) = v3Aggregator.latestRoundData();
        uint256 valueGet = (MINTED_TKOEN_AMOUNT * uint(price) * ADDITIONAL_PRICE_DATA_FEED_PRECISION) /FIX_TOKEN_DECIMAL;
        assertEq(value,valueGet);

    }

    function testRedeemCollateralForTANG() public beforeDeposit {
        vm.prank(user);
        tangEngine.depositAndGetTANG(address(wbtc),MINTED_TKOEN_AMOUNT,GET_TANG_AMOUNT);

        vm.expectEmit();
        emit TANGEngine_BurnTANG(user, BURN_TANG_AMOUNT);
        uint256 tokenAmount = _getBTCAmountWhenBurnTANG(BURN_TANG_AMOUNT);
        emit TANGEngine_RedeemCollateral(user, address(wbtc), tokenAmount);

        vm.prank(user);
        tangEngine.redeemCollateralForTANG(address(wbtc),BURN_TANG_AMOUNT);

        console.log("5000 stableCoin redeem collateral",tokenAmount);
        
    }

    function testRedeemColleral() public beforeDeposit {
        testDepositBTC();
        vm.expectEmit();
        emit TANGEngine_RedeemCollateral(user, address(wbtc), MINTED_TKOEN_AMOUNT);
        vm.prank(user);
        tangEngine.redeemCollateral(address(wbtc),MINTED_TKOEN_AMOUNT);
    }

    function testTANGEngine_TANGBalanceNotEnough() public beforeDeposit {
        vm.expectRevert(TANGEngine.TANGEngine_InfficientBalance.selector);
        vm.prank(user);
        tangEngine.redeemCollateral(address(wbtc),MINTED_TKOEN_AMOUNT);
    }

    function testTANGEngine_RedeemCollateralTooMuch() public {
        testDepositWETHAndGetTANG();
        vm.expectRevert(TANGEngine.TANGEngine_RedeemCollateralTooMuch.selector);
        vm.prank(user);
        tangEngine.redeemCollateral(address(weth),900e18);
    }

    function testBurnTANG() public {
        testDepositWETHAndGetTANG();
        vm.expectEmit();
        emit TANGEngine_BurnTANG(user, GET_TANG_AMOUNT);
        vm.prank(user);
        tangEngine.burnTANG(GET_TANG_AMOUNT);
    }

    function testMintTANG() public {
        testDepositBTC();
        vm.expectEmit();
        emit TANGEngine_MintTangStableCoin(user, GET_TANG_AMOUNT);
        vm.prank(user);
        tangEngine.mintTANG(user,GET_TANG_AMOUNT);
    }

    function testTANGEngine_TokenValueNotEnough() public {
        vm.expectRevert(TANGEngine.TANGEngine_TokenValueNotEnough.selector);
        vm.prank(user);
        tangEngine.mintTANG(user,GET_TANG_AMOUNT);
    }

    function testLiquidation() public {
        testDepositWETHAndGetTANG();
        address user2 = makeAddr("user2");
        //给新的用户user2配置资产 
        vm.startPrank(user2);
        wbtc.mint(user2,MINTED_TKOEN_AMOUNT);
        wbtc.approve(address(tangEngine),MINTED_TKOEN_AMOUNT);
        tangEngine.depositAndGetTANG(address(wbtc),MINTED_TKOEN_AMOUNT,GET_TANG_AMOUNT);
        vm.stopPrank();
        // user2 替 user1 进行清算
        testDepositBTC();
        vm.expectEmit();
        uint256 tokenAmount = _getBTCAmountWhenBurnTANG(GET_TANG_AMOUNT);
        emit TANGEngine_Liquidation(user2, user, address(wbtc),tokenAmount , GET_TANG_AMOUNT);
        vm.prank(user2);
        tangEngine.liquidation(user,GET_TANG_AMOUNT,address(wbtc));
    }


    function testGetTokenAmountWhenBurnTANG() public view {
        uint256 value = tangEngine.getTokenAmountWhenBurnTANG(20000 ether,address(wbtc));
        console.log("getTokenAmountWhenBurnTANG= ",value);
    }

    function _getBTCAmountWhenBurnTANG(uint256 tangAmount) private view returns(uint256) {
        uint256 tangValue = ( tangAmount * STABLE_COIN_PRICE * (LIQUIDATION_RATIO-LIQUIDATION_PRECISION)) / (LIQUIDATION_PRECISION * FIX_TOKEN_DECIMAL);
        console.log("tangValue=",tangValue);
        AggregatorV3Interface priceFeed = AggregatorV3Interface(chainLinkPriceFeed.priceFeedBTC2USD);
        (,int price,,,) = priceFeed.latestRoundData();
        uint256 tokenAmount = (tangValue * FIX_TOKEN_DECIMAL) / (uint256(price) * ADDITIONAL_PRICE_DATA_FEED_PRECISION);
        console.log("tangValue=%s price =%s ",tangValue * PRICE_DATA_FEED_DECIMALS,uint256(price));
        console.log("tokenAmount=",tokenAmount);
        return tokenAmount;
    }



}