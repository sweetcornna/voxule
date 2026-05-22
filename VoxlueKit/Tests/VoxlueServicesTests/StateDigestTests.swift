import Testing
import Foundation
@testable import VoxlueServices

@Test func stateDigestCodableRoundTrip() throws {
    let digest = StateDigest(
        tension: .high,
        sleep: .low,
        calmCapsulesAvailable: 4,
        daysSinceLastSurfacing: 9
    )
    let data = try JSONEncoder().encode(digest)
    let decoded = try JSONDecoder().decode(StateDigest.self, from: data)
    #expect(decoded.tension == .high)
    #expect(decoded.sleep == .low)
    #expect(decoded.calmCapsulesAvailable == 4)
    #expect(decoded.daysSinceLastSurfacing == 9)
}

@Test func levelHasThreeCases() {
    #expect(StateDigest.Level(rawValue: "low") == .low)
    #expect(StateDigest.Level(rawValue: "medium") == .medium)
    #expect(StateDigest.Level(rawValue: "high") == .high)
}

// 合规铁律：编码后的 JSON 里只能出现抽象 Level 与计数，
// 绝不能出现任何原始体征键名（心率/HRV/睡眠时长/心情分值等）。
@Test func stateDigestJSONContainsNoRawHealthValues() throws {
    let digest = StateDigest(
        tension: .medium, sleep: .medium,
        calmCapsulesAvailable: 2, daysSinceLastSurfacing: 3
    )
    let json = String(data: try JSONEncoder().encode(digest), encoding: .utf8)!
    let forbidden = ["heartRate", "hrv", "bpm", "sleepHours",
                     "restingHeartRate", "moodValence", "sdnn", "latitude", "longitude"]
    for key in forbidden {
        #expect(!json.lowercased().contains(key.lowercased()),
                "StateDigest JSON 不得包含原始体征字段：\(key)")
    }
    // 只允许这四个键。
    let object = try JSONSerialization.jsonObject(with: try JSONEncoder().encode(digest)) as! [String: Any]
    #expect(Set(object.keys) == ["tension", "sleep", "calmCapsulesAvailable", "daysSinceLastSurfacing"])
}
