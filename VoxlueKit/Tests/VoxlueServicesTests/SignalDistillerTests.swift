import Testing
import Foundation
@testable import VoxlueServices

@Test func fakeHealthProviderReturnsScriptedSnapshot() async {
    let provider = FakeHealthProviding(
        snapshot: HealthSnapshot(
            moodValence: -0.4, hrvSDNN: 28, restingHeartRate: 72, sleepHours: 5.1
        ),
        authorized: true
    )
    let granted = await provider.requestAuthorization()
    #expect(granted)
    let snapshot = await provider.snapshot()
    #expect(snapshot?.sleepHours == 5.1)
}

@Test func fakeHealthProviderDeniedReturnsNilSnapshot() async {
    let provider = FakeHealthProviding(snapshot: nil, authorized: false)
    let granted = await provider.requestAuthorization()
    #expect(!granted)
    #expect(await provider.snapshot() == nil)
}
