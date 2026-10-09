import Foundation

// These doubles exercise app state, not delivery or haptic perception.
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
    static var stateAfterStart = State.scheduled
    weak var delegate: (any WKExtendedRuntimeSessionDelegate)?
    var state = State.notStarted
    var haptics = 0
    var invalidations = 0
    var requestedDate: Date?
    init() { Self.latest = self }
    func start(at date: Date) { requestedDate = date; state = Self.stateAfterStart }
    func notifyUser(hapticType: Haptic, repeatHandler: (() -> TimeInterval)?) {
        precondition(state == .running); haptics += 1
    }
    func invalidate() { invalidations += 1 }
    func run() { state = .running; delegate?.extendedRuntimeSessionDidStart(self) }
    func end(_ reason: WKExtendedRuntimeSessionInvalidationReason, error: Error? = nil) {
        state = .invalid; delegate?.extendedRuntimeSession(self, didInvalidateWith: reason, error: error)
    }
}
@MainActor final class WKApplication {
    enum State { case active, inactive, background }
    static let instance = WKApplication()
    static func shared() -> WKApplication { instance }
    var applicationState = State.active
}
@MainActor final class MemoryAlarmStore: AlarmStorage {
    var value: AlarmRecord?
    var fails = false
    func load() throws -> AlarmRecord? { if fails { throw AlarmStorageError.invalid }; return value }
    func save(_ record: AlarmRecord) throws {
        if fails { throw AlarmStorageError.invalid }; try record.validate(); value = record
    }
    func clear() throws { if fails { throw AlarmStorageError.invalid }; value = nil }
}
