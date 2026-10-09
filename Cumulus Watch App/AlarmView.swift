import SwiftUI

struct AlarmHomeView<Research: View>: View {
    @Environment(\.scenePhase) private var scenePhase
    @ObservedObject var coordinator: AlarmCoordinator
    @ObservedObject var owner: ExperimentSessionOwner
    @ViewBuilder var research: () -> Research

    var body: some View {
        ExperimentPage {
            ExperimentCard {
                ExperimentPageHeading(compact: true) {
                    Text("Alarm")
                        .font(.headline)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityAddTraits(.isHeader)
                }
                Text(coordinator.status).font(.headline)
                    .fixedSize(horizontal: false, vertical: true)
                if coordinator.canStop {
                    Button { coordinator.stop() } label: {
                        Text("Stop alert").frame(maxWidth: .infinity, minHeight: 44)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                        .buttonStyle(.borderedProminent).frame(minHeight: 44)
                        .disabled(scenePhase != .active)
                } else if coordinator.canCancel {
                    NavigationLink {
                        AlarmTimeSelectionView(coordinator: coordinator, editing: true)
                    } label: {
                        Text("Edit time").frame(maxWidth: .infinity, minHeight: 44)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                        .buttonStyle(.borderedProminent).frame(minHeight: 44)
                        .disabled(scenePhase != .active || !coordinator.canEdit)
                    Button { coordinator.cancel() } label: {
                        Text("Cancel alarm").frame(maxWidth: .infinity, minHeight: 44)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                        .buttonStyle(.bordered).frame(minHeight: 44)
                        .disabled(scenePhase != .active)
                } else if coordinator.canSchedule {
                    NavigationLink {
                        AlarmTimeSelectionView(coordinator: coordinator, editing: false)
                    } label: {
                        Text("Set alarm").frame(maxWidth: .infinity, minHeight: 44)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                        .buttonStyle(.borderedProminent).frame(minHeight: 44)
                        .disabled(scenePhase != .active)
                }
                if let record = coordinator.record {
                    Text(record.phase.pending ? "Requested time" : "Last requested time")
                        .font(.caption).foregroundStyle(.secondary)
                    Text(record.fireDate.formatted(date: .omitted, time: .shortened))
                        .font(.title2.weight(.semibold)).monospacedDigit()
                        .fixedSize(horizontal: false, vertical: true)
                    Text(record.fireDate.formatted(date: .complete, time: .omitted))
                        .font(.body).fixedSize(horizontal: false, vertical: true)
                    Text(record.fireDate.formatted(.dateTime.timeZone(.specificName(.short))))
                        .font(.caption).foregroundStyle(.secondary)
                }
                if coordinator.isUnverified {
                    Text("Saved time only. Waiting for WatchKit to return the session; no new alarm will be created automatically.")
                        .font(.body).fixedSize(horizontal: false, vertical: true)
                }
                if let error = coordinator.errorMessage {
                    Text(error).font(.body).foregroundStyle(.orange)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Text("One-time alarm. No sleep sensing.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            if owner.current != .none && owner.current != .alarm {
                Text("A research session is active or unresolved. Finish it in Research before setting an alarm.")
                    .font(.body).fixedSize(horizontal: false, vertical: true)
            }
            Text("Keep an independent alarm during testing. Scheduled and haptic requested do not confirm that you will wake.")
                .font(.caption).foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            NavigationLink { AlarmHistoryView(coordinator: coordinator) } label: {
                Text("Alarm history").frame(maxWidth: .infinity, minHeight: 44)
                    .fixedSize(horizontal: false, vertical: true)
            }
                .buttonStyle(.bordered).frame(minHeight: 44)
            NavigationLink(destination: research) {
                Text("Research").frame(maxWidth: .infinity, minHeight: 44)
                    .fixedSize(horizontal: false, vertical: true)
            }
                .buttonStyle(.bordered).frame(minHeight: 44)
        }
        .navigationTitle("Cumulus")
        .task(id: scenePhase) {
            while scenePhase == .active && !Task.isCancelled {
                coordinator.refreshState()
                do { try await Task.sleep(for: .milliseconds(500)) }
                catch { return }
            }
        }
    }
}

struct AlarmTimeSelectionView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    @ObservedObject var coordinator: AlarmCoordinator
    let editing: Bool
    @State private var hour: Int
    @State private var minute: Int
    @State private var referenceDate = Date()

    init(coordinator: AlarmCoordinator, editing: Bool) {
        self.coordinator = coordinator
        self.editing = editing
        let date = coordinator.record?.fireDate
        _hour = State(initialValue: date.map { Calendar.current.component(.hour, from: $0) } ?? 7)
        _minute = State(initialValue: date.map { Calendar.current.component(.minute, from: $0) } ?? 0)
    }
    private var candidate: Date? { AlarmTime.next(hour: hour, minute: minute, after: referenceDate) }

    var body: some View {
        Form {
            Section("Time · 24-hour") {
                Picker("Hour", selection: $hour) {
                    ForEach(0..<24, id: \.self) { Text(String(format: "%02d", $0)).tag($0) }
                }
                Picker("Minute", selection: $minute) {
                    ForEach(0..<60, id: \.self) { Text(String(format: "%02d", $0)).tag($0) }
                }
            }
            .pickerStyle(.navigationLink)
            Section("Confirm next occurrence") {
                if let date = candidate {
                    Text(date.formatted(date: .complete, time: .shortened))
                        .font(.body.weight(.semibold)).fixedSize(horizontal: false, vertical: true)
                    Text(date.formatted(.dateTime.timeZone(.specificName(.short))))
                        .font(.caption).foregroundStyle(.secondary)
                    Button {
                        // Submit the displayed absolute date. Never silently roll it to tomorrow on tap.
                        let accepted = editing ? coordinator.edit(to: date) : coordinator.schedule(at: date)
                        if accepted { dismiss() }
                    } label: {
                        Text(editing ? "Replace alarm" : "Schedule alarm")
                            .frame(maxWidth: .infinity, minHeight: 44)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(scenePhase != .active || (editing ? !coordinator.canEdit : !coordinator.canSchedule))
                } else { Text("This time cannot be resolved. Choose another time.") }
            }
            if editing {
                Text("The old alarm will be cancelled first. If the replacement fails, review the status and set it again.")
                    .font(.body).fixedSize(horizontal: false, vertical: true)
            }
            if let error = coordinator.errorMessage {
                Text(error).font(.body).foregroundStyle(.orange).fixedSize(horizontal: false, vertical: true)
            }
            Text("One time only. Review the date and time zone before scheduling.")
                .font(.caption).foregroundStyle(.secondary)
        }
        .tint(.blue).fontDesign(.serif)
        .navigationTitle(editing ? "Edit alarm" : "Set alarm")
        .onChange(of: hour) { referenceDate = Date() }
        .onChange(of: minute) { referenceDate = Date() }
        .onChange(of: scenePhase) { if scenePhase == .active { referenceDate = Date() } }
    }
}

struct AlarmHistoryView: View {
    @ObservedObject var coordinator: AlarmCoordinator
    @State private var confirmsClear = false
    var body: some View {
        ExperimentPage {
            Text("Local events. Requests do not confirm waking.")
                .font(.caption).foregroundStyle(.secondary)
            if coordinator.events.isEmpty { Text("No alarm events yet.") }
            if coordinator.canClear && !coordinator.events.isEmpty {
                Button("Clear alarm history") { confirmsClear = true }
                    .buttonStyle(.bordered).frame(minHeight: 44)
            }
            ForEach(coordinator.events.reversed()) { event in
                ExperimentCard {
                    Text(event.message).font(.body).fixedSize(horizontal: false, vertical: true)
                    Text(event.date.formatted(date: .abbreviated, time: .standard))
                        .font(.caption).monospacedDigit()
                    Text("Requested: \(event.fireDate.formatted(date: .abbreviated, time: .standard))")
                        .font(.caption).foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }.accessibilityElement(children: .combine)
            }
            if let error = coordinator.errorMessage { Text(error).foregroundStyle(.orange) }
        }
        .navigationTitle("History")
        .confirmationDialog("Clear alarm history? Research reports are preserved.", isPresented: $confirmsClear) {
            Button("Clear history", role: .destructive) { coordinator.clearHistory() }
        }
    }
}
