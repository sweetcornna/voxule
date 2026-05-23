import SwiftUI
import SwiftData
import MapKit
import VoxlueData
import VoxlueDesign

/// 地图视图 —— 标出已埋下地点锁胶囊与正在显影的点。
/// 暗房美学：埋下点是一枚暗的相角标记，显影中点是高亮的朱色标记。
struct CapsuleMapView: View {
    @Query private var capsules: [VoxlueData.Capsule]

    /// 当前点开的 pin —— nil 表示无气泡。
    /// 用 Capsule.id 直接定位，避免 Pin 重建时引用失效。
    @State private var selectedPinID: UUID?

    /// 一个可标注的地点锁胶囊。
    private struct Pin: Identifiable {
        let id: UUID
        let coordinate: CLLocationCoordinate2D
        let title: String
        let isDeveloping: Bool
    }

    /// 从全部胶囊里挑出有地点锁、且尚未开启的，转成地图标注。
    private var pins: [Pin] {
        capsules.compactMap { capsule in
            guard case .place(let lat, let lon, _, let placeName) = capsule.lock else {
                return nil
            }
            guard capsule.state != .opened else { return nil }
            return Pin(
                id: capsule.id,
                coordinate: CLLocationCoordinate2D(latitude: lat, longitude: lon),
                title: capsule.title.isEmpty ? placeName : capsule.title,
                isDeveloping: capsule.state == .developing
            )
        }
    }

    var body: some View {
        Map {
            ForEach(pins) { pin in
                Annotation(pin.title, coordinate: pin.coordinate) {
                    // 已埋下：暗房灰相机标；显影中：朱红相片标。
                    // 用 .thinMaterial 让 pin 在浅 / 深底图都有玻璃质感，
                    // 朱红描边在亮底图也保持识别；MapKit Annotation 会把子视图
                    // 栅格化到瓦片边界内，自带 .stamp 阴影会被裁，所以这里靠
                    // 玻璃材质 + 描边而不是阴影来扩边界。
                    // 包一层 Button 让 pin 可点；同一枚再点收起气泡。
                    Button {
                        if selectedPinID == pin.id {
                            selectedPinID = nil
                        } else {
                            selectedPinID = pin.id
                        }
                    } label: {
                        Image(systemName: pin.isDeveloping
                              ? "photo.fill" : "mappin.circle")
                            .font(.title3)
                            .foregroundStyle(pin.isDeveloping
                                             ? VoxlueColor.vermillion
                                             : VoxlueColor.graphite)
                            .padding(VoxlueSpacing.sm)
                            .background(.thinMaterial, in: Circle())
                            .overlay(
                                Circle().strokeBorder(
                                    pin.isDeveloping
                                        ? VoxlueColor.vermillion
                                        : VoxlueColor.graphite,
                                    lineWidth: 1
                                )
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .mapStyle(.standard(elevation: .flat))
        .navigationTitle("埋下的地方")
        // 点空白处收起气泡 —— 一个透明全屏背板，仅在有选中时存在，
        // 不挡住 pin（pin 是地图原生子视图，绘制在 Map 内部，背板在 .overlay
        // 层级之上但与 pin 不冲突，因为 pin 的 Button 命中区在 Annotation 里）。
        .overlay {
            if selectedPinID != nil {
                Color.clear
                    .contentShape(Rectangle())
                    .onTapGesture { selectedPinID = nil }
                    .allowsHitTesting(true)
            }
        }
        .overlay(alignment: .bottom) {
            if pins.isEmpty {
                Text("还没有埋在某个地点的相")
                    .font(VoxlueTypography.caption)
                    .foregroundStyle(VoxlueColor.graphite)
                    .padding(.horizontal, VoxlueSpacing.md)
                    .padding(.vertical, VoxlueSpacing.sm)
                    .background(VoxlueColor.paperHighlight,
                                in: RoundedRectangle(cornerRadius: VoxlueRadius.glass))
                    .voxlueShadow(.paper)
                    .padding(.bottom, VoxlueSpacing.xl)
            }
        }
        .overlay(alignment: .bottom) {
            if let id = selectedPinID,
               let capsule = capsules.first(where: { $0.id == id }) {
                PinDetailBubble(
                    capsule: capsule,
                    onClose: { selectedPinID = nil }
                )
                .padding(.horizontal, VoxlueSpacing.lg)
                .padding(.bottom, VoxlueSpacing.xl)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: selectedPinID)
    }
}

/// 点开 pin 后浮在地图底部的纸卡气泡。
/// SealStamp + 思源宋标题 + Space Mono 元信息 + 「看这枚」入口。
private struct PinDetailBubble: View {
    let capsule: VoxlueData.Capsule
    let onClose: () -> Void

    var body: some View {
        PaperCard {
            VStack(alignment: .leading, spacing: VoxlueSpacing.sm) {
                HStack(alignment: .top) {
                    SealStamp(sealKind)
                    Spacer(minLength: VoxlueSpacing.sm)
                    Button(action: onClose) {
                        Image(systemName: "xmark")
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(VoxlueColor.graphite)
                            .padding(VoxlueSpacing.xs)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("关闭")
                }

                Text(displayTitle)
                    .font(VoxlueTypography.serifTitle)
                    .foregroundStyle(VoxlueColor.ink)
                    .lineLimit(2)

                Text(metaLine)
                    .font(VoxlueTypography.meta)
                    .foregroundStyle(VoxlueColor.graphite)
                    .lineLimit(1)

                NavigationLink {
                    CapsuleDetailView(capsule: capsule)
                } label: {
                    Text("看这枚 →")
                        .font(VoxlueTypography.caption)
                        .foregroundStyle(VoxlueColor.vermillion)
                }
                .buttonStyle(.plain)
                .padding(.top, VoxlueSpacing.xs)
            }
        }
    }

    private var displayTitle: String {
        if !capsule.title.isEmpty { return capsule.title }
        if case .place(_, _, _, let placeName) = capsule.lock { return placeName }
        return "未命名"
    }

    /// 「地点锁 · 外滩」这类一行 meta。锁种 + 地名（若有）。
    private var metaLine: String {
        var parts: [String] = [lockLabel]
        if case .place(_, _, _, let placeName) = capsule.lock, !placeName.isEmpty {
            parts.append(placeName)
        }
        return parts.joined(separator: " · ")
    }

    private var lockLabel: String {
        switch capsule.lock.kind {
        case .place: "地点锁"
        case .date:  "时间锁"
        case .mood:  "情绪锁"
        }
    }

    private var sealKind: SealStamp.Kind {
        switch capsule.state {
        case .buried:     .buried
        case .developing: .developing
        case .developed:  .developed
        case .opened:     .opened
        }
    }
}

#Preview {
    NavigationStack {
        CapsuleMapView()
            .modelContainer(for: VoxlueData.Capsule.self, inMemory: true)
    }
}
