import SwiftUI
import SwiftData
import MapKit
import VoxlueData
import VoxlueDesign

/// 地图视图 —— 标出已埋下地点锁胶囊与正在显影的点。
/// 暗房美学：埋下点是一枚暗的相角标记，显影中点是高亮的朱色标记。
struct CapsuleMapView: View {
    @Query private var capsules: [VoxlueData.Capsule]

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
                    Image(systemName: pin.isDeveloping
                          ? "photo.fill" : "mappin.circle")
                        .font(.title3)
                        .foregroundStyle(pin.isDeveloping
                                         ? VoxlueColor.vermillion
                                         : VoxlueColor.graphite)
                        .padding(VoxlueSpacing.xs)
                        .background(VoxlueColor.paperHighlight, in: Circle())
                        .voxlueShadow(.stamp)
                }
            }
        }
        .mapStyle(.standard(elevation: .flat))
        .navigationTitle("埋下的地方")
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
    }
}

#Preview {
    NavigationStack {
        CapsuleMapView()
            .modelContainer(for: VoxlueData.Capsule.self, inMemory: true)
    }
}
