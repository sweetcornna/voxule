import Foundation
import SwiftData
import CloudKit
import VoxlueData

/// `CircleServicing` 的真实现 —— SwiftData 原生共享 / `CKShare` 对接 CloudKit 共享库。
///
/// 架构文档 §8「共享路」：圈主在私有库建 `Circle` → SwiftData 为它生成 `CKShare`
/// → 圈主把 `CKShare.url` 发出 → 受邀者接受 → `Circle` 与圈内 `Capsule` 落进其共享库；
/// 音频 `Data` 经 `@Attribute(.externalStorage)` 自动镜像为 `CKAsset`。
///
/// 架构文档 §13 隔离原则：本类是唯一感知「SwiftData 原生共享」细节的地方。
/// 若原生共享某边角不稳，可把 `makeInvitation` / `acceptShare` 内部整体换成
/// 手写 `CKShare`（`CKModifyRecordsOperation` + `CKShare(rootRecord:)`），
/// 协议签名与调用方均不变。
@MainActor
@Observable
public final class CircleService: CircleServicing {

    private let modelContext: ModelContext
    private let cloudKitContainerID: String

    /// - Parameters:
    ///   - modelContext: 与 App 共用的主上下文（计划 01 的 `VoxlueModelContainer`）。
    ///   - cloudKitContainerID: CloudKit 容器标识，默认与数据层一致。
    public init(
        modelContext: ModelContext,
        cloudKitContainerID: String = VoxlueModelContainer.cloudKitContainerID
    ) {
        self.modelContext = modelContext
        self.cloudKitContainerID = cloudKitContainerID
    }

    // MARK: - CircleServicing

    public func createCircle(name: String) async throws -> Circle {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw CircleServiceError.emptyCircleName }

        let ownerID = try await currentUserRecordName()
        let circle = Circle(name: trimmed, ownerID: ownerID)
        circle.members = [
            CircleMember(name: "我", userRecordID: ownerID, role: .owner)
        ]
        modelContext.insert(circle)
        try modelContext.save()
        return circle
    }

    public func makeInvitation(for circle: Circle) async throws -> ShareInvitation {
        // SwiftData 原生共享：为该 Circle 取/建一个 CKShare。
        let share = try await cloudKitShare(for: circle)
        guard let url = share.url else {
            throw CircleServiceError.cloudKitUnavailable
        }
        return ShareInvitation(url: url)
    }

    public func acceptShare(from url: URL) async throws {
        guard FakeCircleServicing.looksLikeShareURL(url) else {
            throw CircleServiceError.invalidInvitationURL
        }
        let container = CKContainer(identifier: cloudKitContainerID)
        // 1. 取邀请元数据。
        let metadata: CKShare.Metadata
        do {
            metadata = try await container.shareMetadata(for: url)
        } catch {
            throw CircleServiceError.cloudKitUnavailable
        }
        // 2. 接受邀请 —— Circle 与圈内 Capsule 随之落进本机共享库，
        //    SwiftData 镜像层会把它们带进本地存储。
        do {
            try await container.accept(metadata)
        } catch {
            throw CircleServiceError.cloudKitUnavailable
        }
    }

    public func circles() async throws -> [Circle] {
        // 私有库自建的圈 + 共享库受邀加入的圈，SwiftData 镜像后都落在同一本地库。
        try modelContext.fetch(
            FetchDescriptor<Circle>(sortBy: [SortDescriptor(\.createdAt, order: .reverse)])
        )
    }

    // MARK: - CloudKit 细节（隔离在本类内）

    /// 当前登录用户的 record name；CloudKit 不可用时抛 `cloudKitUnavailable`。
    private func currentUserRecordName() async throws -> String {
        let container = CKContainer(identifier: cloudKitContainerID)
        do {
            let recordID = try await container.userRecordID()
            return recordID.recordName
        } catch {
            throw CircleServiceError.cloudKitUnavailable
        }
    }

    /// 为一个 Circle 取/建底层 CKShare。
    ///
    /// v1 用 SwiftData 原生共享：把 Circle 标记为共享根，由镜像层管理 CKShare 生命周期。
    /// 这里通过 CloudKit 私有库按 Circle.id 取已有共享、不存在则建。
    /// 若原生共享不稳，可整体替换本方法体为纯手写 CKShare，对外不变（§13）。
    private func cloudKitShare(for circle: Circle) async throws -> CKShare {
        let container = CKContainer(identifier: cloudKitContainerID)
        let database = container.privateCloudDatabase
        let zoneID = CKRecordZone.ID(zoneName: "com.apple.coredata.cloudkit.zone")
        let recordID = CKRecord.ID(
            recordName: "CD_Circle_\(circle.id.uuidString)",
            zoneID: zoneID
        )
        do {
            let rootRecord = try await database.record(for: recordID)
            // 已有共享？
            if let existingShareRef = rootRecord.share {
                if let share = try await database.record(for: existingShareRef.recordID) as? CKShare {
                    return share
                }
            }
            // 新建共享。
            let share = CKShare(rootRecord: rootRecord)
            share[CKShare.SystemFieldKey.title] = circle.name as CKRecordValue
            share.publicPermission = .none   // 仅受邀者可入。
            let result = try await database.modifyRecords(
                saving: [rootRecord, share],
                deleting: []
            )
            _ = result
            return share
        } catch {
            throw CircleServiceError.cloudKitUnavailable
        }
    }
}
