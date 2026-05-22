import Testing
import Foundation
@testable import VoxlueData

@Test func recipientHasThreeCases() {
    #expect(Recipient.allCases.count == 3)
}

@Test func capsuleStateHasFourCases() {
    #expect(CapsuleState.allCases.count == 4)
}

@Test func circleRoleHasTwoCases() {
    #expect(CircleRole.allCases.count == 2)
}

@Test func recipientCodableRoundTrip() throws {
    let data = try JSONEncoder().encode(Recipient.circle)
    let decoded = try JSONDecoder().decode(Recipient.self, from: data)
    #expect(decoded == .circle)
}
