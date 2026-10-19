import Foundation

@main @MainActor struct AlarmTrialChecks {
    static func expect(_ value: @autoclosure () -> Bool, _ message: String) { precondition(value(), message) }
    static func main() throws {
        let date = Date(timeIntervalSince1970: 1000)
        let origin = AlarmRecord.Origin(build: "Synthetic 23", os: "Synthetic", timeZone: "UTC")
        var alarm = AlarmRecord(id: UUID(), fireDate: date.addingTimeInterval(60), createdAt: date)
        alarm.origin = origin
        alarm.record("Schedule requested", at: date)
        var trial = try AlarmTrial(record: alarm, capturedAt: date)
        expect(trial.observations.feltHaptic == .unknown && trial.observations.kind == .unspecified,
            "Observations default Unknown; no automatic perception or pass")
        var observations = AlarmTrial.Observations()
        observations.kind = .overnight
        observations.feltHaptic = .yes
        observations.startBattery = .init(percent: 80, observedAt: date)
        observations.endBattery = .init(percent: 65, observedAt: date.addingTimeInterval(100))
        try trial.setObservations(observations, expectedRevision: nil, at: date.addingTimeInterval(101))
        alarm.phase = .hapticRequested
        alarm.record("Haptic requested (default repeat interval)", at: alarm.fireDate.addingTimeInterval(0.25))
        alarm.hapticRequestedAt = alarm.fireDate.addingTimeInterval(0.25)
        try trial.merge(alarm, capturedAt: date.addingTimeInterval(102))
        expect(trial.observations.feltHaptic == .yes && trial.hapticOffsets == [0.25], "Evidence merges without overwriting owner edits")
        let decoded = try AlarmTrial.decode(trial.report())
        expect(decoded.observations == observations && decoded.origin == origin, "Unix diagnostic round trip preserves source and reports")
        do { try trial.setObservations(.init(), expectedRevision: nil, at: date.addingTimeInterval(103))
            preconditionFailure("Stale draft accepted") } catch AlarmTrialError.conflict { }
        var wrong = alarm; wrong = AlarmRecord(id: UUID(), fireDate: alarm.fireDate, createdAt: date)
        do { try trial.merge(wrong, capturedAt: date)
            preconditionFailure("Different alarm merged") } catch AlarmTrialError.invalid { }
        var changedEvent = alarm
        changedEvent.events[0] = .init(id: alarm.events[0].id, alarmID: alarm.id, fireDate: alarm.fireDate,
            date: date, message: "Changed immutable event")
        do { try trial.merge(changedEvent, capturedAt: date)
            preconditionFailure("Conflicting immutable event accepted") } catch AlarmTrialError.invalid { }
        var mismatchedTarget = alarm
        mismatchedTarget.events = [.init(id: UUID(), alarmID: alarm.id, fireDate: date, date: date, message: "Wrong target")]
        do { _ = try AlarmTrial(record: mismatchedTarget, capturedAt: date)
            preconditionFailure("Mismatched target accepted") } catch AlarmTrialError.invalid { }
        var partial = alarm
        partial.events.removeFirst()
        let missing = try AlarmTrial(record: partial, capturedAt: date)
        expect(missing.historyDescription.contains("Partial"), "Missing schedule evidence is explicit")
        var bounded = try AlarmTrial(record: alarm, capturedAt: date)
        for index in 0..<45 {
            alarm.record("Synthetic event \(index)", at: date.addingTimeInterval(Double(index + 103)))
            try bounded.merge(alarm, capturedAt: date.addingTimeInterval(Double(index + 104)))
        }
        expect(bounded.events.count == 40 && bounded.historyTruncated, "Per-alarm history is bounded and loss explicit")
        let legacy = AlarmRecord(id: UUID(), fireDate: date.addingTimeInterval(60), createdAt: date)
        let legacyData = try JSONEncoder().encode(legacy)
        let legacyDecoded = try JSONDecoder().decode(AlarmRecord.self, from: legacyData)
        expect(legacyDecoded.origin == nil, "Old alarm metadata is not invented")
        let fractional = Date(timeIntervalSinceReferenceDate: 811_000_000.1234567)
        var precise = AlarmRecord(id: UUID(), fireDate: fractional.addingTimeInterval(60), createdAt: fractional)
        precise.record("Schedule requested", at: fractional)
        var preciseTrial = try AlarmTrial.decode(AlarmTrial(record: precise, capturedAt: fractional).report())
        precise.record("Scheduled state observed", at: fractional.addingTimeInterval(0.0123456))
        try preciseTrial.merge(precise, capturedAt: fractional.addingTimeInterval(1))
        expect(preciseTrial.events.count == 2, "Foundation alarm dates and Unix report dates merge without false event conflicts")
        var edit = legacy
        edit.phase = .cancellationRequested
        edit.replacementFireDate = date.addingTimeInterval(120)
        edit.record("Cancellation requested before replacement", at: date.addingTimeInterval(1))
        var editedTrial = try AlarmTrial(record: edit, capturedAt: date.addingTimeInterval(2))
        edit.phase = .cancelled
        edit.replacementFireDate = nil
        edit.record("Session invalidated (reason 0)", at: date.addingTimeInterval(3))
        try editedTrial.merge(edit, capturedAt: date.addingTimeInterval(4))
        expect(editedTrial.requestedReplacementDate == date.addingTimeInterval(120), "Confirmed cancellation preserves requested replacement evidence")
        var replacement = AlarmRecord(id: UUID(), fireDate: date.addingTimeInterval(120), createdAt: date)
        replacement.replacesAlarmID = edit.id
        let replacementTrial = try AlarmTrial(record: replacement, capturedAt: date)
        expect(replacementTrial.replacesAlarmID == edit.id, "Replacement report retains prior configuration identity")

        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let archive = TestArchiveStore(directory: directory, build: "Capturing build", os: "Capturing OS")
        let store = AlarmTrialStore(archive: archive, now: { date.addingTimeInterval(200) })
        expect(store.capture(alarm), "Actual archive snapshot saved")
        let saved = try store.load(alarm.id)
        expect(saved.origin == origin && archive.reports.first?.captureBuild == "Capturing build", "Original and capture versions remain distinct")
        expect(store.saveObservations(observations, for: alarm.id, expectedRevision: nil), "Owner observations save")
        let beforeRevision = try store.load(alarm.id).observationsRevision
        alarm.phase = .ended
        alarm.record("Session invalidated (reason 0)", at: date.addingTimeInterval(201))
        expect(store.capture(alarm), "New lifecycle preserves draft revision")
        expect(store.saveObservations(observations, for: alarm.id, expectedRevision: beforeRevision), "Software refresh does not invalidate owner draft")
        expect(!store.saveObservations(.init(), for: alarm.id, expectedRevision: beforeRevision),
            "A reused owner revision is stale even when both saves use the same wall-clock date")
        expect(!store.saveObservations(.init(), for: alarm.id, expectedRevision: nil), "Stale owner draft rejected at storage boundary")
        let reloaded = AlarmTrialStore(archive: TestArchiveStore(directory: directory))
        let reloadedTrial = try reloaded.load(alarm.id)
        expect(reloadedTrial.observations.feltHaptic == .yes && reloadedTrial.phase == .ended, "Persistence survives reload")
        let currentRevision = try store.load(alarm.id).observationsRevision
        let file = directory.appendingPathComponent(saved.reportID + ".json")
        let oldBytes = try Data(contentsOf: file)
        var invalid = observations; invalid.endBattery = .init(percent: 101, observedAt: date)
        expect(!store.saveObservations(invalid, for: alarm.id, expectedRevision: currentRevision), "Bad battery range rejected")
        invalid = observations; invalid.endBattery = .init(percent: 50, observedAt: date.addingTimeInterval(-1))
        expect(!store.saveObservations(invalid, for: alarm.id, expectedRevision: currentRevision), "Reversed battery observations rejected")
        invalid = observations; invalid.settingsNote = String(repeating: "x", count: 201)
        expect(!store.saveObservations(invalid, for: alarm.id, expectedRevision: currentRevision), "Owner note bounded")
        try FileManager.default.setAttributes([.posixPermissions: 0o500], ofItemAtPath: directory.path)
        let failedSave = store.saveObservations(observations, for: alarm.id, expectedRevision: currentRevision)
        try FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: directory.path)
        expect(!failedSave, "Actual write failure surfaced")
        let preserved = try Data(contentsOf: file)
        expect(preserved == oldBytes, "Invalid input and write failure preserve previous report bytes")
        archive.reload()
        expect(archive.deleteAll(), "Completed archive can be cleared")
        expect(store.capture(alarm, importing: true) && archive.reports.isEmpty, "Startup import honors deletion marker")
        expect(store.capture(alarm), "Explicit save may restore selected historical evidence")
        expect(archive.reports.count == 1, "No unrelated report evicted or invented")
        let fullArchive = TestArchiveStore(directory: directory.appendingPathComponent("full"), maximumReports: 0)
        let fullStore = AlarmTrialStore(archive: fullArchive)
        expect(!fullStore.capture(alarm) && fullStore.errorMessage != nil, "Capacity failure is explicit")
        print("PASS: alarm trial identity/provenance, Unknown observations, event merge/bounds, draft conflicts, Unix encoding, archive/reload/deletion and storage failure")
    }
}
