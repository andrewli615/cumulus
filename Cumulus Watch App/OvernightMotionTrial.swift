import Foundation

struct OvernightMotionSummary: Codable, Sendable {
    struct QueryPosition: Codable, Sendable {
        let queryIndex: Int
        let sampleIndex: Int
        let previousAcceptedQueryIndex: Int
    }
    struct OrderExample: Codable, Sendable {
        let relativeSeconds: TimeInterval
        let dateDelta: TimeInterval
        let sensorDelta: TimeInterval
        let position: QueryPosition?
    }
    struct OrderDiagnostics: Codable, Sendable {
        static let exampleLimit = 12
        var repeatedDates = 0
        var backwardDates = 0
        var repeatedSensorTimes = 0
        var backwardSensorTimes = 0
        var withinQuery = 0
        var acrossQueries = 0
        var unknownPosition = 0
        var examples: [OrderExample] = []
        var total: Int { withinQuery + acrossQueries + unknownPosition }

        mutating func record(relativeSeconds: TimeInterval, dateDelta: TimeInterval,
                             sensorDelta: TimeInterval, position: QueryPosition?) {
            if dateDelta == 0 { repeatedDates += 1 }
            else if dateDelta < 0 { backwardDates += 1 }
            if sensorDelta == 0 { repeatedSensorTimes += 1 }
            else if sensorDelta < 0 { backwardSensorTimes += 1 }
            if let position {
                if position.queryIndex == position.previousAcceptedQueryIndex { withinQuery += 1 }
                else { acrossQueries += 1 }
            } else { unknownPosition += 1 }
            if examples.count < Self.exampleLimit {
                examples.append(OrderExample(relativeSeconds: relativeSeconds, dateDelta: dateDelta,
                    sensorDelta: sensorDelta, position: position))
            }
        }

        func validate(duration: TimeInterval, expectedTotal: Int? = nil) throws {
            guard duration.isFinite, duration > 0, duration <= 28800,
                  [repeatedDates, backwardDates, repeatedSensorTimes, backwardSensorTimes,
                   withinQuery, acrossQueries, unknownPosition].allSatisfy({ (0...3_000_000).contains($0) }) else {
                throw OvernightArchiveError.invalid
            }
            guard total <= 3_000_000, expectedTotal == nil || total == expectedTotal,
                  repeatedDates + backwardDates <= total, repeatedSensorTimes + backwardSensorTimes <= total,
                  repeatedDates + backwardDates + repeatedSensorTimes + backwardSensorTimes >= total,
                  examples.count == min(Self.exampleLimit, total) else { throw OvernightArchiveError.invalid }
            for example in examples {
                guard example.relativeSeconds.isFinite, example.relativeSeconds >= 0, example.relativeSeconds < duration,
                      example.dateDelta.isFinite, abs(example.dateDelta) <= duration,
                      example.sensorDelta.isFinite, example.dateDelta <= 0 || example.sensorDelta <= 0 else {
                    throw OvernightArchiveError.invalid
                }
                if let position = example.position {
                    guard (1...Int(ceil(duration / 600))).contains(position.queryIndex), (1...3_000_000).contains(position.sampleIndex),
                          (1...position.queryIndex).contains(position.previousAcceptedQueryIndex) else {
                        throw OvernightArchiveError.invalid
                    }
                }
            }
            guard examples.filter({ $0.dateDelta == 0 }).count <= repeatedDates,
                  examples.filter({ $0.dateDelta < 0 }).count <= backwardDates,
                  examples.filter({ $0.sensorDelta == 0 }).count <= repeatedSensorTimes,
                  examples.filter({ $0.sensorDelta < 0 }).count <= backwardSensorTimes,
                  examples.filter({ $0.position == nil }).count <= unknownPosition,
                  examples.filter({ $0.position.map { $0.queryIndex == $0.previousAcceptedQueryIndex } == true }).count <= withinQuery,
                  examples.filter({ $0.position.map { $0.queryIndex != $0.previousAcceptedQueryIndex } == true }).count <= acrossQueries else {
                throw OvernightArchiveError.invalid
            }
        }
    }
    struct OrderAnomalyCounts: Codable, Sendable {
        var exactTimeRepeats = 0
        var dateOnly = 0
        var sensorTimeOnly = 0
        var bothTimes = 0
        var total: Int { exactTimeRepeats + dateOnly + sensorTimeOnly + bothTimes }
    }
    struct Bucket: Codable, Identifiable, Sendable {
        let id: Int
        var count = 0
        var first: Date?
        var last: Date?
        var maximumGap: TimeInterval = 0
        var invalid = 0
        var outOfOrder = 0
    }
    let start: Date
    let end: Date
    var buckets: [Bucket]
    var count = 0
    var first: Date?
    var last: Date?
    var firstUptime: TimeInterval?
    var lastUptime: TimeInterval?
    var maximumGap: TimeInterval = 0
    var invalid = 0
    var outOfOrder = 0
    var orderAnomalyCounts: OrderAnomalyCounts?
    var orderDiagnostics: OrderDiagnostics?
    var boundaryDuplicates = 0
    var outsideWindow = 0
    var nilChunks = 0
    var emptyChunks = 0
    var unexpectedObjects = 0
    var clockDiscontinuity = false
    var aborted = false

