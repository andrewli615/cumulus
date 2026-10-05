import WatchKit

@MainActor
final class WatchAppDelegate: NSObject, WKApplicationDelegate {
    let alertCoordinator = ScheduledAlertCoordinator()

    func handle(_ extendedRuntimeSession: WKExtendedRuntimeSession) {
        alertCoordinator.attachRelaunchedSession(extendedRuntimeSession)
    }

    func applicationDidBecomeActive() {
        alertCoordinator.refreshState()
    }
}
