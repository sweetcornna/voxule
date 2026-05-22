import SwiftUI
import SwiftData
import MapKit
import VoxlueData

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
                    Image(systemName: pin.isDeveloping
                          ? "photo.fill" : "mappin.circle")
                        .font(.title2)
                        .foregroundStyle(pin.isDeveloping ? .red : .secondary)
                        .padding(6)
                        .background(.thinMaterial, in: Circle())
                }
            }
        }
        .mapStyle(.standard(elevation: .flat))
        .navigationTitle("埋下的地方")
        .overlay(alignment: .bottom) {
            if pins.isEmpty {
                Text("还没有埋在某个地点的相")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .padding(8)
                    .background(.thinMaterial, in: Capsule())
                    .padding(.bottom, 24)
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
