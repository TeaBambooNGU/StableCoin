// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity 0.8.20;

import {Script} from "forge-std/Script.sol";
import {MockV3Aggregator} from "../test/mocks/MockV3Aggregator.sol";
import {VRFCoordinatorV2Interface} from "chainlink-brownie-contracts/contracts/src/v0.8/interfaces/VRFCoordinatorV2Interface.sol";
import {VRFCoordinatorV2Mock} from "chainlink-brownie-contracts/contracts/src/v0.8/mocks/VRFCoordinatorV2Mock.sol";
import {WERC20Mock} from "chainlink-brownie-contracts/contracts/src/v0.8/shared/mocks/WERC20Mock.sol";

struct NetWorkingChainLinkPriceFeed {
    address addressWETH;
    address addressWBTC;
    address priceFeedETH2USD;
    address priceFeedBTC2USD;
}

struct NetWorkingChainLinkVRF {
    address vrfCoordinator;
    address linkToken;
    bytes32 keyHash;
    uint64 subscriptionId;
    uint16 requestConfirmations;
    uint32 callbackGasLimit;
    uint32 numWords;
}

contract ChainLinkConfig is Script {
    NetWorkingChainLinkPriceFeed public activeChainlinkPriceFeed;
    NetWorkingChainLinkVRF public activeChainLinkVRF;
    uint256 public activeDeployOwnerKey;

    address public constant SepoliaWallet = 0xDd7a00B6800db7E458495E37A22c8aea48138a14;

    address public constant ChainLinkSepoliaPriceFeed_ETH_USD = 0x694AA1769357215DE4FAC081bf1f309aDC325306;
    address public constant ChainLinkSepoliaPriceFeed_BTC_USD = 0x1b44F3514812d835EB1BDB0acB33d3fA3351Ee43;
    address public constant ChainLinkSepoliaVRF = 0x8103B0A8A00be2DDC778e6e7eaa21791Cd364625;
    address public constant ChainLinkSepoliaLINK_TOKEN = 0x779877A7B0D9E8603169DdbD7836e478b4624789;
    address public constant SepoliaWETH_ADDRESS = 0xfFf9976782d46CC05630D1f6eBAb18b2324d6B14;
    address public constant SepoliaWBTC_ADDRESS = 0x29f2D40B0605204364af54EC677bD022dA425d03;

    uint8 public constant ETH_USD_DECIMALS = 8;
    uint8 public constant BTC_USD_DECIMALS = 8;
    int256 public constant ETH_USD_INIT_PRICE = 2000e8;
    int256 public constant BTC_USD_INIT_PRICE = 52136e8;
    bytes32 public constant ChainLinkSepoliaVRF_kEYHASH = 0x474e34a077df58807dbe9c96d3c009b23b3c6d0cce433e59bbf5b34f823bc56c;
    uint64 public constant SUBSCRIPTIONID = 9456;
    

    constructor() {
        if (block.chainid == 11155111) {
            activeChainlinkPriceFeed = getSepoliaPriceFeed();
            activeChainLinkVRF = getSepoliaVRF();
        } else if (block.chainid == 31337) {
            activeChainlinkPriceFeed = getAnvilPriceFeed();
            activeChainLinkVRF = getAnvilVRF();
        }
    }

    function getSepoliaPriceFeed() private pure returns (NetWorkingChainLinkPriceFeed memory) {
        NetWorkingChainLinkPriceFeed memory sepoliaPriceFeed = NetWorkingChainLinkPriceFeed({
            priceFeedETH2USD: ChainLinkSepoliaPriceFeed_ETH_USD,
            priceFeedBTC2USD: ChainLinkSepoliaPriceFeed_BTC_USD,
            addressWETH: SepoliaWETH_ADDRESS,
            addressWBTC: SepoliaWBTC_ADDRESS
        });
        return sepoliaPriceFeed;
    }

    function getAnvilPriceFeed() private returns (NetWorkingChainLinkPriceFeed memory) {
        // 如果已经初始化了 就不用再初始化了
        if (activeChainlinkPriceFeed.priceFeedETH2USD != address(0)) {
            return activeChainlinkPriceFeed;
        }
        vm.startBroadcast();
        MockV3Aggregator mockV3 = new MockV3Aggregator(ETH_USD_DECIMALS, ETH_USD_INIT_PRICE);
        address anvilPriceFeedETH2USD = address(mockV3);

        MockV3Aggregator mockV2 = new MockV3Aggregator(BTC_USD_DECIMALS, BTC_USD_INIT_PRICE);
        address anvilPriceFeedBTC2USD = address(mockV2);

        WERC20Mock mockWETH = new WERC20Mock();
        WERC20Mock mockWBTC = new WERC20Mock();
        vm.stopBroadcast();

        NetWorkingChainLinkPriceFeed memory anvilPriceFeed = NetWorkingChainLinkPriceFeed({
            priceFeedETH2USD: anvilPriceFeedETH2USD,
            priceFeedBTC2USD: anvilPriceFeedBTC2USD,
            addressWETH: address(mockWETH),
            addressWBTC: address(mockWBTC)
        });
        return anvilPriceFeed;
    }

    function getSepoliaVRF() private pure returns (NetWorkingChainLinkVRF memory) {
        NetWorkingChainLinkVRF memory netWorkingChainLinkVRF = NetWorkingChainLinkVRF({
            vrfCoordinator: ChainLinkSepoliaVRF,
            linkToken: ChainLinkSepoliaLINK_TOKEN,
            keyHash: ChainLinkSepoliaVRF_kEYHASH,
            subscriptionId: SUBSCRIPTIONID,
            requestConfirmations: 3,
            callbackGasLimit: 1000000,
            numWords: 3
        });
        return netWorkingChainLinkVRF;
    }

    function getAnvilVRF() private returns (NetWorkingChainLinkVRF memory) {

        vm.startBroadcast();
        VRFCoordinatorV2Mock vrfCoordinatorMock = new VRFCoordinatorV2Mock(
            0.25 ether, // 基础费用
            1e6 // 每单位gas需要支付的Link
            );
        vm.stopBroadcast();

        NetWorkingChainLinkVRF memory netWorkingChainLinkVRF = NetWorkingChainLinkVRF({
            vrfCoordinator: address(vrfCoordinatorMock),
            linkToken: address(0),
            keyHash: "aaassaaa",
            subscriptionId: 0,
            requestConfirmations: 3,
            callbackGasLimit: 1000000,
            numWords: 3
        });
        return netWorkingChainLinkVRF;
    }

    function createSubscriptionId(uint256 _deployKey) public returns (uint64 subId) {
        vm.startBroadcast(_deployKey);
        VRFCoordinatorV2Interface vrfCoordinator = VRFCoordinatorV2Interface(activeChainLinkVRF.vrfCoordinator);
        subId = vrfCoordinator.createSubscription();
        vm.stopBroadcast();
    }

    function addConsumer(uint256 _deployKey, address _consumer,uint64 _subscriptionId) public {
        vm.startBroadcast(_deployKey);
        VRFCoordinatorV2Interface vrfCoordinator = VRFCoordinatorV2Interface(activeChainLinkVRF.vrfCoordinator);
        vrfCoordinator.addConsumer(_subscriptionId, _consumer);
        vm.stopBroadcast();
    }

    function getActiveChainlinkPriceFeed() public view returns (NetWorkingChainLinkPriceFeed memory) {
        return activeChainlinkPriceFeed;
    }

    function getActiveChainlinkVRF() public view returns (NetWorkingChainLinkVRF memory) {
        return activeChainLinkVRF;
    }

}
