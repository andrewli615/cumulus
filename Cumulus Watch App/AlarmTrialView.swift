import SwiftUI

struct AlarmTrialNavigation: View {
    @ObservedObject var store: AlarmTrialStore
    let currentRecord: AlarmRecord?
    var body: some View {
        if let error = store.errorMessage {
            Text(error).font(.body).foregroundStyle(.orange).fixedSize(horizontal: false, vertical: true)
        }
        NavigationLink { AlarmTrialListView(store: store, currentRecord: currentRecord) } label: {
            Text("Alarm tests").frame(maxWidth: .infinity, minHeight: 44)
                .fixedSize(horizontal: false, vertical: true)
        }.buttonStyle(.bordered)
    }
}

struct AlarmTrialListView: View {
    @ObservedObject var store: AlarmTrialStore
    @ObservedObject private var archive: TestArchiveStore
    let currentRecord: AlarmRecord?
    init(store: AlarmTrialStore, currentRecord: AlarmRecord?) {
        self.store = store
        self.archive = store.archive
        self.currentRecord = currentRecord
    }
    var body: some View {
        ExperimentPage {
            ExperimentCard {
                ExperimentPageHeading { ExperimentHeading(title: "Alarm tests", symbol: "checklist") }
                Text("Software events and your observations are kept separately. Neither a saved test nor a haptic request proves waking.")
                    .font(.body).fixedSize(horizontal: false, vertical: true)
                if let currentRecord {
                    Button { store.capture(currentRecord) } label: {
                        Text("Save latest alarm evidence").frame(maxWidth: .infinity, minHeight: 44)
                            .fixedSize(horizontal: false, vertical: true)
                    }.buttonStyle(.bordered)
                    Text("Explicitly saves the latest alarm if missing, including after deletion. Old build details stay Unknown.")
                        .font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                }
                if let error = store.errorMessage { Text(error).font(.body).foregroundStyle(.orange) }
                Text("Stored in Saved tests. Deleting completed test data clears these copies and research reports; clearing alarm history is separate. Private exports remain separate.")
                    .font(.caption).fixedSize(horizontal: false, vertical: true)
            }
            let reports = archive.reports.filter { $0.kind == .fixedAlarm }
            if reports.isEmpty { Text("No saved alarm tests. New alarm events are captured automatically when storage is available.").font(.body) }
            ForEach(reports) { report in
                if let id = UUID(uuidString: String(report.id.dropFirst("fixedalarm-".count))) {
                    NavigationLink { AlarmTrialDetailView(id: id, store: store) } label: {
                        ExperimentCard {
                            Text("Alarm \(id.uuidString.prefix(8))").font(.headline)
                            Text("Target: \(report.metrics["Target (capture time zone)"] ?? "Unknown")").font(.body)
                            Text(report.status).font(.caption).fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
            }
        }.navigationTitle("Alarm tests")
    }
}

struct AlarmTrialDetailView: View {
    let id: UUID
    @ObservedObject var store: AlarmTrialStore
    @ObservedObject private var archive: TestArchiveStore
    @State private var trial: AlarmTrial?
    @State private var readError: String?
    init(id: UUID, store: AlarmTrialStore) {
        self.id = id
        self.store = store
        self.archive = store.archive
    }
    var body: some View {
        ExperimentPage {
            if let trial {
                ExperimentCard {
                    ExperimentPageHeading(compact: true) {
                        Text("Alarm").font(.headline).accessibilityAddTraits(.isHeader)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Text(trial.fireDate.formatted(date: .abbreviated, time: .shortened))
                        .font(.body.weight(.semibold)).fixedSize(horizontal: false, vertical: true)
                    NavigationLink { AlarmTrialEditView(trial: trial, store: store) } label: {
                        Text("Edit report").frame(maxWidth: .infinity, minHeight: 44)
                            .fixedSize(horizontal: false, vertical: true)
                    }.buttonStyle(.borderedProminent)
                    Text("Only your observations are editable. Target shown in current time zone. This report does not set or cancel an alarm.")
                        .font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                }
                ExperimentCard {
                    ExperimentHeading(title: "Software evidence", symbol: "clock")
                    ExperimentMetric(label: "Alarm identity", value: trial.alarmID.uuidString)
                    ExperimentMetric(label: "Recorded phase", value: trial.phase.rawValue)
                    ExperimentMetric(label: "Original build", value: trial.origin?.build ?? "Unknown")
                    ExperimentMetric(label: "Original watchOS", value: trial.origin?.os ?? "Unknown")
                    ExperimentMetric(label: "Original time zone", value: trial.origin?.timeZone ?? "Unknown")
                    Text(trial.historyDescription).font(.body).fixedSize(horizontal: false, vertical: true)
                    if trial.clockUncertain { Text("Report clock uncertainty recorded. Timing needs review.").font(.body).foregroundStyle(.orange) }
                    if trial.hapticOffsets.isEmpty { Text("No haptic request retained; absence is not proof no alert occurred.").font(.body) }
                    ForEach(Array(trial.hapticOffsets.enumerated()), id: \.offset) { _, offset in
                        ExperimentMetric(label: "Haptic request from target", value: String(format: "%+.3f s", offset))
                    }
                    if let old = trial.replacesAlarmID { ExperimentMetric(label: "Replaces alarm", value: old.uuidString) }
                    if let replacement = trial.requestedReplacementDate {
                        ExperimentMetric(label: "Requested edit target", value: replacement.formatted(date: .abbreviated, time: .standard))
                    }
                }
                ExperimentCard {
                    ExperimentHeading(title: "Your observations", symbol: "person")
                    ExperimentMetric(label: "Trial type", value: trial.observations.kind.title)
                    ExperimentMetric(label: "Felt haptic", value: trial.observations.feltHaptic.title)
                    ExperimentMetric(label: "Saw alert", value: trial.observations.sawAlert.title)
                    ExperimentMetric(label: "Unexplained duplicate", value: trial.observations.duplicates.title)
                    ExperimentMetric(label: "Old time silent", value: trial.observations.oldTimeSilent.title)
                    ExperimentMetric(label: "Stop worked", value: trial.observations.stopWorked.title)
                    if let saved = trial.observationsUpdatedAt {
                        ExperimentMetric(label: "Owner observations saved", value: saved.formatted(date: .abbreviated, time: .standard))
                    }
                    battery("Start battery", trial.observations.startBattery)
                    battery("End battery", trial.observations.endBattery)
                    if let start = trial.observations.startBattery, let end = trial.observations.endBattery {
                        ExperimentMetric(label: "Reported battery loss", value: "\(start.percent - end.percent) percentage points")
                        Text("Reading times do not prove continuous wear or no charging. Conditions remain separate.").font(.caption)
                    }
                    Text("Self-reports do not automatically qualify an overnight trial or establish waking. Missed details should stay Unknown.")
                        .font(.body).fixedSize(horizontal: false, vertical: true)
                }
                ExperimentCard {
                    ExperimentHeading(title: "Reported conditions", symbol: "list.bullet")
                    ExperimentMetric(label: "Debugger detached", value: trial.observations.debuggerDetached.title)
                    ExperimentMetric(label: "Sleep Focus used", value: trial.observations.sleepFocus.title)
                    ExperimentMetric(label: "Haptics enabled", value: trial.observations.hapticsEnabled.title)
                    ExperimentMetric(label: "Charged during trial", value: trial.observations.charged.title)
                    ExperimentMetric(label: "Interrupted", value: trial.observations.interrupted.title)
                    ExperimentMetric(label: "Settings note", value: trial.observations.settingsNote.isEmpty ? "Unknown" : trial.observations.settingsNote)
                }
                ForEach(trial.events) { event in
                    ExperimentCard {
                        Text(event.message).font(.body).fixedSize(horizontal: false, vertical: true)
                        Text(event.date.formatted(date: .abbreviated, time: .standard)).font(.caption).monospacedDigit()
                    }.accessibilityElement(children: .combine)
                }
            }
            if let readError { Text(readError).font(.body).foregroundStyle(.orange) }
        }.navigationTitle("Alarm test")
            .task(id: archive.reports.first(where: { $0.id == "fixedalarm-" + id.uuidString.lowercased() })?.updatedAt) {
                do { trial = try store.load(id); readError = nil }
                catch { trial = nil; readError = "This trial could not be read or was cleared. Existing files were not changed." }
            }
    }
    @ViewBuilder private func battery(_ label: String, _ reading: AlarmTrial.BatteryReading?) -> some View {
        ExperimentMetric(label: label, value: reading.map { "\($0.percent)%" } ?? "Unknown")
        if let reading { Text(reading.observedAt.formatted(date: .abbreviated, time: .standard)).font(.caption) }
    }
}

struct AlarmTrialEditView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var store: AlarmTrialStore
    let trial: AlarmTrial
    @State private var observations: AlarmTrial.Observations
    @State private var original: AlarmTrial.Observations
    @State private var expectedRevision: UUID?
    @State private var saveError: String?
    init(trial: AlarmTrial, store: AlarmTrialStore) {
        self.trial = trial
        self.store = store
        _observations = State(initialValue: trial.observations)
        _original = State(initialValue: trial.observations)
        _expectedRevision = State(initialValue: trial.observationsRevision)
    }
    var body: some View {
        Form {
            Section {
                Picker("Type", selection: $observations.kind) {
                    ForEach(AlarmTrial.Kind.allCases, id: \.self) { Text($0.title).tag($0) }
                }.pickerStyle(.navigationLink)
                NavigationLink {
                    AlarmTrialAnswersView(observations: $observations, conditions: false)
                } label: {
                    VStack(alignment: .leading) {
                        Text("Alert observations").font(.body)
                        Text("Felt haptic: \(observations.feltHaptic.title)").font(.caption)
                    }.fixedSize(horizontal: false, vertical: true).frame(minHeight: 44)
                }
                NavigationLink {
                    AlarmTrialAnswersView(observations: $observations, conditions: true)
                } label: {
                    Text("Conditions & settings").font(.body).frame(minHeight: 44)
                        .fixedSize(horizontal: false, vertical: true)
                }
            } header: {
                VStack(alignment: .leading, spacing: 4) {
                    Text(trial.fireDate.formatted(date: .abbreviated, time: .shortened))
                        .font(.body.weight(.semibold))
                    Text("Alarm \(trial.alarmID.uuidString.prefix(8))")
                        .font(.caption).foregroundStyle(.secondary)
                }.textCase(nil).fixedSize(horizontal: false, vertical: true)
            } footer: {
                Text("Draft only. Save below; Back discards changes. Leave missed details Unknown.")
                    .font(.caption).fixedSize(horizontal: false, vertical: true)
            }
            Section("Battery · manual readings") {
                batteryLink("Start battery", $observations.startBattery)
                batteryLink("End battery", $observations.endBattery)
                Text("Record a current percentage and time. Missed earlier readings remain Unknown.")
                    .font(.body).fixedSize(horizontal: false, vertical: true)
            }
            Section("Save this alarm's observations") {
                Text(observations == original ? "Review then save" : "Unsaved changes")
                    .font(.body).fixedSize(horizontal: false, vertical: true)
                if let problem = observations.validationMessage {
                    Text(problem).font(.body).foregroundStyle(.orange).fixedSize(horizontal: false, vertical: true)
                }
                if let saveError {
                    Text(saveError).font(.body).foregroundStyle(.orange).fixedSize(horizontal: false, vertical: true)
                }
                Button {
                    if store.saveObservations(observations, for: trial.alarmID, expectedRevision: expectedRevision) { dismiss() }
                    else { saveError = store.errorMessage ?? "Observations were not saved. Your draft remains open." }
                } label: {
                    Text("Save observations").frame(maxWidth: .infinity, minHeight: 44)
                        .fixedSize(horizontal: false, vertical: true)
                }.buttonStyle(.borderedProminent).disabled(observations.validationMessage != nil)
                Text("Your report does not schedule, cancel or qualify an alarm.").font(.caption)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }.fontDesign(.serif).tint(.blue).navigationTitle("Report")
    }
    private func batteryLink(_ title: String, _ reading: Binding<AlarmTrial.BatteryReading?>) -> some View {
        NavigationLink { AlarmTrialBatteryView(title: title, reading: reading) } label: {
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.body)
                if let value = reading.wrappedValue {
                    Text("\(value.percent)% · \(value.observedAt.formatted(date: .abbreviated, time: .standard))")
                        .font(.body).monospacedDigit()
                } else { Text("Unknown").font(.body).foregroundStyle(.secondary) }
            }.fixedSize(horizontal: false, vertical: true).frame(minHeight: 44)
        }
    }
}

private struct AlarmTrialAnswersView: View {
    @Binding var observations: AlarmTrial.Observations
    let conditions: Bool
    var body: some View {
        Form {
            Text("Draft only. Return to Observations and tap Save observations.")
                .font(.body).fixedSize(horizontal: false, vertical: true)
            if conditions {
                Section("Conditions · your report") {
                    answer("Debugger detached", $observations.debuggerDetached)
                    answer("Sleep Focus used", $observations.sleepFocus)
                    answer("Haptics enabled", $observations.hapticsEnabled)
                    answer("Charged during trial", $observations.charged)
                    answer("Interrupted", $observations.interrupted)
                }
                Section("Settings note · optional") {
                    TextField("Actual settings", text: $observations.settingsNote)
                    Text("\(observations.settingsNote.count)/200 characters. Do not paste logs or health records.")
                        .font(.body).fixedSize(horizontal: false, vertical: true)
                    if observations.settingsNote.count > 200 {
                        Text("Shorten this note before saving.").font(.body).foregroundStyle(.orange)
                    }
                }
            } else {
                Section("Alert · your report") {
                    answer("Felt haptic", $observations.feltHaptic)
                    answer("Saw system alert", $observations.sawAlert)
                    answer("Unexplained duplicate", $observations.duplicates)
                    answer("Stop worked", $observations.stopWorked)
                    answer("Old time silent · edit/cancel", $observations.oldTimeSilent)
                }
            }
        }.fontDesign(.serif).tint(.blue).navigationTitle(conditions ? "Conditions" : "Alert report")
    }
    private func answer(_ title: String, _ selection: Binding<AlarmTrial.Answer>) -> some View {
        Picker(selection: selection) {
            ForEach(AlarmTrial.Answer.allCases, id: \.self) { Text($0.title).tag($0) }
        } label: { Text(title).fixedSize(horizontal: false, vertical: true).frame(minHeight: 44) }
            .pickerStyle(.navigationLink)
    }
}

struct AlarmTrialBatteryView: View {
    @Environment(\.dismiss) private var dismiss
    let title: String
    @Binding var reading: AlarmTrial.BatteryReading?
    @State private var percent: Int
    init(title: String, reading: Binding<AlarmTrial.BatteryReading?>) {
        self.title = title
        _reading = reading
        _percent = State(initialValue: reading.wrappedValue?.percent ?? -1)
    }
    var body: some View {
        Form {
            Section {
                if let reading {
                    Text("Recorded draft: \(reading.percent)%").font(.headline)
                    Text(reading.observedAt.formatted(date: .abbreviated, time: .standard)).font(.body)
                } else { Text("No reading recorded").font(.body) }
                Picker("Current percentage", selection: $percent) {
                    Text("Unknown").tag(-1)
                    ForEach(0...100, id: \.self) { Text("\($0)%").tag($0) }
                }.pickerStyle(.navigationLink)
                Button {
                    reading = .init(percent: percent, observedAt: .now)
                    dismiss()
                } label: {
                    Text("Record now & return").frame(maxWidth: .infinity, minHeight: 44)
                        .fixedSize(horizontal: false, vertical: true)
                }.buttonStyle(.borderedProminent).disabled(!(0...100).contains(percent))
                Text("Enter the percentage currently shown by your Watch. Recording timestamps this tap, then returns to the unsaved form. Tap Save observations there. It cannot recover an earlier reading.")
                    .font(.body).fixedSize(horizontal: false, vertical: true)
                if reading != nil {
                    Button {
                        reading = nil
                        dismiss()
                    } label: {
                        Text("Clear draft & return").frame(maxWidth: .infinity, minHeight: 44)
                            .fixedSize(horizontal: false, vertical: true)
                    }.buttonStyle(.bordered)
                }
            }
        }.fontDesign(.serif).tint(.blue).navigationTitle(title)
    }
}
