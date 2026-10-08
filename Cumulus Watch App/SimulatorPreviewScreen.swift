#if DEBUG && targetEnvironment(simulator)
import SwiftUI

struct SimulatorPreviewScreen: View {
    let screen: String
    @StateObject private var archive: TestArchiveStore
    @StateObject private var owner: ExperimentSessionOwner
    @State private var previewMode: OvernightMotionTrial.Mode = .pilot
    private let trial: OvernightMotionTrial

    init(screen: String) {
        self.screen = screen
        _previewMode = State(initialValue: OvernightMotionTrial.Mode(rawValue:
            ProcessInfo.processInfo.environment["CUMULUS_UI_TRIAL"] ?? "") ?? .pilot)
        let store = TestArchiveStore(directory: FileManager.default.temporaryDirectory.appendingPathComponent("CumulusUIFixtures"),
                                     build: "Synthetic UI fixture", os: "Simulated")
        _archive = StateObject(wrappedValue: store)
        _owner = StateObject(wrappedValue: ExperimentSessionOwner(defaults: UserDefaults(suiteName: "CumulusUIFixtures")!))
        var trial = OvernightMotionTrial(mode: .pilot, start: Date().addingTimeInterval(-610),
            uptime: ProcessInfo.processInfo.systemUptime - 610, configuration: .init(), battery: nil)
        trial.phase = .requested
        trial.requestCount = 1
        self.trial = trial
        let report = TestReport(id: "overnight-synthetic-preview", kind: .overnight, createdAt: trial.start,
                               title: "Synthetic pilot", status: "No physical trial", metrics: ["Original build": "Synthetic"])
        store.saveDiagnostics(trial, report: report)
    }

    var body: some View {
        NavigationStack {
            switch screen {
            case "trial-selector":
                ExperimentPage {
                    ExperimentCard { OvernightTrialSelector(mode: $previewMode) }
                }.navigationTitle("Recording")
            case "trial-choices": OvernightTrialChoiceView(mode: $previewMode)
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