    init(start: Date, end: Date) {
        self.start = start
        self.end = end
        let duration = end.timeIntervalSince(start)
        let size = duration.isFinite && duration > 0 && duration <= 28800 ? Int(ceil(duration / 30)) : 0
        buckets = (0..<size).map { Bucket(id: $0) }
        orderAnomalyCounts = OrderAnomalyCounts()
        orderDiagnostics = OrderDiagnostics()
    }

    mutating func receive(date: Date, uptime: TimeInterval, axesFinite: Bool, chunkStart: Date,
                          position: QueryPosition? = nil) {
        guard date.timeIntervalSince1970.isFinite, uptime.isFinite, uptime >= 0, axesFinite else {
            invalid += 1
            if date.timeIntervalSince1970.isFinite, date >= start, date < end, !buckets.isEmpty {
                buckets[Int(date.timeIntervalSince(start) / 30)].invalid += 1
            }
            return
        }
        guard date >= start, date < end else { outsideWindow += 1; return }
        if date == last, uptime == lastUptime, date == chunkStart {
            boundaryDuplicates += 1
            return
        }
        if let last, let lastUptime, date <= last || uptime <= lastUptime {
            outOfOrder += 1
            if var diagnostics = orderDiagnostics {
                diagnostics.record(relativeSeconds: date.timeIntervalSince(start), dateDelta: date.timeIntervalSince(last),
                    sensorDelta: uptime - lastUptime, position: position)
                orderDiagnostics = diagnostics
            }
            if var counts = orderAnomalyCounts {
                if date == last, uptime == lastUptime { counts.exactTimeRepeats += 1 }
                else if date <= last, uptime <= lastUptime { counts.bothTimes += 1 }
                else if date <= last { counts.dateOnly += 1 }
                else { counts.sensorTimeOnly += 1 }
                orderAnomalyCounts = counts
            }
            if !buckets.isEmpty { buckets[Int(date.timeIntervalSince(start) / 30)].outOfOrder += 1 }
            return
        }
        if let first, let firstUptime,
           abs(date.timeIntervalSince(first) - (uptime - firstUptime)) > 1 {
            clockDiscontinuity = true
        }
        let gap = last.map { date.timeIntervalSince($0) } ?? 0
        let index = Int(date.timeIntervalSince(start) / 30)
        guard buckets.indices.contains(index) else { invalid += 1; return }
        buckets[index].count += 1
        buckets[index].first = buckets[index].first ?? date
        buckets[index].last = date
        buckets[index].maximumGap = max(buckets[index].maximumGap, gap)
        count += 1
        first = first ?? date
        firstUptime = firstUptime ?? uptime
        last = date
        lastUptime = uptime
        maximumGap = max(maximumGap, gap)
    }

