// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.20;
import {DeployTangStable} from "script/DeployTangStable.s.sol";
import {Test,console} from "forge-std/Test.sol";
import {TANGEngine,TangStableCoin} from "src/TANGEngine.sol";
import {ChainLinkConfig,NetWorkingChainLinkPriceFeed,WERC20Mock,MockV3Aggregator} from "script/ChainLinkConfig.s.sol";
import {NetWorkingConfig,NetWorking} from "script/NetWorkingConfig.s.sol";

contract TANGEngineTest is Test {

    address public user;
    address public admin;

    TANGEngine public tangEngine;
    TangStableCoin public tangStableCoin;
    NetWorkingChainLinkPriceFeed public chainLinkPriceFeed;
    NetWorking public netWorking;
    WERC20Mock public wbtc;
    WERC20Mock public weth;

    uint256 public constant PRICE_DATA_FEED_DECIMALS = 1e8;

    event TANGEngine_DepositToken(address account, address indexed token, uint256 indexed amount);
    event TANGEngine_MintTangStableCoin(address indexed account, uint256 indexed amount);



    function setUp() public {
        (tangEngine, tangStableCoin,chainLinkPriceFeed,netWorking) = new DeployTangStable().run();
        admin = netWorking.walletAddress;
        user = makeAddr("user");

        weth = WERC20Mock(payable(chainLinkPriceFeed.addressWETH));
        wbtc = WERC20Mock(payable(chainLinkPriceFeed.addressWBTC));
    }

    modifier initDeposit() {
        vm.startPrank(user);
        weth.mint(user,1000);
        wbtc.mint(user,2000);
        weth.approve(address(tangEngine),1000);
        wbtc.approve(address(tangEngine),2000);
        vm.stopPrank();
        _;
    }

    function testGetTokenValue() public {

        uint256 btcValue = tangEngine.getTokenValue(chainLinkPriceFeed.addressWBTC,1000);
        uint256 ethValue = tangEngine.getTokenValue(chainLinkPriceFeed.addressWETH,1000);
        console.log("btcValue:", btcValue);
        console.log("ethValue:", ethValue);
        assertGt(btcValue, 0);
        assertGt(ethValue,0);

    }

    function testDeposit() public initDeposit {
        vm.startPrank(user);
        tangEngine.deposit(address(wbtc),1000);
        uint256 tokenBalance  = tangEngine.getUserCollateralAmount(user,address(wbtc));
        assertEq(tokenBalance,1000);
        vm.stopPrank();
        
    }

    function testDepositTokenNotEnough() public initDeposit {
        vm.expectRevert(TANGEngine.TANGEngine_InfficientBalance.selector);
        tangEngine.deposit(address(weth),5000);
    }

    function testDepositAndGetTANG() public initDeposit {
        vm.expectEmit();
        emit TANGEngine_DepositToken(user, address(weth), 300);
        emit TANGEngine_MintTangStableCoin(user, 20000);
        vm.prank(user);
        tangEngine.depositAndGetTANG(address(weth),300,20000);
        
    }

    function testGetCollateralValue() public initDeposit {
        testDeposit();
        uint256 value = tangEngine.getCollateralValue(user);
        console.log("user CollateralValue=",value);
        MockV3Aggregator v3Aggregator = MockV3Aggregator(chainLinkPriceFeed.priceFeedBTC2USD);
        (,int price,,,) = v3Aggregator.latestRoundData();
        uint256 valueGet = (1000 * uint256(price))/ PRICE_DATA_FEED_DECIMALS;
        assertEq(value,valueGet);

    }
}