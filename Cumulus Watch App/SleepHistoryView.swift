import SwiftUI

struct SleepHistoryView: View {
    @StateObject private var reader = SleepStageReader()
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        ExperimentPage {
            ExperimentCard {
                ExperimentHeading(title: "Sleep history", symbol: "moon.zzz.fill")
                Text("Your stored intervals.")
                    .font(.title3.bold()).fixedSize(horizontal: false, vertical: true)
                Text("Historical HealthKit records, not live sleep detection.")
                    .font(.caption2).foregroundStyle(.secondary)
                Button {
                    reader.refresh()
                } label: {
                    Text("Read / Refresh").frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .disabled(reader.isLoading || reader.isRequestingAccess)
                if reader.isLoading {
                    ProgressView().accessibilityLabel("Reading sleep history")
                }
                Text(reader.status).font(.caption).fixedSize(horizontal: false, vertical: true)
                if let refreshed = reader.refreshedAt {
                    ExperimentMetric(label: "Read at", value: refreshed.formatted(date: .abbreviated, time: .standard))
                }
                if reader.isTruncated {
                    Label("Newest 500 intervals only", systemImage: "exclamationmark.circle")
                        .font(.caption).foregroundStyle(.orange)
                    Text("This is not a complete history.").font(.caption2)
                }
            }
            if let start = reader.windowStart, let end = reader.windowEnd {
                ExperimentCard {
                    ExperimentMetric(label: "Window start", value: start.formatted(date: .abbreviated, time: .shortened))
                    ExperimentMetric(label: "Window end", value: end.formatted(date: .abbreviated, time: .shortened))
                }
            }
            Text("Sources can include Apple and other apps. Intervals can overlap or cross the window boundary. Missing stages do not prove wakefulness. An empty result does not establish denied permission.")
                .font(.caption2).foregroundStyle(.secondary)
            Text("Time zone: \(TimeZone.current.identifier)")
                .font(.caption2).foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            if !reader.intervals.isEmpty {
                ExperimentHeading(title: "Newest first", symbol: "clock")
                LazyVStack(alignment: .leading, spacing: 12) {
                    ForEach(reader.intervals) { interval in
                        ExperimentCard {
                            Text(interval.category).font(.headline)
                            ExperimentMetric(label: "Start", value: interval.start.formatted(date: .abbreviated, time: .standard))
                            ExperimentMetric(label: "End", value: interval.end.formatted(date: .abbreviated, time: .standard))
                            Text("Source: \(interval.source)").font(.caption)
                            Text(interval.sourceIdentifier)
                                .font(.caption2).foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .accessibilityElement(children: .combine)
                    }
                }
            }
        }
        .navigationTitle("Sleep history")
        .onDisappear { reader.clear() }
        .onChange(of: scenePhase) { _, phase in
            if phase == .background { reader.clear() }
        }
    }
}
