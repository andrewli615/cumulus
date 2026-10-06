import SwiftUI

struct ScheduledAlertView: View {
    @Environment(\.scenePhase) private var scenePhase
    @ObservedObject var coordinator: ScheduledAlertCoordinator

    var body: some View {
        ExperimentPage {
            ExperimentCard {
                ExperimentHeading(title: "Scheduled alert", symbol: "alarm")
                Text(coordinator.status).font(.headline)
                if let date = coordinator.requestedStart {
                    ExperimentMetric(label: "Requested start", value: date.formatted(date: .abbreviated, time: .standard))
                }
                if coordinator.canCancel {
                    Button("Cancel") { coordinator.cancel() }
                        .buttonStyle(.borderedProminent)
                        .disabled(scenePhase != .active)
                }
                if coordinator.canStop {
                    Button("Stop alert") { coordinator.stopAlert() }
                        .buttonStyle(.borderedProminent)
                        .disabled(scenePhase != .active)
                }
                if !coordinator.canCancel && !coordinator.canStop {
                    Button {
                        coordinator.schedule()
                    } label: {
                        Text("Schedule test alert")
                            .frame(maxWidth: .infinity)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(scenePhase != .active || !coordinator.canSchedule)
                    Text("Requested for 3 minutes from now.")
                        .font(.caption2).foregroundStyle(.secondary)
                }
                if coordinator.isUnverified {
                    Label("Session unverified", systemImage: "exclamationmark.circle")
                        .font(.caption).foregroundStyle(.orange)
                    Text("A saved request does not confirm a live session. Waiting for WatchKit to deliver it; this app cannot cancel a session it has not received.")
                        .font(.caption2)
                }
                if let error = coordinator.storageError {
                    Text(error).font(.caption).foregroundStyle(.orange)
                }
            }
            Text("Experimental. Keep an independent alarm for any real wake requirement. No motion or heart data is collected by this test.")
                .font(.caption2).foregroundStyle(.secondary)
            ExperimentHeading(title: "Recent events", symbol: "clock")
            if coordinator.events.isEmpty {
                Text("No events recorded yet.").font(.caption).foregroundStyle(.secondary)
            }
            ForEach(coordinator.events.reversed()) { event in
                ExperimentCard {
                    Text(event.message).font(.caption)
                    Text(event.date.formatted(date: .abbreviated, time: .standard))
                        .font(.caption2).monospacedDigit().foregroundStyle(.secondary)
                    if let requested = event.requestedStart {
                        Text("For \(requested.formatted(date: .omitted, time: .standard))")
                            .font(.caption2).foregroundStyle(.secondary)
                    }
                }
                .accessibilityElement(children: .combine)
            }
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
