import Combine
import Foundation

@MainActor
final class ExperimentSessionOwner: ObservableObject {
    enum Owner: String { case none, alert, backgroundMotion, overnightMotion, unresolved }
    @Published private(set) var current: Owner
    private let defaults: UserDefaults
    private let key = "experimentSessionOwner.v1"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if let stored = defaults.object(forKey: key) {
            current = (stored as? String).flatMap(Owner.init(rawValue:)) ?? .unresolved
        } else {
            current = .none
        }
    }

    func reconcile(alertPending: Bool, motionPending: Bool, overnightPending: Bool = false) {
        let count = [alertPending, motionPending, overnightPending].filter { $0 }.count
        let expected: Owner = count > 1 ? .unresolved
            : alertPending ? .alert : motionPending ? .backgroundMotion : overnightPending ? .overnightMotion : .none
        if current == .none { set(expected) }
        else if current != expected { set(.unresolved) }
    }

    func claim(_ owner: Owner) -> Bool {
        guard current == .none, owner == .alert || owner == .backgroundMotion || owner == .overnightMotion else { return false }
        set(owner)
        return true
    }

    func release(_ owner: Owner) {
        guard current == owner else { return }
        set(.none)
    }

    func markUnresolved() { set(.unresolved) }

    private func set(_ owner: Owner) {
        current = owner
        defaults.set(owner.rawValue, forKey: key)
    }
}
