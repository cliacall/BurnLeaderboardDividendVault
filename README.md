# BurnLeaderboardDividendVault

销毁排行榜分红金库 — 税分两池: 80%按销毁权重分红 + 20%奖励前10销毁者

## OpenFour Module

- **类型**: Vault (IOpenFourVault)
- **标签**: `module.vault.burnleaderboard`
- **Solidity**: ^0.8.20
- **依赖**: OpenZeppelin Contracts

## 功能

本合约是 [Flap.sh CA Store](https://flap.sh/bnb/CAstore) 同名 Vault 的 OpenFour 翻版，
可直接集成到 [four.meme](https://four.meme) OpenFour 发射引擎中。

## 合约架构

```
contracts/
├── BurnLeaderboardDividendVault.sol              # 主合约
├── interfaces/
│   ├── IOpenFourVault.sol               # OpenFour Vault 接口
│   ├── ITagDescriptor.sol    # 模块标签接口
│   └── IOpenFourModuleSchema.sol  # 前端表单Schema接口
```

## 部署到 four.meme

1. 访问 https://four.meme/zh-TW/contract/create
2. 上传 `contracts/BurnLeaderboardDividendVault.sol`
3. 填写合约信息并提交审核

## 参考

- Flap CA Store: https://flap.sh/bnb/CAstore
- Four.Meme: https://four.meme
- OpenFour 文档: https://four.meme/docs
