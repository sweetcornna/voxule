import Testing
import Foundation
@testable import VoxlueServices

@Test func fakeNotificationGrantsPermission() async {
    let service = FakeNotificationScheduling()
    #expect(await service.requestPermission() == true)
}

@Test func fakeNotificationRecordsScheduledLock() async throws {
    let service = FakeNotificationScheduling()
    let id = UUID()
    let fireAt = Date(timeIntervalSince1970: 1_900_000_000)
    try await service.scheduleDateLock(capsuleID: id, fireAt: fireAt)
    #expect(service.scheduled[id] == fireAt)
}

@Test func fakeNotificationCancelRemovesScheduledLock() async throws {
    let service = FakeNotificationScheduling()
    let id = UUID()
    try await service.scheduleDateLock(capsuleID: id, fireAt: .now)
    await service.cancel(capsuleID: id)
    #expect(service.scheduled[id] == nil)
}
