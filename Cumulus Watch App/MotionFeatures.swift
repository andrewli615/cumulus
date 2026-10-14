import Foundation

/// Descriptive movement features only. Two window summaries are retained; no raw samples.
struct MotionFeatures: Sendable {
    static let windowDuration: TimeInterval = 30

    struct Window: Sendable {
        let start: TimeInterval
        var end: TimeInterval { start + MotionFeatures.windowDuration }
        private(set) var count = 0
        private(set) var firstTimestamp: TimeInterval?
        private(set) var lastTimestamp: TimeInterval?
        private(set) var lastReceipt: TimeInterval?
        private(set) var maximumGap: TimeInterval = 0
        private(set) var maximumDelay: TimeInterval = 0
        private var magnitudeMean: Double = 0
        private var magnitudeM2: Double = 0
        private var enmoMean: Double = 0

        var meanMagnitude: Double? { count > 0 ? magnitudeMean : nil }
        // Population standard deviation over the observed samples, in g.
        var magnitudeSD: Double? { count > 1 ? sqrt(max(0, magnitudeM2 / Double(count))) : nil }
        var meanENMO: Double? { count > 0 ? enmoMean : nil }
        var observedRate: Double? {
            guard let firstTimestamp, let lastTimestamp, lastTimestamp > firstTimestamp else { return nil }
            return Double(count - 1) / (lastTimestamp - firstTimestamp)
        }
        var leadingGap: TimeInterval? { firstTimestamp.map { $0 - start } }
        var trailingGap: TimeInterval? { lastTimestamp.map { end - $0 } }

        fileprivate mutating func receive(magnitude: Double, timestamp: TimeInterval, receipt: TimeInterval) -> Bool {
            let nextCount = count + 1
            let delta = magnitude - magnitudeMean
            let nextMean = magnitudeMean + delta / Double(nextCount)
            let nextM2 = magnitudeM2 + delta * (magnitude - nextMean)
            let enmo = max(0, magnitude - 1)
            let nextENMO = enmoMean + (enmo - enmoMean) / Double(nextCount)
            guard nextMean.isFinite, nextM2.isFinite, nextENMO.isFinite else { return false }
            if let lastTimestamp { maximumGap = max(maximumGap, timestamp - lastTimestamp) }
            firstTimestamp = firstTimestamp ?? timestamp
            lastTimestamp = timestamp
            lastReceipt = receipt
            maximumDelay = max(maximumDelay, receipt - timestamp)
            count = nextCount
            magnitudeMean = nextMean
            magnitudeM2 = nextM2
            enmoMean = nextENMO
            return true
        }
    }

    private(set) var current: Window?
    private(set) var latestCompleted: Window?
    private(set) var completedWindowCount = 0
    private(set) var skippedWindowCount = 0
    private(set) var invalidSampleCount = 0
    private(set) var orderAnomalyCount = 0
    private(set) var maximumGap: TimeInterval = 0
    private(set) var isStopped = false
    private var lastAcceptedTimestamp: TimeInterval?

    @discardableResult
    mutating func receive(x: Double, y: Double, z: Double, timestamp: TimeInterval, receipt: TimeInterval) -> Bool {
        guard !isStopped else { return false }
        let magnitude = hypot(hypot(x, y), z)
        guard x.isFinite, y.isFinite, z.isFinite, magnitude.isFinite,
              timestamp.isFinite, receipt.isFinite, timestamp >= 0, receipt >= timestamp else {
            invalidSampleCount += 1
            return false
        }
        if let lastAcceptedTimestamp, timestamp <= lastAcceptedTimestamp {
            orderAnomalyCount += 1
            return false
        }

        var window = current ?? Window(start: timestamp)
        var completed: Window?
        var skipped = 0
        if timestamp >= window.end {
            let elapsedWindows = floor((timestamp - window.start) / Self.windowDuration)
            guard elapsedWindows.isFinite, elapsedWindows < Double(Int.max) else {
                invalidSampleCount += 1
                return false
            }
            completed = window
            skipped = Int(elapsedWindows) - 1
            window = Window(start: window.start + elapsedWindows * Self.windowDuration)
        }
        guard timestamp >= window.start, timestamp < window.end,
              window.receive(magnitude: magnitude, timestamp: timestamp, receipt: receipt) else {
            invalidSampleCount += 1
            return false
        }
        // Advance only on accepted sensor times. Never fill a missing window with zeros.
        if let completed {
            latestCompleted = completed
            completedWindowCount += 1
            skippedWindowCount += skipped
        }
        if let lastAcceptedTimestamp { maximumGap = max(maximumGap, timestamp - lastAcceptedTimestamp) }
        lastAcceptedTimestamp = timestamp
        current = window
        return true
    }

    mutating func stop() { isStopped = true }
}
