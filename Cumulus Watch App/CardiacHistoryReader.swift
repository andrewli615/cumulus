import Combine
import Foundation
import HealthKit

enum CardiacKind: String, CaseIterable, Identifiable, Sendable {
    case heartRate, hrv, heartbeatSeries

    var id: String { rawValue }
    var title: String {
        switch self {
        case .heartRate: return "Heart rate"
        case .hrv: return "HRV · SDNN"
        case .heartbeatSeries: return "Heartbeat series"
        }
    }
    var limit: Int {
        switch self {
        case .heartRate: return 2000
        case .hrv: return 500
        case .heartbeatSeries: return 50
        }
    }
    var sampleType: HKSampleType {
        switch self {
        case .heartRate: return HKQuantityType(.heartRate)
        case .hrv: return HKQuantityType(.heartRateVariabilitySDNN)
        case .heartbeatSeries: return HKSeriesType.heartbeat()
        }
    }
}

struct CardiacRecord: Identifiable, Sendable {
    let id: UUID
    let start: Date
    let end: Date
    let source: String
    let sourceIdentifier: String
    let value: Double?
    let count: Int
}

struct CardiacSourceCoverage: Identifiable, Sendable {
    let source: String
    let sourceIdentifier: String
    let recordCount: Int
    let groupedRecordCount: Int
    let firstStart: Date
    let latestEnd: Date
    let largestUncoveredInterval: TimeInterval

    var id: String { sourceIdentifier + "|" + source }
}

struct CardiacSnapshot: Sendable {
    let records: [CardiacRecord]
    let isTruncated: Bool
    let readAt: Date?
    let error: String?
    let rejectedRecords: Int

    func coverage(start: Date, end: Date) -> [CardiacSourceCoverage] {
        let groups = Dictionary(grouping: records) { $0.sourceIdentifier + "|" + $0.source }
        return groups.values.map { rows in
            let sorted = rows.sorted { $0.start < $1.start }
            var cursor = start
            var largestGap: TimeInterval = 0
            for row in sorted {
                let lower = max(start, row.start)
                let upper = min(end, row.end)
                largestGap = max(largestGap, lower.timeIntervalSince(cursor))
                cursor = max(cursor, upper)
            }
            largestGap = max(largestGap, end.timeIntervalSince(cursor))
            return CardiacSourceCoverage(source: sorted[0].source, sourceIdentifier: sorted[0].sourceIdentifier,
                recordCount: rows.count, groupedRecordCount: rows.filter { $0.count > 1 }.count,
                firstStart: sorted[0].start, latestEnd: rows.map(\.end).max()!,
                largestUncoveredInterval: max(0, largestGap))
        }.sorted { $0.id < $1.id }
    }
}

@MainActor
final class CardiacHistoryReader: ObservableObject {
    @Published private(set) var snapshots: [CardiacKind: CardiacSnapshot] = [:]
    @Published private(set) var status = "Tap Read / Refresh to inspect stored cardiac records."
    @Published private(set) var isLoading = false
    @Published private(set) var isRequestingAccess = false
    @Published private(set) var windowStart: Date?
    @Published private(set) var windowEnd: Date?

    var testArchive: TestArchiveStore?
    private var reportStartedAt: Date?
    private let store = HKHealthStore()
    private var queries: [CardiacKind: HKSampleQuery] = [:]
    private var requestID = UUID()

    func refresh() {
        guard !isLoading, !isRequestingAccess else { return }
        guard testArchive?.canStartNewReport != false else { status = "New read blocked: archive needs free storage"; return }
        clear()
        reportStartedAt = Date()
        guard HKHealthStore.isHealthDataAvailable() else {
            status = "HealthKit unavailable on this device"
            saveReport()
            reportStartedAt = nil
            return
        }
        let end = Date()
        let start = end.addingTimeInterval(-24 * 60 * 60)
        windowStart = start
        windowEnd = end
        let request = requestID
        isLoading = true
        isRequestingAccess = true
        status = "Requesting cardiac read access"
        saveReport()
        Task { [weak self] in
            guard let self else { return }
            do {
                try await self.store.requestAuthorization(toShare: [], read: Set(CardiacKind.allCases.map(\.sampleType)))
                self.isRequestingAccess = false
                guard self.requestID == request else { return }
                self.status = "Reading stored records"
                for kind in CardiacKind.allCases {
                    self.read(kind: kind, start: start, end: end, request: request)
                }
            } catch {
                self.isRequestingAccess = false
                guard self.requestID == request else { return }
                self.isLoading = false
                self.status = "Access request failed: \(error.localizedDescription)"
                self.saveReport()
                self.reportStartedAt = nil
            }
        }
    }

