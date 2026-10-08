import Combine
import Foundation

struct CardiacTimingSelection: Sendable, Hashable {
    enum Kind: String, Sendable, Hashable { case groupedHeartRate, heartbeatSeries }
    let id: UUID
    let kind: Kind
    let count: Int
    let start: Date
    let end: Date
    var canInspect: Bool {
        count > (kind == .groupedHeartRate ? 1 : 0) && count <= CardiacTimingSummary.maximumEntries
            && start.timeIntervalSince1970.isFinite
            && end.timeIntervalSince1970.isFinite && end >= start
    }
}

struct CardiacTimingSummary: Sendable {
    var received = 0
    var accepted = 0
    var invalid = 0
    var orderAnomalies = 0
    var gapFlags = 0
    var spacingPairs = 0
    var first: Double?
    var last: Double?
    var minimumSpacing: Double?
    var maximumSpacing: Double?
    var limitReached = false
    var enumerationCompleted = false
    private var canJoinPrevious = false
    static let maximumEntries = 20_000

    mutating func receive(offset: Double, duration: Double, intervalDuration: Double = 0,
                          precededByGap: Bool = false, valueFinite: Bool = true, positiveOffset: Bool = false) {
        guard received < Self.maximumEntries else { limitReached = true; return }
        received += 1
        let canJoin = canJoinPrevious
        canJoinPrevious = false
        if precededByGap { gapFlags += 1 }
        guard offset.isFinite, duration.isFinite, intervalDuration.isFinite, duration >= 0,
              offset >= 0, (!positiveOffset || offset > 0), intervalDuration >= 0,
              offset + intervalDuration <= duration + 0.001, valueFinite else { invalid += 1; return }
        if let last, offset <= last { orderAnomalies += 1; return }
        if let last, canJoin, !precededByGap {
            let spacing = offset - last
            minimumSpacing = min(minimumSpacing ?? spacing, spacing)
            maximumSpacing = max(maximumSpacing ?? spacing, spacing)
            spacingPairs += 1
        }
        first = first ?? offset
        last = offset
        accepted += 1
        canJoinPrevious = true
    }

    func metrics(for kind: CardiacTimingSelection.Kind) -> [String: String] {
        var result = metrics
        if kind == .groupedHeartRate { result["Preceded-by-gap flags"] = "Not provided by quantity-series API" }
        return result
    }

    var metrics: [String: String] {
        ["Entries inspected": String(received), "Valid entries": String(accepted),
         "Invalid entries": String(invalid), "Order anomalies": String(orderAnomalies),
         "Preceded-by-gap flags": String(gapFlags), "Adjacent valid spacing pairs": String(spacingPairs),
         "Minimum contiguous spacing (s)": minimumSpacing.map { String($0) } ?? "Unknown",
         "Maximum contiguous spacing (s)": maximumSpacing.map { String($0) } ?? "Unknown",
         "Observed offset span (s)": first.flatMap { lower in last.map { String($0 - lower) } } ?? "Unknown",
         "Enumeration completed": String(enumerationCompleted), "Entry limit reached": String(limitReached)]
    }
}

@MainActor
protocol CardiacTimingQuerying {
    func inspect(_ selection: CardiacTimingSelection,
                 progress: @escaping @MainActor (CardiacTimingSummary) -> Void) async throws -> CardiacTimingSummary
}

@MainActor
final class CardiacTimingReader: ObservableObject {
    @Published private(set) var summary: CardiacTimingSummary?
    @Published private(set) var status = "Inspect only a record found by Cardiac history."
    @Published private(set) var isReading = false
    @Published private(set) var errorMessage: String?
    private let query: any CardiacTimingQuerying
    private let archive: TestArchiveStore?
    private let canRead: () -> Bool
    private let timeout: Duration
    private var task: Task<Void, Never>?
    private var timeoutTask: Task<Void, Never>?
    private var requestID: UUID?
    private var startedAt: Date?
    private var selection: CardiacTimingSelection?

    init(query: any CardiacTimingQuerying, archive: TestArchiveStore? = nil, canRead: @escaping () -> Bool = { true }, timeout: Duration = .seconds(60)) {
        self.query = query
        self.archive = archive
        self.canRead = canRead
        self.timeout = timeout
    }

    func read(_ selection: CardiacTimingSelection) {
        guard !isReading, canRead(), selection.canInspect, archive?.canStartNewReport != false else { status = "Read blocked: eligible record, free archive space, and no pending experiment required"; return }
        let id = UUID()
        self.selection = selection
        requestID = id
        startedAt = Date()
        summary = CardiacTimingSummary()
        errorMessage = nil
        isReading = true
        status = "Inspecting stored internal timing"
        saveReport()
        let timeout = self.timeout
        timeoutTask = Task { [weak self] in
            do { try await Task.sleep(for: timeout) } catch { return }
            guard let self, self.requestID == id else { return }
            self.status = "Inspection timed out; last checkpoint is partial"
            self.saveReport()
            self.requestID = nil
            self.task?.cancel()
            self.task = nil
            self.timeoutTask = nil
            self.isReading = false
        }
        task = Task { [weak self] in
            guard let self else { return }
            do {
                let result = try await query.inspect(selection) { [weak self] partial in
                    guard let self, self.requestID == id, self.canRead() else { return }
                    self.summary = partial
                }
                guard requestID == id else { return }
                guard !Task.isCancelled, canRead() else { clear(); return }
                timeoutTask?.cancel()
                timeoutTask = nil
                summary = result
                isReading = false
                task = nil
                status = result.limitReached ? "Entry limit reached; partial diagnostic summary"
                    : result.received == 0 ? "No readable internal entries; access or data absence unknown"
                    : result.enumerationCompleted ? "Enumeration completed; review count and anomalies" : "Enumeration incomplete"
                saveReport()
                requestID = nil
            } catch {
                guard requestID == id else { return }
                timeoutTask?.cancel()
                timeoutTask = nil
                errorMessage = error.localizedDescription
                isReading = false
                task = nil
                status = Task.isCancelled ? "Inspection cancelled" : "Inspection failed; no complete result"
                saveReport()
                requestID = nil
            }
        }
    }

    func clear() {
        if isReading {
            status = "Inspection cancelled; last checkpoint is partial"
            saveReport()
        }
        requestID = nil
        task?.cancel()
        task = nil
        timeoutTask?.cancel()
        timeoutTask = nil
        isReading = false
        summary = nil
        errorMessage = nil
        selection = nil
        startedAt = nil
        status = "Internal timing cleared; diagnostic report retained"
    }

    private func saveReport() {
        guard let id = requestID, let startedAt, let selection else { return }
        var metrics = summary?.metrics(for: selection.kind) ?? [:]
        metrics["Record kind"] = selection.kind.rawValue
        metrics["Declared entry count"] = String(selection.count)
        metrics["Received count matches declared"] = summary?.enumerationCompleted == true ? String(summary?.received == selection.count) : "Unknown; enumeration incomplete"
        metrics["Accepted count matches declared"] = summary?.enumerationCompleted == true ? String(summary?.accepted == selection.count) : "Unknown; enumeration incomplete"
        metrics["Individual values, dates and identifiers saved"] = "No"
        metrics["Night-time availability"] = "Unknown; this is a retrospective inspection"
        archive?.save(TestReport(id: "cardiac-" + id.uuidString.lowercased(), kind: .cardiac,
            createdAt: startedAt, title: "Cardiac internal timing", status: status, metrics: metrics))
    }
}
