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
