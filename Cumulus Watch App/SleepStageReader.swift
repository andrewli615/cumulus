import Combine
import Foundation
import HealthKit

struct SleepInterval: Identifiable, Sendable {
    let id: UUID
    let categoryValue: Int
    let start: Date
    let end: Date
    let source: String
    let sourceIdentifier: String

    var category: String {
        switch HKCategoryValueSleepAnalysis(rawValue: categoryValue) {
        case .inBed: return "In bed"
        case .awake: return "Awake"
        case .asleepUnspecified: return "Asleep (unspecified)"
        case .asleepCore: return "Core"
        case .asleepDeep: return "Deep"
        case .asleepREM: return "REM"
        default: return "Unknown category (\(categoryValue))"
        }
    }
}

@MainActor
final class SleepStageReader: ObservableObject {
    @Published private(set) var intervals: [SleepInterval] = []
    @Published private(set) var status = "Tap Read / Refresh to inspect stored sleep records."
    @Published private(set) var isLoading = false
    @Published private(set) var isRequestingAccess = false
    @Published private(set) var windowStart: Date?
    @Published private(set) var windowEnd: Date?
    @Published private(set) var refreshedAt: Date?
    @Published private(set) var isTruncated = false

    var testArchive: TestArchiveStore?
    private var reportStartedAt: Date?
    private let store = HKHealthStore()
    private var query: HKSampleQuery?
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
        guard let start = Calendar.current.date(byAdding: .day, value: -7, to: end) else {
            status = "Could not determine the query window"
            return
        }
        windowStart = start
        windowEnd = end
        let currentRequest = requestID
        let type = HKCategoryType(.sleepAnalysis)
        isLoading = true
        isRequestingAccess = true
        status = "Requesting sleep read access"
        saveReport()
        Task { [weak self] in
            guard let self else { return }
            do {
                try await self.store.requestAuthorization(toShare: [], read: [type])
                self.isRequestingAccess = false
                guard self.requestID == currentRequest else { return }
                self.read(type: type, start: start, end: end, request: currentRequest)
            } catch {
                self.isRequestingAccess = false
                guard self.requestID == currentRequest else { return }
                self.isLoading = false
                self.status = "Access request failed: \(error.localizedDescription)"
                self.saveReport()
                self.reportStartedAt = nil
            }
        }
    }

    private func read(type: HKCategoryType, start: Date, end: Date, request: UUID) {
        status = "Reading stored intervals"
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: [])
        let query = HKSampleQuery(sampleType: type, predicate: predicate, limit: 501,
            sortDescriptors: [NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)]) {
                @Sendable [weak self] _, samples, error in
                let message = error?.localizedDescription
                let rows = (samples ?? []).compactMap { $0 as? HKCategorySample }.map {
                    SleepInterval(id: $0.uuid, categoryValue: $0.value, start: $0.startDate,
                                  end: $0.endDate, source: $0.sourceRevision.source.name,
                                  sourceIdentifier: $0.sourceRevision.source.bundleIdentifier)
                }
                let received = Date()
                Task { @MainActor [weak self] in
                    guard let self, self.requestID == request else { return }
                    self.query = nil
                    self.isLoading = false
                    if let message {
                        self.status = "Read error: \(message)"
                        self.saveReport()
                        self.reportStartedAt = nil
                        return
                    }
                    self.intervals = Array(rows.prefix(500))
                    self.isTruncated = rows.count > 500
                    self.refreshedAt = received
                    self.status = rows.isEmpty ? "No readable sleep records in this window"
                        : "Historical snapshot; \(self.intervals.count) intervals shown"
                    self.saveReport()
                    self.reportStartedAt = nil
                }
            }
        self.query = query
        store.execute(query)
    }

    private func saveReport() {
        guard let start = reportStartedAt else { return }
        let report = TestReport(id: "sleep-" + requestID.uuidString.lowercased(), kind: .sleep,
            createdAt: start, title: "Sleep history read", status: String(status.prefix(500)),
            metrics: ["Readable interval count": String(intervals.count), "Truncated": String(isTruncated),
                "Query window start (Unix seconds)": windowStart.map { String($0.timeIntervalSince1970) } ?? "Unknown",
                "Query window end (Unix seconds)": windowEnd.map { String($0.timeIntervalSince1970) } ?? "Unknown",
                "Individual health records saved": "No"])
        testArchive?.save(report)
    }

    func clear() {
        if reportStartedAt != nil {
            status = "Read cancelled; in-memory records cleared"
            saveReport()
            reportStartedAt = nil
        }
        requestID = UUID()
        if let query { store.stop(query) }
        query = nil
        intervals = []
        windowStart = nil
        windowEnd = nil
        refreshedAt = nil
        isTruncated = false
        isLoading = false
        status = "Records cleared; tap Read / Refresh"
    }
}
