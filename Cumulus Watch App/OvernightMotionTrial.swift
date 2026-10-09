import Foundation
import Darwin

struct OvernightMotionSummary: Codable, Sendable {
    enum TimingBasis: String, Codable, Sendable { case sensorTime }
    struct QueryPosition: Codable, Sendable {
        let queryIndex: Int
        let sampleIndex: Int
        let previousAcceptedQueryIndex: Int
    }
    struct InputComparison: Codable, Sendable {
        let dateDelta: TimeInterval
        let sensorDelta: TimeInterval
        let batchChanged: Bool
        let gettersStable: Bool
    }
    struct SkippedRows: Codable, Sendable {
        var count = 0
        var outsideQuery = 0
        var finiteSensorTimes = 0
        var minimumSensorDelta: TimeInterval?
        var maximumSensorDelta: TimeInterval?

        mutating func record(uptime: TimeInterval?, after previousUptime: TimeInterval?, outsideQuery: Bool = false) {
            guard let previousUptime else { return }
            count += 1
            if outsideQuery { self.outsideQuery += 1 }
            if let uptime, uptime.isFinite, uptime >= 0 {
                let delta = uptime - previousUptime
                guard delta.isFinite else { return }
                finiteSensorTimes += 1
                minimumSensorDelta = min(minimumSensorDelta ?? delta, delta)
                maximumSensorDelta = max(maximumSensorDelta ?? delta, delta)
            }
        }
    }
    struct GapContext: Sendable {
        let position: QueryPosition
        let previousSampleIndex: Int
        let batchChanged: Bool
        let skipped: SkippedRows
    }
    struct GapDiagnostic: Codable, Sendable {
        let relativeSeconds: TimeInterval
        let measuredGap: TimeInterval
        let dateDelta: TimeInterval
        let sensorDelta: TimeInterval
        let position: QueryPosition
        let previousSampleIndex: Int
        let batchChanged: Bool
        let skipped: SkippedRows

