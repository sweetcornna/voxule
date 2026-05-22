import Foundation

/// HealthKit 原始读数快照 —— **仅在设备内存在**。
/// 它是脱敏闸门 `SignalDistiller` 的输入，绝不被序列化上网。
public struct HealthSnapshot: Sendable, Equatable {
    /// `HKStateOfMind` 心情效价，区间约 -1...1（负=不愉快）。
    public let moodValence: Double?
    /// HRV（SDNN，毫秒）。
    public let hrvSDNN: Double?
    /// 静息心率（次/分）。
    public let restingHeartRate: Double?
    /// 最近一晚睡眠时长（小时）。
    public let sleepHours: Double?

    public init(
        moodValence: Double? = nil,
        hrvSDNN: Double? = nil,
        restingHeartRate: Double? = nil,
        sleepHours: Double? = nil
    ) {
        self.moodValence = moodValence
        self.hrvSDNN = hrvSDNN
        self.restingHeartRate = restingHeartRate
        self.sleepHours = sleepHours
    }
}

/// HealthKit 平台能力 wrapper。
/// 真实现读原始体征；预览/测试注入假实现。
public protocol HealthProviding: Sendable {
    /// 申请读取授权（HealthKit 须显式授权）。
    func requestAuthorization() async -> Bool
    /// 取一份原始读数快照；未授权或无数据返回 nil。
    func snapshot() async -> HealthSnapshot?
}

/// 假实现 —— 返回脚本化快照，供预览与单元测试。
public struct FakeHealthProviding: HealthProviding {
    private let scriptedSnapshot: HealthSnapshot?
    private let authorized: Bool

    public init(snapshot: HealthSnapshot?, authorized: Bool = true) {
        self.scriptedSnapshot = snapshot
        self.authorized = authorized
    }

    public func requestAuthorization() async -> Bool { authorized }
    public func snapshot() async -> HealthSnapshot? { authorized ? scriptedSnapshot : nil }
}

// HealthKit 的 HKStateOfMind 等 API 仅 iOS 可用 —— 真实现用 #if os(iOS) 守卫。
// macOS（swift test 宿主）不编译它；自动化测试只覆盖协议与 FakeHealthProviding。
#if os(iOS)
import HealthKit

/// 真实现 —— 经 HealthKit 读 `HKStateOfMind`、HRV、静息心率、睡眠。
/// 这些原始读数只在设备内流转，只交给 `SignalDistiller` 脱敏。
public struct HealthKitHealthProvider: HealthProviding {
    private let store = HKHealthStore()

    public init() {}

    private var readTypes: Set<HKObjectType> {
        var types: Set<HKObjectType> = []
        types.insert(HKObjectType.stateOfMindType())
        if let hrv = HKObjectType.quantityType(forIdentifier: .heartRateVariabilitySDNN) {
            types.insert(hrv)
        }
        if let rhr = HKObjectType.quantityType(forIdentifier: .restingHeartRate) {
            types.insert(rhr)
        }
        types.insert(HKObjectType.categoryType(forIdentifier: .sleepAnalysis)!)
        return types
    }

    public func requestAuthorization() async -> Bool {
        guard HKHealthStore.isHealthDataAvailable() else { return false }
        do {
            try await store.requestAuthorization(toShare: [], read: readTypes)
            return true
        } catch {
            return false
        }
    }

    public func snapshot() async -> HealthSnapshot? {
        guard HKHealthStore.isHealthDataAvailable() else { return nil }
        async let mood = latestMoodValence()
        async let hrv = latestQuantity(.heartRateVariabilitySDNN, unit: .secondUnit(with: .milli))
        async let rhr = latestQuantity(.restingHeartRate,
                                       unit: HKUnit.count().unitDivided(by: .minute()))
        async let sleep = lastNightSleepHours()
        return HealthSnapshot(
            moodValence: await mood,
            hrvSDNN: await hrv,
            restingHeartRate: await rhr,
            sleepHours: await sleep
        )
    }

    private func latestMoodValence() async -> Double? {
        await withCheckedContinuation { continuation in
            let sort = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)
            let query = HKSampleQuery(
                sampleType: HKObjectType.stateOfMindType(),
                predicate: nil, limit: 1, sortDescriptors: [sort]
            ) { _, samples, _ in
                let valence = (samples?.first as? HKStateOfMind)?.valence
                continuation.resume(returning: valence)
            }
            store.execute(query)
        }
    }

    private func latestQuantity(_ id: HKQuantityTypeIdentifier, unit: HKUnit) async -> Double? {
        guard let type = HKObjectType.quantityType(forIdentifier: id) else { return nil }
        return await withCheckedContinuation { continuation in
            let sort = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)
            let query = HKSampleQuery(
                sampleType: type, predicate: nil, limit: 1, sortDescriptors: [sort]
            ) { _, samples, _ in
                let value = (samples?.first as? HKQuantitySample)?.quantity.doubleValue(for: unit)
                continuation.resume(returning: value)
            }
            store.execute(query)
        }
    }

    private func lastNightSleepHours() async -> Double? {
        let type = HKObjectType.categoryType(forIdentifier: .sleepAnalysis)!
        let start = Calendar.current.date(byAdding: .hour, value: -24, to: Date())!
        let predicate = HKQuery.predicateForSamples(withStart: start, end: Date())
        return await withCheckedContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: type, predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: nil
            ) { _, samples, _ in
                let asleep = (samples as? [HKCategorySample])?.filter {
                    $0.value == HKCategoryValueSleepAnalysis.asleepUnspecified.rawValue
                        || $0.value == HKCategoryValueSleepAnalysis.asleepCore.rawValue
                        || $0.value == HKCategoryValueSleepAnalysis.asleepDeep.rawValue
                        || $0.value == HKCategoryValueSleepAnalysis.asleepREM.rawValue
                } ?? []
                guard !asleep.isEmpty else {
                    continuation.resume(returning: nil); return
                }
                let seconds = asleep.reduce(0.0) { $0 + $1.endDate.timeIntervalSince($1.startDate) }
                continuation.resume(returning: seconds / 3600.0)
            }
            store.execute(query)
        }
    }
}
#endif
