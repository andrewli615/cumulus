import Combine
import CoreMotion
import Foundation
import WatchKit

@MainActor
final class BackgroundMotionCoordinator: NSObject, ObservableObject, WKExtendedRuntimeSessionDelegate {
    @Published private(set) var archive = BackgroundMotionArchive()
    @Published private(set) var status = "No session attached"
    @Published private(set) var sensorStatus = "Not collecting"
    @Published private(set) var storageError: String?
    @Published private(set) var canEndSession = false
    @Published private(set) var now = ProcessInfo.processInfo.systemUptime

    let owner: ExperimentSessionOwner
    private let defaults: UserDefaults
    private let testArchive: TestArchiveStore?
    private let storageKey = "backgroundMotionExperiment.v1"
    private let motion = CMMotionManager()
    private let queue: OperationQueue = {
        let queue = OperationQueue()
        queue.maxConcurrentOperationCount = 1
        queue.name = "Cumulus.backgroundMotion"
        return queue
    }()
    private var session: WKExtendedRuntimeSession?
    private var accumulator: BackgroundMotionAccumulator?
    private var timer: Task<Void, Never>?
    private var lastCheckpoint = 0
    private var quarantined = false
    private var ending = false
    private var recordedScheduled = false
    var latest: BackgroundMotionTrial? { archive.trials.last }
    var hasUnresolvedSession: Bool { storageError != nil || latest?.unresolvedSession == true || session != nil }
    var canSchedule: Bool { owner.current == .none && !hasUnresolvedSession && testArchive?.canStartNewReport != false }
    var isCollecting: Bool { accumulator != nil }

    init(owner: ExperimentSessionOwner, defaults: UserDefaults = .standard, testArchive: TestArchiveStore? = nil) {
        self.owner = owner
        self.defaults = defaults
        self.testArchive = testArchive
        super.init()
        guard let data = defaults.data(forKey: storageKey) else { return }
        do {
            archive = try JSONDecoder().decode(BackgroundMotionArchive.self, from: data)
            try archive.validate()
            for trial in archive.trials { saveReport(trial, importing: true) }
            if latest?.unresolvedSession == true {
                archive.trials[archive.trials.count - 1].recover(at: Date(), uptime: now)
                status = "Unverified after relaunch"
                sensorStatus = latest?.phase == .interrupted ? "Collection interrupted" : "Not collecting"
                persist()
            }
        } catch {
            storageError = "Saved trial cannot be read; session ownership is unverified."
            status = "Needs attention"
        }
    }

    func schedule(configuration: BackgroundMotionTrial.Configuration) {
        guard WKApplication.shared().applicationState == .active, canSchedule,
              owner.claim(.backgroundMotion) else { return }
        var configuration = configuration
        configuration.watchModel = String(configuration.watchModel.prefix(128))
        configuration.otherApp = String(configuration.otherApp.prefix(128))
        configuration.watchOS = WKInterfaceDevice.current().systemVersion
        configuration.appBuild = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "Unknown"
        WKInterfaceDevice.current().isBatteryMonitoringEnabled = true
        var trial = BackgroundMotionTrial(id: UUID(), requestedStart: Date().addingTimeInterval(180), configuration: configuration)
        trial.record("Schedule requested", at: Date(), uptime: ProcessInfo.processInfo.systemUptime)
        archive.append(trial)
        persist()
        let newSession = WKExtendedRuntimeSession()
        session = newSession
        newSession.delegate = self
        ending = false
        recordedScheduled = false
        status = "Scheduling requested"
        newSession.start(at: trial.requestedStart)
        refreshState()
    }

    func attach(_ delivered: WKExtendedRuntimeSession, verifiedOwner: Bool) {
        session = delivered
        delivered.delegate = self
        quarantined = !verifiedOwner || storageError != nil
        if quarantined {
            owner.markUnresolved()
            status = "Unknown session owner; collection blocked"
            canEndSession = delivered.state == .running || delivered.state == .scheduled
            return
        }
        WKInterfaceDevice.current().isBatteryMonitoringEnabled = true
        record("Relaunch received session (state \(delivered.state.rawValue))")
        refreshState()
    }

    func refreshState() {
        guard let session else { return }
        canEndSession = !ending && (session.state == .scheduled || session.state == .running)
        guard !quarantined, !ending else { return }
        switch session.state {
        case .notStarted: status = "Scheduling requested"
        case .scheduled:
            status = "Session scheduled"
            if !recordedScheduled { recordedScheduled = true; record("Session scheduled") }
        case .running:
            status = "Session running"
            if latest?.phase == .scheduled { beginCollection() }
            else if accumulator == nil { requestHaptic() }
        case .invalid: status = "Session invalid; awaiting reason"
        @unknown default: status = "Unknown session state"
        }
    }

