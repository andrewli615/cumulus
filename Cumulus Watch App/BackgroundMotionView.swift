import SwiftUI

struct BackgroundMotionView: View {
    @ObservedObject var coordinator: BackgroundMotionCoordinator
    @ObservedObject var owner: ExperimentSessionOwner
    @State private var configuration = BackgroundMotionTrial.Configuration()

    var body: some View {
        List {
            Section("Session") {
                Text(coordinator.status)
                Text(coordinator.sensorStatus)
                if coordinator.isCollecting, let last = coordinator.latest?.samples?.last {
                    Text("Sample age: \(max(0, coordinator.now - last), specifier: "%.2f") s")
                }
                if let error = coordinator.storageError { Text(error).foregroundStyle(.red) }
                if coordinator.canEndSession {
                    Button(coordinator.isCollecting ? "Stop collection & session" : "Cancel / stop session") {
                        coordinator.endSession()
                    }
                }
                Text("Use an independent alarm. This test measures background motion, not wake reliability.")
                    .font(.caption2)
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
                    Button("Schedule in 3 minutes") { coordinator.schedule(configuration: configuration) }
                    Text("Leave Cumulus before the requested start. Collection lasts 60 seconds, then requests a haptic. Return about 5 minutes after the requested start even if no haptic occurs.")
                        .font(.caption2)
                }
            }
            if let latest = coordinator.latest {
                Section("Latest trial") { BackgroundMotionDetails(trial: latest) }
            }
            Section("Recent trials") {
                ForEach(coordinator.archive.trials.reversed()) { trial in
                    NavigationLink {
                        List { BackgroundMotionDetails(trial: trial) }.navigationTitle("Trial details")
                    } label: {
                        Text(trial.requestedStart, format: .dateTime.hour().minute().second())
                    }
                }
            }
        }
        .navigationTitle("Background motion")
    }
}

private struct BackgroundMotionDetails: View {
    let trial: BackgroundMotionTrial

    private func seconds(_ value: Double?) -> String {
        value.map { String(format: "%.3f s", $0) } ?? "Unrecorded"
    }

    var body: some View {
        Text("Requested: \(trial.requestedStart.formatted(date: .abbreviated, time: .complete))")
        Text("Phase: \(trial.phase.rawValue)")
        Text(trial.measurementAssessment)
        Text("Model: \(trial.configuration.watchModel.isEmpty ? "Unrecorded" : trial.configuration.watchModel)")
        Text("watchOS: \(trial.configuration.watchOS); build: \(trial.configuration.appBuild)")
        Text("Exit: \(trial.configuration.condition) \(trial.configuration.otherApp)")
        Text("Low Power Mode: \(trial.configuration.powerMode); wrist: \(trial.configuration.wristState)")
        Text("Debugger detached: \(trial.configuration.debuggerDetached)")
        Text("Battery start/end: \(trial.batteryStart.map { "\(Int($0 * 100))%" } ?? "Unknown") / \(trial.batteryEnd.map { "\(Int($0 * 100))%" } ?? "Unknown")")
        Text("Background throughout: \(trial.backgroundThroughoutWindow ? "Yes" : "Not established")")
        Text("Clock discontinuity: \(trial.clockDiscontinuity ? "Yes" : "No detected change")")
        if let date = trial.collectionDate { Text("Collection: \(date.formatted(date: .abbreviated, time: .complete))") }
        if let samples = trial.samples {
            Text("Accepted: \(samples.count)")
            Text("Start uptime: \(seconds(samples.start))")
            Text("First/last uptime: \(seconds(samples.first)) / \(seconds(samples.last))")
            Text("Startup/trailing gap: \(seconds(samples.startupDelay)) / \(seconds(samples.trailingGap))")
            Text("Max gap/delay: \(seconds(samples.maximumGap)) / \(seconds(samples.maximumDelay))")
            Text("Stop uptime: \(seconds(samples.stoppedAt)); overshoot: \(seconds(samples.stopOvershoot))")
            Text("Rejected order/window: \(samples.duplicatesOrOutOfOrder) / \(samples.outsideWindow)")
            if let error = samples.error { Text("Motion error: \(error)") }
            ForEach(samples.buckets) { bucket in
                VStack(alignment: .leading) {
                    Text("\(bucket.id * 5)–\((bucket.id + 1) * 5)s: \(bucket.count) samples")
                    Text("Sample uptime: \(seconds(bucket.first)) – \(seconds(bucket.last))")
                    Text("Receipt uptime: \(seconds(bucket.firstReceipt)) – \(seconds(bucket.lastReceipt))")
                    Text("Max gap/delay: \(seconds(bucket.maximumGap)) / \(seconds(bucket.maximumDelay))")
                }.font(.caption2)
            }
        }
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
