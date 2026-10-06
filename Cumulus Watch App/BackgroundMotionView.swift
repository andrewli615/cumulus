import SwiftUI

struct BackgroundMotionView: View {
    @ObservedObject var coordinator: BackgroundMotionCoordinator
    @ObservedObject var owner: ExperimentSessionOwner
    @State private var configuration = BackgroundMotionTrial.Configuration()

    var body: some View {
        List {
            Section {
                ExperimentCard {
                    ExperimentHeading(title: "Background motion", symbol: "waveform.path")
                    Text(coordinator.status).font(.headline)
                    Text(coordinator.sensorStatus).font(.caption).foregroundStyle(.secondary)
                    if coordinator.isCollecting, let last = coordinator.latest?.samples?.last {
                        ExperimentMetric(label: "Sample age", value: String(format: "%.2f s", max(0, coordinator.now - last)))
                    }
                    if let samples = coordinator.latest?.samples {
                        ExperimentMetric(label: "Accepted samples", value: "\(samples.count)")
                    }
                    if let error = coordinator.storageError { Text(error).font(.caption).foregroundStyle(.orange) }
                    if coordinator.canEndSession {
                        Button {
                            coordinator.endSession()
                        } label: {
                            Text(coordinator.isCollecting ? "Stop collection & session" : "Cancel / stop session")
                                .frame(maxWidth: .infinity)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .buttonStyle(.borderedProminent)
                    }
                }
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
                Text("Use an independent alarm. This test measures background motion, not wake reliability.")
                    .font(.caption2).foregroundStyle(.secondary)
                    .listRowBackground(Color.clear)
            }
            if coordinator.canSchedule {
                Section("Trial setup") {
                    TextField("Watch model", text: $configuration.watchModel)
                    Picker("Exit method", selection: $configuration.condition) {
                        ForEach(["Digital Crown", "Another app", "Manual stop"], id: \.self) { Text($0) }
                    }
                    if configuration.condition == "Another app" {
                        TextField("Other app name", text: $configuration.otherApp)
                    }
                    Picker("Low Power Mode", selection: $configuration.powerMode) {
                        ForEach(["Unknown", "Off", "On"], id: \.self) { Text($0) }
                    }
                    Picker("Wrist", selection: $configuration.wristState) {
                        ForEach(["Unknown", "Worn unlocked", "Worn locked", "Not worn"], id: \.self) { Text($0) }
                    }
                    Picker("Debugger detached?", selection: $configuration.debuggerDetached) {
                        ForEach(["Unknown", "Yes", "No"], id: \.self) { Text($0) }
                    }
                    Button {
                        coordinator.schedule(configuration: configuration)
                    } label: {
                        Text("Schedule in 3 minutes")
                            .frame(maxWidth: .infinity)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .buttonStyle(.borderedProminent)
                    Text(
                        "Leave Cumulus before the requested start. Collection lasts 60 seconds, then requests a haptic. Return about 5 minutes after the requested start even if no haptic occurs."
                    )
                    .font(.caption2)
                }
            }
            if let latest = coordinator.latest {
                Section("Latest trial") {
                    Text(latest.measurementAssessment).font(.caption)
                    NavigationLink {
                        List { BackgroundMotionDetails(trial: latest) }
                            .navigationTitle("Trial details")
                            .tint(.blue)
                    } label: {
                        Label("Inspect trial", systemImage: "chart.bar.xaxis")
                    }
                }
            }
            Section("Recent trials") {
                if coordinator.archive.trials.isEmpty {
                    Text("No trials recorded yet.").font(.caption).foregroundStyle(.secondary)
                }
                ForEach(coordinator.archive.trials.reversed()) { trial in
                    NavigationLink {
                        List { BackgroundMotionDetails(trial: trial) }.navigationTitle("Trial details")
                    } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(trial.requestedStart.formatted(date: .abbreviated, time: .standard))
                                .font(.caption).monospacedDigit()
                            Text(trial.phase.rawValue.capitalized)
                                .font(.caption2).foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
        .tint(.blue)
        .navigationTitle("Background")
    }
}

private struct BackgroundMotionDetails: View {
    let trial: BackgroundMotionTrial

    private func seconds(_ value: Double?) -> String {
        value.map { String(format: "%.3f s", $0) } ?? "Unrecorded"
    }

    var body: some View {
        Section("Session") {
            Text("Requested: \(trial.requestedStart.formatted(date: .abbreviated, time: .complete))")
            Text("Phase: \(trial.phase.rawValue)")
            Text(trial.measurementAssessment)
        }
        Section("Trial setup") {
            Text("Model: \(trial.configuration.watchModel.isEmpty ? "Unrecorded" : trial.configuration.watchModel)")
            Text("watchOS: \(trial.configuration.watchOS); build: \(trial.configuration.appBuild)")
            Text("Exit: \(trial.configuration.condition) \(trial.configuration.otherApp)")
            Text("Low Power Mode: \(trial.configuration.powerMode); wrist: \(trial.configuration.wristState)")
            Text("Debugger detached: \(trial.configuration.debuggerDetached)")
            Text(
                "Battery start/end: \(trial.batteryStart.map { "\(Int($0 * 100))%" } ?? "Unknown") / \(trial.batteryEnd.map { "\(Int($0 * 100))%" } ?? "Unknown")"
            )
        }
        Section("Collection") {
            Text("Background throughout: \(trial.backgroundThroughoutWindow ? "Yes" : "Not established")")
            Text("Clock discontinuity: \(trial.clockDiscontinuity ? "Yes" : "No detected change")")
            if let date = trial.collectionDate { Text("Collection: \(date.formatted(date: .abbreviated, time: .complete))") }
        }
        if let samples = trial.samples {
            Section("Sample timing") {
                Text("Accepted: \(samples.count)")
                Text("Start uptime: \(seconds(samples.start))")
                Text("First/last uptime: \(seconds(samples.first)) / \(seconds(samples.last))")
                Text("Startup/trailing gap: \(seconds(samples.startupDelay)) / \(seconds(samples.trailingGap))")
                Text("Max gap/delay: \(seconds(samples.maximumGap)) / \(seconds(samples.maximumDelay))")
                Text("Stop uptime: \(seconds(samples.stoppedAt)); overshoot: \(seconds(samples.stopOvershoot))")
                Text("Rejected order/window: \(samples.duplicatesOrOutOfOrder) / \(samples.outsideWindow)")
                if let error = samples.error { Text("Motion error: \(error)") }
            }
            Section("Five-second buckets") {
                ForEach(samples.buckets) { bucket in
                    VStack(alignment: .leading) {
                        Text("\(bucket.id * 5)–\((bucket.id + 1) * 5)s: \(bucket.count) samples")
                        Text("Sample uptime: \(seconds(bucket.first)) – \(seconds(bucket.last))")
                        Text("Receipt uptime: \(seconds(bucket.firstReceipt)) – \(seconds(bucket.lastReceipt))")
                        Text("Max gap/delay: \(seconds(bucket.maximumGap)) / \(seconds(bucket.maximumDelay))")
                    }.font(.caption2)
                }
            }
        }
        Section("Lifecycle events") {
            if let reason = trial.stopReason { Text("Stop: \(reason)") }
            if trial.eventsTruncated { Text("History truncated: evidence incomplete").foregroundStyle(.red) }
            ForEach(trial.events) { event in
                VStack(alignment: .leading) {
                    Text(event.date, format: .dateTime.hour().minute().second())
                    Text("Uptime \(seconds(event.uptime))")
                    Text(event.message)
                }.font(.caption2)
            }
        }
    }
}
