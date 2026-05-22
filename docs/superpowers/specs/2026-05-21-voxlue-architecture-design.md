# voxlue · 架构设计文档

> 日期：2026-05-21　·　状态：已评审通过，待转实现计划
> 用途：第十一届中国高校计算机大赛 — 移动应用创新赛 2026 启迪赛道参赛作品的架构基线

---

## 1. 产品概述

**一句话定位：** voxlue 把一段环境声当成一张待显影的相片 —— 你录下来、装裱、给它上一把锁埋下；某天锁的条件满足，灵动岛轻轻提醒你「这里有一张你洗过一次的相」。

**产品形态（方向 A + C 合并）：** 一个胶囊系统 · 三把锁。不分模式 —— 每枚「声音胶囊」都带**一把锁**和**一个收件人**，原 PDF 的方向 A（家庭声音记忆）和方向 C（声音情绪疗愈）只是锁与收件人的不同组合，共用同一条「埋下」流程和同一个数据模型。

**方向来源：**
- 方向 A · 家庭声音记忆 → 体现为「声音圈」收件人 + 地点锁。
- 方向 C · 声音情绪疗愈 → 体现为「情绪锁」+ 云端陪伴 agent。
- 方向 B · 城市声音方舟 → 体现为「公开」收件人；架构预留，落地排期 v1.1。

**设计语言：** P3 · Photographic Plate（黑白胶片 / 暗房美学），来自 26 份 UI 偏好调研，得票 42% 胜出。立意「纸的温度，不是屏幕的反光」。

---

## 2. 核心概念与术语

| 术语 | 含义 |
|---|---|
| 声音胶囊 Capsule | 产品的核心对象 = 一段声音 + 一把锁 + 一个收件人 + 元数据 |
| 锁 Lock | 胶囊的解锁条件，三选一：地点锁 / 时间锁 / 情绪锁 |
| 收件人 Recipient | 胶囊给谁：自己 / 声音圈 / 公开（v1.1） |
| 显影 Develop | 锁条件满足、胶囊浮现的过程；也是液态玻璃招牌动效的隐喻 |
| 声音圈 Circle | 用户自建、经邀请加入的小圈子（家人或挚友），圈内互相能听到彼此埋下的胶囊 |
| 陪伴 agent | 贯穿全 App 的云端智能体，看用户状态、主动决策、调用工具行动 |

---

## 3. 约束与关键决策

| 维度 | 决策 | 理由 |
|---|---|---|
| 平台 | iOS 26+，SwiftUI | 液态玻璃原生 API、Foundation Models、最新 ActivityKit 全可用 |
| 团队 | 个人开发，无心理学背景 | 方向 C 走轻量「陪伴」叙事，严禁「治疗/诊断/评估」措辞 |
| 后端 | CloudKit（私有 + 共享 + 公共三库） | Apple 原生、零服务器、自带共享能力 |
| 数据层 | SwiftData + CloudKit 自动镜像 | 代码最少、最现代；共享用 SwiftData 原生 sharing |
| App 模式 | MV（SwiftUI + @Observable），不用 MVVM / TCA | 个人开发，给每个 view 套 ViewModel 是纯负担 |
| 单一真相源 | SwiftData 本地库 | 离线优先；UI 用 @Query 直接读 |
| 情绪锁机制 | 主动浮现，由云端 agent 判断 | 不读体征做规则判断，让 agent 权衡 |
| agent 角色 | 全 App 陪伴 agent | 深度融合：浮现 / 埋下建议 / 对话回顾 / 故事集 |
| agent 推理位置 | 云端大模型，但经端侧脱敏闸门 | 原始健康数据永不出设备（PIPL 合规） |
| agent v1 程度 | 轻量 + 完整闭环 | 闭环跑通即可，不追求工具集满 |
| 液态玻璃 | 方案 B：导航层玻璃 + 显影招牌时刻 | 玻璃只在 chrome，纸只在内容；不破坏暗房立意 |
| 公开层 | 架构预留，落地 v1.1 | 内容审核是上架硬性要求；冷启动 ROI 低 |

---

## 4. 系统架构

六层分层架构，上层只依赖下层，下层不认识上层。

