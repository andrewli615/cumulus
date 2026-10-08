import Foundation

@main struct TestArchiveChecks {
    @MainActor static func main() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer {
            try? FileManager.default.removeItem(at: directory)
            try? FileManager.default.removeItem(at: directory.appendingPathExtension("deleted-through"))
        }
        let store = TestArchiveStore(directory: directory, build: "synthetic", os: "synthetic", maximumReports: 2)
        let date = Date(timeIntervalSince1970: 100.123456)
        var first = TestReport(id: "foreground-one", kind: .foreground, createdAt: date,
            title: "Synthetic", status: "Started", metrics: ["Samples": "0"])
        store.saveDiagnostics(["synthetic": 42], report: first)
        precondition(store.errorMessage == nil && store.reports.count == 1 && store.canStartNewReport)
        precondition(store.reports[0].diagnostics == nil)
        let persisted = try store.report(id: first.id)
        precondition(persisted.createdAt == date && persisted.captureBuild == "synthetic")
        let checked1 = try JSONDecoder().decode([String: Int].self, from: persisted.diagnostics!) == ["synthetic": 42]
        precondition(checked1)
        first = TestReport(id: first.id, kind: .foreground, createdAt: date,
            title: "Synthetic", status: "Stopped", metrics: ["Samples": "100"])
        store.save(first)
        let second = TestReport(id: "alert-two", kind: .alert, createdAt: date,
            title: "Synthetic", status: "Not perceived", metrics: [:])
        store.save(second)
        precondition(!store.canStartNewReport)
        let restarted = TestArchiveStore(directory: directory, maximumReports: 2)
        precondition(restarted.reports.count == 2 && restarted.errorMessage == nil)
        let checked2 = try restarted.report(id: first.id).metrics["Samples"] == "100"
        precondition(checked2)
        let before = try Data(contentsOf: directory.appendingPathComponent(first.id + ".json"))
        store.save(TestReport(id: "sleep-three", kind: .sleep, createdAt: date,
            title: "Synthetic", status: "Read", metrics: [:]))
        precondition(store.errorMessage?.contains("full") == true && store.reports.count == 2)
        let checked3 = try Data(contentsOf: directory.appendingPathComponent(first.id + ".json")) == before
        precondition(checked3)
        let small = TestArchiveStore(directory: directory, maximumBytes: before.count)
        small.save(first)
        precondition(small.errorMessage?.contains("full") == true)
        var invalid = first
        invalid.schemaVersion = 2
        store.save(invalid)
        precondition(store.errorMessage != nil)
        store.save(TestReport(id: "foreground-../escape", kind: .foreground, createdAt: date,
            title: "Synthetic", status: "Invalid", metrics: [:]))
        precondition(store.errorMessage != nil)
        let corrupt = directory.appendingPathComponent("cardiac-corrupt.json")
        try Data("not-json".utf8).write(to: corrupt)
        store.reload()
        precondition(store.unreadableFiles == 1 && store.reports.count == 2)
        store.save(TestReport(id: "cardiac-corrupt", kind: .cardiac, createdAt: date,
            title: "Synthetic", status: "Invalid", metrics: [:]))
        let checked4 = try Data(contentsOf: corrupt) == Data("not-json".utf8)
        precondition(checked4)
        try FileManager.default.removeItem(at: corrupt)
        let link = directory.appendingPathComponent("sleep-link.json")
        try FileManager.default.createSymbolicLink(at: link, withDestinationURL: directory.appendingPathComponent(first.id + ".json"))
        store.reload()
        precondition(store.unreadableFiles == 1)
        precondition(store.deleteAll())
        precondition(store.reports.isEmpty && store.storedBytes == 0)
        let empty = TestArchiveStore(directory: directory)
        precondition(empty.reports.isEmpty)
        empty.save(first, importing: true)
        precondition(empty.reports.isEmpty, "Deleted legacy history cannot reappear during import")
        empty.save(first)
        precondition(empty.reports.count == 1, "A new write is not suppressed by clock changes")
        let origin = Date(timeIntervalSince1970: 1000)
        var pilot = OvernightMotionTrial(mode: .pilot, start: origin, uptime: 1000, configuration: .init(), battery: nil)
        pilot.phase = .elapsed
        pilot.requestCount = 1
        var motion = OvernightMotionSummary(start: origin, end: pilot.end)
        for i in 271..<60000 {
            motion.receive(date: origin.addingTimeInterval(Double(i) / 50), uptime: 1000 + Double(i) / 50,
                           axesFinite: true, chunkStart: origin)
        }
        pilot.fullSummary = motion
        var diagnostic = TestReport(id: "overnight-synthetic", kind: .overnight, createdAt: origin,
            title: "Synthetic", status: "Synthetic", metrics: [:])
        diagnostic.diagnostics = try TestReport.encodeDiagnostics(pilot)
        let assessed = try SavedReportAssessment(report: diagnostic)
        precondition(assessed.lines.contains { $0.lowercased().contains("leading") })
        precondition(assessed.lines.contains { $0.contains("visibility unknown") })
        var comparison = OvernightMotionTrial(mode: .comparison, start: origin, uptime: 1000, configuration: .init(), battery: 0.1)
        comparison.phase = .elapsed
        comparison.configuration.charging = "Yes"
        diagnostic.diagnostics = try TestReport.encodeDiagnostics(comparison)
        let batteryAssessment = try SavedReportAssessment(report: diagnostic)
        precondition(batteryAssessment.lines.contains { $0.contains("comparison inconclusive") })
        print("Test archive checks passed: persistence, exact dates, updates, capacity, corrupt files, path validation, symlinks and deletion")
    }
}