    var leadingGap: TimeInterval? { first.map { $0.timeIntervalSince(start) } }
    var trailingGap: TimeInterval? { last.map { end.timeIntervalSince($0) } }
    var observedRate: Double? {
        guard let first, let last, last > first, count > 1 else { return nil }
        return Double(count - 1) / last.timeIntervalSince(first)
    }
    var qualifyingBuckets: Int { buckets.filter { $0.count >= 1350 }.count }
    var meetsTimingCriteria: Bool {
        guard let rate = observedRate, let leading = leadingGap, let trailing = trailingGap,
              !buckets.isEmpty else { return false }
        return Double(qualifyingBuckets) / Double(buckets.count) >= 0.95
            && (45...55).contains(rate) && maximumGap <= 2 && leading <= 5 && trailing <= 5
            && invalid == 0 && outOfOrder == 0 && unexpectedObjects == 0 && nilChunks == 0
            && !clockDiscontinuity && !aborted
    }
    var timingFailures: [String] {
        var failures: [String] = []
        if buckets.isEmpty || Double(qualifyingBuckets) / Double(buckets.count) < 0.95 { failures.append("Bucket coverage below 95%") }
        if let rate = observedRate {
            if !(45...55).contains(rate) { failures.append("Sample rate outside 45–55 Hz") }
        } else { failures.append("Sample rate unknown") }
        if maximumGap > 2 { failures.append("Largest gap exceeds 2 s") }
        if let leading = leadingGap {
            if leading > 5 { failures.append("Leading gap exceeds 5 s") }
        } else { failures.append("Leading gap unknown") }
        if let trailing = trailingGap {
            if trailing > 5 { failures.append("Trailing gap exceeds 5 s") }
        } else { failures.append("Trailing gap unknown") }
        if invalid > 0 { failures.append("Invalid samples") }
        if outOfOrder > 0 { failures.append("Sample order anomalies") }
        if unexpectedObjects > 0 { failures.append("Unexpected objects") }
        if nilChunks > 0 { failures.append("Nil retrieval chunks") }
        if clockDiscontinuity { failures.append("Sample clock discontinuity") }
        if aborted { failures.append("Enumeration incomplete") }
        return failures
    }

    func validate() throws {
        guard start.timeIntervalSince1970.isFinite, end.timeIntervalSince1970.isFinite,
              end > start, end.timeIntervalSince(start) <= 28800, buckets.count <= 960,
              buckets.count == Int(ceil(end.timeIntervalSince(start) / 30)),
              buckets.map(\.id) == Array(0..<buckets.count),
              (0...3_000_000).contains(count), buckets.allSatisfy({
                  (0...3_000_000).contains($0.count) && $0.maximumGap.isFinite && $0.maximumGap >= 0
                  && (0...3_000_000).contains($0.invalid) && (0...3_000_000).contains($0.outOfOrder)
              }),
              buckets.reduce(0, { $0 + $1.count }) == count, maximumGap.isFinite, maximumGap >= 0,
              [invalid, outOfOrder, boundaryDuplicates, outsideWindow, nilChunks, emptyChunks, unexpectedObjects].allSatisfy({ (0...3_000_000).contains($0) }),
              [first, last].compactMap({ $0 }).allSatisfy({ $0 >= start && $0 < end }),
              [firstUptime, lastUptime].compactMap({ $0 }).allSatisfy(\.isFinite),
              (count == 0 ? first == nil && last == nil && firstUptime == nil && lastUptime == nil
                  : first != nil && last != nil && firstUptime != nil && lastUptime != nil) else {
            throw OvernightArchiveError.invalid
        }
        if let counts = orderAnomalyCounts {
            guard [counts.exactTimeRepeats, counts.dateOnly, counts.sensorTimeOnly, counts.bothTimes]
                .allSatisfy({ (0...3_000_000).contains($0) }), counts.total == outOfOrder else {
                throw OvernightArchiveError.invalid
            }
        }
        if let diagnostics = orderDiagnostics {
            try diagnostics.validate(duration: end.timeIntervalSince(start), expectedTotal: outOfOrder)
            if let counts = orderAnomalyCounts {
                guard diagnostics.repeatedDates + diagnostics.backwardDates == counts.exactTimeRepeats + counts.dateOnly + counts.bothTimes,
                      diagnostics.repeatedSensorTimes + diagnostics.backwardSensorTimes == counts.exactTimeRepeats + counts.sensorTimeOnly + counts.bothTimes else {
                    throw OvernightArchiveError.invalid
                }
            }
        }
        for bucket in buckets {
            let bucketStart = start.addingTimeInterval(Double(bucket.id) * 30)
            let bucketEnd = min(end, bucketStart.addingTimeInterval(30))
            guard [bucket.first, bucket.last].compactMap({ $0 }).allSatisfy({ $0 >= bucketStart && $0 < bucketEnd }),
                  bucket.count == 0 ? bucket.first == nil && bucket.last == nil : bucket.first != nil && bucket.last != nil,
                  (bucket.first ?? bucketStart) <= (bucket.last ?? bucketEnd) else { throw OvernightArchiveError.invalid }
        }
        if let first, let last, let firstUptime, let lastUptime {
            guard first <= last, firstUptime >= 0, firstUptime <= lastUptime else { throw OvernightArchiveError.invalid }
        }
    }
}

