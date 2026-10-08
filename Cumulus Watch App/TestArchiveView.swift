import SwiftUI

struct TestArchiveView: View {
    @ObservedObject var archive: TestArchiveStore
    @ObservedObject var owner: ExperimentSessionOwner
    let clearCompletedData: () -> Void
    @State private var confirmDeletion = false

    var body: some View {
        ExperimentPage {
            ExperimentCard {
                ExperimentPageHeading { ExperimentHeading(title: "Saved tests", symbol: "tray.full") }
                Text("\(archive.reports.count) saved \(archive.reports.count == 1 ? "report" : "reports")").font(.headline)
                ExperimentMetric(label: "Archive size", value: String(format: "%.2f MB of 32 MB", Double(archive.storedBytes) / 1_048_576))
                if let reason = archive.newReportBlockReason { Text(reason).font(.caption).foregroundStyle(.orange) }
                Text("Diagnostic summaries stay on this Watch until you delete them or uninstall the app. Up to 200 reports or 32 MB; older reports are never silently replaced by newer runs.").font(.caption2)
                Text("Health readings and raw acceleration are not included. These reports describe software observations, not proof of sleep stages or waking.").font(.caption2).foregroundStyle(.secondary)
                if let message = archive.errorMessage { Text(message).font(.caption).foregroundStyle(.orange) }
                if archive.unreadableFiles > 0 { Text("\(archive.unreadableFiles) unreadable files preserved.").font(.caption2) }
                Button("Reload saved reports") { archive.reload() }.buttonStyle(.bordered)
                Button("Delete completed test data", role: .destructive) { confirmDeletion = true }
                    .buttonStyle(.bordered)
                    .disabled(owner.current != .none)
                Text("Deletion is blocked while a session is pending or unresolved. It clears reports and completed recovery history; it does not stop system recording or delete Health data.").font(.caption2)
            }
            if archive.reports.isEmpty { Text("No saved reports yet. Existing retained experiments are imported when the app opens.").font(.caption) }
            ForEach(archive.reports) { report in
                NavigationLink {
                    TestReportView(report: report, archive: archive)
                } label: {
                    ExperimentCard {
                        Text(report.title).font(.headline)
                        Text(report.createdAt.formatted(date: .abbreviated, time: .standard)).font(.caption2)
                        Text(report.status).font(.caption).foregroundStyle(.secondary)
                    }
                }
            }
        }
        .navigationTitle("Saved tests")
        .confirmationDialog("Delete all saved reports and completed experiment history? This also clears pilot qualification. This cannot be undone.", isPresented: $confirmDeletion) {
            Button("Delete completed test data", role: .destructive) { clearCompletedData() }
        }
    }
}

struct TestReportView: View {
    let report: TestReport
    let archive: TestArchiveStore
    @State private var assessment: SavedReportAssessment?
    @State private var readError: String?
    var body: some View {
        ExperimentPage {
            ExperimentCard {
                ExperimentHeading(title: report.title, symbol: "doc.text")
                Text(report.status).font(.caption)
                ExperimentMetric(label: "Reference time", value: report.createdAt.formatted(date: .abbreviated, time: .standard))
                ExperimentMetric(label: "Last saved", value: report.updatedAt.formatted(date: .abbreviated, time: .standard))
                ExperimentMetric(label: "Captured by build", value: report.captureBuild)
                ExperimentMetric(label: "Captured on watchOS", value: report.captureOS)
                ForEach(report.metrics.keys.sorted(), id: \.self) { key in
                    ExperimentMetric(label: key, value: report.metrics[key] ?? "Unknown")
                }
                Text("Unknown conditions remain unknown. The capture build can differ from the original trial build.").font(.caption2).foregroundStyle(.secondary)
            }
            if let assessment, !assessment.lines.isEmpty {
                ExperimentCard {
                    ExperimentHeading(title: "Evidence review", symbol: "checklist")
                    ForEach(Array(assessment.lines.enumerated()), id: \.offset) { _, line in
                        Text(line).font(.caption).fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
            if let readError { Text(readError).font(.caption).foregroundStyle(.orange) }
            if !report.events.isEmpty {
                ExperimentCard {
                    ExperimentHeading(title: "Recorded events", symbol: "list.bullet")
                    ForEach(Array(report.events.enumerated()), id: \.offset) { _, event in
                        Text("\(event.date.formatted(date: .abbreviated, time: .standard))\n\(event.message)").font(.caption2)
                    }
                }
            }
        }.navigationTitle("Test report")
        .task(id: report.id) {
            do { assessment = try SavedReportAssessment(report: archive.report(id: report.id)) }
            catch { readError = "Saved diagnostic details could not be verified; preserve the report." }
        }
    }
}
