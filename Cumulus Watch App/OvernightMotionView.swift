import SwiftUI

struct OvernightMotionView: View {
    @ObservedObject var coordinator: OvernightMotionCoordinator
    @ObservedObject var owner: ExperimentSessionOwner
    @Environment(\.scenePhase) private var scenePhase
    @State private var mode: OvernightMotionTrial.Mode = .pilot
    @State private var configuration = OvernightMotionTrial.Configuration()
    @State private var charging = "Unknown"
    @State private var interruption = "Unknown"
    @State private var confirmElapsed = false

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            page(at: context.date)
        }
        .navigationTitle("Overnight motion")
        .onAppear {
            charging = coordinator.latest?.configuration.charging ?? "Unknown"
            interruption = coordinator.latest?.configuration.interruption ?? "Unknown"
            coordinator.applicationStateChanged("active")
        }
        .onDisappear { coordinator.cancelRetrieval() }
        .task(id: scenePhase) {
            guard scenePhase == .active else { coordinator.cancelRetrieval(); return }
            while !Task.isCancelled {
                coordinator.refreshClock()
                coordinator.recordReturn()
                do { try await Task.sleep(for: .seconds(1)) } catch { return }
            }
        }
        .confirmationDialog("Only confirm after the full requested duration has elapsed. This does not stop system recording or resolve clock uncertainty.", isPresented: $confirmElapsed) {
            Button("I waited the full duration") { coordinator.acknowledgeElapsedWindow() }
        }
    }

    private func page(at now: Date) -> some View {
        ExperimentPage {
            ExperimentPageHeading {
                Text("A night of\nmeasurements.")
                    .font(.title2.bold())
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityAddTraits(.isHeader)
            }
            Text("Experiment 006 · fixed requests, later retrieval")
                .font(.caption).foregroundStyle(.secondary)
            ExperimentCard {
                ExperimentHeading(title: "System recorder", symbol: "waveform.path")
                ExperimentMetric(label: "Available", value: coordinator.access.available ? "Yes" : "No")
                ExperimentMetric(label: "Motion access", value: coordinator.access.authorization)
                Button(coordinator.isRequestingAccess ? "Checking access…" : "Check motion access") { coordinator.requestAccess() }
                    .disabled(coordinator.hasReservation || coordinator.isRetrieving || coordinator.isRequestingAccess || owner.current != .none)
                Text(coordinator.status).font(.caption)
                if let error = coordinator.storageError { Text(error).font(.caption).foregroundStyle(.orange) }
            }
            if !coordinator.hasReservation {
                ExperimentCard {
                    OvernightTrialSelector(mode: $mode)
                    NavigationLink {
                        OvernightSetupView(configuration: $configuration)
                    } label: {
                        Text("Setup & conditions")
                            .font(.body)
                            .fixedSize(horizontal: false, vertical: true)
                            .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                    }
                    Text(mode == .comparison ? "Track battery for eight hours. No recording request is made."
                         : "One request for \(mode == .pilot ? "20 minutes" : "eight hours"). The system recording cannot be stopped from Cumulus.")
                        .font(.callout).foregroundStyle(.secondary)
                    if mode == .overnight && !coordinator.pilotReady {
                        Text("First pass the pilot timing and visibility checks on this OS and app build.")
                            .font(.callout).foregroundStyle(.orange)
                    }
                    Button {
                        charging = "Unknown"
                        interruption = "Unknown"
                        coordinator.start(mode, configuration: configuration)
                    } label: {
                        Text(mode == .comparison ? "Start comparison" : "Request recording")
                            .font(.body.weight(.semibold))
                            .fixedSize(horizontal: false, vertical: true)
                            .frame(maxWidth: .infinity, minHeight: 44)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(!coordinator.canStart(mode))
                }
                .disabled(coordinator.isRetrieving)
            }
            if let trial = coordinator.latest, trial.mode == .pilot {
                PilotGuideCard(trial: trial, now: now)
            }
            if let trial = coordinator.latest {
                ExperimentCard {
                    ExperimentHeading(title: trial.mode.title, symbol: "clock")
                    ExperimentMetric(label: "Requested start", value: trial.start.formatted(date: .abbreviated, time: .standard))
                    ExperimentMetric(label: "Fixed end", value: trial.end.formatted(date: .abbreviated, time: .standard))
                    if trial.recorderCall != nil {
                        ExperimentMetric(label: "Reserved until", value: trial.reservationEnd.formatted(date: .abbreviated, time: .standard))
                        Text("Window starts at the recorder call. Its return does not confirm samples.").font(.caption2)
                    } else if trial.mode != .comparison && trial.requestCount == 1 {
                        Text("Earlier build: recorder-call timing unknown; original window retained.").font(.caption2).foregroundStyle(.secondary)
                    }
                    ExperimentMetric(label: "Phase", value: trial.phase.rawValue.capitalized)
                    ExperimentMetric(label: "Requests recorded", value: String(trial.requestCount))
                    if trial.recovered { Text("Original window recovered after relaunch.").font(.caption2) }
                    if trial.clockDiscontinuity { Text("Clock/reboot uncertainty: timing evidence is inconclusive.").font(.caption2).foregroundStyle(.orange) }
                    if trial.phase == .uncertain && now >= trial.reservationEnd {
                        Button("Confirm fixed window elapsed") { confirmElapsed = true }
                    }
                    if trial.mode != .comparison {
                        Button("Read pilot block (9–10 min)") { coordinator.retrieve(pilotProbe: true) }
                            .disabled(!coordinator.canRetrieve(pilotProbe: true, now: now))
                        Button("Retrieve whole window") { coordinator.retrieve(pilotProbe: false) }
                            .disabled(!coordinator.canRetrieve(pilotProbe: false, now: now))
                        if trial.mode == .pilot && now < trial.start.addingTimeInterval(600) {
                            Text("Pilot read opens at \(trial.start.addingTimeInterval(600).formatted(date: .omitted, time: .standard)).").font(.caption2)
                        }
                        if coordinator.isRetrieving {
                            Text(coordinator.progress).font(.caption)
                            Button("Cancel retrieval") { coordinator.cancelRetrieval() }
                        }
                        Text(trial.timingStatus).font(.caption)
                        Text(trial.morningVisibility).font(.caption2).foregroundStyle(.secondary)
                        if let probe = trial.latestProbe {
                            ExperimentMetric(label: "Latest pilot block", value: "\(probe.count) samples · \(probe.useful ? "criteria met" : "incomplete")")
                            if !probe.useful && trial.firstUsefulProbeAt != nil {
                                Text("Earlier success retained; the latest block has not met criteria. Pilot not qualified.")
                                    .font(.caption2).foregroundStyle(.orange)
                            }
                        }
                    }
                    NavigationLink("Timing, battery & history") {
                        OvernightTrialView(coordinator: coordinator, trialID: trial.id)
                    }
                }
                if now >= trial.reservationEnd {
                    ExperimentCard {
                        ExperimentHeading(title: "Return observations", symbol: "battery.50percent")
                        Text("Report what happened during this trial. Unknown stays unknown.").font(.caption2)
                        conditionPicker("Charging", selection: $charging, options: ["Unknown", "No", "Yes"])
                            .disabled(coordinator.isRetrieving)
                        conditionPicker("Interruptions", selection: $interruption, options: ["Unknown", "None", "Observed"])
                            .disabled(coordinator.isRetrieving)
                        Button("Save observations") { coordinator.recordConditions(charging: charging, interruption: interruption) }
                            .disabled(coordinator.isRetrieving)
                    }
                }
            }
            if coordinator.archive.trials.count > 1 {
                ExperimentCard {
                    ExperimentHeading(title: "Recent trials", symbol: "list.bullet")
                    ForEach(coordinator.archive.trials.dropLast().reversed()) { trial in
                        NavigationLink(trial.mode.title + " · " + trial.start.formatted(date: .abbreviated, time: .shortened)) {
                            OvernightTrialView(coordinator: coordinator, trialID: trial.id)
                        }
                    }
                }
            }
            Text("Retrieve in the foreground. No sleep classification or wake guarantee. Keep an independent alarm.")
                .font(.caption2).foregroundStyle(.secondary)
        }
    }
}

