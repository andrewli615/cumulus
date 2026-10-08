import Foundation
import WatchKit

@MainActor
final class WatchAppDelegate: NSObject, WKApplicationDelegate {
    let testArchive: TestArchiveStore
    let sessionOwner: ExperimentSessionOwner
    let alertCoordinator: ScheduledAlertCoordinator
    let backgroundCoordinator: BackgroundMotionCoordinator

    let overnightCoordinator: OvernightMotionCoordinator

    override convenience init() {
        #if os(watchOS)
        let build = "\(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "Unknown") (\(Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "Unknown"))"
        self.init(testArchive: TestArchiveStore(build: build, os: WKInterfaceDevice.current().systemVersion))
        #else
        self.init(testArchive: TestArchiveStore(directory: FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)))
        #endif
    }

    init(testArchive: TestArchiveStore, defaults: UserDefaults = .standard) {
        self.testArchive = testArchive
        let owner = ExperimentSessionOwner(defaults: defaults)
        sessionOwner = owner
        alertCoordinator = ScheduledAlertCoordinator(owner: owner, defaults: defaults, testArchive: testArchive)
        backgroundCoordinator = BackgroundMotionCoordinator(owner: owner, defaults: defaults, testArchive: testArchive)
        overnightCoordinator = OvernightMotionCoordinator(owner: owner, defaults: defaults, testArchive: testArchive)
        super.init()
        owner.reconcile(alertPending: alertCoordinator.blocksMotionProbe,
                        motionPending: backgroundCoordinator.hasUnresolvedSession,
                        overnightPending: overnightCoordinator.hasReservation)
        if alertCoordinator.storageError != nil || backgroundCoordinator.storageError != nil || overnightCoordinator.storageError != nil { owner.markUnresolved() }
    }

    func clearCompletedTestData() {
        guard sessionOwner.current == .none, !alertCoordinator.blocksMotionProbe,
              alertCoordinator.storageError == nil, !backgroundCoordinator.hasUnresolvedSession,
              !overnightCoordinator.hasReservation, !overnightCoordinator.isRetrieving,
              !overnightCoordinator.isRequestingAccess, overnightCoordinator.storageError == nil else { return }
        guard testArchive.deleteAll() else { return }
        alertCoordinator.clearCompletedHistory()
        backgroundCoordinator.clearCompletedHistory()
        overnightCoordinator.clearCompletedHistory()
    }

    func handle(_ extendedRuntimeSession: WKExtendedRuntimeSession) {
        switch sessionOwner.current {
        case .alert: alertCoordinator.attachRelaunchedSession(extendedRuntimeSession)
        case .backgroundMotion: backgroundCoordinator.attach(extendedRuntimeSession, verifiedOwner: true)
        case .overnightMotion:
            sessionOwner.markUnresolved()
            backgroundCoordinator.attach(extendedRuntimeSession, verifiedOwner: false)
        case .none, .unresolved: backgroundCoordinator.attach(extendedRuntimeSession, verifiedOwner: false)
        }
    }

    func applicationDidBecomeActive() {
        alertCoordinator.refreshState()
        backgroundCoordinator.applicationStateChanged("active")
        overnightCoordinator.applicationStateChanged("active")
    }

    func applicationWillResignActive() {
        backgroundCoordinator.applicationStateChanged("inactive")
        overnightCoordinator.applicationStateChanged("inactive")
    }
    func applicationDidEnterBackground() {
        backgroundCoordinator.applicationStateChanged("background")
        overnightCoordinator.applicationStateChanged("background")
    }
    func applicationWillEnterForeground() {
        backgroundCoordinator.applicationStateChanged("foreground")
        overnightCoordinator.applicationStateChanged("foreground")
    }
}
