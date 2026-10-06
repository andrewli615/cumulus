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
    private let recorder: OvernightMotionRecorder
    private let owner: ExperimentSessionOwner
    private let defaults: UserDefaults
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
         recorder: OvernightMotionRecorder = OvernightMotionRecorder()) {
        self.owner = owner
        self.defaults = defaults
        self.recorder = recorder
        access = recorder.access()
        if let stored = defaults.object(forKey: key) {
            do {
                guard let data = stored as? Data, data.count <= 2_000_000 else { throw OvernightArchiveError.invalid }
                let loaded = try JSONDecoder().decode(OvernightMotionArchive.self, from: data)
                try loaded.validate()
                archive = loaded
            } catch {
                storageError = "Saved trial cannot be verified. Requests are blocked; preserve the existing data."
                owner.markUnresolved()
            }
        }
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

    func canStart(_ mode: OvernightMotionTrial.Mode) -> Bool {
        storageError == nil && !hasReservation && !isRetrieving && !isRequestingAccess
            && owner.current == .none && WKApplication.shared().applicationState == .active
            && (mode == .comparison || access.canRecord) && (mode != .overnight || pilotReady)
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
        guard canStart(mode), owner.claim(.overnightMotion) else { status = "Request blocked; check access, pilot and session status"; return }
        var settings = configuration
        settings.watchModel = String(settings.watchModel.prefix(128))
        settings.otherApp = String(settings.otherApp.prefix(128))
        settings.watchOS = WKInterfaceDevice.current().systemVersion
        settings.appBuild = build
        settings.timeZone = TimeZone.current.identifier
        let trial = OvernightMotionTrial(mode: mode, start: Date(), uptime: ProcessInfo.processInfo.systemUptime,
                                         configuration: settings, battery: batteryLevel())
        archive.append(trial)
        archive.trials[archive.trials.count - 1].record("Recorder available: \(access.available); authorization: \(access.authorization)")
        archive.trials[archive.trials.count - 1].record(mode == .comparison ? "Comparison started; no recording request" : "Request prepared; original window saved")
        guard persist() else { owner.markUnresolved(); return }
        if mode != .comparison {
            recorder.record(duration: mode.duration)
            mutateLatest { trial in
                trial.requestCount = 1
                trial.phase = .requested
                trial.record("Recording request issued; sample delivery unconfirmed")
            }
        }
        status = mode == .comparison ? "Comparison window active" : "Request issued; retrieve later to inspect samples"
    }

    func refreshClock(now: Date = Date(), uptime: TimeInterval = ProcessInfo.processInfo.systemUptime) {
        guard let trial = latest, storageError == nil else { return }
        let elapsed = uptime - trial.startUptime
        if elapsed < 0 || abs(now.timeIntervalSince(trial.start) - elapsed) > 5 {
            if !trial.clockDiscontinuity {
                mutateLatest { trial in
                    trial.clockDiscontinuity = true
                    if trial.reservesWindow { trial.phase = .uncertain }
                    trial.record("Clock/reboot discontinuity; original window retained", at: now)
                }
            }
            status = "Clock/reboot uncertainty; timing and visibility inconclusive"
            return
        }
        guard trial.reservesWindow else { return }
        guard trial.phase != .uncertain else { status = "Request outcome uncertain; no automatic restart"; return }
        if now >= trial.end {
            mutateLatest { trial in trial.phase = .elapsed; trial.record("Requested window elapsed", at: now) }
            owner.release(.overnightMotion)
            status = "Requested window elapsed; delivery still unconfirmed"
        }
    }

    func acknowledgeElapsedWindow() {
        guard let trial = latest, trial.phase == .uncertain, Date() >= trial.end,
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
        guard let trial = latest, trial.batteryReturn == nil, Date() >= trial.end,
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

    func canRetrieve(pilotProbe: Bool) -> Bool {
        guard let trial = latest, trial.mode != .comparison, trial.requestCount == 1,
              !isRetrieving, !isRequestingAccess, storageError == nil, access.canRecord,
              WKApplication.shared().applicationState == .active,
              owner.current == .none || owner.current == .overnightMotion else { return false }
        let start = pilotProbe ? trial.start.addingTimeInterval(540) : trial.start
        let end = pilotProbe ? trial.start.addingTimeInterval(600) : trial.end
        return (!pilotProbe || trial.mode == .pilot) && Date() >= end && Date().timeIntervalSince(start) < 259200
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
        let id = UUID()
        retrievalID = id
        let flag = OvernightRetrievalCancellation()
        cancellation = flag
        isRetrieving = true
        progress = "Starting retrieval"
        mutateLatest { $0.record("\(pilotProbe ? "Pilot block" : "Full window") retrieval requested; available \(access.available); access \(access.authorization)") }
        recorder.retrieve(start: start, end: end, cancellation: flag, progress: { [weak self] done, total in
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
                let useful = !cancelled && result.error == nil && result.summary.meetsTimingCriteria && self.latest?.clockDiscontinuity == false
                let observation = OvernightMotionTrial.Observation(pilotProbe: pilotProbe, requestedAt: requestedAt, completedAt: result.completedAt,
                    count: result.summary.count, useful: useful, first: result.summary.first, last: result.summary.last,
                    nilChunks: result.summary.nilChunks, emptyChunks: result.summary.emptyChunks, cancelled: cancelled,
                    error: result.error.map { String($0.prefix(400)) })
                self.mutateLatest { current in
                    current.observations.append(observation)
                    current.observations = Array(current.observations.suffix(40))
                    if !cancelled {
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
                    current.record(cancelled ? "Retrieval cancelled; previous summary retained" : "Retrieval completed: \(result.summary.count) samples, nil \(result.summary.nilChunks), empty \(result.summary.emptyChunks)")
                    if let error = result.error { current.record("Retrieval error: \(error)") }
                }
                self.status = cancelled ? "Retrieval cancelled; system request continues to its fixed end" : (result.error ?? "Summary updated; review timing and conditions")
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
    @discardableResult private func persist() -> Bool {
        do {
            try archive.validate()
            defaults.set(try JSONEncoder().encode(archive), forKey: key)
            return true
        } catch {
            storageError = "Trial metadata could not be saved; requests blocked"
            owner.markUnresolved()
            return false
        }
    }
}
