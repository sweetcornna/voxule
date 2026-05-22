import Testing
import Foundation
@testable import VoxlueData

@Test func placeLockRoundTrip() throws {
    let lock = Lock.place(latitude: 31.21, longitude: 121.43, radius: 80, placeName: "武康 × 巨鹿")
    let data = try JSONEncoder().encode(lock)
    let decoded = try JSONDecoder().decode(Lock.self, from: data)
    #expect(decoded == lock)
}

@Test func dateLockRoundTrip() throws {
    let lock = Lock.date(Date(timeIntervalSince1970: 1_800_000_000))
    let data = try JSONEncoder().encode(lock)
    let decoded = try JSONDecoder().decode(Lock.self, from: data)
    #expect(decoded == lock)
}

@Test func moodLockRoundTrip() throws {
    let lock = Lock.mood(notBefore: nil)
    let data = try JSONEncoder().encode(lock)
    let decoded = try JSONDecoder().decode(Lock.self, from: data)
    #expect(decoded == lock)
}

@Test func moodLockKindIsMood() {
    #expect(Lock.mood(notBefore: nil).kind == .mood)
    #expect(Lock.date(.now).kind == .date)
}
