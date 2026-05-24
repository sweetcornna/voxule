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
                            // HIG 命中区 ≥ 44pt；ic 自身 ~28pt + 8 padding ~44，
                            // 显式拉一下 + contentShape 保险。
                            .frame(minWidth: 44, minHeight: 44)
                            .contentShape(Circle())
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .mapStyle(.standard(elevation: .flat))
        // iOS 17+ 原生地图控件：定位按钮 + 指南针 + 比例尺。
        // 自动对齐 safe area，按 mapStyle 自适应配色，省一枚自绘 FAB。
        // Info.plist 已配 NSLocationWhenInUseUsageDescription，权限弹窗就绪。
        .mapControls {
            MapUserLocationButton()
            MapCompass()
            MapScaleView()
        }
        .navigationTitle("埋下的地方")
        // 不再用全屏 Color.clear 背板做「点空白收起」—— 它会吃掉 Map 自己的
        // pan / zoom 手势，地图在气泡打开期间瘫痪。
        // 收起入口：同一枚 pin 二次点击（toggle）+ 气泡右上 ✕ + 「看这枚」push 时清空。
        .overlay(alignment: .center) {
            if pins.isEmpty {
                // 空状态从「底部小 chip」升级成「居中纸卡」：
                // 标题用思源宋告诉「这里目前空着」，朱红 Caveat 手写体补一句
                // 操作引导。卡只占中央 ~280pt，留出地图四周可拖、可缩。
                EmptyMapPaperCard()
                    .frame(maxWidth: 280)
                    .padding(.horizontal, VoxlueSpacing.lg)
                    // allowsHitTesting(false) 让拖动 / 双指缩放穿透纸卡到地图，
                    // 避免 PR #19 的全屏背板吞手势教训。
                    .allowsHitTesting(false)
            }
        }
        .overlay(alignment: .bottom) {
            if let id = selectedPinID,
               let capsule = capsules.first(where: { $0.id == id }) {
                PinDetailBubble(
                    capsule: capsule,
                    onClose: { selectedPinID = nil },
                    onOpenDetail: { selectedPinID = nil }
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
    /// push 进详情时也要清掉外层选中状态 —— 否则 back 回来气泡还杵着。
    var onOpenDetail: () -> Void = {}

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
                // 进详情同时清掉 selectedPinID：用 simultaneousGesture 不抢 navigation，
                // back 回来时气泡不会再杵着。
                .simultaneousGesture(
                    TapGesture().onEnded { onOpenDetail() }
                )
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

/// 地图空状态纸卡 —— 居中浮在地图上，告诉用户「这里目前空着」。
/// 思源宋标题 + Caveat 朱红手写体引导，PaperCard 自带纸质阴影 + 描边。
private struct EmptyMapPaperCard: View {
    var body: some View {
        PaperCard {
            VStack(alignment: .leading, spacing: VoxlueSpacing.sm) {
                Text("还没有埋在地图上")
                    .font(VoxlueTypography.serifTitle)
                    .foregroundStyle(VoxlueColor.ink)
                    .fixedSize(horizontal: false, vertical: true)

                Text("装裱时选「地点锁」，胶囊就会落在这里。")
                    .font(VoxlueTypography.annotation)
                    .foregroundStyle(VoxlueColor.vermillion)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

#Preview {
    NavigationStack {
        CapsuleMapView()
            .modelContainer(for: VoxlueData.Capsule.self, inMemory: true)
    }
}
