import Combine
import Foundation
import WatchKit

@MainActor
final class OvernightMotionCoordinator: ObservableObject {
    @Published private(set) var archive = OvernightMotionArchive()
    @Published private(set) var access: OvernightRecorderAccess
    @Published private(set) var status = "Ready for the availability check"
    @Published private(set) var storageError: String?
    @Published private(set) var isRetrieving = false
    @Published private(set) var isRequestingAccess = false
    @Published private(set) var progress = ""
    @Published private(set) var preflightBattery: Double?
    private let clockTime: (OvernightMotionTrial.ElapsedClock?) -> TimeInterval
    private let recorder: OvernightMotionRecorder
    private let owner: ExperimentSessionOwner
    private let defaults: UserDefaults
    private let testArchive: TestArchiveStore?
    private let key = "overnightMotion.v1"
    private var retrievalID: UUID?
    private var cancellation: OvernightRetrievalCancellation?
    var latest: OvernightMotionTrial? { archive.trials.last }
    var hasReservation: Bool { latest?.reservesWindow == true }
    var build: String {
        "\(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "Unknown") (\(Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "Unknown"))"
    }
    var pilotReady: Bool {
        archive.pilotEvidence?.watchOS == WKInterfaceDevice.current().systemVersion && archive.pilotEvidence?.appBuild == build
    }

    init(owner: ExperimentSessionOwner, defaults: UserDefaults = .standard,
         recorder: OvernightMotionRecorder = OvernightMotionRecorder(), testArchive: TestArchiveStore? = nil,
         clockTime: @escaping (OvernightMotionTrial.ElapsedClock?) -> TimeInterval = OvernightMotionTrial.elapsedTime) {
        self.clockTime = clockTime
        self.owner = owner
        self.defaults = defaults
        self.testArchive = testArchive
        self.recorder = recorder
        access = recorder.access()
        if let stored = defaults.object(forKey: key) {
            do {
                guard let data = stored as? Data, data.count <= 2_000_000 else { throw OvernightArchiveError.invalid }
                let loaded = try JSONDecoder().decode(OvernightMotionArchive.self, from: data)
                try loaded.validate()
                archive = loaded
                for trial in loaded.trials { saveReport(trial, importing: true) }
            } catch {
                storageError = "Saved trial cannot be verified. Requests are blocked; preserve the existing data."
                owner.markUnresolved()
            }
        }
        checkBattery()
        if hasReservation {
            mutateLatest { trial in
                trial.recovered = true
                if trial.phase == .prepared { trial.phase = .uncertain }
                trial.record("Relaunch recovered original window; no new request")
            }
            status = "Original window recovered; no new recording request"
            refreshClock()
        }
    }

    func canStart(_ mode: OvernightMotionTrial.Mode, configuration: OvernightMotionTrial.Configuration = .init()) -> Bool {
        storageError == nil && !hasReservation && !isRetrieving && !isRequestingAccess && testArchive?.canStartNewReport != false
            && owner.current == .none && WKApplication.shared().applicationState == .active
            && (mode == .comparison || access.canRecord) && preflightReason(mode, configuration: configuration) == nil
    }

    private func preparedConfiguration(_ configuration: OvernightMotionTrial.Configuration) -> OvernightMotionTrial.Configuration {
        var settings = configuration
        settings.watchModel = String(settings.watchModel.prefix(128))
        settings.otherApp = String(settings.otherApp.prefix(128))
        settings.watchOS = WKInterfaceDevice.current().systemVersion
        settings.appBuild = build
        settings.timeZone = TimeZone.current.identifier
        return settings
    }

    func checkBattery() {
        guard WKApplication.shared().applicationState == .active, !isRetrieving else { return }
        preflightBattery = batteryLevel()
    }

