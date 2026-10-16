import Foundation

struct ForegroundFeatureCapture: Codable, Sendable {
    static let duration: TimeInterval = 600
    static let maximumWindows = 20

    struct Epoch: Codable, Sendable, Identifiable {
        var id: Double { startSeconds }
        let startSeconds: Double
        let endSeconds: Double
        let firstSampleSeconds: Double
        let lastSampleSeconds: Double
        let lastReceiptSeconds: Double
        let calculatedSeconds: Double
        let calculatedAt: Date
        let count: Int
        let magnitudeMean: Double
        let magnitudeSD: Double?
        let enmoMean: Double
        let observedRate: Double?
        let maximumGap: Double
        let maximumDelay: Double

        init(window: MotionFeatures.Window, reference: Double, date: Date, uptime: Double) throws {
            guard let first = window.firstTimestamp, let last = window.lastTimestamp,
                  let receipt = window.lastReceipt, let mean = window.meanMagnitude,
                  let enmo = window.meanENMO else { throw TestArchiveError.invalid }
            startSeconds = window.start - reference
            endSeconds = window.end - reference
            firstSampleSeconds = first - reference
            lastSampleSeconds = last - reference
            lastReceiptSeconds = receipt - reference
            calculatedSeconds = uptime - reference
            calculatedAt = date
            count = window.count
            magnitudeMean = mean
            magnitudeSD = window.magnitudeSD
            enmoMean = enmo
            observedRate = window.observedRate
            maximumGap = window.maximumGap
            maximumDelay = window.maximumDelay
        }

        func validate(completed: Bool) throws {
            let numbers = [startSeconds, endSeconds, firstSampleSeconds, lastSampleSeconds,
                lastReceiptSeconds, calculatedSeconds, calculatedAt.timeIntervalSince1970,
                magnitudeMean, enmoMean, maximumGap, maximumDelay]
            guard numbers.allSatisfy(\.isFinite), startSeconds >= 0,
                  startSeconds < ForegroundFeatureCapture.duration,
                  abs(endSeconds - startSeconds - 30) < 0.000001,
                  firstSampleSeconds >= startSeconds, lastSampleSeconds >= firstSampleSeconds,
                  lastSampleSeconds < endSeconds, lastReceiptSeconds >= lastSampleSeconds,
                  calculatedSeconds >= lastReceiptSeconds,
                  !completed || calculatedSeconds >= endSeconds,
                  (1...1_000_000).contains(count), magnitudeMean >= 0,
                  enmoMean >= 0, enmoMean <= magnitudeMean + 0.000001,
                  maximumGap >= 0, maximumGap <= lastSampleSeconds - firstSampleSeconds + 0.000001,
                  maximumDelay >= 0 else { throw TestArchiveError.invalid }
            if count > 1 {
                guard let magnitudeSD, magnitudeSD.isFinite, magnitudeSD >= 0,
                      let observedRate, observedRate.isFinite, observedRate > 0,
                      lastSampleSeconds > firstSampleSeconds else { throw TestArchiveError.invalid }
            } else if magnitudeSD != nil || observedRate != nil { throw TestArchiveError.invalid }
        }
    }

    private(set) var schemaVersion = 1
    private(set) var format = "foreground-motion-features"
    private(set) var calculationVersion = 1
    private(set) var source = "foreground-accelerometer"
    private(set) var units = "g"
    private(set) var requestedRate = 10.0
    let id: UUID
    let startedAt: Date
    let startUptime: Double
    let originalBuild: String
    let originalOS: String
    private(set) var epochs: [Epoch] = []
    private(set) var partial: Epoch?
    private(set) var stoppedAt: Date?
    private(set) var stopReason: String?
    private(set) var clockUncertain = false
    private(set) var acceptedSamples = 0
    private(set) var invalidSamples = 0
    private(set) var orderAnomalies = 0
    private(set) var preStartSamples = 0
    private(set) var skippedWindows = 0
    private(set) var maximumGap: Double = 0

