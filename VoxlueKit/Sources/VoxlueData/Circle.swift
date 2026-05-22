import Foundation
import SwiftData

/// 声音圈 —— CKShare 的共享单元。
@Model
public final class Circle {
    public var id: UUID = UUID()
    public var name: String = ""
    public var ownerID: String = ""
    public var createdAt: Date = Date()

    /// CloudKit 镜像要求关系可选。
    @Relationship(deleteRule: .cascade)
    public var members: [CircleMember]? = []

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