    private func read(kind: CardiacKind, start: Date, end: Date, request: UUID) {
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: [])
        let query = HKSampleQuery(sampleType: kind.sampleType, predicate: predicate, limit: kind.limit + 1,
            sortDescriptors: [NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)]) {
                @Sendable [weak self] _, samples, error in
                let message = error?.localizedDescription
                let rows = (samples ?? []).compactMap { sample -> CardiacRecord? in
                    let value: Double?
                    let count: Int
                    if kind == .heartbeatSeries {
                        guard let series = sample as? HKHeartbeatSeriesSample else { return nil }
                        value = nil
                        count = Int(series.count)
                    } else {
                        guard let quantity = sample as? HKQuantitySample else { return nil }
                        let unit = kind == .heartRate ? HKUnit.count().unitDivided(by: .minute()) : HKUnit.secondUnit(with: .milli)
                        value = quantity.quantity.doubleValue(for: unit)
                        count = quantity.count
                    }
                    guard sample.startDate.timeIntervalSince1970.isFinite,
                          sample.endDate.timeIntervalSince1970.isFinite,
                          sample.startDate <= sample.endDate,
                          sample.startDate <= end, sample.endDate >= start,
                          value?.isFinite != false, count >= 0 else { return nil }
                    return CardiacRecord(id: sample.uuid, start: sample.startDate, end: sample.endDate,
                        source: sample.sourceRevision.source.name,
                        sourceIdentifier: sample.sourceRevision.source.bundleIdentifier, value: value, count: count)
                }
                let snapshot = CardiacSnapshot(records: message == nil ? Array(rows.prefix(kind.limit)) : [],
                    isTruncated: (samples?.count ?? 0) > kind.limit,
                    readAt: message == nil ? Date() : nil, error: message,
                    rejectedRecords: message == nil ? (samples?.count ?? 0) - rows.count : 0)
                Task { @MainActor [weak self] in
                    guard let self, self.requestID == request else { return }
                    self.queries[kind] = nil
                    self.snapshots[kind] = snapshot
                    if self.snapshots.count == CardiacKind.allCases.count {
                        self.isLoading = false
                        self.status = self.snapshots.values.contains { $0.error != nil }
                            ? "Read finished with errors; inspect each type"
                            : "Historical snapshot ready"
                        self.saveReport()
                        self.reportStartedAt = nil
                    }
                }
            }
        queries[kind] = query
        store.execute(query)
    }

    private func saveReport() {
        guard let start = reportStartedAt else { return }
        var metrics = ["Individual health records saved": "No",
            "Query window start (Unix seconds)": windowStart.map { String($0.timeIntervalSince1970) } ?? "Unknown",
            "Query window end (Unix seconds)": windowEnd.map { String($0.timeIntervalSince1970) } ?? "Unknown"]
        for kind in CardiacKind.allCases {
            guard let snapshot = snapshots[kind] else { metrics[kind.title + " result"] = "Not completed"; continue }
            metrics[kind.title + " records"] = String(snapshot.records.count)
            metrics[kind.title + " grouped records"] = String(snapshot.records.filter { $0.count > 1 }.count)
            metrics[kind.title + " truncated"] = String(snapshot.isTruncated)
            metrics[kind.title + " rejected"] = String(snapshot.rejectedRecords)
            metrics[kind.title + " error"] = snapshot.error == nil ? "None reported" : "Reported; details remain in memory"
        }
        let report = TestReport(id: "cardiac-" + requestID.uuidString.lowercased(), kind: .cardiac,
            createdAt: start, title: "Cardiac history read", status: String(status.prefix(500)), metrics: metrics)
        testArchive?.save(report)
    }

    func clear() {
        if reportStartedAt != nil {
            status = "Read cancelled; in-memory records cleared"
            saveReport()
            reportStartedAt = nil
        }
        requestID = UUID()
        for query in queries.values { store.stop(query) }
        queries = [:]
        snapshots = [:]
        windowStart = nil
        windowEnd = nil
        isLoading = false
        status = "Records cleared; tap Read / Refresh"
    }
}
