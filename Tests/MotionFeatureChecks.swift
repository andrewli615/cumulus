import Combine
import Foundation

struct CMAcceleration: Sendable { let x: Double; let y: Double; let z: Double }
struct CMAccelerometerData: Sendable { let acceleration: CMAcceleration; let timestamp: TimeInterval }
@MainActor final class CMMotionManager {
    static var latest: CMMotionManager?
    var isAccelerometerAvailable = true
    var accelerometerUpdateInterval: TimeInterval = 0
    var callback: (@Sendable (CMAccelerometerData?, Error?) -> Void)?
    var stops = 0
    init() { Self.latest = self }
    func startAccelerometerUpdates(to queue: OperationQueue, withHandler callback: @escaping @Sendable (CMAccelerometerData?, Error?) -> Void) {
        self.callback = callback
    }
    func stopAccelerometerUpdates() { stops += 1 }
}

@main @MainActor struct MotionFeatureChecks {
    static func expect(_ value: @autoclosure () -> Bool, _ message: String) { precondition(value(), message) }
    static func close(_ actual: Double?, _ expected: Double, _ message: String) {
        expect(actual.map { abs($0 - expected) < 1e-9 } == true, message)
    }
    static func sample(_ features: inout MotionFeatures, _ time: Double, x: Double = 0, y: Double = 0, z: Double = 1, delay: Double = 0) {
        expect(features.receive(x: x, y: y, z: z, timestamp: time, receipt: time + delay), "Accept synthetic sample")
    }
    static func settle() async {
        // Sensor callbacks hop to MainActor; allow queued tasks to finish before inspecting state.
        for _ in 0..<10 { await Task.yield() }
    }

