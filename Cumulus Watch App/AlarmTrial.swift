import Foundation

enum AlarmTrialError: Error { case invalid, conflict }

/// Software evidence and owner observations are deliberately separate. Neither certifies waking.
struct AlarmTrial: Codable, Sendable {
    enum Answer: String, Codable, Sendable, CaseIterable {
        case unknown, yes, no
        var title: String { rawValue.capitalized }
    }
    enum Kind: String, Codable, Sendable, CaseIterable {
        case unspecified, short, edit, cancellation, overnight
        var title: String { rawValue.capitalized }
    }
    struct BatteryReading: Codable, Sendable, Equatable {
        let percent: Int
        let observedAt: Date
    }
    struct Observations: Codable, Sendable, Equatable {
        var kind = Kind.unspecified
        var feltHaptic = Answer.unknown
        var sawAlert = Answer.unknown
        var oldTimeSilent = Answer.unknown
        var stopWorked = Answer.unknown
        var duplicates = Answer.unknown
        var debuggerDetached = Answer.unknown
        var sleepFocus = Answer.unknown
        var hapticsEnabled = Answer.unknown
        var charged = Answer.unknown
        var interrupted = Answer.unknown
        var startBattery: BatteryReading?
        var endBattery: BatteryReading?
        var settingsNote = ""

        func validate() throws {
            guard settingsNote.count <= 200 else { throw AlarmTrialError.invalid }
            for reading in [startBattery, endBattery].compactMap({ $0 }) {
                guard (0...100).contains(reading.percent), reading.observedAt.timeIntervalSince1970.isFinite else {
                    throw AlarmTrialError.invalid
                }
            }
            if let startBattery, let endBattery, endBattery.observedAt < startBattery.observedAt {
                throw AlarmTrialError.invalid
            }
        }
    }

    let schemaVersion: Int
    let alarmID: UUID
    let fireDate: Date
    let requestedAt: Date
    let origin: AlarmRecord.Origin?
    let replacesAlarmID: UUID?
    let firstCapturedAt: Date
    private(set) var lastCapturedAt: Date
    private(set) var phase: AlarmRecord.Phase
    private(set) var requestedReplacementDate: Date?
    private(set) var events: [AlarmRecord.Event]
    private(set) var historyTruncated = false
    private(set) var clockUncertain = false
    private(set) var observations = Observations()
    private(set) var observationsUpdatedAt: Date?
    private(set) var observationsRevision: UUID?

    var reportID: String { "fixedalarm-" + alarmID.uuidString.lowercased() }
    var historyDescription: String {
        if historyTruncated { return "History truncated to the latest 40 events for this alarm" }
        if !events.contains(where: { $0.message == "Schedule requested" }) {
            return "Partial history: no schedule-request event retained"
        }
        return "Captured from schedule request; unrecorded callbacks cannot be ruled out"
    }
    var hapticOffsets: [Double] {
        events.filter { $0.message.hasPrefix("Haptic requested (") }.map { $0.date.timeIntervalSince(fireDate) }
    }

    init(record: AlarmRecord, capturedAt: Date) throws {
        try record.validate()
        schemaVersion = 1
        alarmID = record.id
        fireDate = record.fireDate
        requestedAt = record.createdAt
        origin = record.origin
        replacesAlarmID = record.replacesAlarmID
        firstCapturedAt = capturedAt
        lastCapturedAt = capturedAt
        phase = record.phase
        requestedReplacementDate = record.replacementFireDate
        events = record.events.filter { $0.alarmID == record.id }
        try validate()
    }

    @discardableResult
    mutating func merge(_ record: AlarmRecord, capturedAt: Date) throws -> Bool {
        try record.validate()
        guard record.id == alarmID, record.fireDate == fireDate, record.createdAt == requestedAt,
              record.origin == origin, record.replacesAlarmID == replacesAlarmID,
              capturedAt.timeIntervalSince1970.isFinite else { throw AlarmTrialError.invalid }
        let incoming = record.events.filter { $0.alarmID == alarmID }
        for event in incoming {
            if let old = events.first(where: { $0.id == event.id }), old != event { throw AlarmTrialError.invalid }
        }
        let newEvents = incoming.filter { event in !events.contains { $0.id == event.id } }
        // Replayed snapshots cannot regress a completed phase or rewrite owner observations.
        guard !newEvents.isEmpty else { return false }
        if capturedAt < lastCapturedAt { clockUncertain = true }
        for event in newEvents {
            if let last = events.last, event.date < last.date { clockUncertain = true }
            events.append(event)
        }
        if events.count > 40 { historyTruncated = true; events = Array(events.suffix(40)) }
        phase = record.phase
        if let replacement = record.replacementFireDate { requestedReplacementDate = replacement }
        lastCapturedAt = capturedAt
        try validate()
        return true
    }

    mutating func setObservations(_ value: Observations, expectedRevision: UUID?, at date: Date) throws {
        guard expectedRevision == observationsRevision else { throw AlarmTrialError.conflict }
        try value.validate()
        guard date.timeIntervalSince1970.isFinite else { throw AlarmTrialError.invalid }
        if date < lastCapturedAt || observationsUpdatedAt.map({ date < $0 }) == true { clockUncertain = true }
        observations = value
        observationsUpdatedAt = date
        observationsRevision = UUID()
        try validate()
    }

    func validate() throws {
        let dates = [fireDate, requestedAt, firstCapturedAt, lastCapturedAt]
            + [observationsUpdatedAt, requestedReplacementDate].compactMap { $0 }
        guard (observationsUpdatedAt == nil) == (observationsRevision == nil),
              schemaVersion == 1, dates.allSatisfy({ $0.timeIntervalSince1970.isFinite }),
              replacesAlarmID != alarmID,
              origin.map({ [$0.build, $0.os, $0.timeZone].allSatisfy { $0.count <= 128 } }) != false,
              events.count <= 40, Set(events.map(\.id)).count == events.count,
              events.allSatisfy({ $0.alarmID == alarmID && $0.fireDate == fireDate
                  && $0.date.timeIntervalSince1970.isFinite && $0.message.count <= 500 }) else {
            throw AlarmTrialError.invalid
        }
        try observations.validate()
    }

    func report() throws -> TestReport {
        try validate()
        var report = TestReport(id: reportID, kind: .fixedAlarm, createdAt: requestedAt,
            title: "Fixed alarm trial", status: "Software: \(phase.rawValue); owner observations \(observationsUpdatedAt == nil ? "unrecorded" : "saved")",
            metrics: ["Original build": origin?.build ?? "Unknown", "Original watchOS": origin?.os ?? "Unknown",
                "Original time zone": origin?.timeZone ?? "Unknown", "History": historyDescription,
                "Felt haptic · owner report": observations.feltHaptic.title,
                "Visible alert · owner report": observations.sawAlert.title,
                "Timing uncertain": String(clockUncertain), "Date encoding": "Unix seconds (including nested events)"])
        report.events = events.map { .init(date: $0.date, message: $0.message) }
        report.diagnostics = try TestReport.encodeDiagnostics(self)
        return report
    }

    static func decode(_ report: TestReport) throws -> Self {
        try report.validate()
        guard report.kind == .fixedAlarm, let data = report.diagnostics else { throw AlarmTrialError.invalid }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .secondsSince1970
        let trial = try decoder.decode(Self.self, from: data)
        try trial.validate()
        guard report.id == trial.reportID, report.createdAt == trial.requestedAt else { throw AlarmTrialError.invalid }
        return trial
    }
}
