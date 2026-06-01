import Testing
import Foundation
@testable import VoxlueServices

/// 造一个围栏，经纬度按需指定。
private func region(lat: Double, lon: Double) -> GeofenceRegion {
    GeofenceRegion(capsuleID: UUID(), latitude: lat, longitude: lon, radius: 80)
}

@Test func schedulerKeepsAllWhenUnderTwenty() {
    let regions = (0..<5).map { region(lat: Double($0), lon: 0) }
    let result = GeofenceScheduler.nearest(
        to: (latitude: 0, longitude: 0), from: regions
    )
    #expect(result.count == 5)
}

@Test func schedulerCapsAtTwenty() {
    let regions = (0..<50).map { region(lat: Double($0), lon: 0) }
    let result = GeofenceScheduler.nearest(
        to: (latitude: 0, longitude: 0), from: regions
    )
    #expect(result.count == 20)
}

@Test func schedulerKeepsTheClosestTwenty() {
    // 纬度 0...49：用户在 0，最近 20 个应是纬度 0...19。
    let regions = (0..<50).map { region(lat: Double($0), lon: 0) }
    let result = GeofenceScheduler.nearest(
        to: (latitude: 0, longitude: 0), from: regions
    )
    let keptLatitudes = Set(result.map(\.latitude))
    #expect(keptLatitudes == Set((0..<20).map(Double.init)))
}

@Test func schedulerReSortsWhenUserMoves() {
    // 用户移到纬度 49 一侧，最近 20 个应翻转为纬度 30...49。
    let regions = (0..<50).map { region(lat: Double($0), lon: 0) }
    let result = GeofenceScheduler.nearest(
        to: (latitude: 49, longitude: 0), from: regions
    )
    let keptLatitudes = Set(result.map(\.latitude))
    #expect(keptLatitudes == Set((30..<50).map(Double.init)))
}

@Test func schedulerIsSortedNearestFirst() {
    let regions = [region(lat: 10, lon: 0), region(lat: 1, lon: 0), region(lat: 5, lon: 0)]
    let result = GeofenceScheduler.nearest(
        to: (latitude: 0, longitude: 0), from: regions
    )
    #expect(result.map(\.latitude) == [1, 5, 10])
}

@Test func schedulerHandlesEmptyInput() {
    let result = GeofenceScheduler.nearest(
        to: (latitude: 0, longitude: 0), from: []
    )
    #expect(result.isEmpty)
}

// MARK: - D16 无定位时的监听决策

@Test func regionsToMonitorUsesNearestWhenLocationKnown() {
    let regions = (0..<50).map { region(lat: Double($0), lon: 0) }
    let result = GeofenceScheduler.regionsToMonitor(
        userLocation: (latitude: 0, longitude: 0), from: regions
    )
    #expect(result?.count == 20)
}

@Test func regionsToMonitorKeepsAllWhenNoLocationButUnderLimit() {
    let regions = (0..<5).map { region(lat: Double($0), lon: 0) }
    let result = GeofenceScheduler.regionsToMonitor(userLocation: nil, from: regions)
    #expect(result?.count == 5)
}

@Test func regionsToMonitorHoldsCurrentSetWhenNoLocationAndOverLimit() {
    // 无定位且超额：返回 nil（维持现状），绝不按 (0,0) 乱排选错的 20 个。
    let regions = (0..<50).map { region(lat: Double($0), lon: 0) }
    let result = GeofenceScheduler.regionsToMonitor(userLocation: nil, from: regions)
    #expect(result == nil)
}

// MARK: - D17 半径夹紧

@Test func clampedRadiusBoundsToSystemRange() {
    #expect(GeofenceScheduler.clampedRadius(80, max: 1000) == 80)      // 区间内不变
    #expect(GeofenceScheduler.clampedRadius(0, max: 1000) == 1)        // ≤0 → 1
    #expect(GeofenceScheduler.clampedRadius(-50, max: 1000) == 1)      // 负 → 1
    #expect(GeofenceScheduler.clampedRadius(200_000, max: 1000) == 1000) // 超限 → max
}
