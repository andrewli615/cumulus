import SwiftUI

struct ExperimentChooserView: View {
    @ObservedObject var coordinator: ScheduledAlertCoordinator

    var body: some View {
        NavigationStack {
            List {
                NavigationLink("Motion probe") {
                    ContentView()
                }
                .disabled(coordinator.blocksMotionProbe)
                NavigationLink("Scheduled alert test") {
                    ScheduledAlertView(coordinator: coordinator)
                }
                Text(coordinator.status)
                    .font(.caption)
                if coordinator.blocksMotionProbe {
                    Text("Finish the alert test before opening the motion probe.")
                        .font(.caption2)
                }
            }
            .navigationTitle("Cumulus")
        }
    }
}
