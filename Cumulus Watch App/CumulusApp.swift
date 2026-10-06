import SwiftUI

@main
struct CumulusApp: App {
    @WKApplicationDelegateAdaptor(WatchAppDelegate.self) private var appDelegate

    var body: some Scene {
        WindowGroup {
            ExperimentChooserView(coordinator: appDelegate.alertCoordinator,
                                  background: appDelegate.backgroundCoordinator, overnight: appDelegate.overnightCoordinator, owner: appDelegate.sessionOwner)
        }
    }
}