    var reportID: String { "foreground-" + id.uuidString.lowercased() }
    var status: String {
        stoppedAt == nil ? "Completion not recorded; \(epochs.count) completed windows saved"
            : "Stopped: \(stopReason ?? "Unknown"); \(epochs.count) completed windows saved"
    }
    func expired(at uptime: Double) -> Bool {
        !uptime.isFinite || uptime < startUptime || uptime - startUptime >= Self.duration
    }

    mutating func rejectPreStartSample() {
        guard stoppedAt == nil else { return }
        preStartSamples += 1
    }

    mutating func stopWithUncertainClock(at date: Date) throws {
        guard stoppedAt == nil else { return }
        clockUncertain = true
        stoppedAt = date
        stopReason = "Capture clock uncertain; final partial not recorded"
        try validate()
    }

    mutating func observe(_ features: MotionFeatures, samples: Int, date: Date, uptime: Double, stopping reason: String? = nil) throws {
        guard stoppedAt == nil else { return }
        let elapsed = uptime - startUptime
        guard elapsed.isFinite, elapsed >= 0, date.timeIntervalSince1970.isFinite else { throw TestArchiveError.invalid }
        clockUncertain = clockUncertain || abs(date.timeIntervalSince(startedAt) - elapsed) > 2
        if features.completedWindowCount > epochs.count {
            guard features.completedWindowCount == epochs.count + 1,
                  epochs.count < Self.maximumWindows,
                  let window = features.latestCompleted else { throw TestArchiveError.invalid }
            let epoch = try Epoch(window: window, reference: startUptime, date: date, uptime: uptime)
            try epoch.validate(completed: true)
            epochs.append(epoch)
        }
        acceptedSamples = samples
        invalidSamples = features.invalidSampleCount
        orderAnomalies = features.orderAnomalyCount
        skippedWindows = features.skippedWindowCount
        maximumGap = features.maximumGap
        if let reason {
            if let window = features.current {
                partial = try Epoch(window: window, reference: startUptime, date: date, uptime: uptime)
            }
            stoppedAt = date
            stopReason = String(reason.prefix(500))
        }
        try validate()
    }

    func validate() throws {
        guard schemaVersion == 1, format == "foreground-motion-features",
              calculationVersion == 1, source == "foreground-accelerometer", units == "g", requestedRate == 10,
              startedAt.timeIntervalSince1970.isFinite, startUptime.isFinite, startUptime >= 0,
              originalBuild.count <= 128, originalOS.count <= 128,
              epochs.count <= Self.maximumWindows, maximumGap.isFinite, maximumGap >= 0,
              [acceptedSamples, invalidSamples, orderAnomalies, preStartSamples, skippedWindows].allSatisfy({ (0...1_000_000).contains($0) }),
              (stoppedAt == nil) == (stopReason == nil), (stopReason?.count ?? 0) <= 500,
              stoppedAt?.timeIntervalSince1970.isFinite != false,
              partial == nil || stoppedAt != nil else { throw TestArchiveError.invalid }
        var previousEnd: Double = 0
        for epoch in epochs {
            try epoch.validate(completed: true)
            guard epoch.startSeconds >= previousEnd else { throw TestArchiveError.invalid }
            previousEnd = epoch.endSeconds
        }
        if let partial {
            try partial.validate(completed: false)
            guard partial.startSeconds >= previousEnd else { throw TestArchiveError.invalid }
        }
        guard epochs.reduce(0, { $0 + $1.count }) + (partial?.count ?? 0) <= acceptedSamples else {
            throw TestArchiveError.invalid
        }
    }

    func report() throws -> TestReport {
        try validate()
        var report = TestReport(id: reportID, kind: .foreground, createdAt: startedAt,
            title: "Foreground movement features", status: status,
            metrics: ["Completed windows": String(epochs.count), "Partial window": String(partial != nil),
                "Accepted samples": String(acceptedSamples), "Clock mapping uncertain": String(clockUncertain),
                "Pre-start samples excluded": String(preStartSamples),
                "Original build": originalBuild, "Original watchOS": originalOS,
                "Input": "Foreground accelerometer; requested 10 Hz; units g",
                "Calculation": "Magnitude, population SD, sample-mean clipped ENMO; version 1"])
        report.diagnostics = try TestReport.encodeDiagnostics(self)
        return report
    }
}
