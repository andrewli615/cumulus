import Combine
import Foundation
import HealthKit

/// Observes stored heart-rate records; it does not activate continuous sensing.
@MainActor
final class HeartRateReader: ObservableObject {
    struct Reading: Sendable {
        let id: UUID
        let beatsPerMinute: Double
        let startDate: Date
        let endDate: Date
        let receivedAt: Date
        let source: String
    }

    @Published private(set) var latest: Reading?
    @Published private(set) var isMonitoring = false
    @Published private(set) var isRequestingAccess = false
    @Published private(set) var status = "Not started"

    private let store = HKHealthStore()
    private var query: HKAnchoredObjectQuery?
    private var runID = UUID()

    func start() {
        guard !isMonitoring, !isRequestingAccess else { return }
        latest = nil
        guard HKHealthStore.isHealthDataAvailable() else {
            status = "HealthKit unavailable"
            return
        }
        runID = UUID()
        let currentRun = runID
        let type = HKQuantityType(.heartRate)
        isMonitoring = true
        isRequestingAccess = true
        status = "Requesting read access"

        Task { [weak self] in
            guard let self else { return }
            do {
                try await self.store.requestAuthorization(toShare: [], read: [type])
                self.isRequestingAccess = false
                guard self.isMonitoring, self.runID == currentRun else { return }
                // Completing authorization does not prove read access was granted.
                self.beginQuery(type: type, currentRun: currentRun)
            } catch {
                self.isRequestingAccess = false
                guard self.runID == currentRun else { return }
                self.stop(reason: "Access request failed: \(error.localizedDescription)")
            }
        }
    }

    private func beginQuery(type: HKQuantityType, currentRun: UUID) {
        status = "Looking for readable samples"
        // No end date: new records remain eligible while this query is active.
        let predicate = HKQuery.predicateForSamples(
            withStart: Date().addingTimeInterval(-24 * 60 * 60),
            end: nil, options: .strictStartDate
        )
        let handler: @Sendable (HKAnchoredObjectQuery, [HKSample]?, [HKDeletedObject]?, HKQueryAnchor?, Error?) -> Void = {
            [weak self] _, samples, deleted, _, error in
            let receivedAt = Date()
            let message = error?.localizedDescription
            let removedIDs = Set((deleted ?? []).map(\.uuid))
            let sample = (samples ?? []).compactMap { $0 as? HKQuantitySample }
                .filter { !removedIDs.contains($0.uuid) }
                .max { $0.endDate < $1.endDate }
            let reading = sample.map {
                Reading(id: $0.uuid,
                        beatsPerMinute: $0.quantity.doubleValue(for: HKUnit.count().unitDivided(by: .minute())),
                        startDate: $0.startDate, endDate: $0.endDate,
                        receivedAt: receivedAt, source: $0.sourceRevision.source.name)
            }
            Task { @MainActor [weak self] in
                guard let self, self.isMonitoring, self.runID == currentRun else { return }
                if let message {
                    self.latest = nil
                    self.stop(reason: "Read error: \(message)")
                    return
                }
                if let latest = self.latest, removedIDs.contains(latest.id) {
                    self.latest = nil
                    // Rebuild the snapshot rather than falsely claiming the store
                    // is empty when an older readable record may still exist.
                    if let query = self.query { self.store.stop(query) }
                    self.runID = UUID()
                    self.beginQuery(type: HKQuantityType(.heartRate), currentRun: self.runID)
                    return
                }
                if let reading, reading.endDate >= (self.latest?.endDate ?? .distantPast) {
                    self.latest = reading
                }
                self.status = self.latest == nil
                    ? "No readable samples in this run's query window"
                    : "Watching for stored updates"
            }
        }
        let query = HKAnchoredObjectQuery(type: type, predicate: predicate,
                                         anchor: nil, limit: HKObjectQueryNoLimit,
                                         resultsHandler: handler)
        query.updateHandler = handler
        self.query = query
        store.execute(query)
    }

    func stop(reason: String = "Stopped") {
        runID = UUID()
        if let query {
            store.stop(query)
        }
        query = nil
        isMonitoring = false
        status = reason
        // An OS permission sheet can outlive Stop. Its completion clears this flag.
        // While it is pending, start() refuses to launch another permission request.
    }
}