struct OvernightMotionTrial: Codable, Identifiable, Sendable {
    enum Mode: String, Codable, CaseIterable, Identifiable, Sendable {
        case pilot, overnight, comparison
        var id: String { rawValue }
        var title: String {
            switch self { case .pilot: return "20-minute pilot"; case .overnight: return "8-hour recording"; case .comparison: return "8-hour comparison" }
        }
        var duration: TimeInterval { self == .pilot ? 1200 : 28800 }
    }
    enum Phase: String, Codable, Sendable { case prepared, requested, comparison, elapsed, uncertain }
    struct Configuration: Codable, Sendable, Equatable {
        var watchModel = "Unknown"
        var watchOS = "Unknown"
        var appBuild = "Unknown"
        var timeZone = "Unknown"
        var wrist = "Unknown"
        var powerMode = "Unknown"
        var sleepFocus = "Unknown"
        var sleepTracking = "Unknown"
        var debuggerDetached = "Unknown"
        var otherApp = "Unknown"
        var charging = "Unknown"
        var interruption = "Unknown"
    }
    struct Observation: Codable, Sendable {
        let pilotProbe: Bool
        let requestedAt: Date
        let completedAt: Date
        let count: Int
        let useful: Bool
        let first: Date?
        let last: Date?
        let nilChunks: Int
        let emptyChunks: Int
        let cancelled: Bool
        let error: String?
        var clockDiscontinuity: Bool?
        var orderDiagnostics: OvernightMotionSummary.OrderDiagnostics?
    }
    struct Event: Codable, Identifiable, Sendable {
        let id: UUID
        let date: Date
        let message: String
    }
    struct Battery: Codable, Sendable {
        let date: Date
        let level: Double?
    }
    struct RecorderCall: Codable, Sendable {
        let preparedAt: Date
        let preparedUptime: TimeInterval
        let returnedAt: Date
        let returnedUptime: TimeInterval
    }
    let id: UUID
    let mode: Mode
    var start: Date
    var end: Date
    var startUptime: TimeInterval
    var recorderCall: RecorderCall?
    var configuration: Configuration
    var phase: Phase
    var requestCount = 0
    var recovered = false
    var clockDiscontinuity = false
    var batteryStart: Battery
    var batteryReturn: Battery?
    var departure: Date?
    var fullSummary: OvernightMotionSummary?
    var fullReadAt: Date?
    var firstUsefulReadAt: Date?
    var latestProbe: Observation?
    var observations: [Observation] = []
    var firstUsefulProbeAt: Date?
    var precedingIncompleteProbeAt: Date?
    var events: [Event] = []
    var eventsTruncated = false