struct OvernightTrialSelector: View {
    @Binding var mode: OvernightMotionTrial.Mode

    var body: some View {
        NavigationLink {
            OvernightTrialChoiceView(mode: $mode)
        } label: {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Choose trial").font(.callout).foregroundStyle(.secondary)
                    Spacer(minLength: 4)
                    Image(systemName: "chevron.right").font(.body)
                        .foregroundStyle(.secondary).accessibilityHidden(true)
                }
                Text(mode.title).font(.body.weight(.semibold))
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
            .padding(.vertical, 6)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityHint("Opens the trial choices. Selecting a trial does not start it.")
    }
}

struct OvernightTrialChoiceView: View {
    @Binding var mode: OvernightMotionTrial.Mode
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        List {
            ForEach(OvernightMotionTrial.Mode.allCases) { option in
                Button {
                    mode = option
                    dismiss()
                } label: {
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 6) {
                            Text(option.title).font(.body.weight(.semibold))
                                .fixedSize(horizontal: false, vertical: true)
                            Text(detail(for: option)).font(.callout).foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        Spacer(minLength: 4)
                        if mode == option {
                            Image(systemName: "checkmark").foregroundStyle(.blue)
                                .accessibilityHidden(true)
                        }
                    }
                    .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                    .padding(.vertical, 6)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(mode == option ? .isSelected : [])
                .accessibilityHint("Selects the trial and returns to setup. It does not start a recording.")
            }
        }
        .navigationTitle("Choose trial")
    }

    private func detail(for mode: OvernightMotionTrial.Mode) -> String {
        switch mode {
        case .pilot: "Short recording check."
        case .overnight: "Record motion after the pilot qualifies."
        case .comparison: "Battery baseline. No recording."
        }
    }
}