    func preflightReason(_ mode: OvernightMotionTrial.Mode, configuration: OvernightMotionTrial.Configuration) -> String? {
        guard mode != .pilot else { return nil }
        if mode == .overnight && !pilotReady { return "Pass the pilot on this OS and build first." }
        let settings = preparedConfiguration(configuration)
        if !settings.hasKnownWearSetup { return "Complete setup: model, wrist, power, Focus, tracking, other app and detached debugger." }
        if !OvernightBatteryCriteria.canBegin(level: preflightBattery) {
            return "Eight-hour trials need a known battery of at least \(Int((OvernightBatteryCriteria.minimumStartLevel * 100).rounded()))%. Check battery after charging, then run without charging."
        }
        if mode == .overnight && archive.comparableBaseline(configuration: settings) == nil {
            return "Complete a matching eight-hour comparison with no charging, interruption or clock uncertainty first."
        }
        return nil
    }

    func requestAccess() {
        guard WKApplication.shared().applicationState == .active, !hasReservation, !isRetrieving,
              !isRequestingAccess, owner.current == .none else { return }
        isRequestingAccess = true
        recorder.requestAccess { [weak self] message in
            Task { @MainActor in
                guard let self else { return }
                self.isRequestingAccess = false
                self.access = self.recorder.access()
                self.status = message ?? "Access check completed: \(self.access.authorization)"
            }
        }
    }

    func start(_ mode: OvernightMotionTrial.Mode, configuration: OvernightMotionTrial.Configuration) {
        refreshClock()
        access = recorder.access()
        let preparedAt = Date()
        let preparedUptime = clockTime(.continuous)
        checkBattery()
        if let reason = preflightReason(mode, configuration: configuration) { status = reason; return }
        guard canStart(mode, configuration: configuration), owner.claim(.overnightMotion) else {
            status = "Request blocked; check access, storage and session status"
            return
        }
        let settings = preparedConfiguration(configuration)
        let battery = preflightBattery
        var trial = OvernightMotionTrial(mode: mode, start: Date(), uptime: clockTime(.continuous),
                                         configuration: settings, battery: battery, elapsedClock: .continuous, measurementBasis: .sensorTime)
        if mode == .overnight { trial.batteryComparisonID = archive.comparableBaseline(configuration: settings)?.id }
        archive.append(trial)
        archive.trials[archive.trials.count - 1].record("Recorder available: \(access.available); authorization: \(access.authorization)")
        archive.trials[archive.trials.count - 1].record(mode == .comparison ? "Comparison started; no recording request" : "Request prepared; provisional window saved")
        guard persist() else { owner.markUnresolved(); return }
        if mode != .comparison {
            let startedAt = Date()
            let startedUptime = clockTime(.continuous)
            recorder.record(duration: mode.duration)
            let returnedAt = Date()
            let returnedUptime = clockTime(.continuous)
            mutateLatest { trial in
                trial.start = startedAt
                trial.end = startedAt.addingTimeInterval(mode.duration)
                trial.startUptime = startedUptime
                trial.recorderCall = .init(preparedAt: preparedAt, preparedUptime: preparedUptime,
                                           returnedAt: returnedAt, returnedUptime: returnedUptime)
                trial.requestCount = 1
                trial.phase = .requested
                trial.record("Recorder call entered; sample delivery unconfirmed", at: startedAt)
                trial.record("Recorder call returned; reservation includes full duration", at: returnedAt)
            }
            refreshClock(now: returnedAt, uptime: returnedUptime)
        }
        if latest?.clockDiscontinuity != true {
            status = mode == .comparison ? "Comparison window active" : "Request issued; retrieve later to inspect samples"
        }
    }