    init(mode: Mode, start: Date, uptime: TimeInterval, configuration: Configuration, battery: Double?) {
        id = UUID()
        self.mode = mode
        self.start = start
        end = start.addingTimeInterval(mode.duration)
        startUptime = uptime
        self.configuration = configuration
        phase = mode == .comparison ? .comparison : .prepared
        batteryStart = Battery(date: start, level: battery)
    }
    mutating func record(_ message: String, at date: Date = Date()) {
        events.append(Event(id: UUID(), date: date, message: String(message.prefix(400))))
        if events.count > 40 { events.removeFirst(events.count - 40); eventsTruncated = true }
    }
    var reservesWindow: Bool { phase != .elapsed }
    var reservationEnd: Date {
        max(end, recorderCall?.returnedAt.addingTimeInterval(mode.duration) ?? end)
    }
    var reservationEndUptime: TimeInterval { (recorderCall?.returnedUptime ?? startUptime) + mode.duration }
    var hasCompletedObservation: Bool {
        phase == .elapsed && (mode == .comparison ? batteryReturn != nil : fullSummary != nil && fullReadAt != nil)
    }
    func clockIsContinuous(now: Date, uptime: TimeInterval) -> Bool {
        let elapsed = uptime - startUptime
        return elapsed >= 0 && abs(now.timeIntervalSince(start) - elapsed) <= 5
    }
    var batteryDrop: Double? {
        guard let begin = batteryStart.level, let finish = batteryReturn?.level else { return nil }
        return (begin - finish) * 100
    }
    var pilotQualified: Bool {
        guard mode == .pilot, requestCount == 1, phase == .elapsed, !clockDiscontinuity,
              fullSummary?.meetsTimingCriteria == true, latestProbe?.useful == true,
              let observed = firstUsefulProbeAt else { return false }
        return observed >= start.addingTimeInterval(600) && observed <= start.addingTimeInterval(840)
    }
    var timingStatus: String {
        guard let summary = fullSummary else { return "No full-window retrieval yet" }
        return summary.meetsTimingCriteria && !clockDiscontinuity
            ? "Sample timing criteria met; review conditions" : "Sample timing criteria not met"
    }
    var morningVisibility: String {
        guard !clockDiscontinuity else { return "Clock/reboot uncertainty; visibility inconclusive" }
        guard let observed = firstUsefulReadAt else { return "No useful full-window observation" }
        return observed <= end.addingTimeInterval(300) ? "Observed useful by end + 5 minutes"
            : "Later observation; earlier availability unknown"
    }
}

enum OvernightArchiveError: Error { case invalid }

struct OvernightMotionArchive: Codable, Sendable {
    struct PilotEvidence: Codable, Sendable {
        let id: UUID
        let watchOS: String
        let appBuild: String
    }
    var trials: [OvernightMotionTrial] = []
    var pilotEvidence: PilotEvidence?

