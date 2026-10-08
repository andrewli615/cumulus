import Foundation

struct SavedReportAssessment {
    let lines: [String]

    init(report: TestReport) throws {
        guard report.kind == .overnight, let data = report.diagnostics else { lines = []; return }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .secondsSince1970
        let trial = try decoder.decode(OvernightMotionTrial.self, from: data)
        try OvernightMotionArchive(trials: [trial]).validate()
        var items = ["Original trial build: \(trial.configuration.appBuild). Capture version is not the trial version."]
        if trial.mode == .comparison {
            items.append("Comparison only: no motion collection is expected.")
            items.append("Battery start: \(trial.batteryStart.level.map { String(format: "%.0f%%", $0 * 100) } ?? "Unknown")")
            items.append("Battery return: \(trial.batteryReturn?.level.map { String(format: "%.0f%%", $0 * 100) } ?? "Unknown")")
            items.append("Charging: \(trial.configuration.charging); interruptions: \(trial.configuration.interruption).")
            if trial.configuration.charging != "No" || trial.configuration.interruption != "None" || trial.clockDiscontinuity {
                items.append("Battery comparison inconclusive: charging, interruptions, or timing uncertainty are unresolved.")
            } else {
                items.append("Compare against a recording with matching build, settings, and elapsed wear time; this report alone cannot establish recording cost.")
            }
        } else {
            if let summary = trial.fullSummary {
                items += summary.timingFailures
                if summary.meetsTimingCriteria { items.append("Stored sample timing criteria met; this alone does not qualify overnight feasibility.") }
            } else { items.append("Full-window sample timing is unknown: no summary was saved.") }
            items.append(trial.morningVisibility)
            if trial.mode == .pilot {
                items.append(trial.pilotQualified ? "Stored pilot qualification criteria met for the original build/OS."
                    : "Stored pilot qualification criteria not met. Review all failures and missing observations.")
                if let time = trial.firstUsefulProbeAt {
                    items.append(String(format: "First useful block observation: %.1f seconds after block end.", time.timeIntervalSince(trial.start.addingTimeInterval(600))))
                } else { items.append("Early block visibility unknown: no useful probe observation.") }
            }
        }
        if trial.clockDiscontinuity { items.append("Clock/reboot discontinuity recorded; cause is unknown.") }
        if trial.eventsTruncated { items.append("Event history is truncated to its latest 40 entries.") }
        items.append("Software observations do not establish sleeping, perceived alerts, or unrecorded conditions.")
        lines = items
    }
}
