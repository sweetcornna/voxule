import SwiftUI
import SwiftData
import VoxlueData

/// App 根骨架 —— 四标签：首页（巨大录音键）/ 样片墙 / 地图 / 我。
/// 首页是 App 入口，让「冲一张声音」是用户第一动作；样片墙是储存。
/// 深链 / 通知 / 灵动岛点击经 `CapsuleRouter` 落到一张详情 sheet。
struct RootTabView: View {
    /// 触发引擎依赖容器；预览未注入时为 nil（不影响渲染）。
    @Environment(AppDependencies.self) private var dependencies: AppDependencies?

    /// 全量拉一次胶囊，在内存里数 developing 数量。
    /// 不走 #Predicate：state 是 CapsuleState 枚举（rawValue: String），
    /// 直接在谓词里写 `.developing` 会触发 SwiftData 谓词解析的边角坑，
    /// 计数 UI 数据量小，内存过滤更直观也更稳。
    @Query private var capsules: [VoxlueData.Capsule]

    /// 浮现待听数 —— 即「有几枚胶囊浮上来了，正等你按下播放」。
    /// 这是暗房隐喻里的「未读邮件灯」：照片已经显影，等你来看。
    private var developingCount: Int {
        capsules.filter { $0.state == .developing }.count
    }

    var body: some View {
        TabView {
            Tab("首页", systemImage: "mic.fill") {
                HomeView()
            }
            Tab("样片墙", systemImage: "rectangle.stack") {
                ShelfView()
            }
            .badge(developingCount)
            Tab("地图", systemImage: "map") {
                NavigationStack { CapsuleMapView() }
            }
            Tab("我", systemImage: "person.crop.circle") {
                CircleListView()
            }
        }
        .sheet(isPresented: routedSheetBinding) {
            if let id = dependencies?.router.routedCapsuleID {
                NavigationStack { RoutedCapsuleDetailView(capsuleID: id) }
            }
        }
    }

    /// 把 `router.routedCapsuleID` 是否非空映射成 sheet 的 isPresented。
    private var routedSheetBinding: Binding<Bool> {
        Binding(
            get: { dependencies?.router.routedCapsuleID != nil },
            set: { presented in
                if !presented { dependencies?.router.routedCapsuleID = nil }
            }
        )
    }
}

/// 深链落地页 —— 按 capsuleID 现查胶囊，命中则展示详情。
/// 处于 developing 的胶囊走「浮现卡」陪伴语气落地；其他状态（developed/opened/buried）走常规详情。
/// developing 来源不止 agent：TriggerEngine.surface() 三条路径都会把胶囊推到 developing —
/// (1) agent 闭环主动浮现；(2) 地点锁围栏命中；(3) 时间锁通知点击。
/// v1 选择不区分来源，让「一段你埋下的声音，浮上来了」这句陪伴语气覆盖三者。
struct RoutedCapsuleDetailView: View {
    let capsuleID: UUID
    @Query(sort: \VoxlueData.Capsule.createdAt, order: .reverse)
    private var capsules: [VoxlueData.Capsule]

    var body: some View {
        if let capsule = capsules.first(where: { $0.id == capsuleID }) {
            if capsule.state == .developing {
                SurfacedCapsuleView(capsuleID: capsule.id)
            } else {
                CapsuleDetailView(capsule: capsule)
            }
        } else {
            ContentUnavailableView(
                "找不到这枚胶囊",
                systemImage: "questionmark.circle",
                description: Text("它可能已被划掉。")
            )
        }
    }
}

#Preview {
    RootTabView()
        .environment(\.appEnvironment, .preview())
        .modelContainer(for: VoxlueDataModelsPreview.all, inMemory: true)
}
