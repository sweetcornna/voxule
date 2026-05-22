import Foundation
import SwiftData

/// SwiftData 容器工厂。
/// - 生产配置：镜像到 CloudKit 私有库。
/// - 测试配置：纯内存，不接 CloudKit。
public enum VoxlueModelContainer {

    /// CloudKit 容器标识符，需与 Xcode iCloud 能力里的容器一致。
    public static let cloudKitContainerID = "iCloud.com.voxlue.app"

    public static let schema = Schema([
        Capsule.self,
        Circle.self,
        CircleMember.self,
    ])

    /// 创建一个 ModelContainer。
    /// - Parameter inMemory: true 为内存配置（测试/预览用），false 为生产配置（CloudKit 镜像）。
    public static func make(inMemory: Bool = false) throws -> ModelContainer {
        let configuration: ModelConfiguration
        if inMemory {
            configuration = ModelConfiguration(
                schema: schema,
                isStoredInMemoryOnly: true,
                cloudKitDatabase: .none
            )
        } else {
            configuration = ModelConfiguration(
                schema: schema,
                isStoredInMemoryOnly: false,
                cloudKitDatabase: .private(cloudKitContainerID)
            )
        }
        return try ModelContainer(for: schema, configurations: [configuration])
    }
}