private func conditionPicker(_ title: String, selection: Binding<String>, options: [String]) -> some View {
    Picker(title, selection: selection) { ForEach(options, id: \.self) { Text($0).tag($0) } }
        .pickerStyle(.navigationLink)
        .font(.body)
}

private struct OvernightSetupView: View {
    @Binding var configuration: OvernightMotionTrial.Configuration
    var body: some View {
        List {
            Text("OS, build and time zone are captured automatically. Leave unobserved details Unknown.").font(.caption2)
            TextField("Watch model", text: $configuration.watchModel)
            conditionPicker("Wrist / lock", selection: $configuration.wrist, options: ["Unknown", "Worn, unlocked", "Other"])
            conditionPicker("Low Power Mode", selection: $configuration.powerMode, options: ["Unknown", "Off", "On"])
            conditionPicker("Sleep Focus", selection: $configuration.sleepFocus, options: ["Unknown", "Off", "On"])
            conditionPicker("Sleep tracking", selection: $configuration.sleepTracking, options: ["Unknown", "Off", "On"])
            conditionPicker("Debugger detached", selection: $configuration.debuggerDetached, options: ["Unknown", "Yes", "No"])
            TextField("Other app (or None)", text: $configuration.otherApp)
            Text("Record actual charging and interruptions after returning.").font(.caption2)
        }
        .navigationTitle("Trial setup")
    }
}