    static func main() async throws {
        var quiet = MotionFeatures()
        for index in 0..<300 { sample(&quiet, 100 + Double(index) / 10) }
        expect(quiet.latestCompleted == nil && quiet.current?.count == 300, "Partial window is not declared complete early")
        sample(&quiet, 130, z: 2)
        expect(quiet.latestCompleted?.count == 300 && quiet.current?.count == 1, "Boundary belongs to following window")
        close(quiet.latestCompleted?.meanMagnitude, 1, "Quiet magnitude includes gravity")
        close(quiet.latestCompleted?.magnitudeSD, 0, "Constant gravity has no magnitude variation")
        close(quiet.latestCompleted?.meanENMO, 0, "ENMO subtracts 1 g and clips negatives")
        close(quiet.latestCompleted?.observedRate, 10, "Rate comes from accepted timestamps")
        close(quiet.latestCompleted?.trailingGap, 0.1, "Window boundary gap is retained")
        close(quiet.current?.meanMagnitude, 2, "Future motion does not alter completed feature")

        var moving = MotionFeatures()
        for index in 0..<300 { sample(&moving, Double(index) / 10, z: index.isMultiple(of: 2) ? 1 : 3, delay: 0.25) }
        close(moving.current?.meanMagnitude, 2, "Alternating magnitudes have mean 2 g")
        close(moving.current?.magnitudeSD, 1, "Known population SD")
        close(moving.current?.meanENMO, 1, "Known sample-mean ENMO")
        close(moving.current?.maximumDelay, 0.25, "Receipt delay remains separate from sensor time")

        var rotated = MotionFeatures()
        sample(&rotated, 1, x: 1, z: 0)
        sample(&rotated, 2, y: 1, z: 0)
        sample(&rotated, 3, z: -1)
        close(rotated.current?.meanMagnitude, 1, "Orientation does not change norm")
        close(rotated.current?.magnitudeSD, 0, "Norm alone cannot detect all rotation")

        var sparse = MotionFeatures()
        sample(&sparse, 100)
        sample(&sparse, 109, z: 0.5)
        sample(&sparse, 195, z: 2)
        expect(sparse.completedWindowCount == 1 && sparse.skippedWindowCount == 2, "Empty windows counted without fabricated quiet features")
        expect(sparse.latestCompleted?.count == 2 && sparse.current?.count == 1, "No samples fabricated across gaps")
        close(sparse.latestCompleted?.maximumGap, 9, "Internal gap retained")
        close(sparse.latestCompleted?.trailingGap, 21, "Trailing missingness remains visible")
        close(sparse.current?.leadingGap, 5, "Leading missingness remains visible")
        close(sparse.maximumGap, 86, "Cross-window gap retained")
        expect(sparse.current?.magnitudeSD == nil, "One sample cannot supply variability")
        close(sparse.latestCompleted?.meanENMO, 0, "Sub-gravity norms clip at zero")

        expect(!sparse.receive(x: 0, y: 0, z: 1, timestamp: 195, receipt: 200), "Duplicate rejected")
        expect(!sparse.receive(x: 0, y: 0, z: 1, timestamp: 194, receipt: 200), "Backward time rejected")
        expect(!sparse.receive(x: .nan, y: 0, z: 1, timestamp: 196, receipt: 200), "NaN rejected")
        expect(!sparse.receive(x: 0, y: 0, z: 1, timestamp: 196, receipt: 195), "Future measurement rejected")
        expect(!sparse.receive(x: 0, y: 0, z: 1, timestamp: .infinity, receipt: .infinity), "Nonfinite clock rejected")
        expect(sparse.orderAnomalyCount == 2 && sparse.invalidSampleCount == 3, "Rejected quality counts remain visible")
        sample(&sparse, 196)
        expect(sparse.current?.count == 2, "Rejected entries do not poison subsequent state")
        sparse.stop()
        expect(!sparse.receive(x: 0, y: 0, z: 1, timestamp: 197, receipt: 197), "Late sample after stop ignored")
        expect(sparse.current?.count == 2 && sparse.latestCompleted?.count == 2, "Stop freezes both summaries")

        var overflow = MotionFeatures()
        sample(&overflow, 0)
        expect(!overflow.receive(x: 1e200, y: 0, z: 0, timestamp: 1, receipt: 1), "Variance overflow rejected without corrupting state")
        sample(&overflow, 2)
        close(overflow.current?.magnitudeSD, 0, "Overflow does not contaminate variance")
        expect(!overflow.receive(x: 0, y: 0, z: 1, timestamp: 1e300, receipt: 1e300), "Unrepresentable window index rejected")

        var many = MotionFeatures()
        for index in 0..<10_000 { sample(&many, Double(index) * 30) }
        expect(many.completedWindowCount == 9_999 && many.latestCompleted?.count == 1 && many.current?.count == 1, "Long stream retains only two window summaries")

        let monitor = MotionMonitor()
        let manager = CMMotionManager.latest!
        monitor.start()
        let oldCallback = manager.callback!
        let time = ProcessInfo.processInfo.systemUptime - 1
        oldCallback(.init(acceleration: .init(x: 0, y: 0, z: 1), timestamp: time), nil)
        await settle()
        expect(monitor.sampleCount == 1 && monitor.features.current?.count == 1, "Actual monitor feeds features through MainActor")
        monitor.stop()
        oldCallback(.init(acceleration: .init(x: 0, y: 0, z: 2), timestamp: time + 0.1), nil)
        await settle()
        expect(monitor.sampleCount == 1 && monitor.features.current?.count == 1, "Stopped monitor ignores queued samples")
        monitor.start()
        expect(monitor.features.current == nil && monitor.sampleCount == 0, "Start resets features")
        oldCallback(.init(acceleration: .init(x: 0, y: 0, z: 2), timestamp: time + 0.2), nil)
        await settle()
        expect(monitor.features.current == nil, "Old run cannot mutate restarted monitor")
        manager.callback?(.init(acceleration: .init(x: .nan, y: 0, z: 1), timestamp: time + 0.3), nil)
        await settle()
        expect(monitor.features.invalidSampleCount == 1 && monitor.sampleCount == 0 && monitor.latest == nil, "Invalid value never reaches displayed reading")
        manager.callback?(nil, NSError(domain: "Synthetic motion error", code: 1))
        await settle()
        expect(!monitor.isMonitoring && monitor.features.isStopped && monitor.status.hasPrefix("Motion error:"), "API error stops collection and feature updates")
        print("PASS: magnitude/SD/ENMO, boundaries, gaps, invalid/order/clock data, bounded state, stop/restart and monitor callbacks")
    }
}
