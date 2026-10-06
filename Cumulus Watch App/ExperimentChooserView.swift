import SwiftUI

struct ExperimentChooserView: View {
    @ObservedObject var coordinator: ScheduledAlertCoordinator

    @ObservedObject var background: BackgroundMotionCoordinator
    @ObservedObject var owner: ExperimentSessionOwner

    var body: some View {
        NavigationStack {
            List {
                NavigationLink("Motion probe") {
                    ContentView()
                }
                .disabled(owner.current != .none)
                NavigationLink("Scheduled alert test") {
                    ScheduledAlertView(coordinator: coordinator)
                }
                NavigationLink("Background motion test") {
                    BackgroundMotionView(coordinator: background, owner: owner)
                }
                NavigationLink("Sleep history") {
                    SleepHistoryView()
                }
                .disabled(owner.current != .none)
                Text(coordinator.status)
                    .font(.caption)
                if owner.current != .none {
                    Text("Finish the scheduled experiment before opening the motion probe or sleep history.")
                        .font(.caption2)
                }
            }
            .navigationTitle("Cumulus")
        }
    }
}
