import Combine
import Foundation
import WatchKit

@MainActor
final class AlarmCoordinator: NSObject, ObservableObject, WKExtendedRuntimeSessionDelegate {
    @Published private(set) var record: AlarmRecord?
    @Published private(set) var status = "Not set"
    @Published private(set) var errorMessage: String?
    @Published private(set) var isUnverified = false
    @Published private(set) var canCancel = false
    @Published private(set) var canStop = false

    var hasReservation: Bool { session != nil || isUnverified || record?.phase.pending == true || storageFailed }
    var canSchedule: Bool { !hasReservation && owner.current == .none }
    var canEdit: Bool { canCancel && !storageFailed }
    var canClear: Bool { session == nil && !isUnverified && record?.phase.pending != true && owner.current == .none }
    var events: [AlarmRecord.Event] { record?.events ?? [] }

    private let owner: ExperimentSessionOwner
    private let store: any AlarmStorage
    private let now: () -> Date
    private var session: WKExtendedRuntimeSession?
    private var replacement: Date?
    private var pendingInvalidation = false
    private var storageFailed = false
    private var didRequestHaptic = false

    init(owner: ExperimentSessionOwner, store: any AlarmStorage = AlarmFileStore(), now: @escaping () -> Date = Date.init) {
        self.owner = owner
        self.store = store
        self.now = now
        super.init()
        do {
            record = try store.load()
            if let record {
                isUnverified = record.phase.pending
                didRequestHaptic = record.hapticRequestedAt != nil
                status = isUnverified ? "Unverified after relaunch" : completedStatus(record.phase)
            }
        } catch {
            storageFailed = true
            isUnverified = true
            status = "Needs attention"
            errorMessage = "Saved alarm cannot be read. A pending session may still exist."
        }
    }

    func schedule(at fireDate: Date) {
        guard WKApplication.shared().applicationState == .active else {
            errorMessage = "Open Cumulus to schedule the alarm."; return
        }
        guard AlarmTime.isValid(fireDate, now: now()) else {
            errorMessage = "Choose a future time within the next 36 hours."; return
        }
        guard canSchedule, owner.claim(.alarm) else {
            errorMessage = "Finish the existing alarm or research session first."; return
        }
        let history = events
        record = AlarmRecord(id: UUID(), fireDate: fireDate, createdAt: now(), events: history)
        replacement = nil
        didRequestHaptic = false
        isUnverified = false
        errorMessage = nil
        status = "Scheduling requested"
        append("Schedule requested")
        // Persist before requesting a session. Failure must never look like a scheduled alarm.
        guard persist() else {
            record?.phase = .failed
            status = "Needs attention"
            owner.release(.alarm)
            return
        }
        let newSession = WKExtendedRuntimeSession()
        session = newSession
        newSession.delegate = self
        newSession.start(at: fireDate)
        refreshState()
    }

    func edit(to fireDate: Date) {
        guard canEdit, AlarmTime.isValid(fireDate, now: now()),
              WKApplication.shared().applicationState == .active else {
            errorMessage = "The alarm cannot be edited now. Choose a future time within 36 hours."; return
        }
        replacement = fireDate
        invalidate(stopping: false)
    }
    func cancel() { replacement = nil; invalidate(stopping: false) }
    func stop() { replacement = nil; invalidate(stopping: true) }

    private func invalidate(stopping: Bool) {
        guard WKApplication.shared().applicationState == .active, let session,
              stopping ? canStop : canCancel else { return }
        pendingInvalidation = true
        record?.phase = stopping ? .stopRequested : .cancellationRequested
        status = stopping ? "Stop requested" : "Cancellation requested"
        canCancel = false
        canStop = false
        append(replacement == nil ? status : "Cancellation requested before replacement")
        _ = persist()
        // A storage failure must not prevent stopping an attached live session.
        session.invalidate()
    }

    func attach(_ delivered: WKExtendedRuntimeSession) {
        delivered.delegate = self
        // Ownership alone is insufficient when configuration is missing/corrupt.
        guard !storageFailed, record?.phase.pending == true,
              session == nil || session === delivered else {
            owner.markUnresolved()
            session = delivered
            isUnverified = true
            canCancel = false
            canStop = false
            status = "Needs attention"
            errorMessage = "Received a session without verified alarm configuration. No new alert requested."
            return
        }
        session = delivered
        isUnverified = false
        append("Relaunch received session (state \(delivered.state.rawValue))")
        _ = persist()
        refreshState()
    }