    func refreshClock(now: Date = Date(), uptime: TimeInterval? = nil) {
        guard let trial = latest, storageError == nil else { return }
        guard !trial.hasCompletedObservation else { return }
        let uptime = uptime ?? clockTime(trial.elapsedClock)
        if !trial.clockIsContinuous(now: now, uptime: uptime) {
            if !trial.clockDiscontinuity {
                mutateLatest { trial in
                    trial.clockDiscontinuity = true
                    trial.firstClockMismatch = .init(observedAt: now, wallElapsed: now.timeIntervalSince(trial.start),
                                                     clockElapsed: uptime - trial.startUptime)
                    if trial.reservesWindow { trial.phase = .uncertain }
                    trial.record("Clock/reboot discontinuity; original window retained", at: now)
                }
            }
            status = "Clock/reboot uncertainty; timing and visibility inconclusive"
            return
        }
        guard trial.reservesWindow else { return }
        guard trial.phase != .uncertain else { status = "Request outcome uncertain; no automatic restart"; return }
        if now >= trial.reservationEnd && uptime >= trial.reservationEndUptime {
            mutateLatest { trial in trial.phase = .elapsed; trial.record("Requested window elapsed", at: now) }
            owner.release(.overnightMotion)
            status = "Requested window elapsed; delivery still unconfirmed"
        }
    }

    func acknowledgeElapsedWindow() {
        guard let trial = latest, trial.phase == .uncertain, Date() >= trial.reservationEnd,
              WKApplication.shared().applicationState == .active, storageError == nil else { return }
        mutateLatest { trial in
            trial.phase = .elapsed
            trial.record("Owner confirmed fixed window elapsed; uncertainty preserved")
        }
        owner.release(.overnightMotion)
        status = "Window acknowledged; uncertain trials cannot qualify the pilot"
    }

    func applicationStateChanged(_ state: String) {
        if state != "active" { cancelRetrieval() }
        if state == "active" {
            checkBattery()
            access = recorder.access()
            refreshClock()
            recordReturn()
        }
        guard let trial = latest, trial.reservesWindow else { return }
        let departure = state == "background" && trial.departure == nil
        let battery = departure ? batteryLevel() : nil
        mutateLatest { trial in
            if departure {
                trial.departure = Date()
                trial.batteryStart = OvernightMotionTrial.Battery(date: Date(), level: battery)
            }
            trial.record("App \(state)")
        }
    }

    func recordReturn() {
        guard let trial = latest, trial.batteryReturn == nil, Date() >= trial.reservationEnd,
              WKApplication.shared().applicationState == .active, storageError == nil else { return }
        let battery = batteryLevel()
        mutateLatest { trial in
            trial.batteryReturn = OvernightMotionTrial.Battery(date: Date(), level: battery)
            trial.record("Return battery captured before retrieval")
        }
    }

    func recordConditions(charging: String, interruption: String) {
        guard let trial = latest, Date() >= trial.end, !isRetrieving, storageError == nil,
              WKApplication.shared().applicationState == .active else { return }
        mutateLatest { trial in
            trial.configuration.charging = String(charging.prefix(128))
            trial.configuration.interruption = String(interruption.prefix(128))
            trial.record("Owner recorded charging/interruption observations")
        }
    }

    func canRetrieve(pilotProbe: Bool, now: Date = Date()) -> Bool {
        guard let trial = latest, trial.mode != .comparison, trial.requestCount == 1,
              !isRetrieving, !isRequestingAccess, storageError == nil, access.canRecord,
              WKApplication.shared().applicationState == .active,
              owner.current == .none || owner.current == .overnightMotion else { return false }
        let start = pilotProbe ? trial.start.addingTimeInterval(540) : trial.start
        let end = pilotProbe ? trial.start.addingTimeInterval(600) : trial.end
        return (!pilotProbe || trial.mode == .pilot) && now >= end && now.timeIntervalSince(start) < 259200
    }

