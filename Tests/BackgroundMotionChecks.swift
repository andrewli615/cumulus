import Foundation

// Platform doubles validate app logic, not WatchKit delivery or hardware behavior.
protocol WKExtendedRuntimeSessionDelegate: AnyObject {
    func extendedRuntimeSessionDidStart(_ session: WKExtendedRuntimeSession)
    func extendedRuntimeSessionWillExpire(_ session: WKExtendedRuntimeSession)
    func extendedRuntimeSession(_ session: WKExtendedRuntimeSession,
        didInvalidateWith reason: WKExtendedRuntimeSessionInvalidationReason, error: Error?)
}
enum WKExtendedRuntimeSessionInvalidationReason: Int { case none, expired, error }
@MainActor final class WKExtendedRuntimeSession {
    enum State: Int { case notStarted, scheduled, running, invalid }
    enum Haptic { case notification }
    static var latest: WKExtendedRuntimeSession?
    weak var delegate: (any WKExtendedRuntimeSessionDelegate)?
    var state = State.notStarted
    var haptics = 0
    var invalidations = 0
    init() { Self.latest = self }
    func start(at date: Date) { state = .scheduled }
    func notifyUser(hapticType: Haptic, repeatHandler: (() -> TimeInterval)?) {
        precondition(state == .running)
        haptics += 1
    }
    func invalidate() { invalidations += 1 }
    func run() { state = .running; delegate?.extendedRuntimeSessionDidStart(self) }
    func expireSoon() { delegate?.extendedRuntimeSessionWillExpire(self) }
    func end(_ reason: WKExtendedRuntimeSessionInvalidationReason, error: Error? = nil) {
        state = .invalid
        delegate?.extendedRuntimeSession(self, didInvalidateWith: reason, error: error)
    }
}
@MainActor protocol WKApplicationDelegate {}
@MainActor final class WKApplication {
    enum State { case active, inactive, background }
    static let instance = WKApplication()
    static func shared() -> WKApplication { instance }
    var applicationState = State.active
}
@MainActor final class WKInterfaceDevice {
    static let instance = WKInterfaceDevice()
    static func current() -> WKInterfaceDevice { instance }
    var systemVersion = "Synthetic"
    var isBatteryMonitoringEnabled = false
    var batteryLevel: Float = 0.8
}
struct CMAccelerometerData: Sendable { let timestamp: TimeInterval }
@MainActor final class CMMotionManager {
    static var latest: CMMotionManager?
    var isAccelerometerAvailable = true
    var accelerometerUpdateInterval: TimeInterval = 0
    var callback: (@Sendable (CMAccelerometerData?, Error?) -> Void)?
    var starts = 0
    var stops = 0
    init() { Self.latest = self }
    func startAccelerometerUpdates(to queue: OperationQueue, withHandler callback: @escaping @Sendable (CMAccelerometerData?, Error?) -> Void) {
        starts += 1
        self.callback = callback
    }
    func stopAccelerometerUpdates() { stops += 1 }
}

@main struct Checks {
    static func expect(_ condition: @autoclosure () -> Bool, _ message: String) {
        precondition(condition(), message)
    }
    static func trial() -> BackgroundMotionTrial {
        BackgroundMotionTrial(id: UUID(), requestedStart: Date(timeIntervalSince1970: 1_000), configuration: .init())
    }
    @MainActor static func settle() async { try? await Task.sleep(for: .milliseconds(30)) }

