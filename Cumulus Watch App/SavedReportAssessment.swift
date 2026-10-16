import Foundation

struct SavedReportAssessment {
    let lines: [String]
    let featureCapture: ForegroundFeatureCapture?
    private struct Header: Decodable { let format: String? }

    init(report: TestReport) throws {
        if report.kind == .foreground, let data = report.diagnostics,
           try JSONDecoder().decode(Header.self, from: data).format == "foreground-motion-features" {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .secondsSince1970
            let capture = try decoder.decode(ForegroundFeatureCapture.self, from: data)
            try capture.validate()
            guard capture.reportID == report.id, capture.startedAt == report.createdAt else { throw TestArchiveError.invalid }
            featureCapture = capture
            lines = [capture.status,
                "Original build: \(capture.originalBuild); watchOS: \(capture.originalOS).",
                "\(capture.epochs.count) completed windows; final partial: \(capture.partial == nil ? "none" : "present").",
                "Invalid samples: \(capture.invalidSamples); order anomalies: \(capture.orderAnomalies); empty windows skipped: \(capture.skippedWindows).",
                "Pre-start sensor samples excluded: \(capture.preStartSamples).",
                capture.clockUncertain ? "Wall/uptime mapping uncertain; do not assume reliable calendar alignment."
                    : "No mapping mismatch recorded; foreground receipt/calculation times are software observations.",
                "Movement features do not establish sleep, stages, perceived alerts or all-night availability."]
            return
        }
        featureCapture = nil
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