    func retrieve(pilotProbe: Bool) {
        guard let trial = latest, trial.mode != .comparison, trial.requestCount == 1,
              !isRetrieving, !isRequestingAccess, storageError == nil,
              WKApplication.shared().applicationState == .active,
              owner.current == .none || owner.current == .overnightMotion else { return }
        refreshClock()
        access = recorder.access()
        guard access.canRecord else { status = "Retrieval blocked: \(access.authorization)"; return }
        let start = pilotProbe ? trial.start.addingTimeInterval(540) : trial.start
        let end = pilotProbe ? trial.start.addingTimeInterval(600) : trial.end
        guard !pilotProbe || trial.mode == .pilot, Date() >= end else { status = "Wait until the selected window ends"; return }
        guard Date().timeIntervalSince(start) < 259200 else { status = "Window exceeds three-day retention; evidence inconclusive"; return }
        recordReturn()
        let requestedAt = Date()
        let requestClockContinuous = trial.clockIsContinuous(now: requestedAt, uptime: clockTime(trial.elapsedClock))
        let id = UUID()
        retrievalID = id
        let flag = OvernightRetrievalCancellation()
        cancellation = flag
        isRetrieving = true
        progress = "Starting retrieval"
        mutateLatest { $0.record("\(pilotProbe ? "Pilot block" : "Full window") retrieval requested; available \(access.available); access \(access.authorization)") }
        recorder.retrieve(start: start, end: end, cancellation: flag, timingBasis: trial.measurementBasis, progress: { [weak self] done, total in
            Task { @MainActor in
                guard let self, self.retrievalID == id else { return }
                self.progress = "Retrieved chunk \(done) of \(total)"
            }
        }, completion: { [weak self] result in
            Task { @MainActor in
                guard let self, self.retrievalID == id, self.latest?.id == trial.id else { return }
                self.isRetrieving = false
                self.retrievalID = nil
                self.cancellation = nil
                self.refreshClock()
                let cancelled = result.cancelled || flag.isCancelled || WKApplication.shared().applicationState != .active
                let readClockUncertain = !requestClockContinuous
                    || !trial.clockIsContinuous(now: Date(), uptime: self.clockTime(trial.elapsedClock))
                let preserveCompletedEvidence = readClockUncertain && trial.hasCompletedObservation
                let useful = !cancelled && !readClockUncertain && result.error == nil
                    && result.summary.meetsTimingCriteria && self.latest?.clockDiscontinuity == false
                var observation = OvernightMotionTrial.Observation(pilotProbe: pilotProbe, requestedAt: requestedAt, completedAt: result.completedAt,
                    count: result.summary.count, useful: useful, first: result.summary.first, last: result.summary.last,
                    nilChunks: result.summary.nilChunks, emptyChunks: result.summary.emptyChunks, cancelled: cancelled,
                    error: result.error.map { String($0.prefix(400)) })
                observation.clockDiscontinuity = readClockUncertain
                observation.orderDiagnostics = result.summary.orderDiagnostics
                observation.timingAssessment = .init(summary: result.summary, pilotProbe: pilotProbe)
                self.mutateLatest { current in
                    current.observations.append(observation)
                    current.observations = Array(current.observations.suffix(40))
                    if !cancelled && !preserveCompletedEvidence {
                        if pilotProbe {
                            current.latestProbe = observation
                            if useful { current.firstUsefulProbeAt = current.firstUsefulProbeAt ?? result.completedAt }
                            else if current.firstUsefulProbeAt == nil { current.precedingIncompleteProbeAt = result.completedAt }
                        } else {
                            current.fullSummary = result.summary
                            current.fullReadAt = result.completedAt
                            if useful { current.firstUsefulReadAt = current.firstUsefulReadAt ?? result.completedAt }
                        }
                    }
                    if cancelled { current.record("Retrieval cancelled; previous summary retained") }
                    else if preserveCompletedEvidence { current.record("Retrieval clock uncertain; previous summary retained") }
                    else { current.record("Retrieval completed: \(result.summary.count) samples, nil \(result.summary.nilChunks), empty \(result.summary.emptyChunks)") }
                    if let error = result.error { current.record("Retrieval error: \(error)") }
                }
                if cancelled { self.status = "Retrieval cancelled; system request continues to its fixed end" }
                else if readClockUncertain { self.status = preserveCompletedEvidence
                    ? "Retrieval clock uncertain; completed evidence retained" : "Samples retrieved; clock timing inconclusive" }
                else { self.status = result.error ?? "Summary updated; review timing and conditions" }
            }
        })
    }

