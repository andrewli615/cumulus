import SwiftUI

struct ForegroundFeatureHistoryView: View {
    let capture: ForegroundFeatureCapture

    var body: some View {
        ExperimentPage {
            ExperimentCard {
                ExperimentHeading(title: "Windows", symbol: "chart.xyaxis.line")
                Text(capture.stoppedAt == nil ? "Completion unrecorded" : "Stopped").font(.caption)
                Text("\(capture.epochs.count) completed · \(capture.partial == nil ? 0 : 1) partial")
                    .font(.body).fixedSize(horizontal: false, vertical: true)
                Text("Foreground movement · g").font(.caption).foregroundStyle(.secondary)
                if capture.clockUncertain {
                    Text("Clock mapping uncertain. Do not assume reliable calendar alignment.")
                        .font(.body).fixedSize(horizontal: false, vertical: true)
                }
            }
            if capture.epochs.isEmpty { Text("No completed windows were saved.").font(.body) }
            ForEach(capture.epochs) { epoch in epochCard(epoch, completed: true) }
            if let partial = capture.partial { epochCard(partial, completed: false) }
            Text("Times are seconds from run start. Calendar alignment uses an approximate wall/uptime reference. Movement summaries are not sleep estimates. The report details retain the stop reason.")
                .font(.body).fixedSize(horizontal: false, vertical: true)
        }.navigationTitle("Movement")
    }

    private func epochCard(_ epoch: ForegroundFeatureCapture.Epoch, completed: Bool) -> some View {
        ExperimentCard {
            Text(completed ? "Completed window" : "Partial window")
                .font(.headline).accessibilityAddTraits(.isHeader)
            ExperimentMetric(label: "Window from run start", value: String(format: "%.2f–%.2f s", epoch.startSeconds, epoch.endSeconds))
            ExperimentMetric(label: "Accepted samples", value: String(epoch.count))
            metric("Mean magnitude", epoch.magnitudeMean, "g")
            if let sd = epoch.magnitudeSD { metric("Magnitude variability", sd, "g") }
            metric("Mean ENMO", epoch.enmoMean, "g")
            if let rate = epoch.observedRate { metric("Observed rate", rate, "Hz") }
            metric("Leading gap", epoch.firstSampleSeconds - epoch.startSeconds, "s")
            if completed { metric("Trailing gap", epoch.endSeconds - epoch.lastSampleSeconds, "s") }
            metric("Largest within-window gap", epoch.maximumGap, "s")
            metric("Maximum receipt delay", epoch.maximumDelay, "s")
            metric("Last measurement from start", epoch.lastSampleSeconds, "s")
            metric("Last receipt from start", epoch.lastReceiptSeconds, "s")
            metric("Feature calculation from start", epoch.calculatedSeconds, "s")
            ExperimentMetric(label: "Calculated at", value: epoch.calculatedAt.formatted(date: .abbreviated, time: .standard))
        }
    }

    private func metric(_ label: String, _ value: Double, _ unit: String) -> some View {
        ExperimentMetric(label: label, value: String(format: "%.3f %@", value, unit))
    }
}