    func applicationStateChanged(_ name: String) {
        guard latest?.unresolvedSession == true, !quarantined else { return }
        if isCollecting, WKApplication.shared().applicationState != .background {
            archive.trials[archive.trials.count - 1].backgroundThroughoutWindow = false
        }
        record("App state: \(name)")
        refreshState()
    }

    private func beginCollection() {
        guard latest?.phase == .scheduled, accumulator == nil else { return }
        let uptime = ProcessInfo.processInfo.systemUptime
        archive.trials[archive.trials.count - 1].begin(at: Date(), uptime: uptime,
            inBackground: WKApplication.shared().applicationState == .background)
        archive.trials[archive.trials.count - 1].batteryStart = batteryLevel()
        let collector = BackgroundMotionAccumulator(start: uptime)
        accumulator = collector
        lastCheckpoint = 0
        persist()
        guard motion.isAccelerometerAvailable else {
            collector.fail("Accelerometer unavailable", at: uptime)
            finishCollection(reason: "Motion error")
            return
        }
        motion.accelerometerUpdateInterval = 0.1
        motion.startAccelerometerUpdates(to: queue) { @Sendable data, error in
            let receipt = ProcessInfo.processInfo.systemUptime
            if let error { collector.fail(String("\((error as NSError).domain) code \((error as NSError).code): \(error.localizedDescription)".prefix(500)), at: receipt) }
            else if let timestamp = data?.timestamp { collector.receive(timestamp: timestamp, receipt: receipt) }
        }
        sensorStatus = "Waiting for samples"
        timer = Task { @MainActor [weak self] in
            while !Task.isCancelled {
                do { try await Task.sleep(for: .seconds(0.5)) } catch { return }
                guard let self, self.accumulator != nil else { return }
                self.tick()
            }
        }
    }

    private func tick() {
        guard let accumulator else { return }
        now = ProcessInfo.processInfo.systemUptime
        let summary = accumulator.snapshot()
        let index = archive.trials.count - 1
        archive.trials[index].samples = summary
        archive.trials[index].observeClock(date: Date(), uptime: now)
        if WKApplication.shared().applicationState != .background { archive.trials[index].backgroundThroughoutWindow = false }
        sensorStatus = summary.status(now: now)
        if summary.error != nil { finishCollection(reason: "Motion error"); return }
        if now - summary.start >= 60 { finishCollection(reason: "60-second window ended"); return }
        let checkpoint = Int((now - summary.start) / 5)
        if checkpoint > lastCheckpoint {
            lastCheckpoint = checkpoint
            record("Sample checkpoint: \(summary.count) accepted")
        }
    }

    private func finishCollection(reason: String, haptic: Bool = true) {
        guard let accumulator else { return }
        let uptime = ProcessInfo.processInfo.systemUptime
        let summary = accumulator.stop(at: uptime)
        self.accumulator = nil
        motion.stopAccelerometerUpdates()
        timer?.cancel()
        timer = nil
        let index = archive.trials.count - 1
        archive.trials[index].samples = summary
        archive.trials[index].observeClock(date: Date(), uptime: uptime)
        archive.trials[index].stop(reason: reason, at: Date(), uptime: uptime)
        archive.trials[index].batteryEnd = batteryLevel()
        sensorStatus = summary.error == nil ? "Collection stopped" : "Motion error; collection stopped"
        if let error = summary.error { record("Motion error: \(error)") }
        persist()
        if haptic { requestHaptic() }
    }

    func endSession() {
        guard WKApplication.shared().applicationState == .active, let session,
              canEndSession else { return }
        if !quarantined {
            if isCollecting { finishCollection(reason: "Manual stop") }
            else if latest?.phase == .scheduled {
                archive.trials[archive.trials.count - 1].stop(reason: "Canceled before collection", at: Date(), uptime: ProcessInfo.processInfo.systemUptime)
            }
            record(session.state == .scheduled ? "Cancellation requested" : "Stop session requested")
        }
        ending = true
        canEndSession = false
        status = "Invalidation requested"
        session.invalidate()
    }

