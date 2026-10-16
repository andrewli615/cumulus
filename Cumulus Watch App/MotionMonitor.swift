import Combine
import CoreMotion
import Foundation

/// Owns a foreground-only sensor subscription. No samples are written to disk.
@MainActor
final class MotionMonitor: ObservableObject {
    struct Reading: Sendable {
        let x: Double
        let y: Double
        let z: Double
        let timestamp: TimeInterval // Device uptime, not a calendar date.
    }

    @Published private(set) var latest: Reading?
    @Published private(set) var sampleCount = 0
    @Published private(set) var observedRate: Double?
    @Published private(set) var isMonitoring = false
    @Published private(set) var status = "Not started"
    @Published private(set) var features = MotionFeatures()
    @Published private(set) var featureCapture: ForegroundFeatureCapture?
    @Published private(set) var captureMessage = "Movement summaries are not saved"

    private let manager = CMMotionManager()
    private let queue: OperationQueue = {
        let queue = OperationQueue()
        queue.name = "Cumulus motion"
        queue.maxConcurrentOperationCount = 1
        return queue
    }()
    private var runID = UUID()
    private var firstTimestamp: TimeInterval?
    private var captureArchive: TestArchiveStore?
    private var captureDeadline: Task<Void, Never>?
    private let uptime: @Sendable () -> TimeInterval
    private let date: () -> Date

    init(uptime: @escaping @Sendable () -> TimeInterval = { ProcessInfo.processInfo.systemUptime },
         date: @escaping () -> Date = { Date() }) {
        self.uptime = uptime
        self.date = date
    }

    func start(archive: TestArchiveStore? = nil) {
        guard !isMonitoring else { return }
        latest = nil
        sampleCount = 0
        observedRate = nil
        firstTimestamp = nil
        features = MotionFeatures()
        featureCapture = nil
        captureArchive = archive
        captureMessage = "Movement summaries are not saved"
        guard manager.isAccelerometerAvailable else {
            status = "Accelerometer unavailable"
            return
        }
        if let archive {
            guard archive.canStartNewReport else {
                status = "Saved run not started: archive unavailable"
                captureMessage = archive.newReportBlockReason ?? "Check Saved tests storage"
                return
            }
            featureCapture = ForegroundFeatureCapture(id: UUID(), startedAt: date(), startUptime: uptime(),
                originalBuild: archive.build, originalOS: archive.os)
            guard persistCapture() else {
                status = "Saved run not started: initial save failed"
                return
            }
        }

        runID = UUID()
        let currentRun = runID
        isMonitoring = true
        status = "Waiting for motion"
        // A requested rate, not a guarantee. Measure the actual timestamps below.
        manager.accelerometerUpdateInterval = 0.1
        let receiptClock = uptime
        manager.startAccelerometerUpdates(to: queue) { @Sendable [weak self] data, error in
            let message = error?.localizedDescription
            let x = data?.acceleration.x
            let y = data?.acceleration.y
            let z = data?.acceleration.z
            let timestamp = data?.timestamp
            let receipt = receiptClock()
            Task { @MainActor [weak self] in
                guard let self, self.isMonitoring, self.runID == currentRun else { return }
                if let message {
                    self.stop(reason: "Motion error: \(message)")
                    return
                }
                if let capture = self.featureCapture {
                    let currentUptime = self.uptime()
                    if capture.expired(at: currentUptime) {
                        self.stop(reason: !currentUptime.isFinite || currentUptime < capture.startUptime
                            ? "Stopped: capture clock uncertain" : "10-minute saved-run limit reached")
                        return
                    }
                }
                guard let x, let y, let z, let timestamp else { return }
                if let start = self.featureCapture?.startUptime, timestamp.isFinite, timestamp < start {
                    self.featureCapture?.rejectPreStartSample()
                    self.status = "Ignored sensor sample from before this run"
                    return
                }
                let previousWindows = self.features.completedWindowCount
                guard self.features.receive(x: x, y: y, z: z, timestamp: timestamp, receipt: receipt) else {
                    self.status = "Rejected motion sample; inspect quality"
                    return
                }
                let reading = Reading(x: x, y: y, z: z, timestamp: timestamp)
                self.latest = reading
                self.sampleCount += 1
                if let first = self.firstTimestamp, reading.timestamp > first {
                    self.observedRate = Double(self.sampleCount - 1) / (reading.timestamp - first)
                } else {
                    self.firstTimestamp = reading.timestamp
                }
                self.status = "Receiving motion"
                if self.features.completedWindowCount != previousWindows, self.featureCapture != nil {
                    guard self.persistCapture() else {
                        self.stop(reason: "Stopped after feature save failure")
                        return
                    }
                }
            }
        }
        if archive != nil {
            captureDeadline = Task { @MainActor [weak self] in
                do { try await Task.sleep(for: .seconds(ForegroundFeatureCapture.duration)) }
                catch { return }
                guard let self, self.isMonitoring, self.runID == currentRun else { return }
                self.stop(reason: "10-minute saved-run limit reached")
            }
        }
    }

    func stop(reason: String = "Stopped") {
        let wasMonitoring = isMonitoring
        runID = UUID() // Ignore callbacks already queued by the previous run.
        manager.stopAccelerometerUpdates()
        features.stop()
        isMonitoring = false
        status = reason
        captureDeadline?.cancel()
        captureDeadline = nil
        if wasMonitoring, featureCapture != nil { _ = persistCapture(stopping: reason) }
    }

    @discardableResult
    private func persistCapture(stopping reason: String? = nil) -> Bool {
        guard var capture = featureCapture, let archive = captureArchive else { return false }
        do {
            let currentUptime = uptime()
            if reason != nil, !currentUptime.isFinite || currentUptime < capture.startUptime {
                try capture.stopWithUncertainClock(at: date())
            } else {
                try capture.observe(features, samples: sampleCount, date: date(), uptime: currentUptime, stopping: reason)
            }
            let report = try capture.report()
            featureCapture = capture
            guard archive.save(report) else {
                captureMessage = "Save failed. The last saved snapshot may have completion unrecorded."
                return false
            }
            captureMessage = reason == nil ? "Saved \(capture.epochs.count) completed windows; collection is foreground only"
                : "Saved stopped run in Saved tests"
            return true
        } catch TestArchiveError.invalid {
            captureMessage = "Feature timing or format could not be verified. Last saved snapshot preserved."
        } catch is EncodingError {
            captureMessage = "Feature encoding failed. Last saved snapshot preserved."
        } catch {
            captureMessage = "Unexpected feature-save error. Last saved snapshot preserved."
        }
        return false
    }
}
