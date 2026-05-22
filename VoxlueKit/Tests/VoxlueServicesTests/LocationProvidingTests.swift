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