```
┌─ App 壳层 ──────── 入口 · 场景 · 深链/通知路由 · 依赖装配
├─ 功能模块层 ────── 样片墙 · 地图 · 埋下 · 胶囊详情/回放 · 声音圈 · 我
│                    （SwiftUI + @Observable）
├─ 设计系统层 ────── 设计 tokens · 暗房纸感控件 · 液态玻璃导航层 · 显影动效
├─ 领域服务层 ────── CapsuleStore · TriggerEngine · AudioEngine · CircleService
│                    · AgentGateway · SignalDistiller · IntelligenceService
├─ 数据层 ────────── SwiftData 模型 + ModelContainer · CloudKit 镜像 · CKShare
│                    · PublicCapsuleService（v1.1）
└─ 平台能力层 ────── CoreLocation · ActivityKit · AVFoundation · HealthKit
                     · FoundationModels · CloudKit
```

**SPM 本地包划分（个人开发，刻意克制，只切 3 个）：**
- `VoxlueDesign` —— 设计系统层全部内容。
- `VoxlueData` —— 数据层：SwiftData 模型、ModelContainer 配置、CloudKit 配置、CircleService、PublicCapsuleService。
- `VoxlueServices` —— 领域服务层其余服务。
- 功能视图与 App 壳层直接放 App target。

**原则：** 平台能力层每个能力都包一层 wrapper（协议 + 真实实现 + 假实现），让 SwiftUI 预览和单元测试能注入替身，不必真的跑围栏 / 联网。

---

## 5. 数据模型（SwiftData）

四个实体。`Lock` 是 Codable 枚举，作为 Capsule 的一个属性存，不单独建表。

### Capsule · 声音胶囊（@Model，核心实体）
| 字段 | 类型 | 说明 |
|---|---|---|
| id | UUID | |
| title | String | 端侧大模型可代写 |
| audioData | Data | `@Attribute(.externalStorage)`，CloudKit 镜像时自动变 CKAsset |
| duration | TimeInterval | 15s – 3min，用户自由定 |
| waveform | [Float] | 预算好的声纹采样，绘制用，避免每次解码音频 |
| state | CapsuleState | 生命周期枚举，见状态机 |
| lock | Lock | Codable 枚举 |
| recipient | Recipient | 自己 / 声音圈 / 公开 |
| circleID | UUID? | recipient = 声音圈 时指向 Circle |
| authorID / authorName | String | 谁埋的，圈内显示「奶奶」 |
| latitude / longitude / placeName | Double? / String? | 录制地点 |
| weather / tags / note | String? / [String] / String? | 片基上的小字 |
| createdAt / openedAt | Date / Date? | |

### Lock · 锁（Codable 枚举）
- `.place(latitude, longitude, radius, placeName)` —— 地点锁
- `.date(Date)` —— 时间锁
- `.mood(notBefore: Date?)` —— 情绪锁，主动浮现

### Circle · 声音圈（@Model）
`id` · `name` · `ownerID` · `createdAt` · `members: [CircleMember]`。是 CKShare 的共享单元。

### CircleMember（@Model）
`name` · `userRecordID` · `role`（owner / member）· `joinedAt`。

### CapsuleState · 显影状态机
```
（录音 + 装裱）
   └─▶ buried 已埋下·潜伏
          └─（锁条件满足）─▶ developing 显影中·灵动岛 + 霜化动效
                                  └─（用户看到）─▶ developed 已显影·等你听
                                                       └─（播放）─▶ opened 已开启
```
三把锁都汇到这一条线；圈内胶囊与自己的胶囊走完全一样的状态机。

### CloudKit 镜像约束（模型定义须遵守）
- 所有属性可选或带默认值。
- 不使用 `@Attribute(.unique)`（CloudKit 不支持唯一约束）。
- 所有关系必须可选。

---

## 6. 三把锁与触发引擎

`TriggerEngine` 是 App 的心脏，是纯后台服务，**不依赖任何 UI 状态** —— 因为它要在三种执行上下文里都能正确工作：① 前台（App 开着）② 被地理围栏唤醒 ③ 后台任务（BGTaskScheduler）。它拥有显影状态机，并对外暴露 `surfaceCapsule(id)`。

### 地点锁
- 机制：CoreLocation 地理围栏（`CLCircularRegion` 区域监听）。
- **硬约束：iOS 一个 App 最多同时监听 20 个围栏。** TriggerEngine 内含 `GeofenceScheduler`，永远只把「离用户最近的 20 个」装进系统，用户移动时（significant location change）重新排序轮换。这是此类 App 最经典的坑，必须一开始就设计进去。
- 圈内胶囊同步到本机后，一视同仁地参与围栏排队。

### 时间锁
- 机制：注册本地日历通知（`UNCalendarNotificationTrigger`）—— 保证 App 没开也能提醒。
- 兜底：App 启动 / 后台刷新时再扫一遍过期胶囊，防通知被划掉或未触发。

