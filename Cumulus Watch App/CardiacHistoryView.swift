import SwiftUI

struct CardiacHistoryView: View {
    @StateObject private var reader = CardiacHistoryReader()
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        ExperimentPage {
            ExperimentCard {
                ExperimentHeading(title: "Cardiac history", symbol: "heart.text.square")
                Text("Explore the last 24 hours.")
                    .font(.title3.bold()).fixedSize(horizontal: false, vertical: true)
                Button {
                    reader.refresh()
                } label: {
                    Text("Read / Refresh").frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .disabled(reader.isLoading || reader.isRequestingAccess)
                if reader.isLoading {
                    ProgressView().accessibilityLabel("Reading cardiac records")
                }
                Text(reader.status).font(.caption)
            }
            if let start = reader.windowStart, let end = reader.windowEnd {
                ExperimentCard {
                    ExperimentMetric(label: "Window start", value: date(start))
                    ExperimentMetric(label: "Window end", value: date(end))
                }
                ForEach(CardiacKind.allCases) { kind in
                    if let snapshot = reader.snapshots[kind] {
                        CardiacSnapshotView(kind: kind, snapshot: snapshot, start: start, end: end)
                    }
                }
            }
            Text("Historical records. Read / Refresh does not start heart sensing. Empty results do not establish denied permission. Records clear when you leave or background the app.")
                .font(.caption2).foregroundStyle(.secondary)
            Text("Time zone: \(TimeZone.current.identifier)")
                .font(.caption2).foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .navigationTitle("Cardiac history")
        .onDisappear { reader.clear() }
        .onChange(of: scenePhase) { _, phase in
            if phase == .background { reader.clear() }
        }
    }

    private func date(_ value: Date) -> String {
        value.formatted(date: .abbreviated, time: .standard)
    }
}

private struct CardiacSnapshotView: View {
    @State private var showsRecords = false
    let kind: CardiacKind
    let snapshot: CardiacSnapshot
    let start: Date
    let end: Date

    var body: some View {
        ExperimentCard {
            ExperimentHeading(title: kind.title, symbol: "heart")
            if let error = snapshot.error {
                Label("Read error", systemImage: "exclamationmark.circle")
                    .font(.caption).foregroundStyle(.orange)
                Text(error).font(.caption2)
            } else {
                ExperimentMetric(label: "Records shown", value: "\(snapshot.records.count)")
                if let readAt = snapshot.readAt {
                    ExperimentMetric(label: "Read at", value: date(readAt))
                }
                if snapshot.records.isEmpty {
                    Text("No readable records in this window.").font(.caption)
                }
                if snapshot.isTruncated {
                    Label("Newest \(kind.limit) records only", systemImage: "exclamationmark.circle")
                        .font(.caption).foregroundStyle(.orange)
                    Text("Counts and gaps describe this partial snapshot.").font(.caption2)
                }
                if snapshot.rejectedRecords > 0 {
                    Text("Skipped \(snapshot.rejectedRecords) invalid or unexpected records; evidence incomplete.")
                        .font(.caption).foregroundStyle(.orange)
                }
                Text(explanation).font(.caption2).foregroundStyle(.secondary)
                ForEach(snapshot.coverage(start: start, end: end)) { coverage in
                    VStack(alignment: .leading, spacing: 6) {
                        Divider()
                        Text(coverage.source).font(.headline)
                        Text(coverage.sourceIdentifier).font(.caption2).foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                        ExperimentMetric(label: "Source records", value: "\(coverage.recordCount)")
                        if kind != .heartbeatSeries {
                            ExperimentMetric(label: "Grouped quantity records", value: "\(coverage.groupedRecordCount)")
                        }
                        ExperimentMetric(label: "Earliest record start", value: date(coverage.firstStart))
                        ExperimentMetric(label: "Latest record end", value: date(coverage.latestEnd))
                        ExperimentMetric(label: "Longest interval outside record spans", value: String(format: "%.1f min", coverage.largestUncoveredInterval / 60))
                    }
                }
                if !snapshot.records.isEmpty {
                    Button(showsRecords ? "Hide records" : "Show records · newest first") {
                        showsRecords.toggle()
                    }
                    .buttonStyle(.bordered)
                    .accessibilityValue(showsRecords ? "Expanded" : "Collapsed")
                    if showsRecords {
                        LazyVStack(alignment: .leading, spacing: 12) {
                            ForEach(snapshot.records) { record in
                                VStack(alignment: .leading, spacing: 5) {
                                    Divider()
                                    if let value = record.value {
                                        ExperimentMetric(label: record.count > 1 ? "Grouped quantity value" : "Stored value",
                                            value: String(format: "%.1f %@", value, kind == .heartRate ? "bpm" : "ms"))
                                    }
                                    ExperimentMetric(label: kind == .heartbeatSeries ? "Recorded beats" : "Quantity count", value: "\(record.count)")
                                    ExperimentMetric(label: "Start", value: date(record.start))
                                    ExperimentMetric(label: "End", value: date(record.end))
                                    Text("Source: \(record.source)").font(.caption)
                                    Text(record.sourceIdentifier).font(.caption2).foregroundStyle(.secondary)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                                .accessibilityElement(children: .combine)
                            }
                        }
                    }
                }
            }
        }
    }

    private var explanation: String {
        switch kind {
        case .heartRate:
            return "Grouped quantity records can contain multiple values. Individual timestamps within them are not read by this screen."
        case .hrv:
            return "SDNN is a stored variability summary in milliseconds, not a sequence of beat intervals."
        case .heartbeatSeries:
            return "Series dates and beat counts only. Individual beat timings and gap flags are not read yet."
        }
    }

    private func date(_ value: Date) -> String {
        value.formatted(date: .abbreviated, time: .standard)
    }
}

#Preview {
    NavigationStack { CardiacHistoryView() }
}
