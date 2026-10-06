import Combine
import Foundation
import WatchKit

@MainActor
final class ScheduledAlertCoordinator: NSObject, ObservableObject, WKExtendedRuntimeSessionDelegate {
    struct Event: Codable, Identifiable {
        let id: UUID
        let date: Date
        let requestedStart: Date?
        let message: String
    }

    private struct SavedExperiment: Codable {
        let requestedStart: Date?
        let unresolvedSession: Bool
        let hapticRequested: Bool
        let events: [Event]
    }

    @Published private(set) var status = "No session scheduled"
    @Published private(set) var requestedStart: Date?
    @Published private(set) var events: [Event] = []
    @Published private(set) var storageError: String?
    @Published private(set) var isUnverified = false
    @Published private(set) var canCancel = false
    @Published private(set) var canStop = false

    var canSchedule: Bool { session == nil && !isUnverified && storageError == nil && owner.current == .none }
    var blocksMotionProbe: Bool { session != nil || isUnverified }

    private let owner: ExperimentSessionOwner
    private let defaults: UserDefaults
    private let storageKey = "scheduledAlertExperiment.v1"
    private var session: WKExtendedRuntimeSession?
    private var didRecordScheduled = false
    private var didRecordStart = false
    private var didRequestHaptic = false
    private var pendingStop: String?
    private var unresolvedSession = false

    init(owner: ExperimentSessionOwner, defaults: UserDefaults = .standard) {
        self.owner = owner
        self.defaults = defaults
        super.init()
        guard let data = defaults.data(forKey: storageKey) else { return }
        do {
            let saved = try JSONDecoder().decode(SavedExperiment.self, from: data)
            requestedStart = saved.requestedStart
            events = Array(saved.events.suffix(40))
            unresolvedSession = saved.unresolvedSession
            didRequestHaptic = saved.hapticRequested
            isUnverified = saved.unresolvedSession
            status = isUnverified ? "Unverified after relaunch" : "No live session attached"
        } catch {
            storageError = "Could not read saved experiment history. Session state is unknown."
            status = "Needs attention"
            isUnverified = true
        }
    }

    func schedule() {
        guard WKApplication.shared().applicationState == .active, canSchedule, owner.claim(.alert) else { return }
        let newSession = WKExtendedRuntimeSession()
        session = newSession
        newSession.delegate = self
        didRecordScheduled = false
        didRecordStart = false
        didRequestHaptic = false
        pendingStop = nil
        requestedStart = Date().addingTimeInterval(180)
        unresolvedSession = true
        status = "Scheduling requested"
        record("Schedule requested")
        guard let requestedStart else { return }
        newSession.start(at: requestedStart)
        refreshState()
    }

    func attachRelaunchedSession(_ deliveredSession: WKExtendedRuntimeSession) {
        let replacingAttachedSession = session != nil && session !== deliveredSession
        session = deliveredSession
        deliveredSession.delegate = self
        if replacingAttachedSession {
            didRecordScheduled = false
            didRecordStart = false
            didRequestHaptic = false
            pendingStop = nil
        }
        isUnverified = false
        unresolvedSession = true
        status = didRequestHaptic ? "Haptic previously requested" : "Session received"
        record("Relaunch handler received session (state \(deliveredSession.state.rawValue))")
        refreshState()
    }

    func refreshState() {
        guard let session else { return }
        canCancel = pendingStop == nil && session.state == .scheduled
        canStop = pendingStop == nil && session.state == .running
        if pendingStop != nil { return }
        switch session.state {
        case .notStarted:
            status = "Scheduling requested"
        case .scheduled:
            status = "Session scheduled"
            if !didRecordScheduled {
                didRecordScheduled = true
                record("Session scheduled")
            }
        case .running:
            requestHapticIfRunning()
        case .invalid:
            status = "Session invalid; awaiting reason"
        @unknown default:
            status = "Unknown session state"
        }
    }