### 情绪锁
- 机制：「主动浮现」。BGTaskScheduler 在安静时段唤醒 AgentGateway → 走 agent 闭环（见 §7）由 agent 判断是否浮现、浮现哪一枚。
- 静音架：情绪胶囊永远可在 App 内手动打开。
- 频率用户可调（轻轻地 / 偶尔 / 关）。**全程不读体征做规则判断、不打分。**

---

## 7. 云端 Agent 架构

**角色：** 全 App 陪伴 agent。看用户状态、主动决策、调用工具行动。

### 数据流（三段）

**① 设备内 —— 信号采集与脱敏**
- 信号源：HealthKit（`HKStateOfMind` 心情记录、HRV、静息心率、睡眠）+ App 上下文（最近埋/听、粗粒度位置）。
- `SignalDistiller`（端侧脱敏闸门）把原始数据压成一个抽象、不可识别的 `StateDigest`，例：`{ 紧绷度:偏高, 睡眠:差, 可用平静胶囊:4, 距上次浮现:9天 }`。可借助端侧 Foundation Models 辅助。

**网络边界：只有 `StateDigest` 越过 —— 原始健康数据永不出设备。**

**② 云端 —— voxlue agent**
- 云端大模型（Claude / GPT 等），多步推理。
- 输入：`StateDigest` + 非敏感上下文（胶囊库元数据、地名）。
- 工具集（MCP 式）：`surfaceCapsule()` · `searchCapsules()` · `composeStory()` · `draftTitle()` · `adjustCadence()`。

**③ 设备内 —— 执行**
- `AgentGateway` 接住工具调用，派发给本地服务（TriggerEngine 显影、CapsuleStore 读写、起灵动岛），结果回传 agent，必要时继续下一轮。

### agent 密钥中转服务
客户端不能内嵌大模型 API key。需一个**极薄的无状态代理**（一个 serverless 函数即可，无数据库），持有 key 并转发请求。这是 v1 唯一的自建服务端组件。

### 四个融合点
情绪浮现（替代写死规则）· 埋下建议（标题/标签/选锁）· 对话式回顾（自然语言找胶囊）· 家人故事集（圈内多段声音编成一辑）。

### 隐私与合规边界
- 原始健康数据不出设备；云端只见抽象摘要。
- 定位是「陪你」不是「诊断你」；文案、过审、答辩严禁「治疗 / 评估 / 改善症状」。
- 健康数据使用须显式授权 + 清晰隐私说明。

---

## 8. CloudKit 同步与共享

SwiftData 是本地唯一真相源，离线照常用；CloudKit 后台机会性同步。三条路：

- **私有路** —— 自己的胶囊（所有情绪锁、自己的时间/地点锁）。SwiftData 自动镜像到 CloudKit **私有库**，零同步代码，跨用户自有设备同步。
- **共享路** —— 声音圈。经 **CKShare** 共享：圈主建圈生成共享链接 → iMessage/链接发出 → 受邀者点击接受 → 圈与圈内胶囊进入其**共享库**。音频走 CKAsset 同步。
- **公共路（v1.1）** —— 公开胶囊存 CloudKit **公共库**。SwiftData 的自动镜像不覆盖公共库，故走单独的原生 CloudKit 路径 `PublicCapsuleService`（`CKQuery`，支持按位置查「附近的公开胶囊」）。

### 声音圈邀请流程
圈主建「声音圈」→ 生成 CKShare 链接 → iMessage / 链接发出 → 受邀者点击接受 → 圈 + 胶囊进入其共享库。不依赖 Apple 家人共享。

### 触发方式差异（重要）
- 私有 / 圈内胶囊：靠地理围栏（数量少，20 个够用）。
- 公开胶囊：可能成千上万，**不逐个设围栏**，靠「到某处时查附近」的位置查询发现。

### 四个必须设计进去的点
1. 模型遵守 CloudKit 镜像约束（见 §5）。
2. **收件人埋下时定死** —— 一枚胶囊是私有/圈内/公开在装裱时选定，之后不可改；CloudKit 跨库搬记录很麻烦，v1 不做。
3. **离线优先** —— 没网也能录、埋、听，CloudKit 慢慢追。
4. **共享兜底** —— v1 用 SwiftData 原生共享；若某边角不稳，`CircleService` 这层把它隔离，可单独退回手写 CKShare，不波及其它。

---

## 9. 前端 / 液态玻璃层

