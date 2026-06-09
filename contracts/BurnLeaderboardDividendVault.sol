// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./interfaces/IOpenFourVault.sol";
import "./interfaces/IOpenFourModuleSchema.sol";
import "./interfaces/ITagDescriptor.sol";

/// @title BurnLeaderboardDividendVault — 销毁排行榜分红金库
/// @notice 税分两池: Burn Dividend(80%)按销毁价值权重分红, Leaderboard(20%)奖励前10销毁者
/// @dev DApp销毁: 60%永久黑 hole, 30%按价值权重重新分配
contract BurnLeaderboardDividendVault is IOpenFourVault, IOpenFourModuleSchema, ITagDescriptor {
    struct BurnConfig {
        uint16 burnDividendBps;   // 销毁分红比例 (默认80%=8000bps)
        uint16 leaderboardBps;    // 排行榜比例 (默认20%=2000bps)
        uint8 leaderboardSize;    // 排行榜人数 (默认10)
    }

    struct BurnerInfo {
        uint256 totalBurned;      // 累计销毁价值
        uint256 rewardDebt;
        uint256 lastClaimTime;
    }

    mapping(address => BurnConfig) internal _configs;
    mapping(address => mapping(address => BurnerInfo)) internal _burners;
    mapping(address => uint256) internal _burnDividendPool;   // 80%池
    mapping(address => uint256) internal _leaderboardPool;     // 20%池
    mapping(address => uint256) internal _totalBurned;
    mapping(address => uint256) internal _accRewardPerBurn;
    address internal _fourCore;

    uint256 internal constant MAGNITUDE = 1e18;
    uint256 internal constant BPS_BASE = 10000;

    modifier onlyCore() { require(msg.sender == _fourCore, "!core"); _; }
    error AlreadyInitialized();

    function init(address token, address fourCore, bytes calldata params, string calldata) external {
        if (address(_fourCore) != address(0)) revert AlreadyInitialized();
        _fourCore = fourCore;
        _configs[token] = abi.decode(params, (BurnConfig));
    }

    function onBuy(address, uint256, uint256 payment, uint256, bytes calldata) external onlyCore {
        _distributeTax(msg.sender, payment);
    }

    function onSell(address, uint256, uint256 payment, uint256, bytes calldata) external onlyCore {
        _distributeTax(msg.sender, payment);
    }

    function vaultBalance() external view returns (uint256) {
        return _burnDividendPool[msg.sender] + _leaderboardPool[msg.sender];
    }

    function _distributeTax(address token, uint256 payment) internal {
        BurnConfig storage cfg = _configs[token];
        uint256 burnShare = payment * cfg.burnDividendBps / BPS_BASE;
        uint256 leaderShare = payment - burnShare;
        _burnDividendPool[token] += burnShare;
        _leaderboardPool[token] += leaderShare;
        if (_totalBurned[token] > 0) {
            _accRewardPerBurn[token] += burnShare * MAGNITUDE / _totalBurned[token];
        }
    }

    /// @notice 记录销毁（通过DApp销毁时调用）
    function recordBurn(address token, uint256 burnValue) external {
        BurnerInfo storage b = _burners[token][msg.sender];
        b.totalBurned += burnValue;
        b.lastClaimTime = block.timestamp;
        _totalBurned[token] += burnValue;
        // 60%进黑 hole（实际执行在DApp层）
        // 30%重新分配（此时已经计入totalBurned）
    }

    function claimDividend(address token) external {
        BurnerInfo storage b = _burners[token][msg.sender];
        uint256 pending = b.totalBurned * _accRewardPerBurn[token] / MAGNITUDE - b.rewardDebt;
        if (pending > 0 && pending <= _burnDividendPool[token]) {
            b.rewardDebt += pending;
            _burnDividendPool[token] -= pending;
            payable(msg.sender).transfer(pending);
        }
    }

    function getInitParams() external pure returns (bytes memory) {
        return abi.encode(BurnConfig({burnDividendBps: 8000, leaderboardBps: 2000, leaderboardSize: 10}));
    }

    function moduleEncodeSchema() external pure returns (ModuleEncodeSchema memory) {
        ParamDescriptor[] memory params = new ParamDescriptor[](3);
        params[0] = ParamDescriptor("burnDividendBps", "销毁分红比例(bps)", "80%池的比例", "uint16", false, bytes32(uint256(8000)), bytes32(uint256(0)), bytes32(uint256(10000)));
        params[1] = ParamDescriptor("leaderboardBps", "排行榜比例(bps)", "排行榜池的比例", "uint16", false, bytes32(uint256(2000)), bytes32(uint256(0)), bytes32(uint256(10000)));
        params[2] = ParamDescriptor("leaderboardSize", "排行榜人数", "奖励前N名销毁者", "uint8", false, bytes32(uint256(10)), bytes32(uint256(3)), bytes32(uint256(50)));
        return ModuleEncodeSchema(1, "module.vault.burn-leaderboard", params);
    }

    function descriptor() external pure returns (bytes8 tagId, string memory tag, string memory version) {
        tagId = bytes8(keccak256(bytes("module.vault.burn-leaderboard")));
        tag = "module.vault.burn-leaderboard";
        version = "v1.0.0";
    }
}
