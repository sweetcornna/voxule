import Testing
import Foundation
@testable import VoxlueServices

@Test func fakeLocationGrantsPermission() async {
    let provider = FakeLocationProviding()
    #expect(await provider.requestPermission() == true)
}

@Test func fakeLocationRecordsMonitoredRegions() async {
    let provider = FakeLocationProviding()
    let regions = [
        GeofenceRegion(capsuleID: UUID(), latitude: 31.2, longitude: 121.4, radius: 80),
    ]
    await provider.monitor(regions: regions)
    #expect(provider.monitoredRegions == regions)
}

@Test func fakeLocationEmitsEnteredEvent() async {
    let provider = FakeLocationProviding()
    let id = UUID()
    let collector = Task { () -> [GeofenceEvent] in
        var received: [GeofenceEvent] = []
        for await event in provider.events {
            received.append(event)
            if received.count == 1 { break }
        }
        return received
    }
    provider.simulateEntry(capsuleID: id)
    let received = await collector.value
    #expect(received == [.entered(capsuleID: id)])
}

// CLLocationProvider 是 iOS 专有真实现，其测试同样用 #if os(iOS) 守卫。
#if os(iOS)
@Test func clLocationProviderConformsToProtocol() {
    let provider: LocationProviding = CLLocationProvider()
    #expect(type(of: provider) == CLLocationProvider.self)
}

@Test func clLocationProviderTrimsToTwentyRegions() async {
    let provider = CLLocationProvider()
    let regions = (0..<50).map {
        GeofenceRegion(capsuleID: UUID(), latitude: Double($0), longitude: 0, radius: 80)
    }
    await provider.monitor(regions: regions)
    // 系统监听数永不超过 20。
    #expect(provider.monitoredRegionCount <= 20)
}
#endif