private struct OvernightTrialView: View {
    @ObservedObject var coordinator: OvernightMotionCoordinator
    let trialID: UUID
    private func seconds(_ value: Double?) -> String { value.map { String(format: "%.2f s", $0) } ?? "Unknown" }
    private func date(_ value: Date?) -> String { value?.formatted(date: .abbreviated, time: .standard) ?? "Unknown" }
    var body: some View {
        ExperimentPage {
            if let trial = coordinator.archive.trials.first(where: { $0.id == trialID }) {
                ExperimentCard {
                    ExperimentHeading(title: "Sample timing", symbol: "waveform.path")
                    Text(trial.timingStatus).font(.caption)
                    if trial.clockDiscontinuity {
                        Text("Trial clock/reboot uncertainty: timing is inconclusive.").font(.caption2).foregroundStyle(.orange)
                    }
                    if let summary = trial.fullSummary {
                        ForEach(summary.timingFailures, id: \.self) { failure in
                            Label(failure, systemImage: "exclamationmark.circle").font(.caption2).foregroundStyle(.orange)
                        }
                        ExperimentMetric(label: "Unique valid samples", value: String(summary.count))
                        ExperimentMetric(label: "Buckets ≥ 1,350", value: "\(summary.qualifyingBuckets) / \(summary.buckets.count)")
                        ExperimentMetric(label: "Observed rate", value: summary.observedRate.map { String(format: "%.2f Hz", $0) } ?? "Unknown")
                        ExperimentMetric(label: "First sample", value: date(summary.first))
                        ExperimentMetric(label: "Last sample", value: date(summary.last))
                        ExperimentMetric(label: "Largest gap", value: seconds(summary.maximumGap))
                        ExperimentMetric(label: "Leading / trailing", value: "\(seconds(summary.leadingGap)) / \(seconds(summary.trailingGap))")
                        ExperimentMetric(label: "Invalid / order anomalies", value: "\(summary.invalid) / \(summary.outOfOrder)")
                        if summary.outOfOrder > 0 {
                            NavigationLink("Inspect order anomalies") {
                                OvernightOrderAnomaliesView(summary: summary)
                            }
                        }
                        ExperimentMetric(label: "Expected overlap / outside window", value: "\(summary.boundaryDuplicates) / \(summary.outsideWindow)")
                        ExperimentMetric(label: "Nil / empty chunks", value: "\(summary.nilChunks) / \(summary.emptyChunks)")
                        ExperimentMetric(label: "Unexpected objects", value: String(summary.unexpectedObjects))
                        Text(summary.clockDiscontinuity || summary.aborted ? "Clock or enumeration incomplete" : "Enumeration completed").font(.caption2)
                        NavigationLink("Thirty-second buckets") {
                            ScrollView {
                                LazyVStack(alignment: .leading, spacing: 12) {
                                    ForEach(summary.buckets) { bucket in
                                        VStack(alignment: .leading) {
                                            Text("\(bucket.id + 1) · \(summary.start.addingTimeInterval(Double(bucket.id) * 30).formatted(date: .omitted, time: .standard))").font(.headline)
                                            Text("\(bucket.count) samples · gap \(seconds(bucket.maximumGap))").font(.caption)
                                            Text("\(date(bucket.first)) → \(date(bucket.last))").font(.caption2)
                                            Text("Invalid \(bucket.invalid) · order \(bucket.outOfOrder)").font(.caption2)
                                        }
                                    }
                                }.padding()
                            }.navigationTitle("Buckets")
                        }
                    }
                    ExperimentMetric(label: "Latest full read", value: date(trial.fullReadAt))
                    ExperimentMetric(label: "First useful full read", value: date(trial.firstUsefulReadAt))
                    ExperimentMetric(label: "First useful pilot probe", value: date(trial.firstUsefulProbeAt))
                    ExperimentMetric(label: "Prior incomplete probe", value: date(trial.precedingIncompleteProbeAt))
                    Text(trial.morningVisibility).font(.caption2)
                }
                ExperimentCard {
                    ExperimentHeading(title: "Request timing", symbol: "clock")
                    ExperimentMetric(label: "Elapsed clock", value: trial.clockLabel)
                    if let mismatch = trial.firstClockMismatch {
                        ExperimentMetric(label: "First clock mismatch", value: date(mismatch.observedAt))
                        ExperimentMetric(label: "Wall elapsed", value: seconds(mismatch.wallElapsed))
                        ExperimentMetric(label: "Clock elapsed", value: seconds(mismatch.clockElapsed))
                        ExperimentMetric(label: "Wall minus clock", value: String(format: "%+.2f s", mismatch.difference))
                    } else if trial.clockDiscontinuity {
                        Text("Mismatch measurements were not saved for this trial.").font(.caption2)
                    }

                    ExperimentMetric(label: "Window start", value: date(trial.start))
                    ExperimentMetric(label: "Window end", value: date(trial.end))
                    if let call = trial.recorderCall {
                        ExperimentMetric(label: "Preparation began", value: date(call.preparedAt))
                        ExperimentMetric(label: "Preparation duration", value: seconds(trial.startUptime - call.preparedUptime))
                        ExperimentMetric(label: "Recorder call returned", value: date(call.returnedAt))
                        ExperimentMetric(label: "Call duration", value: seconds(call.returnedUptime - trial.startUptime))
                        ExperimentMetric(label: "Reserved until", value: date(trial.reservationEnd))
                        Text("These dates describe the request, not confirmation that recording started.").font(.caption2)
                    } else if trial.mode != .comparison {
                        Text("Recorder-call timing was not saved. The original window and measurements are unchanged.").font(.caption2)
                    }
                }
                ExperimentCard {
                    ExperimentHeading(title: "Battery & conditions", symbol: "battery.50percent")
                    ExperimentMetric(label: "Before leaving", value: trial.batteryStart.level.map { String(format: "%.0f%%", $0 * 100) } ?? "Unknown")
                    ExperimentMetric(label: "Battery start time", value: date(trial.batteryStart.date))
                    ExperimentMetric(label: "Returned", value: trial.batteryReturn?.level.map { String(format: "%.0f%%", $0 * 100) } ?? "Unknown")
                    ExperimentMetric(label: "Return time", value: date(trial.batteryReturn?.date))
                    ExperimentMetric(label: "Drop", value: trial.batteryDrop.map { String(format: "%.1f points", $0) } ?? "Unknown")
                    Text(coordinator.archive.batteryAssessment(for: trial)).font(.caption2)
                    let settings = trial.configuration
                    Text("\(settings.watchModel) · watchOS \(settings.watchOS) · build \(settings.appBuild)\n\(settings.timeZone)\nWrist: \(settings.wrist)\nLow power: \(settings.powerMode)\nSleep Focus: \(settings.sleepFocus)\nSleep tracking: \(settings.sleepTracking)\nDebugger detached: \(settings.debuggerDetached)\nOther app: \(settings.otherApp)\nCharging: \(settings.charging)\nInterruptions: \(settings.interruption)").font(.caption2)
                }
                ExperimentCard {
                    ExperimentHeading(title: "Retrieval attempts", symbol: "arrow.down.circle")
                    ForEach(Array(trial.observations.enumerated()), id: \.offset) { _, read in
                        Text("\(read.pilotProbe ? "Pilot block" : "Full window")\n\(date(read.requestedAt)) → \(date(read.completedAt))\n\(read.count) samples · \(read.useful ? "useful" : "incomplete") · nil \(read.nilChunks) · empty \(read.emptyChunks)\nFirst \(date(read.first))\nLast \(date(read.last))\n\(read.cancelled ? "Cancelled" : read.error ?? "No API error reported")").font(.caption2)
                        if read.clockDiscontinuity == true {
                            Text("Retrieval clock uncertain; this attempt cannot establish visibility.").font(.caption2).foregroundStyle(.orange)
                        }
                        if let diagnostics = read.orderDiagnostics {
                            NavigationLink("Inspect this read's ordering") {
                                OvernightOrderAnomaliesView(diagnostics: diagnostics)
                            }.font(.caption)
                        }
                    }
                }
                ExperimentCard {
                    ExperimentHeading(title: "Lifecycle events", symbol: "list.bullet")
                    if trial.eventsTruncated { Text("Earlier events trimmed; latest 40 retained.").font(.caption2) }
                    ForEach(trial.events) { event in
                        Text("\(date(event.date))\n\(event.message)").font(.caption2)
                    }
                }
            } else { Text("Trial no longer retained; only three recent trials are stored.") }
        }.navigationTitle("Trial details")
    }
}

