import Testing
import Foundation
import UserNotifications
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

@Test func unNotificationServiceBuildsRequestWithCapsuleID() {
    let id = UUID()
    let fireAt = Date(timeIntervalSinceNow: 86_400)
    let request = UNNotificationService.makeRequest(capsuleID: id, fireAt: fireAt)
    #expect(request.identifier == id.uuidString)
    #expect(request.content.userInfo["capsuleID"] as? String == id.uuidString)
    #expect(request.trigger is UNCalendarNotificationTrigger)
}
