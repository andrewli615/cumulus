import Foundation
import WatchKit

@MainActor
final class WatchAppDelegate: NSObject, WKApplicationDelegate {
    let sessionOwner: ExperimentSessionOwner
    let alertCoordinator: ScheduledAlertCoordinator
    let backgroundCoordinator: BackgroundMotionCoordinator

    override init() {
        let owner = ExperimentSessionOwner()
        sessionOwner = owner
        alertCoordinator = ScheduledAlertCoordinator(owner: owner)
        backgroundCoordinator = BackgroundMotionCoordinator(owner: owner)
        super.init()
        owner.reconcile(alertPending: alertCoordinator.blocksMotionProbe,
                        motionPending: backgroundCoordinator.hasUnresolvedSession)
        if alertCoordinator.storageError != nil || backgroundCoordinator.storageError != nil { owner.markUnresolved() }
    }

    func handle(_ extendedRuntimeSession: WKExtendedRuntimeSession) {
        switch sessionOwner.current {
        case .alert: alertCoordinator.attachRelaunchedSession(extendedRuntimeSession)
        case .backgroundMotion: backgroundCoordinator.attach(extendedRuntimeSession, verifiedOwner: true)
        case .none, .unresolved: backgroundCoordinator.attach(extendedRuntimeSession, verifiedOwner: false)
        }
    }

    func applicationDidBecomeActive() {
        alertCoordinator.refreshState()
        backgroundCoordinator.applicationStateChanged("active")
    }

    func applicationWillResignActive() { backgroundCoordinator.applicationStateChanged("inactive") }
    func applicationDidEnterBackground() { backgroundCoordinator.applicationStateChanged("background") }
    func applicationWillEnterForeground() { backgroundCoordinator.applicationStateChanged("foreground") }
}
