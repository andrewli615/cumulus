import SwiftUI

struct ScheduledAlertView: View {
    @Environment(\.scenePhase) private var scenePhase
    @ObservedObject var coordinator: ScheduledAlertCoordinator

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                Text(coordinator.status).font(.headline)
                if let date = coordinator.requestedStart {
                    Text("Requested start").font(.caption)
                    Text(date.formatted(date: .abbreviated, time: .standard))
                        .monospacedDigit()
                }

                Button("Schedule test alert") { coordinator.schedule() }
                    .buttonStyle(.borderedProminent)
                    .disabled(scenePhase != .active || !coordinator.canSchedule)
                Text("Starts about 3 minutes from now.").font(.caption2)

                if coordinator.canCancel {
                    Button("Cancel") { coordinator.cancel() }
                        .disabled(scenePhase != .active)
                }
                if coordinator.canStop {
                    Button("Stop alert") { coordinator.stopAlert() }
                        .disabled(scenePhase != .active)
                }
                if coordinator.isUnverified {
                    Text("A saved request does not confirm a live session. Waiting for WatchKit to deliver it; this app cannot cancel a session it has not received.")
                        .font(.caption2)
                }
                if let error = coordinator.storageError {
                    Text(error).font(.caption2)
                }
                Text("Experimental. Keep an independent alarm for any real wake requirement.")
                    .font(.caption2)
                Text("No motion or heart data is collected by this test.").font(.caption2)

                Divider()
                Text("Recent events").font(.headline)
                ForEach(coordinator.events.reversed()) { event in
                    VStack(alignment: .leading, spacing: 3) {
                        Text(event.date.formatted(date: .abbreviated, time: .standard))
                            .font(.caption2).monospacedDigit()
                        Text(event.message).font(.caption)
                        if let requested = event.requestedStart {
                            Text("For \(requested.formatted(date: .omitted, time: .standard))")
                                .font(.caption2)
                        }
                    }
                    .accessibilityElement(children: .combine)
                }
            }
            .padding(.horizontal, 8)
        }
        .navigationTitle("Alert test")
        .task(id: scenePhase) {
            // The session has no scheduled-state delegate callback.
            while scenePhase == .active && !Task.isCancelled {
                coordinator.refreshState()
                do { try await Task.sleep(for: .seconds(0.5)) }
                catch { return }
            }
        }
    }
}