        func validate(duration: TimeInterval, maximumGap: TimeInterval) throws {
            guard relativeSeconds.isFinite, (0..<duration).contains(relativeSeconds),
                  measuredGap.isFinite, measuredGap > 0, measuredGap == maximumGap,
                  dateDelta.isFinite, abs(dateDelta) <= duration,
                  sensorDelta.isFinite, sensorDelta > 0,
                  (1...Int(ceil(duration / 600))).contains(position.queryIndex),
                  (1...position.queryIndex).contains(position.previousAcceptedQueryIndex),
                  (1...3_000_000).contains(position.sampleIndex), (1...3_000_000).contains(previousSampleIndex),
                  (0...3_000_000).contains(skipped.count), (0...skipped.count).contains(skipped.outsideQuery),
                  (0...skipped.count).contains(skipped.finiteSensorTimes) else { throw OvernightArchiveError.invalid }
            if skipped.finiteSensorTimes == 0 {
                guard skipped.minimumSensorDelta == nil, skipped.maximumSensorDelta == nil else { throw OvernightArchiveError.invalid }
            } else {
                guard let minimum = skipped.minimumSensorDelta, let maximum = skipped.maximumSensorDelta,
                      minimum.isFinite, maximum.isFinite, minimum <= maximum else { throw OvernightArchiveError.invalid }
            }
        }
    }
    struct OrderExample: Codable, Sendable {
        let relativeSeconds: TimeInterval
        let dateDelta: TimeInterval
        let sensorDelta: TimeInterval
        let position: QueryPosition?
        var inputComparison: InputComparison?
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
                             sensorDelta: TimeInterval, position: QueryPosition?, inputComparison: InputComparison? = nil) {
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
                    sensorDelta: sensorDelta, position: position, inputComparison: inputComparison))
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
                if let input = example.inputComparison {
                    guard input.dateDelta.isFinite, input.sensorDelta.isFinite else { throw OvernightArchiveError.invalid }
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
    var timingBasis: TimingBasis?
    var sensorOrderFailures: Int?
    var maximumWallMappingDifference: TimeInterval?
    var outsideQuery: Int?
    var largestGapDiagnostic: GapDiagnostic?
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

    init(start: Date, end: Date, timingBasis: TimingBasis? = nil) {
        self.timingBasis = timingBasis
        sensorOrderFailures = timingBasis == .sensorTime ? 0 : nil
        maximumWallMappingDifference = timingBasis == .sensorTime ? 0 : nil
        outsideQuery = timingBasis == .sensorTime ? 0 : nil
        self.start = start
        self.end = end
        let duration = end.timeIntervalSince(start)
        let size = duration.isFinite && duration > 0 && duration <= 28800 ? Int(ceil(duration / 30)) : 0
        buckets = (0..<size).map { Bucket(id: $0) }
        orderAnomalyCounts = OrderAnomalyCounts()
        orderDiagnostics = OrderDiagnostics()
    }

    mutating func receive(date: Date, uptime: TimeInterval, axesFinite: Bool, chunkStart: Date,
                          position: QueryPosition? = nil, inputComparison: InputComparison? = nil,
                          gapContext: GapContext? = nil) {
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
                    sensorDelta: uptime - lastUptime, position: position, inputComparison: inputComparison)
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
            if timingBasis != .sensorTime || uptime <= lastUptime {
                if timingBasis == .sensorTime { sensorOrderFailures! += 1 }
                return
            }
        }
        if let first, let firstUptime {
            let difference = abs(date.timeIntervalSince(first) - (uptime - firstUptime))
            if timingBasis == .sensorTime {
                maximumWallMappingDifference = max(maximumWallMappingDifference ?? 0, difference)
            }
            if difference > 1 { clockDiscontinuity = true }
        }
        // Sensor elapsed time measures motion; the original wall dates remain available for alignment.
        let timingDate = timingBasis == .sensorTime
            ? (first ?? date).addingTimeInterval(uptime - (firstUptime ?? uptime)) : date
        guard timingDate >= start, timingDate < end else { outsideWindow += 1; return }
        let gap = timingBasis == .sensorTime ? lastUptime.map { uptime - $0 } ?? 0
            : last.map { date.timeIntervalSince($0) } ?? 0
        let index = Int(timingDate.timeIntervalSince(start) / 30)
        guard buckets.indices.contains(index) else { invalid += 1; return }
        if gap > maximumGap {
            // Keep only the largest gap; diagnostics never change sample acceptance.
            largestGapDiagnostic = gapContext.flatMap { context in
                guard let last, let lastUptime else { return nil }
                return GapDiagnostic(relativeSeconds: timingDate.timeIntervalSince(start), measuredGap: gap,
                    dateDelta: date.timeIntervalSince(last), sensorDelta: uptime - lastUptime,
                    position: context.position, previousSampleIndex: context.previousSampleIndex,
                    batchChanged: context.batchChanged, skipped: context.skipped)
            }
        }
        buckets[index].count += 1
        buckets[index].first = buckets[index].first ?? timingDate
        buckets[index].last = timingDate
        buckets[index].maximumGap = max(buckets[index].maximumGap, gap)
        count += 1
        first = first ?? date
        firstUptime = firstUptime ?? uptime
        last = date
        lastUptime = uptime
        maximumGap = max(maximumGap, gap)
    }

    var leadingGap: TimeInterval? { first.map { $0.timeIntervalSince(start) } }
    var trailingGap: TimeInterval? {
        if timingBasis == .sensorTime, let first, let firstUptime, let lastUptime {
            return end.timeIntervalSince(first.addingTimeInterval(lastUptime - firstUptime))
        }
        return last.map { end.timeIntervalSince($0) }
    }
    var clockLabel: String { timingBasis == .sensorTime ? "Sensor elapsed time; raw wall dates retained" : "Legacy wall-date timing" }
    var blockingOrderFailures: Int { timingBasis == .sensorTime ? sensorOrderFailures ?? outOfOrder : outOfOrder }
    var observedRate: Double? {
        guard let first, let last, count > 1 else { return nil }
        if timingBasis == .sensorTime, let firstUptime, let lastUptime, lastUptime > firstUptime {
            return Double(count - 1) / (lastUptime - firstUptime)
        }
        return last > first ? Double(count - 1) / last.timeIntervalSince(first) : nil
    }
    var qualifyingBuckets: Int { buckets.filter { $0.count >= 1350 }.count }
    var meetsTimingCriteria: Bool {
        if timingBasis == .sensorTime && (sensorOrderFailures == nil || maximumWallMappingDifference == nil || outsideQuery == nil) { return false }
        guard let rate = observedRate, let leading = leadingGap, let trailing = trailingGap,
              !buckets.isEmpty else { return false }
        return Double(qualifyingBuckets) / Double(buckets.count) >= 0.95
            && (45...55).contains(rate) && maximumGap <= 2 && leading <= 5 && trailing <= 5
            && invalid == 0 && blockingOrderFailures == 0 && unexpectedObjects == 0 && nilChunks == 0
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
        if blockingOrderFailures > 0 { failures.append(timingBasis == .sensorTime ? "Sensor timestamp order anomalies" : "Sample order anomalies") }
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
        if timingBasis == .sensorTime {
            guard let sensorOrderFailures, (0...outOfOrder).contains(sensorOrderFailures),
                  let maximumWallMappingDifference, maximumWallMappingDifference.isFinite, maximumWallMappingDifference >= 0,
                  maximumWallMappingDifference <= 1 || clockDiscontinuity,
                  let outsideQuery, (0...3_000_000).contains(outsideQuery) else { throw OvernightArchiveError.invalid }
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
        if let diagnostic = largestGapDiagnostic {
            guard count >= 2 else { throw OvernightArchiveError.invalid }
            try diagnostic.validate(duration: end.timeIntervalSince(start), maximumGap: maximumGap)
        }
        for bucket in buckets {
            let bucketStart = start.addingTimeInterval(Double(bucket.id) * 30)
            let bucketEnd = min(end, bucketStart.addingTimeInterval(30))
            guard [bucket.first, bucket.last].compactMap({ $0 }).allSatisfy({ $0 >= bucketStart && $0 < bucketEnd }),
                  bucket.count == 0 ? bucket.first == nil && bucket.last == nil : bucket.first != nil && bucket.last != nil,
                  (bucket.first ?? bucketStart) <= (bucket.last ?? bucketEnd) else { throw OvernightArchiveError.invalid }
        }
        if let first, let last, let firstUptime, let lastUptime {
            guard (timingBasis == .sensorTime || first <= last), firstUptime >= 0, firstUptime <= lastUptime else { throw OvernightArchiveError.invalid }
        }
    }
}

