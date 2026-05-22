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

    /// 胶囊的锁。读写经 lockData 编解码。
    public var lock: Lock {
        get { (try? JSONDecoder().decode(Lock.self, from: lockData)) ?? .mood(notBefore: nil) }
        set { lockData = Capsule.encode(newValue) }
    }

    public var recipient: Recipient = Recipient.me
    /// recipient == .circle 时指向 Circle.id。
    public var circleID: UUID?

    public var authorID: String = ""
    public var authorName: String = ""

    public var latitude: Double?
    public var longitude: Double?
    public var placeName: String?
    public var weather: String?
    public var tags: [String] = []
    public var note: String?

    public var createdAt: Date = Date()
    public var openedAt: Date?

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
        self.recipient = recipient
        self.circleID = circleID
        self.authorID = authorID
        self.authorName = authorName
        self.createdAt = createdAt
    }

    private static func encode(_ lock: Lock) -> Data {
        (try? JSONEncoder().encode(lock)) ?? Data()
    }
}
