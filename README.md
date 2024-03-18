## StableCoin 稳定币TANG
### 开发框架 Foundry
### SEPOLIA上的合约地址
- TangStableCoin => 0x25C4D40f5057a4F8eef99826cD7cB5C08A75c0B8
- TANGEngine     => 0x08CBce327bAe5cE7a5B7Ac9dD0e014D698dF2948
### 基本参数
1. 支持质押的资产：WBTC 和 WETH
2. 质押资产和TANG的转化比（健康因子）：150% 
3. 质押资产的价格数据源： ChainLink预言机
4. 清算时的额外奖励份额 10%

### 安装依赖库
#### chainLink 预言机依赖
```
 forge install smartcontractkit/chainlink-brownie-contracts  --no-commit
```
#### OpenZeppelin 三方库依赖
```
forge install Openzeppelin/openzeppelin-contracts --no-commit
```
### .env环境文件配置
```
SEPOLIA_RPC_URL=xxxx
SEPOLIA_WALLET_KEY=xxx
SEPOLIA_WALLET=xxx
ANVIL_WALLET_KEY=xxx
ANVIL_WALLET=xxx
ETHERSCAN_API_KEY=xxxx
```
### 完成单元测试 模糊测试
#### 本地anvil环境
```
forge test
```
#### SEPOLIA环境
```
forge test --fork-url $SEPOLIA_RPC_URL --mp test/TANGEngineTest.t.sol
```
#### 获得测试覆盖率
```
forge coverage
```
### 一键部署到SEPOLIA
```
make deploy ARGS="--network sepolia"
```