    @MainActor static func main() async throws {
        var summary = MotionSampleSummary(start: 100)
        for index in 0..<600 { summary.receive(timestamp: 100 + Double(index) / 10, receipt: 100.01 + Double(index) / 10) }
        expect(summary.count == 600 && summary.buckets.allSatisfy { $0.count == 50 }, "600 samples across exact bucket boundaries")
        expect(summary.meetsSampleCriteria, "Uniform fresh samples pass sample thresholds")
        summary.receive(timestamp: 160, receipt: 160)
        expect(summary.count == 600 && summary.outsideWindow == 1, "60-second endpoint excluded")
        summary.receive(timestamp: 159.9, receipt: 159.95)
        expect(summary.duplicatesOrOutOfOrder == 1 && !summary.meetsSampleCriteria, "Duplicate rejected")
        var gaps = MotionSampleSummary(start: 100)
        gaps.receive(timestamp: 104, receipt: 104.1)
        gaps.receive(timestamp: 110, receipt: 113)
        expect(gaps.maximumGap == 6 && gaps.buckets[2].maximumGap == 6 && gaps.maximumDelay == 3, "Cross-bucket gap and delayed receipt retained")
        expect(gaps.status(now: 112.01) == "Samples stale", "Stale after two seconds")
        var invalid = MotionSampleSummary(start: 100)
        invalid.receive(timestamp: .nan, receipt: 101)
        expect(invalid.clockInvalid, "Invalid clocks rejected")
        let accumulator = BackgroundMotionAccumulator(start: 100)
        accumulator.receive(timestamp: 101, receipt: 101.1)
        _ = accumulator.stop(at: 102)
        DispatchQueue.concurrentPerform(iterations: 100) { _ in accumulator.receive(timestamp: 103, receipt: 103.1) }
        expect(accumulator.snapshot().count == 1, "Concurrent late callbacks rejected after stop")
        let failed = BackgroundMotionAccumulator(start: 100)
        failed.fail("Synthetic error", at: 101)
        failed.receive(timestamp: 102, receipt: 102)
        expect(failed.snapshot().count == 0 && failed.snapshot().error != nil, "Error freezes accepted samples")
        var recovery = trial()
        recovery.begin(at: Date(timeIntervalSince1970: 1_000), uptime: 100, inBackground: true)
        recovery.recover(at: Date(timeIntervalSince1970: 1_010), uptime: 110)
        recovery.begin(at: Date(), uptime: 120, inBackground: true)
        expect(recovery.phase == .interrupted && recovery.samples?.start == 100 && recovery.samples?.stoppedAt == nil, "Relaunch never restarts or invents stop time")
        var clock = trial()
        clock.begin(at: Date(timeIntervalSince1970: 1_000), uptime: 100, inBackground: true)
        clock.observeClock(date: Date(timeIntervalSince1970: 2_000), uptime: 101)
        expect(clock.clockDiscontinuity, "Wall-clock discontinuity detected")
        for n in 0..<45 { recovery.record("event \(n)", at: Date(), uptime: 120) }
        expect(recovery.events.count == 40 && recovery.eventsTruncated, "Event cap is explicit")
        var archive = BackgroundMotionArchive()
        for _ in 0..<8 { var item = trial(); item.unresolvedSession = false; archive.append(item) }
        try archive.validate()
        expect(archive.trials.count == 5, "Five-trial bound")
        let encoded = try JSONEncoder().encode(archive)
        try JSONDecoder().decode(BackgroundMotionArchive.self, from: encoded).validate()
        archive.trials[0].unresolvedSession = true
        do { try archive.validate(); fatalError("Invalid ownership archive accepted") } catch {}

        let suite = "Cumulus.synthetic.\(UUID())"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let owner = ExperimentSessionOwner(defaults: defaults)
        expect(owner.claim(.alert) && !owner.claim(.backgroundMotion), "Exclusive ownership")
        owner.release(.backgroundMotion)
        expect(owner.current == .alert, "Wrong owner cannot release")
        owner.release(.alert)
        let alert = ScheduledAlertCoordinator(owner: owner, defaults: defaults)
        let coordinator = BackgroundMotionCoordinator(owner: owner, defaults: defaults)
        WKApplication.shared().applicationState = .background
        coordinator.schedule(configuration: .init())
        expect(coordinator.latest == nil, "Schedule requires active app")
        WKApplication.shared().applicationState = .active
        coordinator.schedule(configuration: .init())
        let session = WKExtendedRuntimeSession.latest!
        let motion = CMMotionManager.latest!
        expect(coordinator.status == "Session scheduled" && !alert.canSchedule, "Only observed scheduled state; alert blocked")
        WKApplication.shared().applicationState = .background
        session.run()
        await settle()
        expect(coordinator.isCollecting && motion.starts == 1 && session.haptics == 0, "Collect only while running, before haptic")
        motion.callback?(CMAccelerometerData(timestamp: ProcessInfo.processInfo.systemUptime), nil)
        session.expireSoon()
        await settle()
        expect(!coordinator.isCollecting && motion.stops == 1 && session.haptics == 1, "Will-expire stops sensors before haptic")
        let count = coordinator.latest!.samples!.count
        motion.callback?(CMAccelerometerData(timestamp: ProcessInfo.processInfo.systemUptime), nil)
        expect(coordinator.latest!.samples!.count == count, "Late callback cannot mutate frozen trial")
        expect(owner.current == .backgroundMotion, "Will-expire does not release ownership")
        session.end(.expired)
        await settle()
        expect(owner.current == .none && coordinator.status == "Session expired", "Confirmed expiry releases ownership")
        WKApplication.shared().applicationState = .active
        coordinator.schedule(configuration: .init())
        let canceled = WKExtendedRuntimeSession.latest!
        coordinator.endSession()
        expect(canceled.invalidations == 1 && owner.current == .backgroundMotion, "Cancellation waits for invalidation")
        canceled.end(.none)
        await settle()
        expect(owner.current == .none && !coordinator.latest!.unresolvedSession, "Cancellation resolved")
        coordinator.schedule(configuration: .init())
        let errorSession = WKExtendedRuntimeSession.latest!
        errorSession.run()
        await settle()
        motion.callback?(nil, NSError(domain: "Synthetic", code: 42))
        try await Task.sleep(for: .milliseconds(600))
        expect(!coordinator.isCollecting && coordinator.latest?.samples?.error != nil, "Sensor error cleans up coordinator")
        errorSession.end(.error, error: NSError(domain: "SyntheticSession", code: 43))
        await settle()
        expect(owner.current == .none, "Session error releases ownership after cleanup")
        coordinator.schedule(configuration: .init())
        let manual = WKExtendedRuntimeSession.latest!
        manual.run()
        await settle()
        coordinator.endSession()
        expect(!coordinator.isCollecting && coordinator.latest?.stopReason == "Manual stop", "Manual stop freezes collection")
        manual.end(.none)
        await settle()
        // Old-session callbacks must not attach themselves to a later run.
        coordinator.schedule(configuration: .init())
        session.run()
        await settle()
        expect(!coordinator.isCollecting, "Old-session start ignored")
        WKExtendedRuntimeSession.latest!.end(.none)
        await settle()
        var interrupted = trial()
        interrupted.begin(at: Date(), uptime: ProcessInfo.processInfo.systemUptime, inBackground: true)
        defaults.set(try JSONEncoder().encode(BackgroundMotionArchive(trials: [interrupted])), forKey: "backgroundMotionExperiment.v1")
        let restored = BackgroundMotionCoordinator(owner: owner, defaults: defaults)
        let delivered = WKExtendedRuntimeSession()
        delivered.state = .running
        restored.attach(delivered, verifiedOwner: true)
        expect(restored.latest?.phase == .interrupted && !restored.isCollecting, "Actual coordinator relaunch recovery does not restart")
        expect(delivered.haptics == 1, "Recovered interrupted session can request cleanup haptic")
        delivered.end(.none)
        await settle()
        let scheduledTrial = trial()
        defaults.set(try JSONEncoder().encode(BackgroundMotionArchive(trials: [scheduledTrial])), forKey: "backgroundMotionExperiment.v1")
        let scheduledRecovery = BackgroundMotionCoordinator(owner: owner, defaults: defaults)
        let scheduledDelivery = WKExtendedRuntimeSession()
        scheduledDelivery.state = .running
        scheduledRecovery.attach(scheduledDelivery, verifiedOwner: true)
        expect(scheduledRecovery.isCollecting, "Pre-collection relaunch can start its original trial")
        scheduledDelivery.end(.error, error: NSError(domain: "Synthetic", code: 44))
        await settle()
        expect(!scheduledRecovery.isCollecting && CMMotionManager.latest!.stops == 1, "Direct invalidation stops active sensor")
        defaults.set(Data("invalid JSON".utf8), forKey: "backgroundMotionExperiment.v1")
        let corrupt = BackgroundMotionCoordinator(owner: owner, defaults: defaults)
        let unknown = WKExtendedRuntimeSession()
        unknown.state = .running
        corrupt.attach(unknown, verifiedOwner: true)
        expect(!corrupt.isCollecting && owner.current == .unresolved, "Corrupt history cannot authorize collection")
        let conflict = ExperimentSessionOwner(defaults: defaults)
        conflict.reconcile(alertPending: true, motionPending: true)
        expect(conflict.current == .unresolved && !conflict.claim(.alert), "Conflicting evidence blocks scheduling")
        print("PASS: sample boundaries, freshness, bounds, clocks, ownership, cancellation, error/expiry/manual-stop cleanup, stale callbacks and relaunch interruption")
    }
}