    private func requestHaptic() {
        guard !quarantined, let session, session.state == .running,
              latest?.hapticRequested == false else { return }
        archive.trials[archive.trials.count - 1].hapticRequested = true
        session.notifyUser(hapticType: .notification, repeatHandler: nil)
        status = "Haptic requested after collection"
        record("Haptic requested after collection (default repeat interval)")
    }

    private func batteryLevel() -> Float? {
        let value = WKInterfaceDevice.current().batteryLevel
        return value >= 0 ? value : nil
    }

    private func record(_ message: String, at date: Date = Date(), uptime: TimeInterval = ProcessInfo.processInfo.systemUptime) {
        guard !archive.trials.isEmpty, !quarantined else { return }
        archive.trials[archive.trials.count - 1].record(message, at: date, uptime: uptime)
        persist()
    }

    private func persist() {
        do { defaults.set(try JSONEncoder().encode(archive), forKey: storageKey); storageError = nil }
        catch { storageError = "Could not encode trial metadata; evidence is incomplete." }
        if let latest { saveReport(latest) }
    }

    func clearCompletedHistory() {
        guard owner.current == .none, !hasUnresolvedSession else { return }
        archive = BackgroundMotionArchive()
        defaults.removeObject(forKey: storageKey)
        status = "Completed history cleared"
    }

    private func saveReport(_ trial: BackgroundMotionTrial, importing: Bool = false) {
        let report = TestReport(id: "background-" + trial.id.uuidString.lowercased(), kind: .background,
            createdAt: trial.events.first?.date ?? trial.requestedStart, title: "Background motion",
            status: trial.measurementAssessment, metrics: ["Phase": trial.phase.rawValue,
                "Original build": trial.configuration.appBuild, "Original watchOS": trial.configuration.watchOS,
                "Samples": trial.samples.map { String($0.count) } ?? "Unknown",
                "Unresolved session": String(trial.unresolvedSession),
                "Haptic requested": String(trial.hapticRequested), "Events truncated": String(trial.eventsTruncated)],
            events: trial.events.map { .init(date: $0.date, message: String($0.message.prefix(500))) })
        testArchive?.saveDiagnostics(trial, report: report, importing: importing)
    }

    nonisolated func extendedRuntimeSessionDidStart(_ session: WKExtendedRuntimeSession) {
        let identity = ObjectIdentifier(session)
        let date = Date(), uptime = ProcessInfo.processInfo.systemUptime
        Task { @MainActor [weak self] in
            guard let self, let attached = self.session, ObjectIdentifier(attached) == identity else { return }
            self.record("Session start callback", at: date, uptime: uptime)
            self.refreshState()
        }
    }

    nonisolated func extendedRuntimeSessionWillExpire(_ session: WKExtendedRuntimeSession) {
        let identity = ObjectIdentifier(session)
        let date = Date(), uptime = ProcessInfo.processInfo.systemUptime
        Task { @MainActor [weak self] in
            guard let self, let attached = self.session, ObjectIdentifier(attached) == identity else { return }
            self.record("Session will expire", at: date, uptime: uptime)
            self.finishCollection(reason: "Session will expire")
            self.status = "Session expiring"
        }
    }

    nonisolated func extendedRuntimeSession(_ session: WKExtendedRuntimeSession,
        didInvalidateWith reason: WKExtendedRuntimeSessionInvalidationReason, error: Error?) {
        let identity = ObjectIdentifier(session)
        let date = Date(), uptime = ProcessInfo.processInfo.systemUptime
        let code = reason.rawValue
        let message = error.map { String("\(($0 as NSError).domain) code \(($0 as NSError).code): \($0.localizedDescription)".prefix(500)) }
        Task { @MainActor [weak self] in
            guard let self, let attached = self.session, ObjectIdentifier(attached) == identity else { return }
            self.finishCollection(reason: "Session invalidated", haptic: false)
            self.session = nil
            self.canEndSession = false
            if !self.quarantined, !self.archive.trials.isEmpty {
                if self.latest?.phase == .scheduled {
                    self.archive.trials[self.archive.trials.count - 1].stop(reason: "Session ended before collection", at: date, uptime: uptime)
                }
                self.archive.trials[self.archive.trials.count - 1].unresolvedSession = false
                self.record("Session invalidated (reason \(code))", at: date, uptime: uptime)
                if let message { self.record("Session error: \(message)", at: date, uptime: uptime) }
                self.owner.release(.backgroundMotion)
            }
            self.status = self.quarantined ? "Session ended; saved ownership still unverified" :
                (code == WKExtendedRuntimeSessionInvalidationReason.expired.rawValue ? "Session expired" : "Session ended")
        }
    }
}
