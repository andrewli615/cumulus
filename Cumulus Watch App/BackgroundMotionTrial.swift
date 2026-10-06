import Foundation

struct MotionSampleSummary: Codable, Sendable {
    struct Bucket: Codable, Identifiable, Sendable {
        let id: Int
        var count = 0
        var first: TimeInterval?
        var last: TimeInterval?
        var firstReceipt: TimeInterval?
        var lastReceipt: TimeInterval?
        var maximumGap: TimeInterval = 0
        var maximumDelay: TimeInterval = 0
    }

    let start: TimeInterval
    var buckets = (0..<12).map { Bucket(id: $0) }
    var count = 0
    var first: TimeInterval?
    var last: TimeInterval?
    var maximumGap: TimeInterval = 0
    var maximumDelay: TimeInterval = 0
    var duplicatesOrOutOfOrder = 0
    var outsideWindow = 0
    var clockInvalid = false
    var stoppedAt: TimeInterval?
    var error: String?

    mutating func receive(timestamp: TimeInterval, receipt: TimeInterval) {
        guard stoppedAt == nil else { return }
        guard timestamp.isFinite, receipt.isFinite, timestamp <= receipt,
              receipt >= start else {
            clockInvalid = true
            return
        }
        let offset = timestamp - start
        guard offset >= 0, offset < 60, receipt < start + 60 else {
            outsideWindow += 1
            return
        }
        if let last, timestamp <= last {
            duplicatesOrOutOfOrder += 1
            return
        }
        let index = Int(offset / 5)
        let gap = last.map { timestamp - $0 } ?? 0
        let delay = receipt - timestamp
        first = first ?? timestamp
        last = timestamp
        count += 1
        maximumGap = max(maximumGap, gap)
        maximumDelay = max(maximumDelay, delay)
        buckets[index].count += 1
        buckets[index].first = buckets[index].first ?? timestamp
        buckets[index].last = timestamp
        buckets[index].firstReceipt = buckets[index].firstReceipt ?? receipt
        buckets[index].lastReceipt = receipt
        buckets[index].maximumGap = max(buckets[index].maximumGap, gap)
        buckets[index].maximumDelay = max(buckets[index].maximumDelay, delay)
    }

    var startupDelay: TimeInterval? { first.map { $0 - start } }
    var trailingGap: TimeInterval? { last.map { start + 60 - $0 } }
    var stopOvershoot: TimeInterval? { stoppedAt.map { $0 - (start + 60) } }

    func status(now: TimeInterval) -> String {
        if error != nil { return "Motion error" }
        if stoppedAt != nil { return "Collection stopped" }
        guard now >= start, !clockInvalid else { return "Sample clock uncertain" }
        guard let last else { return now - start > 2 ? "Samples stale; none received" : "Waiting for samples" }
        return now - last > 2 ? "Samples stale" : "Samples arriving"
    }

    var meetsSampleCriteria: Bool {
        guard !clockInvalid, error == nil, duplicatesOrOutOfOrder == 0,
              let startupDelay, let trailingGap else { return false }
        return buckets.allSatisfy { $0.count >= 40 }
            && startupDelay <= 2 && trailingGap <= 2
            && maximumGap <= 2 && maximumDelay <= 2
    }
}

// Core Motion writes on its queue; the coordinator snapshots on MainActor.
// All mutable state is protected by this lock. No acceleration values are stored.
final class BackgroundMotionAccumulator: @unchecked Sendable {
    private let lock = NSLock()
    private var summary: MotionSampleSummary

    init(start: TimeInterval) { summary = MotionSampleSummary(start: start) }

    func receive(timestamp: TimeInterval, receipt: TimeInterval) {
        lock.lock()
        defer { lock.unlock() }
        summary.receive(timestamp: timestamp, receipt: receipt)
    }

    func fail(_ message: String, at uptime: TimeInterval) {
        lock.lock()
        defer { lock.unlock() }
        guard summary.stoppedAt == nil else { return }
        summary.error = message
        summary.stoppedAt = uptime
    }

    func snapshot() -> MotionSampleSummary {
        lock.lock()
        defer { lock.unlock() }
        return summary
    }

    func stop(at uptime: TimeInterval) -> MotionSampleSummary {
        lock.lock()
        defer { lock.unlock() }
        if summary.stoppedAt == nil { summary.stoppedAt = uptime }
        return summary
    }
}

