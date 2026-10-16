import Foundation

final class FeatureClock: @unchecked Sendable {
    private let lock = NSLock()
    private var value: Double = 100
    func set(_ time: Double) { lock.lock(); value = time; lock.unlock() }
    func read() -> Double { lock.lock(); defer { lock.unlock() }; return value }
}

@main @MainActor struct ForegroundFeatureCaptureChecks {
    static func expect(_ value: @autoclosure () -> Bool, _ message: String) { precondition(value(), message) }
    static func drain() async { for _ in 0..<20 { await Task.yield() } }
    static func decode(_ report: TestReport) throws -> ForegroundFeatureCapture {
        let decoder = JSONDecoder(); decoder.dateDecodingStrategy = .secondsSince1970
        let value = try decoder.decode(ForegroundFeatureCapture.self, from: report.diagnostics!)
        try value.validate()
        return value
    }
    static func main() async throws {
        let origin = Date(timeIntervalSince1970: 1000)
        var features = MotionFeatures()
        features.receive(x: 0, y: 0, z: 1, timestamp: 100, receipt: 100.1)
        features.receive(x: 0, y: 0, z: 3, timestamp: 110, receipt: 110.1)
        features.receive(x: 0, y: 0, z: 2, timestamp: 130, receipt: 130.1)
        var capture = ForegroundFeatureCapture(id: UUID(), startedAt: origin, startUptime: 100,
            originalBuild: "Synthetic 21", originalOS: "Synthetic")
        try capture.observe(features, samples: 3, date: origin.addingTimeInterval(31), uptime: 131)
        expect(capture.epochs.count == 1 && capture.partial == nil, "Only completed window persisted during collection")
        expect(capture.epochs[0].magnitudeMean == 2 && capture.epochs[0].magnitudeSD == 1 && capture.epochs[0].enmoMean == 1,
               "Known arithmetic preserved in feature payload")
        expect(capture.epochs[0].calculatedSeconds == 31 && capture.epochs[0].lastSampleSeconds == 10,
               "Calculation availability remains separate from measurement")
        expect(capture.status.contains("Completion not recorded"), "Persisted active snapshot makes no live collection claim")
        try capture.observe(features, samples: 3, date: origin.addingTimeInterval(32), uptime: 132, stopping: "Synthetic manual stop")
        expect(capture.partial?.count == 1 && capture.epochs.count == 1 && capture.stoppedAt != nil,
               "Stop retains final partial without declaring completion")
        let report = try capture.report()
        let checked = try decode(report)
        expect(checked.originalBuild == "Synthetic 21" && checked.partial?.count == 1, "Versioned round trip preserves origin and partial")
        let assessment = try SavedReportAssessment(report: report)
        expect(assessment.featureCapture?.id == capture.id && assessment.lines.contains { $0.contains("do not establish sleep") },
               "Saved report inspector validates and explains movement-only evidence")
        var legacy = TestReport(id: "foreground-legacy", kind: .foreground, createdAt: origin,
            title: "Synthetic legacy counts", status: "Stopped", metrics: [:])
        legacy.diagnostics = try TestReport.encodeDiagnostics(["count": 10])
        let legacyAssessment = try SavedReportAssessment(report: legacy)
        expect(legacyAssessment.featureCapture == nil, "Legacy foreground metadata is not decoded as feature rows")
        var mismatched = TestReport(id: "foreground-other", kind: .foreground, createdAt: origin,
            title: "Synthetic", status: "Synthetic", metrics: [:])
        mismatched.diagnostics = report.diagnostics
        do { _ = try SavedReportAssessment(report: mismatched); preconditionFailure("Mismatched identity accepted") }
        catch TestArchiveError.invalid { }
        var object = try JSONSerialization.jsonObject(with: report.diagnostics!) as! [String: Any]
        expect(object["x"] == nil && object["y"] == nil && object["z"] == nil && object["rawSamples"] == nil,
               "No raw vectors in saved format")
        object["schemaVersion"] = 999
        let decoder = JSONDecoder(); decoder.dateDecodingStrategy = .secondsSince1970
        let invalid = try decoder.decode(ForegroundFeatureCapture.self, from: JSONSerialization.data(withJSONObject: object))
        do { try invalid.validate(); preconditionFailure("Unknown schema accepted") } catch TestArchiveError.invalid { }

        var uncertain = ForegroundFeatureCapture(id: UUID(), startedAt: origin, startUptime: 100,
            originalBuild: "Synthetic", originalOS: "Synthetic")
        try uncertain.observe(features, samples: 3, date: origin.addingTimeInterval(-10), uptime: 131)
        expect(uncertain.clockUncertain, "Wall-clock change explicitly retained")
        expect(!uncertain.expired(at: 699.99) && uncertain.expired(at: 700) && uncertain.expired(at: 99),
               "Deadline boundaries and reboot clock reject further saved collection")
        var manyFeatures = MotionFeatures()
        var bounded = ForegroundFeatureCapture(id: UUID(), startedAt: origin, startUptime: 100,
            originalBuild: "Synthetic", originalOS: "Synthetic")
        for index in 0...20 {
            let time = 100 + Double(index) * 30
            manyFeatures.receive(x: 0, y: 0, z: 1, timestamp: time, receipt: time)
            try bounded.observe(manyFeatures, samples: index + 1, date: origin.addingTimeInterval(Double(index) * 30), uptime: time)
        }
        expect(bounded.epochs.count == 20, "Twenty completed-window ceiling")
        // The boundary sample at the deadline is outside a production saved run.
        do { try bounded.observe(manyFeatures, samples: 21, date: origin.addingTimeInterval(600), uptime: 700, stopping: "Limit")
            preconditionFailure("Out-of-duration partial accepted") } catch TestArchiveError.invalid { }

        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = TestArchiveStore(directory: directory, build: "Synthetic 21", os: "Synthetic")
        let clock = FeatureClock()
        let monitor = MotionMonitor(uptime: { clock.read() }, date: { origin.addingTimeInterval(clock.read() - 100) })
        let manager = CMMotionManager.latest!
        monitor.start(archive: store)
        expect(monitor.isMonitoring && manager.starts == 1 && store.reports.count == 1, "Initial save precedes sensor start")
        let identifier = monitor.featureCapture!.reportID
        let before = try Data(contentsOf: directory.appendingPathComponent(identifier + ".json"))
        let callback = manager.callback!
        callback(.init(acceleration: .init(x: 0, y: 0, z: 1), timestamp: 99), nil)
        await drain()
        expect(monitor.featureCapture?.preStartSamples == 1 && monitor.sampleCount == 0,
               "Cached pre-start measurements cannot enter saved windows")
        clock.set(100.11)
        callback(.init(acceleration: .init(x: 0, y: 0, z: 1), timestamp: 100.1), nil)
        await drain()
        let afterSample = try Data(contentsOf: directory.appendingPathComponent(identifier + ".json"))
        expect(afterSample == before, "No disk write on individual sample")
        clock.set(130.21)
        callback(.init(acceleration: .init(x: 0, y: 0, z: 2), timestamp: 130.2), nil)
        await drain()
        let completed = try decode(store.report(id: identifier))
        expect(completed.epochs.count == 1 && completed.stoppedAt == nil, "Actual callback saves a completed epoch")
        let fresh = TestArchiveStore(directory: directory)
        let recovered = try decode(fresh.report(id: identifier))
        expect(recovered.status.contains("Completion not recorded"), "Process restart cannot invent stop or tail")
        clock.set(131)
        monitor.stop(reason: "Synthetic stop")
        let stopped = try decode(store.report(id: identifier))
        expect(stopped.partial?.count == 1 && stopped.stopReason == "Synthetic stop", "Actual stop persists partial and reason")
        callback(.init(acceleration: .init(x: 0, y: 0, z: 3), timestamp: 131), nil)
        await drain()
        let afterLate = try decode(store.report(id: identifier))
        expect(afterLate.acceptedSamples == 2, "Late callback cannot change saved run")
        expect(store.deleteAll(), "Feature history can be deleted")
        expect(TestArchiveStore(directory: directory).reports.isEmpty, "Deleted feature history remains empty after reload")

        clock.set(200)
        monitor.start(archive: store)
        let limitedID = monitor.featureCapture!.reportID
        clock.set(800)
        manager.callback?(.init(acceleration: .init(x: 0, y: 0, z: 1), timestamp: 800), nil)
        await drain()
        expect(!monitor.isMonitoring && monitor.status.contains("limit"), "Deadline callback stops actual monitor")
        let afterLimit = try decode(store.report(id: limitedID))
        expect(afterLimit.acceptedSamples == 0, "Expired sample excluded")

        let full = TestArchiveStore(directory: directory.appendingPathComponent("full"), maximumReports: 0)
        clock.set(900)
        let starts = manager.starts
        monitor.start(archive: full)
        expect(!monitor.isMonitoring && manager.starts == starts, "Storage preflight prevents sensor start")
        store.reload()
        monitor.start(archive: store)
        let failedID = monitor.featureCapture!.reportID
        let oldFile = try Data(contentsOf: directory.appendingPathComponent(failedID + ".json"))
        try FileManager.default.setAttributes([.posixPermissions: 0o500], ofItemAtPath: directory.path)
        clock.set(900.11)
        manager.callback?(.init(acceleration: .init(x: 0, y: 0, z: 1), timestamp: 900.1), nil)
        await drain()
        clock.set(930.21)
        manager.callback?(.init(acceleration: .init(x: 0, y: 0, z: 1), timestamp: 930.2), nil)
        await drain()
        try FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: directory.path)
        expect(!monitor.isMonitoring && monitor.captureMessage.contains("failed"), "Unexpected save failure stops collection")
        let afterFailure = try Data(contentsOf: directory.appendingPathComponent(failedID + ".json"))
        expect(afterFailure == oldFile, "Write failure preserves last readable snapshot")
        store.reload()
        clock.set(1000)
        monitor.start(archive: store)
        let clockID = monitor.featureCapture!.reportID
        clock.set(999)
        manager.callback?(.init(acceleration: .init(x: 0, y: 0, z: 1), timestamp: 999), nil)
        await drain()
        let clockFailure = try decode(store.report(id: clockID))
        expect(!monitor.isMonitoring && monitor.status.contains("clock uncertain") && clockFailure.clockUncertain,
               "Clock failure stops collection and persists explicit uncertainty")
        expect(clockFailure.partial == nil && clockFailure.stopReason?.contains("partial not recorded") == true,
               "An uncertain clock cannot manufacture partial timing")
        let initialDirectory = directory.appendingPathComponent("initial-write")
        let initialFailure = TestArchiveStore(directory: initialDirectory)
        try FileManager.default.setAttributes([.posixPermissions: 0o500], ofItemAtPath: initialDirectory.path)
        clock.set(2000)
        let previousStarts = manager.starts
        monitor.start(archive: initialFailure)
        try FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: initialDirectory.path)
        expect(!monitor.isMonitoring && manager.starts == previousStarts && monitor.status.contains("initial save failed"),
               "Unexpected initial write failure prevents sensor collection")
        print("PASS: feature schema/arithmetic/availability, partials/bounds/clocks, persistence/relaunch/deletion, callback saves, deadlines and storage failure")
    }
}
