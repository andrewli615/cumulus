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

    private let manager = CMMotionManager()
    private let queue: OperationQueue = {
        let queue = OperationQueue()
        queue.name = "Cumulus motion"
        queue.maxConcurrentOperationCount = 1
        return queue
    }()
    private var runID = UUID()
    private var firstTimestamp: TimeInterval?

    func start() {
        guard !isMonitoring else { return }
        latest = nil
        sampleCount = 0
        observedRate = nil
        firstTimestamp = nil
        guard manager.isAccelerometerAvailable else {
            status = "Accelerometer unavailable"
            return
        }

        runID = UUID()
        let currentRun = runID
        isMonitoring = true
        status = "Waiting for motion"
        // A requested rate, not a guarantee. Measure the actual timestamps below.
        manager.accelerometerUpdateInterval = 0.1
        manager.startAccelerometerUpdates(to: queue) { [weak self] data, error in
            let message = error?.localizedDescription
            let reading = data.map {
                Reading(x: $0.acceleration.x, y: $0.acceleration.y,
                        z: $0.acceleration.z, timestamp: $0.timestamp)
            }
            Task { @MainActor [weak self] in
                guard let self, self.isMonitoring, self.runID == currentRun else { return }
                if let message {
                    self.stop(reason: "Motion error: \(message)")
                    return
                }
                guard let reading else { return }
                self.latest = reading
                self.sampleCount += 1
                if let first = self.firstTimestamp, reading.timestamp > first {
                    self.observedRate = Double(self.sampleCount - 1) / (reading.timestamp - first)
                } else {
                    self.firstTimestamp = reading.timestamp
                }
                self.status = "Receiving motion"
            }
        }
    }

    func stop(reason: String = "Stopped") {
        runID = UUID() // Ignore callbacks already queued by the previous run.
        manager.stopAccelerometerUpdates()
        isMonitoring = false
        status = reason
    }
}
