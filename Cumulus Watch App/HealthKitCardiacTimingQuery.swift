import Foundation
import HealthKit

@MainActor
final class HealthKitCardiacTimingQuery: CardiacTimingQuerying {
    private let store = HKHealthStore()

    func inspect(_ selection: CardiacTimingSelection,
                 progress: @escaping @MainActor (CardiacTimingSummary) -> Void) async throws -> CardiacTimingSummary {
        guard selection.canInspect else { throw CardiacTimingQueryError.ineligible }
        var summary = CardiacTimingSummary()
        let duration = selection.end.timeIntervalSince(selection.start)
        let predicate = HKQuery.predicateForObject(with: selection.id)
        switch selection.kind {
        case .groupedHeartRate:
            let descriptor = HKQuantitySeriesSampleQueryDescriptor(
                predicate: .quantitySample(type: HKQuantityType(.heartRate), predicate: predicate))
            for try await entry in descriptor.results(for: store) {
                try Task.checkCancellation()
                summary.receive(offset: entry.dateInterval.start.timeIntervalSince(selection.start), duration: duration,
                    intervalDuration: entry.dateInterval.duration,
                    valueFinite: entry.quantity.doubleValue(for: HKUnit.count().unitDivided(by: .minute())).isFinite)
                if summary.received >= CardiacTimingSummary.maximumEntries { summary.limitReached = true; break }
                if summary.received % 250 == 0 { progress(summary); await Task.yield() }
            }
        case .heartbeatSeries:
            let descriptor = HKSampleQueryDescriptor(predicates: [.heartbeatSeries(predicate)], sortDescriptors: [], limit: 1)
            let samples = try await descriptor.result(for: store)
            try Task.checkCancellation()
            guard let sample = samples.first, sample.uuid == selection.id else { return summary }
            for try await heartbeat in HKHeartbeatSeriesQueryDescriptor(sample).results(for: store) {
                try Task.checkCancellation()
                summary.receive(offset: heartbeat.timeIntervalSinceStart, duration: duration,
                    precededByGap: heartbeat.precededByGap, positiveOffset: true)
                if summary.received >= CardiacTimingSummary.maximumEntries { summary.limitReached = true; break }
                if summary.received % 250 == 0 { progress(summary); await Task.yield() }
            }
        }
        try Task.checkCancellation()
        summary.enumerationCompleted = !summary.limitReached
        return summary
    }
}

enum CardiacTimingQueryError: Error { case ineligible }
