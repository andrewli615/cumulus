import SwiftUI

struct SleepHistoryView: View {
    @StateObject private var reader = SleepStageReader()
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        List {
            Section("Stored sleep records") {
                Text("Historical HealthKit records, not live sleep detection. Sources can include Apple and other apps.")
                    .font(.caption2)
                Button("Read / Refresh") { reader.refresh() }
                    .disabled(reader.isLoading || reader.isRequestingAccess)
                if reader.isLoading { ProgressView() }
                Text(reader.status).font(.caption)
                if let start = reader.windowStart, let end = reader.windowEnd {
                    Text("Window: \(start.formatted(date: .abbreviated, time: .shortened)) – \(end.formatted(date: .abbreviated, time: .shortened))")
                        .font(.caption2)
                }
                if let refreshed = reader.refreshedAt {
                    Text("Read at: \(refreshed.formatted(date: .abbreviated, time: .standard))")
                        .font(.caption2)
                }
                if reader.isTruncated {
                    Text("Showing only the newest 500 intervals. This is not a complete history.")
                        .font(.caption).foregroundStyle(.orange)
                }
                Text("Intervals can overlap or cross the window boundary. Missing stages do not prove wakefulness. An empty result does not establish denied permission.")
                    .font(.caption2)
                Text("Times use this Watch’s current time zone: \(TimeZone.current.identifier).")
                    .font(.caption2)
            }
            Section("Intervals, newest first") {
                ForEach(reader.intervals) { interval in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(interval.category).font(.headline)
                        Text("Start: \(interval.start.formatted(date: .abbreviated, time: .standard))")
                        Text("End: \(interval.end.formatted(date: .abbreviated, time: .standard))")
                        Text("Source: \(interval.source)")
                        Text(interval.sourceIdentifier)
                    }.font(.caption2)
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