enum OvernightBatteryCriteria {
    static let maximumDrop = 25.0
    static let minimumReturnLevel = 0.2
    static let maximumAdditionalDrop = 10.0
    static let durationTolerance: TimeInterval = 900
    static var minimumStartLevel: Double { minimumReturnLevel + maximumDrop / 100 }
    static func canBegin(level: Double?) -> Bool {
        guard let level, level.isFinite, (0...1).contains(level) else { return false }
        // Battery level is supplied as Float by WatchKit; compare at that same precision.
        return Float(level) >= Float(minimumStartLevel)
    }
}

struct OvernightMotionTrial: Codable, Identifiable, Sendable {
    enum ElapsedClock: String, Codable, Sendable {
        case continuous
    }
    struct ClockMismatch: Codable, Sendable {
        let observedAt: Date
        let wallElapsed: TimeInterval
        let clockElapsed: TimeInterval
        var difference: TimeInterval { wallElapsed - clockElapsed }
    }
    // Keep the stored clock basis: old awake-time values cannot be converted after the fact.
    static func elapsedTime(for clock: ElapsedClock?) -> TimeInterval {
        if clock == .continuous {
            return Double(clock_gettime_nsec_np(CLOCK_MONOTONIC_RAW)) / 1_000_000_000
        }
        return ProcessInfo.processInfo.systemUptime
    }
    var clockLabel: String { elapsedClock == .continuous ? "Continuous (includes device sleep)" : "Legacy awake time" }

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