    func cancel() { invalidateSession(action: "Cancellation") }
    func stopAlert() { invalidateSession(action: "Stop alert") }

    private func invalidateSession(action: String) {
        guard WKApplication.shared().applicationState == .active,
              let session, pendingStop == nil,
              session.state == .scheduled || session.state == .running else { return }
        pendingStop = action
        canCancel = false
        canStop = false
        status = "\(action) requested"
        record("\(action) requested")
        session.invalidate()
    }

    private func requestHapticIfRunning() {
        guard let session, session.state == .running, pendingStop == nil else { return }
        if !didRecordStart {
            didRecordStart = true
            record("Running session observed")
        }
        guard !didRequestHaptic else { return }
        didRequestHaptic = true
        session.notifyUser(hapticType: .notification, repeatHandler: nil)
        status = "Haptic requested"
        canCancel = false
        canStop = true
        record("Haptic requested (default repeat interval)")
    }

    nonisolated func extendedRuntimeSessionDidStart(_ extendedRuntimeSession: WKExtendedRuntimeSession) {
        let identity = ObjectIdentifier(extendedRuntimeSession)
        let date = Date()
        Task { @MainActor [weak self] in
            guard let self, let session = self.session, ObjectIdentifier(session) == identity else { return }
            self.record("Session start callback", at: date)
            self.didRecordStart = true
            self.refreshState()
        }
    }

    nonisolated func extendedRuntimeSessionWillExpire(_ extendedRuntimeSession: WKExtendedRuntimeSession) {
        let identity = ObjectIdentifier(extendedRuntimeSession)
        let date = Date()
        Task { @MainActor [weak self] in
            guard let self, let session = self.session, ObjectIdentifier(session) == identity else { return }
            self.record("Session will expire", at: date)
            self.status = "Session expiring"
        }
    }

    nonisolated func extendedRuntimeSession(
        _ extendedRuntimeSession: WKExtendedRuntimeSession,
        didInvalidateWith reason: WKExtendedRuntimeSessionInvalidationReason, error: Error?
    ) {
        let identity = ObjectIdentifier(extendedRuntimeSession)
        let date = Date()
        let reasonCode = reason.rawValue
        let errorDetails = error.map { "\(($0 as NSError).domain) code \(($0 as NSError).code): \($0.localizedDescription)" }
        Task { @MainActor [weak self] in
            guard let self, let session = self.session, ObjectIdentifier(session) == identity else { return }
            self.session = nil
            self.unresolvedSession = false
            self.isUnverified = false
            self.canCancel = false
            self.canStop = false
            if reasonCode == WKExtendedRuntimeSessionInvalidationReason.expired.rawValue {
                self.status = "Session expired"
                self.record("Session expired", at: date)
            } else if errorDetails != nil || reasonCode == WKExtendedRuntimeSessionInvalidationReason.error.rawValue {
                self.status = "Needs attention"
            } else if let action = self.pendingStop,
                      reasonCode == WKExtendedRuntimeSessionInvalidationReason.none.rawValue {
                self.status = action == "Cancellation" ? "Canceled" : "Alert stopped"
            } else {
                self.status = "Session ended"
            }
            self.pendingStop = nil
            self.record("Session invalidated (reason \(reasonCode))", at: date)
            if let errorDetails { self.record("Error: \(errorDetails)", at: date) }
            self.owner.release(.alert)
        }
    }

    private func record(_ message: String, at date: Date = Date()) {
        events.append(Event(id: UUID(), date: date, requestedStart: requestedStart, message: message))
        events = Array(events.suffix(40))
        let saved = SavedExperiment(requestedStart: requestedStart, unresolvedSession: unresolvedSession,
                                    hapticRequested: didRequestHaptic, events: events)
        do {
            defaults.set(try JSONEncoder().encode(saved), forKey: storageKey)
            storageError = nil
        } catch {
            storageError = "Could not encode experiment history; recent events may not survive relaunch."
        }
    }
}
