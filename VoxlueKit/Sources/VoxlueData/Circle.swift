import Foundation
import SwiftData

/// 声音圈 —— CKShare 的共享单元。
@Model
public final class Circle {
    public var id: UUID = UUID()
    public var name: String = ""
    public var ownerID: String = ""
    public var createdAt: Date = Date()

    /// 单向 to-many 关系（CircleMember 不持有反向的 circle 引用）—— v1 有意为之：
    /// 成员只随 Circle 级联增删，不会被独立删除。CloudKit 镜像要求关系可选。
    @Relationship(deleteRule: .cascade)
    public var members: [CircleMember]? = []

    /// 圈内胶囊 —— CKShare 把胶囊记录挂到 Circle 这棵共享树下，受邀方才看得到（D7）。
    /// 删除圈只解除关联、不删胶囊（nullify）。CloudKit 镜像要求关系可选。
    @Relationship(deleteRule: .nullify, inverse: \Capsule.circle)
    public var capsules: [Capsule]? = []

    public init(
        id: UUID = UUID(),
        name: String = "",
        ownerID: String = "",
        createdAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.ownerID = ownerID
        self.createdAt = createdAt
    }
}

/// 声音圈成员。
@Model
public final class CircleMember {
    public var id: UUID = UUID()
    public var name: String = ""
    public var userRecordID: String = ""
    public var role: CircleRole = CircleRole.member
    public var joinedAt: Date = Date()

    public init(
        id: UUID = UUID(),
        name: String = "",
        userRecordID: String = "",
        role: CircleRole = .member,
        joinedAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.userRecordID = userRecordID
        self.role = role
        self.joinedAt = joinedAt
    }
}
