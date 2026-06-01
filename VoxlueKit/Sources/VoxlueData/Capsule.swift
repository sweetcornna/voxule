import Foundation
import SwiftData

/// 声音胶囊 —— 产品的核心实体。
/// CloudKit 镜像约束：所有属性可选或带默认值；无 `@Attribute(.unique)`；关系可选。
@Model
public final class Capsule {
    public var id: UUID = UUID()
    public var title: String = ""

    /// 音频以外部文件存储，CloudKit 镜像时自动变 CKAsset。
    @Attribute(.externalStorage) public var audioData: Data?

    public var duration: TimeInterval = 0
    /// 预算好的声纹采样，绘制用，避免每次解码音频。
    public var waveform: [Float] = []

    public var state: CapsuleState = CapsuleState.buried

    /// Lock 以 JSON 编码后存为 Data。SwiftData 无法可靠持久化「带关联值的 Codable
    /// 枚举」—— 直接存 `Lock` 会在二次保存时触发 Core Data「required value」校验失败。
    /// 对外 API 不变，仍是 `capsule.lock`。
    private var lockData: Data = Capsule.encode(.mood(notBefore: nil))

    /// 锁的种类，与 `lockData` 同步持久化。两个作用：
    /// 1) 即便 payload 解码失败也绝不丢失锁的「类型」（D11：不把定时/地点锁悄悄
    ///    降级成随时可浮现的情绪锁）；
    /// 2) `lockKind` 高频读取（样片墙 / 地图 / reconcile / 蒸馏）无需解码整段 payload（D25）。
    private var lockKindRaw: String = Lock.Kind.mood.rawValue

    /// 解码后的锁缓存 —— 不持久化，避免每次访问都新建 JSONDecoder 重解（D25）。
    @Transient private var cachedLock: Lock?

    /// 胶囊的锁。读写经 lockData 编解码，解码结果缓存。
    public var lock: Lock {
        get {
            if let cachedLock { return cachedLock }
            let decoded = Capsule.decodeLock(from: lockData, kindRaw: lockKindRaw)
            cachedLock = decoded
            return decoded
        }
        set {
            lockData = Capsule.encode(newValue)
            lockKindRaw = newValue.kind.rawValue
            cachedLock = newValue
        }
    }

    /// 锁的种类 —— 不解码 payload 的廉价读取（D25）。
    public var lockKind: Lock.Kind { Lock.Kind(rawValue: lockKindRaw) ?? .mood }

    public var recipient: Recipient = Recipient.me
    /// recipient == .circle 时指向 Circle.id。
    public var circleID: UUID?

    public var authorID: String = ""
    public var authorName: String = ""

    /// 录制地点（拍下这张「相」时人在哪），与 `Lock.place` 的解锁围栏坐标是两回事。
    public var latitude: Double?
    public var longitude: Double?
    public var placeName: String?
    public var weather: String?
    public var tags: [String] = []
    public var note: String?

    public var createdAt: Date = Date()
    public var openedAt: Date?
    /// 胶囊被「浮现」（buried → developing）的时刻。蒸馏「距上次浮现天数」用（D12）。
    public var surfacedAt: Date?

    /// 所属声音圈 —— CKShare 时把胶囊记录挂到 Circle 这棵共享树下，受邀方才看得到（D7）。
    /// 与 `circleID`（保留给 @Query / #Predicate 的查询键）并存：分配进圈时两者同写。
    public var circle: Circle?

    /// 创建时只设录制流程已知的字段；latitude/longitude/placeName/weather/tags/note
    /// 等元数据由上层在创建后补写。
    public init(
        id: UUID = UUID(),
        title: String = "",
        audioData: Data? = nil,
        duration: TimeInterval = 0,
        waveform: [Float] = [],
        state: CapsuleState = .buried,
        lock: Lock = .mood(notBefore: nil),
        recipient: Recipient = .me,
        circleID: UUID? = nil,
        authorID: String = "",
        authorName: String = "",
        createdAt: Date = Date()
    ) {
        self.id = id
        self.title = title
        self.audioData = audioData
        self.duration = duration
        self.waveform = waveform
        self.state = state
        self.lockData = Capsule.encode(lock)
        self.lockKindRaw = lock.kind.rawValue
        self.recipient = recipient
        self.circleID = circleID
        self.authorID = authorID
        self.authorName = authorName
        self.createdAt = createdAt
    }

    static func encode(_ lock: Lock) -> Data {
        (try? JSONEncoder().encode(lock)) ?? Data()
    }

    /// 解码锁 payload；失败时按持久化的 kind 回退到一把「绝不自动浮现」的安全锁，
    /// 绝不把定时/地点锁静默降级成随时可浮现的情绪锁（D11）。
    static func decodeLock(from data: Data, kindRaw: String) -> Lock {
        if let decoded = try? JSONDecoder().decode(Lock.self, from: data) {
            return decoded
        }
        return Lock.safeFallback(forKindRaw: kindRaw)
    }
}