    mutating func append(_ trial: OvernightMotionTrial) {
        trials.append(trial)
        if trials.count > 3 { trials.removeFirst(trials.count - 3) }
        if trial.mode == .pilot { pilotEvidence = nil }
    }
    mutating func updatePilotEvidence() {
        if let trial = trials.last, trial.pilotQualified {
            pilotEvidence = PilotEvidence(id: trial.id, watchOS: trial.configuration.watchOS, appBuild: trial.configuration.appBuild)
        } else if let trial = trials.last, pilotEvidence?.id == trial.id {
            pilotEvidence = nil
        }
    }
    func validate() throws {
        guard trials.count <= 3, Set(trials.map(\.id)).count == trials.count,
              trials.filter(\.reservesWindow).count <= 1,
              !trials.dropLast().contains(where: \.reservesWindow) else { throw OvernightArchiveError.invalid }
        if let pilotEvidence {
            guard pilotEvidence.watchOS.count <= 128, pilotEvidence.appBuild.count <= 128 else { throw OvernightArchiveError.invalid }
        }
        for trial in trials {
            guard trial.start.timeIntervalSince1970.isFinite, trial.end == trial.start.addingTimeInterval(trial.mode.duration),
                  trial.startUptime.isFinite, trial.startUptime >= 0,
                  (0...1).contains(trial.requestCount), trial.events.count <= 40,
                  trial.observations.count <= 40,
                  trial.events.allSatisfy({ $0.date.timeIntervalSince1970.isFinite && $0.message.count <= 400 }),
                  [trial.batteryStart.level, trial.batteryReturn?.level].compactMap({ $0 }).allSatisfy({ $0.isFinite && (0...1).contains($0) })
                  else { throw OvernightArchiveError.invalid }
            if let call = trial.recorderCall {
                guard trial.mode != .comparison, trial.requestCount == 1,
                      call.preparedAt.timeIntervalSince1970.isFinite, call.returnedAt.timeIntervalSince1970.isFinite,
                      call.preparedUptime.isFinite, call.preparedUptime >= 0, call.preparedUptime <= trial.startUptime,
                      call.returnedUptime.isFinite, call.returnedUptime >= trial.startUptime,
                      trial.reservationEnd.timeIntervalSince1970.isFinite else { throw OvernightArchiveError.invalid }
            }
            let settings = trial.configuration
            guard [settings.watchModel, settings.watchOS, settings.appBuild, settings.timeZone, settings.wrist,
                   settings.powerMode, settings.sleepFocus, settings.sleepTracking, settings.debuggerDetached,
                   settings.otherApp, settings.charging, settings.interruption].allSatisfy({ $0.count <= 128 }),
                  trial.mode != .comparison || trial.requestCount == 0,
                  [trial.departure, trial.batteryStart.date, trial.batteryReturn?.date, trial.fullReadAt,
                   trial.firstUsefulReadAt, trial.firstUsefulProbeAt, trial.precedingIncompleteProbeAt]
                    .compactMap({ $0 }).allSatisfy({ $0.timeIntervalSince1970.isFinite }) else { throw OvernightArchiveError.invalid }
            for observation in trial.observations + [trial.latestProbe].compactMap({ $0 }) {
                guard observation.requestedAt.timeIntervalSince1970.isFinite,
                      observation.completedAt.timeIntervalSince1970.isFinite,
                      (0...3_000_000).contains(observation.count), (0...48).contains(observation.nilChunks),
                      (0...48).contains(observation.emptyChunks), (observation.error?.count ?? 0) <= 400 else {
                    throw OvernightArchiveError.invalid
                }
                if let diagnostics = observation.orderDiagnostics {
                    try diagnostics.validate(duration: observation.pilotProbe ? 60 : trial.mode.duration)
                }
            }
            if let summary = trial.fullSummary {
                try summary.validate()
                guard summary.start == trial.start, summary.end == trial.end else { throw OvernightArchiveError.invalid }
            }
        }
    }

    func batteryAssessment(for trial: OvernightMotionTrial) -> String {
        guard trial.mode == .overnight else { return "Battery comparison applies to recording nights" }
        guard trial.configuration.charging == "No", trial.configuration.interruption == "None",
              let drop = trial.batteryDrop, let returned = trial.batteryReturn, let remaining = returned.level else {
            return "Battery conditions or readings incomplete"
        }
        guard drop >= 0 else { return "Battery increased; charging or reading mismatch" }
        if drop > 25 || remaining < 0.2 { return "Battery threshold not met" }
        guard let baseline = trials.last(where: { $0.mode == .comparison && $0.id != trial.id }),
              let baseDrop = baseline.batteryDrop, baseDrop >= 0, let baseReturn = baseline.batteryReturn,
              abs(returned.date.timeIntervalSince(trial.batteryStart.date) - baseReturn.date.timeIntervalSince(baseline.batteryStart.date)) <= 900,
              baseline.configuration == trial.configuration,
              trial.configuration.watchModel != "Unknown",
              trial.configuration.wrist != "Unknown", trial.configuration.powerMode != "Unknown",
              trial.configuration.sleepFocus != "Unknown", trial.configuration.sleepTracking != "Unknown",
              trial.configuration.debuggerDetached == "Yes" else { return "Comparable baseline not established; review settings" }
        return drop <= baseDrop + 10 ? "Battery thresholds met for matched metadata; review conditions" : "Additional battery threshold not met"
    }
}
