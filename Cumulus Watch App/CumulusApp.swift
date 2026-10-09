import SwiftUI

@main
struct CumulusApp: App {
    @WKApplicationDelegateAdaptor(WatchAppDelegate.self) private var appDelegate

    var body: some Scene {
        WindowGroup {
            #if DEBUG && targetEnvironment(simulator)
            if let screen = ProcessInfo.processInfo.environment["CUMULUS_UI_PREVIEW"] {
                SimulatorPreviewScreen(screen: screen)
            } else {
                home
            }
            #else
            home
            #endif
        }
    }

    private var home: some View {
        NavigationStack {
            AlarmHomeView(coordinator: appDelegate.alarmCoordinator, owner: appDelegate.sessionOwner) { chooser }
        }.fontDesign(.serif)
    }

    private var chooser: some View {
        ExperimentChooserView(alarm: appDelegate.alarmCoordinator, coordinator: appDelegate.alertCoordinator,
                              background: appDelegate.backgroundCoordinator,
                              overnight: appDelegate.overnightCoordinator,
                              owner: appDelegate.sessionOwner,
                              testArchive: appDelegate.testArchive,
                              clearCompletedData: appDelegate.clearCompletedTestData)
    }
}
