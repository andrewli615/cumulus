import SwiftUI

struct CardiacTimingView: View {
    let selection: CardiacTimingSelection
    @ObservedObject var owner: ExperimentSessionOwner
    @StateObject private var reader: CardiacTimingReader
    @Environment(\.scenePhase) private var scenePhase

    init(selection: CardiacTimingSelection, owner: ExperimentSessionOwner, archive: TestArchiveStore?) {
        self.selection = selection
        self.owner = owner
        _reader = StateObject(wrappedValue: CardiacTimingReader(query: HealthKitCardiacTimingQuery(), archive: archive,
                                                               canRead: { owner.current == .none }))
    }

    var body: some View {
        ExperimentPage {
            ExperimentCard {
                ExperimentHeading(title: "Internal timing", symbol: "heart.text.square")
                Text(selection.kind == .groupedHeartRate ? "One observed grouped heart-rate record." : "One observed heartbeat series.").font(.caption)
                ExperimentMetric(label: "Declared entries", value: String(selection.count))
                Button("Inspect internal timing") { reader.read(selection) }
                    .buttonStyle(.borderedProminent)
                    .disabled(reader.isReading || scenePhase != .active || owner.current != .none)
                Text("Read-only, foreground inspection. This does not start sensing or establish when the data became available overnight.").font(.caption2)
                Text(reader.status).font(.caption)
                if let error = reader.errorMessage { Text(error).font(.caption2).foregroundStyle(.orange) }
                if reader.isReading {
                    ProgressView().accessibilityLabel("Inspecting internal timing")
                    Button("Cancel inspection") { reader.clear() }.buttonStyle(.bordered)
                }
            }
            if let summary = reader.summary {
                ExperimentCard {
                    ExperimentHeading(title: "Timing diagnostics", symbol: "list.bullet")
                    ForEach(summary.metrics(for: selection.kind).keys.sorted(), id: \.self) { key in
                        ExperimentMetric(label: key, value: summary.metrics(for: selection.kind)[key] ?? "Unknown")
                    }
                    Text("Spacing describes consecutive valid entries, excluding flagged gaps. Quantity spacing is not heartbeat timing. No HRV or sleep stage is inferred.").font(.caption2).foregroundStyle(.secondary)
                    Text("Saved tests retains these bounded diagnostics. Individual values, sample dates, record IDs and sources are not saved; leaving clears memory.").font(.caption2)
                }
            }
        }
        .navigationTitle("Timing")
        .onDisappear { reader.clear() }
        .onChange(of: scenePhase) { _, phase in if phase != .active { reader.clear() } }
        .onChange(of: owner.current) { _, phase in if phase != .none { reader.clear() } }
    }
}
