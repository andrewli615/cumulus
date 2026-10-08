import Foundation

@main struct CardiacTimingProviderChecks {
    @MainActor static func main() async throws {
        let query = HealthKitCardiacTimingQuery()
        let origin = Date(timeIntervalSince1970: 1000)
        let grouped = CardiacTimingSelection(id: UUID(), kind: .groupedHeartRate, count: 2,
            start: origin, end: origin.addingTimeInterval(100))
        SyntheticTimingHealth.quantityEntries = [
            .init(quantity: .init(value: 60), dateInterval: DateInterval(start: origin, duration: 1)),
            .init(quantity: .init(value: 60), dateInterval: DateInterval(start: origin.addingTimeInterval(5), duration: 1))]
        let quantities = try await query.inspect(grouped, progress: { _ in })
        precondition(SyntheticTimingHealth.selectedID == grouped.id && quantities.enumerationCompleted)
        precondition(quantities.accepted == 2 && quantities.maximumSpacing == 5)
        let heartbeat = CardiacTimingSelection(id: UUID(), kind: .heartbeatSeries, count: 3,
            start: origin, end: origin.addingTimeInterval(100))
        SyntheticTimingHealth.samples = [.init(id: heartbeat.id)]
        SyntheticTimingHealth.heartbeats = [.init(timeIntervalSinceStart: 1, precededByGap: false),
            .init(timeIntervalSinceStart: 2, precededByGap: false), .init(timeIntervalSinceStart: 10, precededByGap: true)]
        let beats = try await query.inspect(heartbeat, progress: { _ in })
        precondition(SyntheticTimingHealth.selectedID == heartbeat.id && beats.received == 3 && beats.gapFlags == 1)
        precondition(beats.spacingPairs == 1 && beats.maximumSpacing == 1)
        SyntheticTimingHealth.samples = [.init(id: UUID())]
        let missing = try await query.inspect(heartbeat, progress: { _ in })
        precondition(missing.received == 0 && !missing.enumerationCompleted, "Mismatched lookup cannot inspect another record")
        SyntheticTimingHealth.fail = true
        do { _ = try await query.inspect(grouped, progress: { _ in }); fatalError("Query error must propagate") }
        catch { }
        SyntheticTimingHealth.fail = false
        SyntheticTimingHealth.quantityEntries = (0..<20_001).map {
            .init(quantity: .init(value: 60), dateInterval: DateInterval(start: origin.addingTimeInterval(Double($0) / 1000), duration: 0))
        }
        let bounded = try await query.inspect(grouped, progress: { _ in })
        precondition(bounded.received == 20_000 && bounded.limitReached && !bounded.enumerationCompleted)
        let cancelled = Task { @MainActor in
            try await query.inspect(grouped, progress: { _ in })
        }
        cancelled.cancel()
        do { _ = try await cancelled.value; fatalError("Cancelled enumeration must stop") }
        catch is CancellationError { }
        print("PASS: actual HealthKit adapter predicate selection, interval conversion, beat gap flags, mismatched lookup, errors, cancellation and entry cap")
    }
}
