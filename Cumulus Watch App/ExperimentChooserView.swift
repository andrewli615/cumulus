import SwiftUI

struct ExperimentChooserView: View {
    @ObservedObject var coordinator: ScheduledAlertCoordinator
    @ObservedObject var background: BackgroundMotionCoordinator
    @ObservedObject var overnight: OvernightMotionCoordinator
    @ObservedObject var owner: ExperimentSessionOwner

    var body: some View {
        NavigationStack {
            ExperimentPage {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Explore your\nWatch data.")
                        .font(.title2.bold())
                        .fixedSize(horizontal: false, vertical: true)
                    Text("Six small experiments.")
                        .font(.caption).foregroundStyle(.secondary)
                }
                if owner.current != .none {
                    ExperimentCard {
                        ExperimentHeading(title: "Session status", symbol: "clock")
                        Text(owner.current == .unresolved ? "Session ownership unresolved" : (owner.current == .alert ? coordinator.status : owner.current == .overnightMotion ? overnight.status : background.status))
                            .font(.caption)
                        Text("Finish the active trial before opening motion or health history.")
                            .font(.caption2).foregroundStyle(.secondary)
                    }
                }
                NavigationLink {
                    ContentView()
                } label: {
                    ExperimentDestination(title: "Motion probe", subtitle: "Movement & heart records", symbol: "waveform.path.ecg")
                }
                .disabled(owner.current != .none)
                NavigationLink {
                    ScheduledAlertView(coordinator: coordinator)
                } label: {
                    ExperimentDestination(title: "Scheduled alert", subtitle: "Test a future haptic", symbol: "alarm")
                }
                NavigationLink {
                    BackgroundMotionView(coordinator: background, owner: owner)
                } label: {
                    ExperimentDestination(title: "Background motion", subtitle: "A 60-second sensor trial", symbol: "waveform.path")
                }
                NavigationLink {
                    SleepHistoryView()
                } label: {
                    ExperimentDestination(title: "Sleep history", subtitle: "Explore stored intervals", symbol: "moon.zzz.fill")
                }
                .disabled(owner.current != .none)
                NavigationLink {
                    CardiacHistoryView()
                } label: {
                    ExperimentDestination(title: "Cardiac history", subtitle: "Heart records & coverage", symbol: "heart.text.square")
                }
                .disabled(owner.current != .none)
                NavigationLink {
                    OvernightMotionView(coordinator: overnight, owner: owner)
                } label: {
                    ExperimentDestination(title: "Overnight motion", subtitle: "Fixed recording · later retrieval", symbol: "moon.stars")
                }
                Text("Research in progress. Keep an independent alarm.")
                    .font(.caption2).foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .navigationTitle("Cumulus")
        }
    }
}

private struct ExperimentDestination: View {
    @Environment(\.isEnabled) private var isEnabled
    let title: String
    let subtitle: String
    let symbol: String

    var body: some View {
        ExperimentCard {
            HStack {
                Image(systemName: symbol).foregroundStyle(.blue).font(.title3)
                Spacer()
                Image(systemName: "chevron.right").font(.caption2).foregroundStyle(.secondary)
            }
            Text(title).font(.headline).fixedSize(horizontal: false, vertical: true)
            Text(subtitle).font(.caption2).foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .opacity(isEnabled ? 1 : 0.5)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(title). \(subtitle)")
    }
}
