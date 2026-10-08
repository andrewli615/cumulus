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
                chooser
            }
            #else
            chooser
            #endif
        }
    }

    private var chooser: some View {
        ExperimentChooserView(coordinator: appDelegate.alertCoordinator,
                              background: appDelegate.backgroundCoordinator,
                              overnight: appDelegate.overnightCoordinator,
                              owner: appDelegate.sessionOwner,
                              testArchive: appDelegate.testArchive,
                              clearCompletedData: appDelegate.clearCompletedTestData)
    }
}
