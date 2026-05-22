# voxlue · 声音胶囊

> 第十一届中国高校计算机大赛 · 移动应用创新赛 2026 启迪赛道参赛作品

voxlue 把一段环境声当成一张待显影的相片 —— 你录下来、装裱、给它上一把锁埋下；某天锁的条件满足，灵动岛轻轻提醒你「这里有一张你洗过一次的相」。

一个胶囊系统 · 三把锁（地点 / 时间 / 情绪）· 三个收件人（自己 / 声音圈 / 公开）。

## 文档怎么读

新加入的同学请从**路线图**读起：

| 文档 | 路径 |
|---|---|
| 架构设计（源头真相） | `docs/superpowers/specs/2026-05-21-voxlue-architecture-design.md` |
| **v1 实现路线图与分工** | `docs/superpowers/plans/2026-05-22-voxlue-v1-roadmap.md` |
| 计划 01 项目骨架与数据层 | `docs/superpowers/plans/2026-05-21-voxlue-01-foundation-data.md` |
| 计划 02–06 详细实现计划 | `docs/superpowers/plans/2026-05-22-voxlue-02..06-*.md` |

路线图定义了**计划地图、双轨分工、冻结的接口契约**。前端轨与协作者轨据此并行开工、互不阻塞。

## 进度

| 计划 | 主责 | 状态 |
|---|---|---|
| 01 项目骨架与数据层 | 协作者 | ✅ 已完成（合入 main） |
| 02 录音→装裱→回放主循环 | 双轨 | 📋 待执行 |
| 03 TriggerEngine 三把锁 | 双轨 | 📋 待执行 |
| 04 设计系统与液态玻璃 | 前端 | 📋 待执行 |
| 05 声音圈共享 | 双轨 | 📋 待执行 |
| 06 云端 agent 闭环 | 双轨 | 📋 待执行 |

## 工程结构

- `voxule/` —— Xcode 应用工程（iOS 26 / SwiftUI）
- `VoxlueKit/` —— 本地 SPM 包，三个 library 目标：`VoxlueData`（✅）· `VoxlueServices` · `VoxlueDesign`
- `docs/` —— 设计文档与实现计划

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

CloudKit 真同步需 Apple Developer 账号、在 CloudKit Dashboard 建容器 `iCloud.com.voxlue.app` 并以带 iCloud 能力的 Team 签名。

## 环境

Xcode 26.5 · Swift 6.2 · iOS 26 · SwiftData + CloudKit · Swift Testing
