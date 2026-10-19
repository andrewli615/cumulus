#if DEBUG && targetEnvironment(simulator)
import SwiftUI

struct SimulatorPreviewScreen: View {
    let screen: String
    @StateObject private var archive: TestArchiveStore
    @StateObject private var owner: ExperimentSessionOwner
    @StateObject private var alarm: AlarmCoordinator
    @State private var previewMode: OvernightMotionTrial.Mode = .pilot
    @State private var previewConfiguration = OvernightMotionTrial.Configuration()
    private let trial: OvernightMotionTrial
    private let featureFixture: MotionFeatures
    private let savedFeatureFixture: ForegroundFeatureCapture
    private let alarmTrialFixture: AlarmTrial
    private let alarmTrialStore: AlarmTrialStore
    @State private var previewBattery: AlarmTrial.BatteryReading?
    private var orderSummary: OvernightMotionSummary {
        var summary = OvernightMotionSummary(start: trial.start, end: trial.start.addingTimeInterval(1200))
        summary.receive(date: trial.start.addingTimeInterval(1), uptime: 1000, axesFinite: true, chunkStart: trial.start)
        for index in 0..<14 {
            summary.receive(date: trial.start.addingTimeInterval(index.isMultiple(of: 2) ? 1 : 0.99),
                uptime: 1000.02 + Double(index) * 0.02, axesFinite: true, chunkStart: trial.start,
                position: .init(queryIndex: 1, sampleIndex: index + 2, previousAcceptedQueryIndex: 1))
        }
        return summary
    }