struct OvernightOrderAnomaliesView: View {
    let total: Int
    let counts: OvernightMotionSummary.OrderAnomalyCounts?
    let diagnostics: OvernightMotionSummary.OrderDiagnostics?

    init(summary: OvernightMotionSummary) {
        total = summary.outOfOrder
        counts = summary.orderAnomalyCounts
        diagnostics = summary.orderDiagnostics
    }
    init(diagnostics: OvernightMotionSummary.OrderDiagnostics) {
        total = diagnostics.total
        counts = nil
        self.diagnostics = diagnostics
    }
    var body: some View {
        ExperimentPage {
            ExperimentCard {
                ExperimentHeading(title: "Order anomalies", symbol: "list.bullet")
                ExperimentMetric(label: "Recorded total", value: String(total))
                if let counts {
                    ExperimentMetric(label: "Repeated time pair", value: String(counts.exactTimeRepeats))
                    ExperimentMetric(label: "Date only", value: String(counts.dateOnly))
                    ExperimentMetric(label: "Sensor time only", value: String(counts.sensorTimeOnly))
                    ExperimentMetric(label: "Both time fields", value: String(counts.bothTimes))
                    Text("Compared with the last accepted sample. Counts identify times that did not increase, not their cause. Expected chunk overlap is separate.").font(.caption2)
                } else if diagnostics == nil {
                    Text("Breakdown unavailable for this older summary. The recorded total is unchanged.").font(.caption2)
                }
                if let diagnostics {
                    ExperimentMetric(label: "Repeated dates", value: String(diagnostics.repeatedDates))
                    ExperimentMetric(label: "Backward dates", value: String(diagnostics.backwardDates))
                    ExperimentMetric(label: "Repeated sensor times", value: String(diagnostics.repeatedSensorTimes))
                    ExperimentMetric(label: "Backward sensor times", value: String(diagnostics.backwardSensorTimes))
                    ExperimentMetric(label: "Within query", value: String(diagnostics.withinQuery))
                    ExperimentMetric(label: "Across queries", value: String(diagnostics.acrossQueries))
                    ExperimentMetric(label: "Position unknown", value: String(diagnostics.unknownPosition))
                    Text("Each timing difference compares with the last accepted sample. Query and row numbers start at 1. These diagnostics explain a failed comparison, not its cause.").font(.caption)
                    Text("First \(diagnostics.examples.count) examples of \(total) failures; totals include failures beyond the 12-example limit.").font(.caption)
                } else {
                    Text("Timing differences and query positions were not recorded by this older build.").font(.caption)
                }
            }
            if let diagnostics {
                ForEach(Array(diagnostics.examples.enumerated()), id: \.offset) { index, example in
                    ExperimentCard {
                        Text("Failure \(index + 1)").font(.headline)
                        ExperimentMetric(label: "From window start", value: String(format: "%.2f s", example.relativeSeconds))
                        ExperimentMetric(label: "Date difference", value: String(format: "%+.6g s", example.dateDelta))
                        ExperimentMetric(label: "Sensor difference", value: String(format: "%+.6g s", example.sensorDelta))
                        if let position = example.position {
                            Text("Query \(position.queryIndex), sample row \(position.sampleIndex). Last accepted sample: query \(position.previousAcceptedQueryIndex).").font(.caption)
                        } else { Text("Query position unknown.").font(.caption) }
                    }
                }
            }
        }.navigationTitle("Order anomalies")
    }
}

struct PilotGuideCard: View {
    let trial: OvernightMotionTrial
    let now: Date
    var body: some View {
        let guide = PilotGuide(trial: trial, now: now)
        ExperimentCard {
            ExperimentHeading(title: guide.title, symbol: "list.number")
            if let target = guide.target {
                ExperimentMetric(label: "Target time", value: target.formatted(date: .omitted, time: .standard))
                Text(now < target ? "In \(Int(ceil(target.timeIntervalSince(now)))) seconds" : "Target time reached")
                    .font(.caption2).monospacedDigit()
            }
            Text(guide.instruction).font(.caption)
            Text("The recording request continues while you leave. Probes require an active app and your tap.").font(.caption2).foregroundStyle(.secondary)
        }
    }
}