        var hasKnownWearSetup: Bool {
            [watchModel, watchOS, appBuild, timeZone, wrist, powerMode, sleepFocus, sleepTracking, otherApp].allSatisfy {
                let value = $0.trimmingCharacters(in: .whitespacesAndNewlines)
                return !value.isEmpty && value.caseInsensitiveCompare("Unknown") != .orderedSame
            } && debuggerDetached == "Yes"
        }
    }
    struct TimingAssessment: Codable, Sendable {
        var timingBasis: OvernightMotionSummary.TimingBasis?
        let qualifyingBuckets: Int
        let bucketCount: Int
        let bucketCounts: [Int]?
        let maximumGap: TimeInterval
        let observedRate: Double?
        let failures: [String]

        init(summary: OvernightMotionSummary, pilotProbe: Bool) {
            timingBasis = summary.timingBasis
            qualifyingBuckets = summary.qualifyingBuckets
            bucketCount = summary.buckets.count
            bucketCounts = pilotProbe ? summary.buckets.map(\.count) : nil
            maximumGap = summary.maximumGap
            observedRate = summary.observedRate
            failures = summary.timingFailures
        }
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
        var timingAssessment: TimingAssessment?
        var largestGapDiagnostic: OvernightMotionSummary.GapDiagnostic?
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
    var elapsedClock: ElapsedClock?
    var measurementBasis: OvernightMotionSummary.TimingBasis?
    var batteryComparisonID: UUID?
    var firstClockMismatch: ClockMismatch?
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

    init(mode: Mode, start: Date, uptime: TimeInterval, configuration: Configuration, battery: Double?, elapsedClock: ElapsedClock? = nil, measurementBasis: OvernightMotionSummary.TimingBasis? = nil) {
        id = UUID()
        self.mode = mode
        self.start = start
        end = start.addingTimeInterval(mode.duration)
        startUptime = uptime
        self.elapsedClock = elapsedClock
        self.measurementBasis = measurementBasis
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
        return uptime.isFinite && elapsed >= 0 && abs(now.timeIntervalSince(start) - elapsed) <= 5
    }
    var batteryDrop: Double? {
        guard let begin = batteryStart.level, let finish = batteryReturn?.level else { return nil }
        return (begin - finish) * 100
    }
    var hasComparableBatteryWindow: Bool {
        guard mode != .pilot, phase == .elapsed, !clockDiscontinuity,
              configuration.hasKnownWearSetup, configuration.charging == "No", configuration.interruption == "None",
              let returned = batteryReturn, returned.date >= end,
              let drop = batteryDrop, drop >= 0 else { return false }
        let duration = returned.date.timeIntervalSince(batteryStart.date)
        return abs(duration - mode.duration) <= OvernightBatteryCriteria.durationTolerance
            && abs(batteryStart.date.timeIntervalSince(start)) <= OvernightBatteryCriteria.durationTolerance
    }

    var pilotQualified: Bool {
        guard mode == .pilot, requestCount == 1, phase == .elapsed, !clockDiscontinuity,
              fullSummary?.meetsTimingCriteria == true, fullSummary?.timingBasis == measurementBasis,
              latestProbe?.useful == true, latestProbe?.timingAssessment?.timingBasis == measurementBasis,
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
            if let mismatch = trial.firstClockMismatch {
                guard trial.clockDiscontinuity, mismatch.observedAt.timeIntervalSince1970.isFinite,
                      mismatch.wallElapsed.isFinite, mismatch.clockElapsed.isFinite,
                      mismatch.difference.isFinite,
                      mismatch.clockElapsed < 0 || abs(mismatch.difference) > 5 else {
                    throw OvernightArchiveError.invalid
                }
            }
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
                if let assessment = observation.timingAssessment {
                    let expectedBuckets = Int(ceil((observation.pilotProbe ? 60 : trial.mode.duration) / 30))
                    guard assessment.timingBasis == trial.measurementBasis, assessment.bucketCount == expectedBuckets,
                          (0...expectedBuckets).contains(assessment.qualifyingBuckets),
                          assessment.maximumGap.isFinite, assessment.maximumGap >= 0,
                          assessment.observedRate.map({ $0.isFinite && $0 > 0 }) ?? true,
                          assessment.failures.count <= 16, Set(assessment.failures).count == assessment.failures.count,
                          assessment.failures.allSatisfy({ !$0.isEmpty && $0.count <= 100 }),
                          !observation.useful || assessment.failures.isEmpty else { throw OvernightArchiveError.invalid }
                    if let counts = assessment.bucketCounts {
                        guard observation.pilotProbe, counts.count == expectedBuckets,
                              counts.allSatisfy({ (0...3_000_000).contains($0) }),
                              counts.reduce(0, +) == observation.count,
                              counts.filter({ $0 >= 1350 }).count == assessment.qualifyingBuckets else {
                            throw OvernightArchiveError.invalid
                        }
                    }
                }
                if let diagnostics = observation.orderDiagnostics {
                    try diagnostics.validate(duration: observation.pilotProbe ? 60 : trial.mode.duration)
                }
                if let diagnostic = observation.largestGapDiagnostic {
                    guard observation.count >= 2, let assessment = observation.timingAssessment else { throw OvernightArchiveError.invalid }
                    try diagnostic.validate(duration: observation.pilotProbe ? 60 : trial.mode.duration, maximumGap: assessment.maximumGap)
                }
            }
            if let summary = trial.fullSummary {
                try summary.validate()
                guard summary.start == trial.start, summary.end == trial.end, summary.timingBasis == trial.measurementBasis else { throw OvernightArchiveError.invalid }
            }
        }
    }

    func comparableBaseline(configuration: OvernightMotionTrial.Configuration) -> OvernightMotionTrial? {
        guard let baseline = trials.last(where: { $0.mode == .comparison }), baseline.hasComparableBatteryWindow else { return nil }
        var expected = configuration
        expected.charging = "No"
        expected.interruption = "None"
        return baseline.configuration == expected ? baseline : nil
    }

    func batteryAssessment(for trial: OvernightMotionTrial) -> String {
        guard trial.mode == .overnight else { return "Battery comparison applies to recording nights" }
        guard trial.hasComparableBatteryWindow, let drop = trial.batteryDrop,
              let returned = trial.batteryReturn, let remaining = returned.level else {
            return "Battery conditions, clock or eight-hour readings incomplete"
        }
        if drop > OvernightBatteryCriteria.maximumDrop || remaining < OvernightBatteryCriteria.minimumReturnLevel {
            return "Battery threshold not met"
        }
        guard let baseline = comparableBaseline(configuration: trial.configuration),
              baseline.end <= trial.start, trial.batteryComparisonID == nil || trial.batteryComparisonID == baseline.id,
              let baseDrop = baseline.batteryDrop, let baseReturn = baseline.batteryReturn,
              abs(returned.date.timeIntervalSince(trial.batteryStart.date) - baseReturn.date.timeIntervalSince(baseline.batteryStart.date)) <= OvernightBatteryCriteria.durationTolerance else {
            return "Comparable baseline not established; review settings, clock and durations"
        }
        return drop <= baseDrop + OvernightBatteryCriteria.maximumAdditionalDrop
            ? "Battery thresholds met for matched metadata; review conditions" : "Additional battery threshold not met"
    }
}