    init(screen: String) {
        self.screen = screen
        _previewMode = State(initialValue: OvernightMotionTrial.Mode(rawValue:
            ProcessInfo.processInfo.environment["CUMULUS_UI_TRIAL"] ?? "") ?? .pilot)
        let store = TestArchiveStore(directory: FileManager.default.temporaryDirectory.appendingPathComponent("CumulusUIFixtures"),
                                     build: "Synthetic UI fixture", os: "Simulated")
        _archive = StateObject(wrappedValue: store)
        let trialStore = AlarmTrialStore(archive: store)
        alarmTrialStore = trialStore
        var syntheticAlarm = AlarmRecord(id: UUID(), fireDate: Date().addingTimeInterval(-60), createdAt: Date().addingTimeInterval(-240))
        syntheticAlarm.origin = .init(build: "Synthetic 23", os: "Simulated", timeZone: "UTC")
        syntheticAlarm.phase = .ended
        syntheticAlarm.record("Schedule requested", at: syntheticAlarm.createdAt)
        syntheticAlarm.record("Haptic requested (synthetic fixture)", at: syntheticAlarm.fireDate.addingTimeInterval(0.5))
        syntheticAlarm.record("Session invalidated (synthetic fixture)", at: syntheticAlarm.fireDate.addingTimeInterval(10))
        trialStore.capture(syntheticAlarm)
        do { alarmTrialFixture = try trialStore.load(syntheticAlarm.id) }
        catch { fatalError("Could not prepare synthetic alarm-trial fixture") }
        let fixtureOwner = ExperimentSessionOwner(defaults: UserDefaults(suiteName: "CumulusUIFixtures.\(UUID())")!)
        _owner = StateObject(wrappedValue: fixtureOwner)
        let alarmStore = AlarmFileStore(url: FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).appendingPathComponent("alarm.json"))
        if screen == "alarm-unverified" || screen == "alarm-history" {
            var saved = AlarmRecord(id: UUID(), fireDate: Date().addingTimeInterval(3600), createdAt: .now)
            saved.phase = screen == "alarm-unverified" ? .scheduled : .cancelled
            saved.record("Synthetic schedule request; no physical alarm", at: .now)
            if screen == "alarm-history" { saved.record("Synthetic cancellation confirmed", at: .now) }
            do { try alarmStore.save(saved) } catch { assertionFailure("Could not save synthetic alarm fixture") }
        }
        _alarm = StateObject(wrappedValue: AlarmCoordinator(owner: fixtureOwner, store: alarmStore))
        var trial = OvernightMotionTrial(mode: .pilot, start: Date().addingTimeInterval(-610),
            uptime: ProcessInfo.processInfo.systemUptime - 610, configuration: .init(), battery: nil)
        trial.phase = .requested
        trial.requestCount = 1
        self.trial = trial
        var features = MotionFeatures()
        let origin = ProcessInfo.processInfo.systemUptime - 32
        for index in 0..<320 {
            let timestamp = origin + Double(index) / 10
            features.receive(x: 0, y: 0, z: index.isMultiple(of: 2) ? 1 : 1.2,
                             timestamp: timestamp, receipt: timestamp + 0.01)
        }
        features.stop()
        featureFixture = features
        var savedFeatures = ForegroundFeatureCapture(id: UUID(), startedAt: Date().addingTimeInterval(-32),
            startUptime: origin, originalBuild: "Synthetic 22", originalOS: "Simulated")
        do {
            try savedFeatures.markActivity(.still, date: savedFeatures.startedAt, uptime: origin)
            try savedFeatures.observe(features, samples: 320, date: .now,
                uptime: ProcessInfo.processInfo.systemUptime, stopping: "Synthetic UI fixture")
        } catch { assertionFailure("Could not prepare synthetic feature fixture") }
        savedFeatureFixture = savedFeatures
        let report = TestReport(id: "overnight-synthetic-preview", kind: .overnight, createdAt: trial.start,
                               title: "Synthetic pilot", status: "No physical trial", metrics: ["Original build": "Synthetic"])
        store.saveDiagnostics(trial, report: report)
    }

    var body: some View {
        NavigationStack {
            switch screen {
            case "alarm-home", "alarm-unverified":
                AlarmHomeView(coordinator: alarm, owner: owner) { Text("Synthetic research destination") }
            case "alarm-setup": AlarmTimeSelectionView(coordinator: alarm, editing: false)
            case "alarm-history": AlarmHistoryView(coordinator: alarm)
            case "alarm-trials": AlarmTrialListView(store: alarmTrialStore, currentRecord: nil)
            case "alarm-trial": AlarmTrialDetailView(id: alarmTrialFixture.alarmID, store: alarmTrialStore)
            case "alarm-observations": AlarmTrialEditView(trial: alarmTrialFixture, store: alarmTrialStore)
            case "alarm-battery": AlarmTrialBatteryView(title: "Synthetic battery", reading: $previewBattery)
            case "motion-features":
                ExperimentPage {
                    ExperimentCard { MotionFeatureSection(features: featureFixture, isMonitoring: false) }
                }.navigationTitle("Analysis")
            case "motion-probe": ContentView(testArchive: archive)
            case "feature-history": ForegroundFeatureHistoryView(capture: savedFeatureFixture)
            case "movement-guide":
                ExperimentPage {
                    ExperimentCard {
                        MovementComparisonGuide(capture: savedFeatureFixture, isMonitoring: false, mark: { _ in })
                    }
                }.navigationTitle("Comparison")
            case "trial-selector":
                ExperimentPage {
                    ExperimentCard { OvernightTrialSelector(mode: $previewMode) }
                }.navigationTitle("Recording")
            case "trial-choices": OvernightTrialChoiceView(mode: $previewMode)
            case "trial-setup": OvernightSetupView(configuration: $previewConfiguration)
            case "order": OvernightOrderAnomaliesView(summary: orderSummary)
            case "gap":
                OvernightGapView(diagnostic: .init(relativeSeconds: 600, measuredGap: 3.02,
                    dateDelta: 3.02, sensorDelta: 3.02,
                    position: .init(queryIndex: 2, sampleIndex: 1, previousAcceptedQueryIndex: 1),
                    previousSampleIndex: 29850, batchChanged: true,
                    skipped: .init(count: 151, outsideQuery: 151, finiteSensorTimes: 151,
                        minimumSensorDelta: 0.02, maximumSensorDelta: 3.02)))
            case "archive": TestArchiveView(archive: archive, owner: owner, clearCompletedData: {})
            case "report":
                if let report = archive.reports.first { TestReportView(report: report, archive: archive) }
            case "guide":
                ExperimentPage { PilotGuideCard(trial: trial, now: .now) }.navigationTitle("Pilot guide")
            case "timing":
                CardiacTimingView(selection: .init(id: UUID(), kind: .heartbeatSeries, count: 70,
                    start: .now, end: Date().addingTimeInterval(60)), owner: owner, archive: nil)
            default: Text("Unknown synthetic preview")
            }
        }
        .fontDesign(.serif)
        .dynamicTypeSize(ProcessInfo.processInfo.environment["CUMULUS_UI_TEXT"] == "larger" ? .xxxLarge : .large)
    }
}
#endif
