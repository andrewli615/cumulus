import Foundation
import WatchKit

@MainActor
final class WatchAppDelegate: NSObject, WKApplicationDelegate {
    let testArchive: TestArchiveStore
    let sessionOwner: ExperimentSessionOwner
    let alarmCoordinator: AlarmCoordinator
    let alarmTrials: AlarmTrialStore
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

    init(testArchive: TestArchiveStore, defaults: UserDefaults = .standard, alarmStore: any AlarmStorage = AlarmFileStore()) {
        self.testArchive = testArchive
        let owner = ExperimentSessionOwner(defaults: defaults)
        sessionOwner = owner
        let trials = AlarmTrialStore(archive: testArchive)
        alarmTrials = trials
        alarmCoordinator = AlarmCoordinator(owner: owner, store: alarmStore,
            makeOrigin: { .init(build: testArchive.build, os: testArchive.os, timeZone: TimeZone.current.identifier) },
            recordObservation: { record in
                // Capture after the alarm action can proceed. Deletion markers also suppress queued old snapshots.
                Task { @MainActor in trials.capture(record, importing: true) }
            })
        alertCoordinator = ScheduledAlertCoordinator(owner: owner, defaults: defaults, testArchive: testArchive)
        backgroundCoordinator = BackgroundMotionCoordinator(owner: owner, defaults: defaults, testArchive: testArchive)
        overnightCoordinator = OvernightMotionCoordinator(owner: owner, defaults: defaults, testArchive: testArchive)
        super.init()
        owner.reconcile(alertPending: alertCoordinator.blocksMotionProbe,
                        motionPending: backgroundCoordinator.hasUnresolvedSession,
                        overnightPending: overnightCoordinator.hasReservation, alarmPending: alarmCoordinator.hasReservation)
        if alarmCoordinator.isUnverified && alarmCoordinator.errorMessage != nil || alertCoordinator.storageError != nil || backgroundCoordinator.storageError != nil || overnightCoordinator.storageError != nil { owner.markUnresolved() }
        if let record = alarmCoordinator.record { trials.capture(record, importing: true) }
    }

    func clearCompletedTestData() {
        guard sessionOwner.current == .none, !alarmCoordinator.hasReservation, !alertCoordinator.blocksMotionProbe,
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
        case .alarm: alarmCoordinator.attach(extendedRuntimeSession)
        case .alert: alertCoordinator.attachRelaunchedSession(extendedRuntimeSession)
        case .backgroundMotion: backgroundCoordinator.attach(extendedRuntimeSession, verifiedOwner: true)
        case .overnightMotion:
            sessionOwner.markUnresolved()
            backgroundCoordinator.attach(extendedRuntimeSession, verifiedOwner: false)
        case .none, .unresolved: backgroundCoordinator.attach(extendedRuntimeSession, verifiedOwner: false)
        }
    }

    func applicationDidBecomeActive() {
        alarmCoordinator.refreshState()
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
