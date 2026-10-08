import Foundation

struct SyntheticObjectPredicate: Sendable { let id: UUID }
final class HKHealthStore: Sendable {}
struct HKQuantityType: Sendable {
    enum Identifier { case heartRate }
    init(_ identifier: Identifier) {}
}
struct HKUnit: Sendable {
    static func count() -> HKUnit { .init() }
    static func minute() -> HKUnit { .init() }
    func unitDivided(by: HKUnit) -> HKUnit { self }
}
struct HKQuantity: Sendable {
    let value: Double
    func doubleValue(for: HKUnit) -> Double { value }
}
final class HKQuantitySample: Sendable {}
final class HKHeartbeatSeriesSample: Sendable {
    let uuid: UUID
    init(id: UUID) { uuid = id }
}
enum HKQuery {
    static func predicateForObject(with id: UUID) -> SyntheticObjectPredicate { .init(id: id) }
}
struct HKSamplePredicate<Sample>: Sendable { let id: UUID }
extension HKSamplePredicate where Sample == HKQuantitySample {
    static func quantitySample(type: HKQuantityType, predicate: SyntheticObjectPredicate) -> Self { .init(id: predicate.id) }
}
extension HKSamplePredicate where Sample == HKHeartbeatSeriesSample {
    static func heartbeatSeries(_ predicate: SyntheticObjectPredicate) -> Self { .init(id: predicate.id) }
}
@MainActor enum SyntheticTimingHealth {
    static var selectedID: UUID?
    static var quantityEntries: [HKQuantitySeriesSampleQueryDescriptor.Entry] = []
    static var heartbeats: [HKHeartbeatSeriesQueryDescriptor.Beat] = []
    static var samples: [HKHeartbeatSeriesSample] = []
    static var fail = false
}
struct HKQuantitySeriesSampleQueryDescriptor {
    struct Entry: Sendable { let quantity: HKQuantity; let dateInterval: DateInterval }
    let predicate: HKSamplePredicate<HKQuantitySample>
    @MainActor func results(for: HKHealthStore) -> AsyncThrowingStream<Entry, Error> {
        SyntheticTimingHealth.selectedID = predicate.id
        let entries = SyntheticTimingHealth.quantityEntries
        let fail = SyntheticTimingHealth.fail
        return AsyncThrowingStream { continuation in
            for entry in entries { continuation.yield(entry) }
            if fail { continuation.finish(throwing: NSError(domain: "Synthetic", code: 1)) }
            else { continuation.finish() }
        }
    }
}
struct HKSampleQueryDescriptor<Sample> {
    let predicates: [HKSamplePredicate<Sample>]
    let sortDescriptors: [Int]
    let limit: Int
    @MainActor func result(for: HKHealthStore) async throws -> [Sample] {
        SyntheticTimingHealth.selectedID = predicates.first?.id
        if SyntheticTimingHealth.fail { throw NSError(domain: "Synthetic", code: 2) }
        return Array((SyntheticTimingHealth.samples as? [Sample] ?? []).prefix(limit))
    }
}
struct HKHeartbeatSeriesQueryDescriptor {
    struct Beat: Sendable { let timeIntervalSinceStart: Double; let precededByGap: Bool }
    let sample: HKHeartbeatSeriesSample
    init(_ sample: HKHeartbeatSeriesSample) { self.sample = sample }
    @MainActor func results(for: HKHealthStore) -> AsyncThrowingStream<Beat, Error> {
        let beats = SyntheticTimingHealth.heartbeats
        return AsyncThrowingStream { continuation in
            for beat in beats { continuation.yield(beat) }
            continuation.finish()
        }
    }
}