    func cancelRetrieval() {
        guard isRetrieving else { return }
        cancellation?.cancel()
        status = "Cancelling retrieval; system recording has no stop API"
    }

    private func batteryLevel() -> Double? {
        let device = WKInterfaceDevice.current()
        device.isBatteryMonitoringEnabled = true
        let level = Double(device.batteryLevel)
        return (0...1).contains(level) ? level : nil
    }
    private func mutateLatest(_ update: (inout OvernightMotionTrial) -> Void) {
        guard !archive.trials.isEmpty else { return }
        update(&archive.trials[archive.trials.count - 1])
        archive.updatePilotEvidence()
        _ = persist()
    }
    func clearCompletedHistory() {
        guard owner.current == .none, !hasReservation, !isRetrieving, !isRequestingAccess, storageError == nil else { return }
        archive = OvernightMotionArchive()
        defaults.removeObject(forKey: key)
        status = "Completed history and pilot qualification cleared"
    }

    private func saveReport(_ trial: OvernightMotionTrial, importing: Bool = false) {
        var metrics = ["Mode": trial.mode.title, "Phase": trial.phase.rawValue,
            "Original build": trial.configuration.appBuild, "Original watchOS": trial.configuration.watchOS,
            "Charging": trial.configuration.charging, "Interruption": trial.configuration.interruption,
            "Elapsed clock": trial.clockLabel, "Clock discontinuity": String(trial.clockDiscontinuity), "Pilot software criteria": String(trial.pilotQualified),
            "Visibility": trial.morningVisibility, "Events truncated": String(trial.eventsTruncated),
            "Requested start (Unix seconds)": String(trial.start.timeIntervalSince1970),
            "Requested end (Unix seconds)": String(trial.end.timeIntervalSince1970)]
        if let id = trial.batteryComparisonID { metrics["Battery comparison trial"] = id.uuidString }
        if let summary = trial.fullSummary {
            metrics["Measurement timing"] = summary.clockLabel
            metrics["Sensor order failures"] = summary.sensorOrderFailures.map(String.init) ?? "Not separately recorded"
            metrics["Samples"] = String(summary.count)
            metrics["Qualifying buckets"] = "\(summary.qualifyingBuckets)/\(summary.buckets.count)"
            metrics["Observed Hz"] = summary.observedRate.map { String($0) } ?? "Unknown"
            metrics["Largest gap (s)"] = String(summary.maximumGap)
            metrics["Leading gap (s)"] = summary.leadingGap.map { String($0) } ?? "Unknown"
            metrics["Trailing gap (s)"] = summary.trailingGap.map { String($0) } ?? "Unknown"
            metrics["Order anomalies"] = String(summary.outOfOrder)
        }
        let report = TestReport(id: "overnight-" + trial.id.uuidString.lowercased(), kind: .overnight,
            createdAt: trial.recorderCall?.preparedAt ?? trial.start, title: "Overnight · " + trial.mode.title,
            status: trial.timingStatus, metrics: metrics,
            events: trial.events.map { .init(date: $0.date, message: $0.message) })
        testArchive?.saveDiagnostics(trial, report: report, importing: importing)
    }

    @discardableResult private func persist() -> Bool {
        do {
            try archive.validate()
            defaults.set(try JSONEncoder().encode(archive), forKey: key)
            if let latest { saveReport(latest) }
            return true
        } catch {
            storageError = "Trial metadata could not be saved; requests blocked"
            owner.markUnresolved()
            return false
        }
    }
}
