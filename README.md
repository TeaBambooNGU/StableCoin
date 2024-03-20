## StableCoin 稳定币TANG
### 开发框架 Foundry
### SEPOLIA上的合约地址
- TangStableCoin => 0xff4dc3868025ed2A6dE6a0bBaD99F79468756CA8
- TANGEngine     => 0x25765fa8C6994C17B64770851F33FE24Deb65f7E
### 基本参数
1. 支持质押的资产：WBTC 和 WETH
2. 质押资产和TANG的转化比（健康因子）：150% 
3. 质押资产的价格数据源： ChainLink预言机
4. 清算时的额外奖励份额 10%

### 安装依赖库
#### 一键安装所需依赖（chainLink，OpenZeppelin，forge-std）
```
make install
```
#### chainLink 预言机依赖
```
forge install smartcontractkit/chainlink-brownie-contracts  --no-commit
```
#### OpenZeppelin 三方库依赖
```
forge install Openzeppelin/openzeppelin-contracts --no-commit
```
#### forge-std 依赖
```
forge install foundry-rs/forge-std --no-commit
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