struct BackgroundMotionTrial: Codable, Identifiable, Sendable {
    enum Phase: String, Codable { case scheduled, collecting, stopped, interrupted }
    struct Configuration: Codable, Sendable {
        var watchModel = ""
        var watchOS = "Unknown"
        var appBuild = "Unknown"
        var powerMode = "Unknown"
        var wristState = "Unknown"
        var debuggerDetached = "Unknown"
        var condition = "Digital Crown"
        var otherApp = ""

        var isComplete: Bool {
            !watchModel.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                && watchOS != "Unknown" && appBuild != "Unknown"
                && powerMode != "Unknown" && wristState != "Unknown"
                && debuggerDetached == "Yes"
                && (condition != "Another app" || !otherApp.isEmpty)
        }
    }
    struct Event: Codable, Identifiable, Sendable {
        let id: UUID
        let date: Date
        let uptime: TimeInterval
        let message: String
    }

    let id: UUID
    let requestedStart: Date
    let configuration: Configuration
    var phase = Phase.scheduled
    var unresolvedSession = true
    var hapticRequested = false
    var collectionDate: Date?
    var samples: MotionSampleSummary?
    var backgroundThroughoutWindow = false
    var clockDiscontinuity = false
    var stopReason: String?
    var batteryStart: Float?
    var batteryEnd: Float?
    var events: [Event] = []
    var eventsTruncated = false

    mutating func record(_ message: String, at date: Date, uptime: TimeInterval) {
        events.append(Event(id: UUID(), date: date, uptime: uptime, message: String(message.prefix(500))))
        if events.count > 40 {
            eventsTruncated = true
            events = Array(events.suffix(40))
        }
    }

    mutating func begin(at date: Date, uptime: TimeInterval, inBackground: Bool) {
        guard phase == .scheduled else { return }
        phase = .collecting
        collectionDate = date
        samples = MotionSampleSummary(start: uptime)
        backgroundThroughoutWindow = inBackground
        record("Collection started; app background: \(inBackground)", at: date, uptime: uptime)
    }

    mutating func observeClock(date: Date, uptime: TimeInterval) {
        guard let collectionDate, let samples, phase == .collecting else { return }
        if uptime < samples.start || abs(date.timeIntervalSince(collectionDate) - (uptime - samples.start)) > 1 {
            clockDiscontinuity = true
        }
    }

    mutating func stop(reason: String, at date: Date, uptime: TimeInterval) {
        guard phase == .collecting || phase == .scheduled else { return }
        if phase == .collecting, samples?.stoppedAt == nil { samples?.stoppedAt = uptime }
        phase = .stopped
        stopReason = reason
        record("Collection stopped: \(reason)", at: date, uptime: uptime)
    }

    mutating func recover(at date: Date, uptime: TimeInterval) {
        guard unresolvedSession, phase == .collecting else { return }
        phase = .interrupted
        stopReason = "Process interrupted; actual sensor stop time unknown"
        backgroundThroughoutWindow = false
        record("Interrupted collection; not restarted", at: date, uptime: uptime)
    }

    var measurementAssessment: String {
        if phase == .interrupted || clockDiscontinuity || eventsTruncated {
            return "Inconclusive: interrupted or incomplete evidence"
        }
        guard phase == .stopped else { return "Measurement pending" }
        guard configuration.isComplete, batteryStart != nil, batteryEnd != nil else {
            return "Inconclusive: missing trial metadata"
        }
        if configuration.condition == "Manual stop" {
            return "Manual-stop trial: inspect stop and invalidation events"
        }
        guard let samples, samples.stoppedAt != nil else { return "Inconclusive: no complete sample window" }
        guard backgroundThroughoutWindow, stopReason == "60-second window ended" else {
            return "Criteria not met: inspect lifecycle and stop reason"
        }
        return samples.meetsSampleCriteria
            ? "Sample thresholds met; review lifecycle and stop overshoot"
            : "Sample thresholds not met"
    }
}

struct BackgroundMotionArchive: Codable {
    var trials: [BackgroundMotionTrial] = []

    mutating func append(_ trial: BackgroundMotionTrial) {
        trials.append(trial)
        trials = Array(trials.suffix(5))
    }

    func validate() throws {
        guard trials.count <= 5, Set(trials.map(\.id)).count == trials.count,
              trials.filter(\.unresolvedSession).count <= 1,
              !trials.dropLast().contains(where: \.unresolvedSession),
              trials.allSatisfy({ $0.events.count <= 40 && ($0.samples == nil || $0.samples?.buckets.map(\.id) == Array(0..<12)) }) else {
            throw CocoaError(.coderReadCorrupt)
        }
    }
}
