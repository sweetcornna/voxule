#if DEBUG
import Foundation
import SwiftData
import VoxlueData
import VoxlueServices

/// 仅 DEBUG 构建可用 —— 在 App 内一键种入丰富示例数据，让前端不用真录音、真共享、真后台也能
/// 在样片墙 / 地图 / 我 各页看到真实内容。
/// 设计原则：不依赖任何真音频文件（audioData 留空），保证可在任意模拟器上跑。
/// 时间锁 / 地点锁 / 情绪锁、各 CapsuleState、各 recipient 都覆盖到。
enum DevSampleData {

    /// 装入一组示例胶囊 + 声音圈到当前 ModelContext。
    /// 已存在的数据不动 —— 多次点击会累积，按需用 `wipe()` 清空。
    static func seedAll(into context: ModelContext) {
        let circles = sampleCircles()
        for circle in circles { context.insert(circle) }
        let mineCircleID = circles.first?.id
        for capsule in sampleCapsules(circleID: mineCircleID) {
            context.insert(capsule)
        }
        try? context.save()
    }

    /// 清掉本地全部 `Capsule` / `Circle` / `CircleMember`。
    static func wipe(context: ModelContext) {
        try? context.delete(model: VoxlueData.Capsule.self)
        try? context.delete(model: VoxlueData.Circle.self)
        try? context.delete(model: VoxlueData.CircleMember.self)
        try? context.save()
    }

    /// 八枚胶囊 —— 覆盖三种锁、四种状态、两种 recipient。
    static func sampleCapsules(circleID: UUID? = nil) -> [VoxlueData.Capsule] {
        let now = Date()
        let waveform = FakeAudioRecording.fakeWaveform
        return [
            // buried · 情绪锁 · 给自己
            VoxlueData.Capsule(
                title: "外婆喊吃饭",
                waveform: waveform,
                state: .buried,
                lock: .mood(notBefore: nil),
                recipient: .me,
                createdAt: now.addingTimeInterval(-60 * 60 * 24 * 7)
            ),
            // buried · 时间锁（一年后）· 给自己
            VoxlueData.Capsule(
                title: "给一年后的自己",
                waveform: waveform,
                state: .buried,
                lock: .date(now.addingTimeInterval(60 * 60 * 24 * 365)),
                recipient: .me,
                createdAt: now.addingTimeInterval(-60 * 60 * 3)
            ),
            // buried · 地点锁 · 给声音圈
            VoxlueData.Capsule(
                title: "海边那段笑声",
                waveform: waveform,
                state: .buried,
                lock: .place(
                    latitude: 22.3193, longitude: 114.1694,
                    radius: 200, placeName: "维多利亚港"
                ),
                recipient: circleID == nil ? .me : .circle,
                circleID: circleID,
                createdAt: now.addingTimeInterval(-60 * 60 * 24 * 30)
            ),
            // developing · 情绪锁 · 给自己（试浮现卡）
            VoxlueData.Capsule(
                title: "雨夜的录音",
                waveform: waveform,
                state: .developing,
                lock: .mood(notBefore: nil),
                recipient: .me,
                createdAt: now.addingTimeInterval(-60 * 60 * 24 * 14)
            ),
            // developed · 时间锁（已到期）· 给自己
            VoxlueData.Capsule(
                title: "三个月前的你",
                waveform: waveform,
                state: .developed,
                lock: .date(now.addingTimeInterval(-60 * 60 * 24)),
                recipient: .me,
                createdAt: now.addingTimeInterval(-60 * 60 * 24 * 90)
            ),
            // opened · 情绪锁 · 给自己
            VoxlueData.Capsule(
                title: "深夜的电话",
                waveform: waveform,
                state: .opened,
                lock: .mood(notBefore: nil),
                recipient: .me,
                createdAt: now.addingTimeInterval(-60 * 60 * 24 * 60)
            ),
            // buried · 情绪锁 · 给声音圈
            VoxlueData.Capsule(
                title: "周末家庭聚餐",
                waveform: waveform,
                state: .buried,
                lock: .mood(notBefore: nil),
                recipient: circleID == nil ? .me : .circle,
                circleID: circleID,
                createdAt: now.addingTimeInterval(-60 * 60 * 12)
            ),
            // buried · 地点锁 · 给自己
            VoxlueData.Capsule(
                title: "上学路上",
                waveform: waveform,
                state: .buried,
                lock: .place(
                    latitude: 39.9042, longitude: 116.4074,
                    radius: 150, placeName: "故宫附近"
                ),
                recipient: .me,
                createdAt: now.addingTimeInterval(-60 * 60 * 24 * 5)
            ),
        ]
    }

    /// 两个示例声音圈。
    static func sampleCircles() -> [VoxlueData.Circle] {
        [
            VoxlueData.Circle(name: "家", ownerID: "me"),
            VoxlueData.Circle(name: "大学室友", ownerID: "me"),
        ]
    }
}
#endif