    func refreshState() {
        guard let session, !isUnverified else { return }
        if pendingInvalidation { canCancel = false; canStop = false; return }
        if record?.phase == .cancellationRequested || record?.phase == .stopRequested {
            status = "Cancellation unconfirmed after relaunch"
            if WKApplication.shared().applicationState == .active,
               session.state == .scheduled || session.state == .running {
                pendingInvalidation = true
                append("Resuming requested invalidation after relaunch")
                _ = persist()
                session.invalidate()
            }
            canCancel = false; canStop = false
            return
        }
        canCancel = session.state == .scheduled
        canStop = session.state == .running
        switch session.state {
        case .notStarted: status = "Scheduling requested"
        case .scheduled:
            status = "Scheduled"
            if record?.phase != .scheduled {
                record?.phase = .scheduled
                append("Scheduled state observed")
                _ = persist()
            }
        case .running:
            status = "Haptic requested"
            guard !didRequestHaptic else { return }
            didRequestHaptic = true
            session.notifyUser(hapticType: .notification, repeatHandler: nil)
            record?.phase = .hapticRequested
            record?.hapticRequestedAt = now()
            append("Haptic requested (default repeat interval)")
            _ = persist()
        case .invalid:
            canCancel = false; canStop = false
            status = "Ended; awaiting reason"
        @unknown default:
            canCancel = false; canStop = false
            status = "Needs attention"
        }
    }

    nonisolated func extendedRuntimeSessionDidStart(_ delivered: WKExtendedRuntimeSession) {
        let identity = ObjectIdentifier(delivered)
        let date = Date()
        Task { @MainActor [weak self] in
            guard let self, let session = self.session, ObjectIdentifier(session) == identity else { return }
            self.append("Session start callback", at: date)
            _ = self.persist()
            self.refreshState()
        }
    }
    nonisolated func extendedRuntimeSessionWillExpire(_ delivered: WKExtendedRuntimeSession) {
        let identity = ObjectIdentifier(delivered)
        let date = Date()
        Task { @MainActor [weak self] in
            guard let self, let session = self.session, ObjectIdentifier(session) == identity else { return }
            self.append("Session will expire", at: date)
            _ = self.persist()
        }
    }
    nonisolated func extendedRuntimeSession(_ delivered: WKExtendedRuntimeSession,
        didInvalidateWith reason: WKExtendedRuntimeSessionInvalidationReason, error: Error?) {
        let identity = ObjectIdentifier(delivered)
        let date = Date()
        let reasonCode = reason.rawValue
        let details = error.map { "\(($0 as NSError).domain) code \(($0 as NSError).code): \($0.localizedDescription)" }
        Task { @MainActor [weak self] in
            guard let self, let session = self.session, ObjectIdentifier(session) == identity else { return }
            let previousPhase = self.record?.phase
            let replacement = self.replacement
            self.session = nil
            self.replacement = nil
            self.pendingInvalidation = false
            self.isUnverified = false
            self.canCancel = false
            self.canStop = false
            let succeeded = details == nil && reasonCode == WKExtendedRuntimeSessionInvalidationReason.none.rawValue
            if succeeded && previousPhase == .cancellationRequested { self.record?.phase = .cancelled }
            else if succeeded && previousPhase == .stopRequested { self.record?.phase = .stopped }
            else if details != nil || reasonCode == WKExtendedRuntimeSessionInvalidationReason.error.rawValue {
                self.record?.phase = .failed
            } else { self.record?.phase = .ended }
            self.status = self.completedStatus(self.record?.phase ?? .failed)
            self.append("Session invalidated (reason \(reasonCode))", at: date)
            if let details { self.errorMessage = details; self.append("Error: \(details)", at: date) }
            self.owner.release(.alarm)
            let saved = self.persist()
            if let replacement {
                guard succeeded, saved, previousPhase == .cancellationRequested,
                      WKApplication.shared().applicationState == .active,
                      AlarmTime.isValid(replacement, now: self.now()) else {
                    self.errorMessage = "Replacement not set. The previous session ended; review and schedule again."
                    return
                }
                self.schedule(at: replacement)
            }
        }
    }

    func clearHistory() {
        guard canClear else { return }
        do {
            try store.clear()
            record = nil
            storageFailed = false
            errorMessage = nil
            status = "Not set"
        } catch {
            errorMessage = "Could not clear alarm history. No research data was changed."
        }
    }
    private func completedStatus(_ phase: AlarmRecord.Phase) -> String {
        switch phase {
        case .cancelled: "Cancelled"
        case .stopped: "Stopped"
        case .failed: "Needs attention"
        default: "Ended"
        }
    }
    private func append(_ message: String, at date: Date? = nil) { record?.record(message, at: date ?? now()) }
    @discardableResult private func persist() -> Bool {
        guard let record else { return false }
        do {
            try store.save(record)
            storageFailed = false
            return true
        } catch {
            storageFailed = true
            errorMessage = "Could not save alarm state. Scheduling evidence may not survive relaunch."
            return false
        }
    }
}
