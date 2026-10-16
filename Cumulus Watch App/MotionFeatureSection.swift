import SwiftUI

struct MotionFeatureSection: View {
    let features: MotionFeatures
    let isMonitoring: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ExperimentHeading(title: "Features", symbol: "chart.xyaxis.line")
            Text("30 s · movement only")
                .font(.body).fixedSize(horizontal: false, vertical: true)
            if isMonitoring, let timestamp = features.current?.lastTimestamp {
                TimelineView(.periodic(from: .now, by: 1)) { _ in
                    let age = ProcessInfo.processInfo.systemUptime - timestamp
                    Text(age < 0 ? "Sample clock mismatch" : age > 2 ? "No recent samples (over 2 s). Features are historical." : String(format: "Latest accepted sample: %.1f s ago", age))
                        .font(.body).fixedSize(horizontal: false, vertical: true)
                        .foregroundStyle(age < 0 || age > 2 ? Color.orange : Color.secondary)
                }
            }
            if let window = features.latestCompleted ?? features.current {
                Text(features.latestCompleted == nil ? "Partial window" : "Completed window")
                    .font(.headline).fixedSize(horizontal: false, vertical: true)
                ExperimentMetric(label: "Accepted samples", value: String(window.count))
                if let value = window.meanMagnitude { metric("Mean magnitude", value, unit: "g") }
                if let value = window.magnitudeSD { metric("Magnitude variability", value, unit: "g") }
                else { Text("Variability needs at least two samples.").font(.body) }
                if let value = window.meanENMO { metric("Mean ENMO", value, unit: "g") }
                if let rate = window.observedRate { metric("Observed rate", rate, unit: "Hz") }
                metric("Largest within-window gap", window.maximumGap, unit: "s")
                if let gap = window.leadingGap { metric("Leading gap", gap, unit: "s") }
                if features.latestCompleted != nil, let gap = window.trailingGap {
                    metric("Trailing gap", gap, unit: "s")
                }
                metric("Maximum receipt delay", window.maximumDelay, unit: "s")
                if let timestamp = window.lastTimestamp {
                    TimelineView(.periodic(from: .now, by: 1)) { _ in
                        let age = ProcessInfo.processInfo.systemUptime - timestamp
                        Text(age >= 0 ? String(format: "Summary sample age: %.1f s", age) : "Sample clock mismatch")
                            .font(.body).monospacedDigit().fixedSize(horizontal: false, vertical: true)
                    }
                }
            } else {
                Text("Start monitoring to inspect movement. No accepted samples yet.")
                    .font(.body).fixedSize(horizontal: false, vertical: true)
            }
            ExperimentMetric(label: "Completed windows", value: String(features.completedWindowCount))
            ExperimentMetric(label: "Empty windows skipped", value: String(features.skippedWindowCount))
            ExperimentMetric(label: "Invalid samples", value: String(features.invalidSampleCount))
            ExperimentMetric(label: "Sample order anomalies", value: String(features.orderAnomalyCount))
            metric("Largest gap across this run", features.maximumGap, unit: "s")
            if features.latestCompleted != nil, let current = features.current {
                Text("Current partial window: \(current.count) samples.")
                    .font(.body).fixedSize(horizontal: false, vertical: true)
            }
            Text(isMonitoring ? "Updates only while this probe is active. Missing samples are not quiet movement." : "Collection stopped. Retained summaries do not update until another run.")
                .font(.body).fixedSize(horizontal: false, vertical: true)
            Text("No sleep estimate. Live features reset on Start; optional saving retains bounded summaries in Saved tests. Completion does not establish adequate coverage.")
                .font(.body).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
        }
    }

    private func metric(_ label: String, _ value: Double, unit: String) -> some View {
        ExperimentMetric(label: label, value: String(format: "%.3f %@", value, unit))
    }
}
