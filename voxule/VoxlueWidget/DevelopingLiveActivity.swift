import SwiftUI
import WidgetKit
import ActivityKit
import VoxlueServices

/// 「显影中」灵动岛 + 锁屏 Live Activity。
/// 胶囊从 buried → developing 时由 `LiveActivityController` 起。
/// 暗房美学：锁屏卡片是一张正在显影的相纸，霜化进度由 developProgress 驱动。
struct DevelopingLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: DevelopingActivityAttributes.self) { context in
            // 锁屏 / 通知中心展开态。
            lockScreenView(context: context)
                .padding(16)
                .activityBackgroundTint(Color.black.opacity(0.85))
                .activitySystemActionForegroundColor(.white)
        } dynamicIsland: { context in
            DynamicIsland {
                // 展开态。
                DynamicIslandExpandedRegion(.leading) {
                    Image(systemName: "photo.on.rectangle.angled")
                        .foregroundStyle(.white)
                }
                DynamicIslandExpandedRegion(.center) {
                    VStack(alignment: .leading, spacing: 2) {
                        // §2.2 文案契约：浮现的灵动岛文案永远是这一句。
                        Text("这里有一张你洗过一次的相")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        Text(context.attributes.title)
                            .font(.headline)
                            .foregroundStyle(.white)
                            .lineLimit(1)
                    }
                }
                DynamicIslandExpandedRegion(.bottom) {
                    ProgressView(value: context.state.developProgress)
                        .tint(.white)
                }
            } compactLeading: {
                Image(systemName: "photo")
                    .foregroundStyle(.white)
            } compactTrailing: {
                Text("\(Int(context.state.developProgress * 100))%")
                    .font(.caption2)
                    .foregroundStyle(.white)
            } minimal: {
                Image(systemName: "photo")
                    .foregroundStyle(.white)
            }
            // 点灵动岛跳到该胶囊详情 —— 深链由 CapsuleRouter 处理。
            .widgetURL(URL(string: "voxlue://capsule/\(context.attributes.capsuleID.uuidString)"))
        }
    }

    @ViewBuilder
    private func lockScreenView(
        context: ActivityViewContext<DevelopingActivityAttributes>
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "photo.on.rectangle.angled")
                    .foregroundStyle(.white)
                // §2.2 文案契约：浮现的灵动岛文案永远是这一句。
                Text("这里有一张你洗过一次的相")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                Spacer()
            }
            Text(context.attributes.title)
                .font(.title3)
                .foregroundStyle(.white)
                .lineLimit(2)
            ProgressView(value: context.state.developProgress)
                .tint(.white)
        }
    }
}
