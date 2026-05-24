# voxlue · 声音胶囊

> 第十一届中国高校计算机大赛 · 移动应用创新赛 2026 启迪赛道参赛作品

voxlue 把一段环境声当成一张待显影的相片 —— 你录下来、装裱、给它上一把锁埋下；某天锁的条件满足，灵动岛轻轻提醒你「这里有一张你洗过一次的相」。

一个胶囊系统 · 三把锁（地点 / 时间 / 情绪）· 三个收件人（自己 / 声音圈 / 公开）。

## 现状

**v1 全部 6 份计划已落地、合入 `main`**，并在其上完成了大量 UX / 设计语言深化（截至本次 commit 累计 40+ 个增量 PR）：

| 维度 | 落地 |
|---|---|
| 主功能 | 录音→装裱→埋下→显影→回放 闭环；声音圈共享（CKShare 骨架）；云端 agent 浮现闭环骨架 |
| 设计语言 | P3 Photographic Plate · 暗房黑白胶片美学；纸·墨·朱 八色 + 4 套自定义字体（Crimson Pro / 思源宋 / Space Mono / Caveat）+ FilmPerforations / PhotoCard / NegativeCard / SealStamp 等组件 |
| App 形态 | 四标签：首页（巨大录音键 + 浮现待听 pill + 最近一段预览 + 状态统计 + 每日 prompt）· 样片墙（按时间分段 / 搜索 / contextMenu / swipeActions）· 地图（朱红 pin + PaperCard 详情气泡）· 我（声音圈 + 设置） |
| 仪式感 | 录音呼吸波形 / 朱章 spring 入场 / 朱章状态转场 / 「埋下」盖章仪式 / FrostReveal 显影动效 / 浮现卡霜化入场 |
| 工程 | UI 测试主循环 testRecordBuryPlayMainLoop 始终绿；swift test 108 测例全绿；Worker tsc 全绿；临床措辞合规扫描 |

## 文档怎么读

新加入的同学请从**路线图**读起：

| 文档 | 路径 |
|---|---|
| 架构设计（源头真相） | `docs/superpowers/specs/2026-05-21-voxlue-architecture-design.md` |
| **v1 实现路线图与分工** | `docs/superpowers/plans/2026-05-22-voxlue-v1-roadmap.md` |
| 计划 01 项目骨架与数据层 | `docs/superpowers/plans/2026-05-21-voxlue-01-foundation-data.md` |
| 计划 02–06 详细实现计划 | `docs/superpowers/plans/2026-05-22-voxlue-02..06-*.md` |

路线图记录了 v1 整体回归（§7）、设计语言全面落地（§8）、以及后续 8+ 批多 agent 并行 PR 总账（§9）。

## v1 实现进度

| 计划 | 主责 | 状态 |
|---|---|---|
| 01 项目骨架与数据层 | 协作者 | ✅ 已合入 |
| 02 录音→装裱→回放主循环 | 双轨 | ✅ 已合入 PR #2 |
| 03 TriggerEngine 三把锁 | 双轨 | ✅ 已合入 PR #3 |
| 04 设计系统与液态玻璃 | 前端 | ✅ 已合入 PR #1 |
| 05 声音圈共享 | 双轨 | ✅ 已合入 PR #4 |
| 06 云端 agent 闭环 | 双轨 | ✅ 已合入 PR #5 |

## 工程结构

- `voxule/` —— Xcode 应用工程（iOS 26 / SwiftUI）
  - `voxule/voxule/` —— 视图层 / 壳层 / Dev 工具
  - `voxule/VoxlueWidget/` —— 灵动岛 widget 源文件（Xcode target 待开发者环境新建）
- `VoxlueKit/` —— 本地 SPM 包，三个 library 目标：
  - `VoxlueData` —— 模型层（Capsule / Circle / Lock / 枚举）
  - `VoxlueServices` —— 领域服务（AudioEngine / TriggerEngine / CircleService / AgentGateway / IntelligenceService 等）
  - `VoxlueDesign` —— 设计系统包（tokens / Paper 组件 / Glass chrome / Motion）
- `backend/agent-proxy/` —— Cloudflare Worker serverless 代理（TypeScript）
- `docs/` —— 设计文档与实现计划
- `scripts/check-clinical-words.sh` —— 临床措辞合规扫描

## 构建与测试

包单元测试：

```bash
cd VoxlueKit && swift test
```

App 构建（模拟器，免签名）：

```bash
xcodebuild -project voxule/voxule.xcodeproj -scheme voxule \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  build CODE_SIGNING_ALLOWED=NO
```

UI 测试主循环：

```bash
xcodebuild test -project voxule/voxule.xcodeproj -scheme voxule \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -only-testing:voxuleUITests/voxuleUITests/testRecordBuryPlayMainLoop \
  CODE_SIGNING_ALLOWED=NO
```

CloudKit 真同步需 Apple Developer 账号、在 CloudKit Dashboard 建容器 `iCloud.com.voxlue.app` 并以带 iCloud 能力的 Team 签名。

## DEBUG 体验

设置 → Dev 工具 内可一键种入 8 枚示例胶囊 + 2 个声音圈、手动触发 agent 浮现、重置 cadence、重新看一遍首启引导。仅 DEBUG 构建可见，Release 编译期剥离。

## 仍需在开发者环境收尾

- VoxlueWidget Xcode target 须在 Xcode 新建（源文件已在 `voxule/VoxlueWidget/`）
- `cd backend/agent-proxy && wrangler deploy` —— 部署 serverless 代理后把真实 URL 填入 `voxuleApp.agentProxyURL`
- 真机 + iCloud 账号验证 CKShare 共享 / HealthKit 授权 / 真 agent 联调
- 真 API key 与大模型对接

## 环境

Xcode 26.5 · Swift 6.2 · iOS 26 · SwiftData + CloudKit · Swift Testing · iOS 26 原生玻璃 chrome