`VoxlueDesign` 包内含四块：
- **设计 tokens** —— 纸·墨·朱八色、字阶、圆角、暖色阴影。
- **暗房纸感控件** —— 相片 / 负片 / 朱章 / 批注 / 纸卡。内容层永远是纸。
- **液态玻璃导航层** —— 标签栏、sheet、灵动岛、浮动控制，用 iOS 26 原生 `.glassEffect` / `GlassEffectContainer`，做暖色 tint（偏纸奶油色），不用冷蓝科技玻璃。
- **显影动效** —— 霜化开的招牌转场。胶囊 `buried → developing` 时播放，是 UI 与领域状态机的接缝。

**方案 B 原则：** 玻璃只在「手指要操作的层」，纸只在「要被回忆的东西」。液态玻璃被认真用上（拿下「显影」核心隐喻），暗房纸感立意不被破坏。

**字体栈：** Crimson Pro（display，斜体）· Noto Serif SC 思源宋（中文）· Space Mono（元数据）· Caveat（朱红手写批注）。

**文案语气：** 系统是一个安静的、旧派的冲洗师。不说「录音」说「冲一张」，不说「保存」说「定影」。

---

## 10. 隐私、合规与内容安全

- **健康数据最小化** —— 端侧脱敏闸门，原始数据不出设备；显式授权 + 隐私说明。
- **无医疗声明** —— 全产品定位「陪伴」，规避临床措辞。
- **位置粗粒度** —— 公开胶囊不允许精确定位到家。
- **公开层内容审核（v1.1 随公开层落地）** —— App Store 对 UGC 的硬性要求：内容过滤、举报、屏蔽用户、24 小时内处理举报。

---

## 11. MVP 范围

| 档位 | 内容 |
|---|---|
| **v1 核心 · 必做** | 录音→装裱→显影→回放 主循环；三把锁（地点/时间/情绪）；样片墙 + 地图；灵动岛显影提醒；声音圈（建圈/邀请/共享）；云端 agent 闭环（脱敏闸门→agent→显影）；HealthKit 信号接入；液态玻璃导航 + 显影动效 |
| **v1 加分 · 有时间就做** | 端侧大模型自动标题/标签；家人故事集 composeStory；对话式回顾；agent 主动埋下建议；空间音频回放 |
| **v1.1+ · 架构预留** | 公开层（公共库发现 + 地图热力 + 发布）；内容审核/举报/屏蔽；圈内身份精细权限 |

v1 核心做完，方向 A、C 即完整，故事讲得通、demo 演得出。公开层架构已留位（`recipient.public`、`PublicCapsuleService` 接口），v1.1 接上不返工。

---

## 12. 模块与服务清单

**SPM 包：** `VoxlueDesign` · `VoxlueData` · `VoxlueServices`。功能视图 + 壳层在 App target。

**领域服务：**
| 服务 | 职责 |
|---|---|
| CapsuleStore | 胶囊增删改查，封装 ModelContext 写操作 |
| TriggerEngine | 三把锁判定 + 显影状态机；含 GeofenceScheduler |
| AudioEngine | 录音、播放、声纹采样、（v1 加分）空间音频 |
| CircleService | 声音圈：建圈、CKShare 邀请、共享同步；隔离共享实现 |
| PublicCapsuleService | 公开胶囊原生 CloudKit 读写（v1.1） |
| AgentGateway | 构建 agent 请求、接收并派发工具调用、循环 |
| SignalDistiller | 端侧脱敏闸门，HealthKit 原始数据 → StateDigest |
| IntelligenceService | 端侧 Foundation Models：脱敏闸门辅助、离线兜底、自动标题 |
| NotificationService | 本地通知调度（时间锁） |

---

## 13. 关键风险

| 风险 | 应对 |
|---|---|
| SwiftData 原生共享成熟度不足 | CircleService 隔离，可单退回手写 CKShare |
| 地理围栏 20 上限 | GeofenceScheduler 就近轮换，一开始即设计 |
| agent 中转服务运维 | 选无状态 serverless，无数据库，运维成本趋零 |
| 健康数据合规（PIPL / App Store） | 端侧脱敏闸门；原始数据不出设备；显式授权 |
| 公开层内容审核负担 | 排期 v1.1，架构留位，不进 v1 |
| 个人开发工作量 | 严守 MVP 三档；v1 加分项可砍 |

---

## 14. 下一步

转入 writing-plans，按 §11 的 v1 核心档拆分实现计划。建议拆分顺序：数据层与模型 → 录音/装裱/回放主循环 → TriggerEngine 三把锁 → 设计系统与液态玻璃 → 声音圈共享 → agent 闭环。
