import Foundation

@main struct AlarmChecks {
    static func expect(_ condition: @autoclosure () -> Bool, _ message: String) { precondition(condition(), message) }
    @MainActor static func settle() async { try? await Task.sleep(for: .milliseconds(30)) }
    @MainActor static func main() async throws {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        expect(!AlarmTime.isValid(now, now: now), "Past/present dates rejected")
        expect(AlarmTime.isValid(now.addingTimeInterval(129_600), now: now), "36-hour boundary accepted")
        expect(!AlarmTime.isValid(now.addingTimeInterval(129_601), now: now), "Beyond 36 hours rejected")
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/Vancouver")!
        let formatter = ISO8601DateFormatter()
        let midnight = formatter.date(from: "2026-10-10T06:59:00Z")!
        let morning = AlarmTime.next(hour: 7, minute: 0, after: midnight, calendar: calendar)!
        expect(calendar.component(.day, from: morning) == 10, "Next morning crosses midnight")
        let spring = formatter.date(from: "2026-03-08T09:00:00Z")!
        let skipped = AlarmTime.next(hour: 2, minute: 30, after: spring, calendar: calendar)!
        expect(calendar.component(.hour, from: skipped) == 3 && calendar.component(.minute, from: skipped) == 30,
               "Nonexistent time resolves forward preserving minutes")
        let autumn = formatter.date(from: "2026-11-01T07:00:00Z")!
        expect(AlarmTime.next(hour: 1, minute: 30, after: autumn, calendar: calendar) == formatter.date(from: "2026-11-01T08:30:00Z"),
               "Repeated time resolves to first occurrence")
        expect(AlarmTime.next(hour: 24, minute: 0, after: now) == nil, "Invalid components rejected")
        let defaults = UserDefaults(suiteName: "Cumulus.AlarmChecks.\(UUID())")!
        let owner = ExperimentSessionOwner(defaults: defaults)
        let store = MemoryAlarmStore()
        let alarm = AlarmCoordinator(owner: owner, store: store, now: { now })
        let date = now.addingTimeInterval(180)
        WKApplication.shared().applicationState = .background
        alarm.schedule(at: date)
        expect(alarm.record == nil && owner.current == .none, "Inactive scheduling refused")
        WKApplication.shared().applicationState = .active
        alarm.schedule(at: now.addingTimeInterval(130_000))
        expect(alarm.record == nil, "Bad date creates no alarm")
        WKExtendedRuntimeSession.stateAfterStart = .notStarted
        alarm.schedule(at: date)
        let first = WKExtendedRuntimeSession.latest!
        expect(alarm.status == "Scheduling requested" && owner.current == .alarm, "Request is not scheduling evidence")
        alarm.schedule(at: date)
        expect(WKExtendedRuntimeSession.latest === first, "Duplicate prevented")
        first.state = .scheduled
        alarm.refreshState()
        expect(alarm.status == "Scheduled" && alarm.canCancel, "Observed scheduled state permits cancellation")
        let changed = date.addingTimeInterval(600)
        alarm.edit(to: changed)
        expect(first.invalidations == 1 && first.requestedDate == date, "Edit cancels old before replacement")
        alarm.refreshState()
        expect(WKExtendedRuntimeSession.latest === first, "No replacement before callback")
        WKExtendedRuntimeSession.stateAfterStart = .scheduled
        first.end(.none)
        await settle()
        let second = WKExtendedRuntimeSession.latest!
        expect(second !== first && second.requestedDate == changed, "Replacement starts only after confirmation")
        first.run()
        await settle()
        expect(first.haptics == 0 && alarm.record?.fireDate == changed, "Old start callback cannot alert or mutate replacement")
        second.run()
        await settle()
        alarm.refreshState()
        expect(second.haptics == 1 && alarm.status == "Haptic requested", "Haptic requested once while running")
        let recovered = AlarmCoordinator(owner: owner, store: store, now: { now })
        expect(recovered.isUnverified && !recovered.canSchedule && !recovered.canStop, "Saved pending request remains unverified")
        let delivered = WKExtendedRuntimeSession()
        delivered.state = .running
        recovered.attach(delivered)
        expect(delivered.haptics == 0 && recovered.canStop, "Known haptic request survives recovery without duplication")
        recovered.stop()
        delivered.end(.none)
        await settle()
        expect(recovered.status == "Stopped" && owner.current == .none, "Stop confirmed and ownership released")
        recovered.clearHistory()
        expect(store.value == nil && recovered.record == nil, "Completed alarm history clears independently")

        let failed = AlarmCoordinator(owner: owner, store: store, now: { now })
        failed.schedule(at: date)
        let third = WKExtendedRuntimeSession.latest!
        failed.edit(to: changed)
        third.end(.error, error: NSError(domain: "Synthetic", code: 1))
        await settle()
        expect(WKExtendedRuntimeSession.latest === third && !failed.hasReservation && failed.errorMessage != nil,
               "Invalidation error prevents replacement")
        failed.schedule(at: date)
        let fourth = WKExtendedRuntimeSession.latest!
        failed.edit(to: changed)
        WKExtendedRuntimeSession.stateAfterStart = .notStarted
        fourth.end(.none)
        await settle()
        let fifth = WKExtendedRuntimeSession.latest!
        fifth.end(.error, error: NSError(domain: "Synthetic", code: 2))
        await settle()
        expect(failed.status == "Needs attention" && failed.record?.phase == .failed, "Replacement scheduling error is not armed")
        WKExtendedRuntimeSession.stateAfterStart = .scheduled
        failed.schedule(at: date)
        let sixth = WKExtendedRuntimeSession.latest!
        failed.cancel()
        let pendingRecovery = AlarmCoordinator(owner: owner, store: store, now: { now })
        let pendingDelivered = WKExtendedRuntimeSession(); pendingDelivered.state = .scheduled
        pendingRecovery.attach(pendingDelivered)
        expect(pendingDelivered.invalidations == 1 && pendingDelivered.requestedDate == nil,
               "Recovery resumes requested cancellation without re-arming")
        pendingDelivered.end(.none)
        await settle()
        expect(pendingRecovery.status == "Cancelled", "Recovered cancellation confirms result")
        // Ignore the abandoned test instance; it represents the terminated process.
        expect(sixth.invalidations == 1, "Original cancellation issued once")
        pendingRecovery.schedule(at: date)
        pendingRecovery.edit(to: changed)
        let interruptedEdit = AlarmCoordinator(owner: owner, store: store, now: { now })
        expect(store.value?.replacementFireDate == changed && interruptedEdit.errorMessage != nil,
               "Pending replacement survives persistence and is reported on relaunch")
        let interruptedSession = WKExtendedRuntimeSession(); interruptedSession.state = .scheduled
        interruptedEdit.attach(interruptedSession)
        interruptedSession.end(.none)
        await settle()
        expect(WKExtendedRuntimeSession.latest === interruptedSession && interruptedEdit.canSchedule,
               "Interrupted edit does not automatically re-arm after recovery")
        expect(interruptedEdit.errorMessage?.contains("Replacement not set") == true,
               "Interrupted edit reports the lost replacement explicitly")
        expect(store.value?.replacementFireDate == nil, "Completed recovery clears pending replacement")
        interruptedEdit.schedule(at: date)
        let noDetails = WKExtendedRuntimeSession.latest!
        noDetails.end(.error)
        await settle()
        expect(interruptedEdit.record?.phase == .failed && interruptedEdit.errorMessage?.contains("no details") == true,
               "Platform error without details still has an actionable explanation")
        interruptedEdit.schedule(at: date)
        let staleState = WKExtendedRuntimeSession.latest!
        staleState.state = .invalid
        expect(!interruptedEdit.edit(to: changed) && staleState.invalidations == 0,
               "Stale UI actions cannot invalidate an already ended session")
        staleState.end(.none)
        await settle()
        interruptedEdit.schedule(at: date)
        let writeDuringCancel = WKExtendedRuntimeSession.latest!
        store.fails = true
        interruptedEdit.cancel()
        expect(writeDuringCancel.invalidations == 1, "Storage failure cannot prevent cancellation")
        store.fails = false
        writeDuringCancel.end(.none)
        await settle()
        expect(interruptedEdit.status == "Cancelled" && interruptedEdit.canSchedule, "Cancellation persists after storage recovers")
        store.fails = true
        let corrupt = AlarmCoordinator(owner: owner, store: store)
        expect(corrupt.hasReservation && corrupt.isUnverified, "Unreadable storage blocks scheduling")
        store.fails = false
        store.value = nil
        let writeFailure = AlarmCoordinator(owner: owner, store: store, now: { now })
        let lastSession = WKExtendedRuntimeSession.latest
        store.fails = true
        writeFailure.schedule(at: date)
        expect(WKExtendedRuntimeSession.latest === lastSession && owner.current == .none && writeFailure.errorMessage != nil,
               "Persistence failure before request never starts session")
        store.fails = false
        writeFailure.clearHistory()
        expect(writeFailure.canSchedule, "Known completed state can clear after storage failure")
        writeFailure.schedule(at: date)
        let expiring = WKExtendedRuntimeSession.latest!
        expiring.end(.expired)
        await settle()
        expect(writeFailure.status == "Ended" && owner.current == .none, "Expiry cleanup releases ownership")
        let freshStore = MemoryAlarmStore()
        let fresh = AlarmCoordinator(owner: owner, store: freshStore, now: { now })
        fresh.schedule(at: date)
        let pending = AlarmCoordinator(owner: owner, store: freshStore, now: { now })
        let running = WKExtendedRuntimeSession(); running.state = .running
        pending.attach(running)
        pending.refreshState()
        expect(running.haptics == 1, "Recovered running session without prior request alerts once")
        pending.stop(); running.end(.none)
        await settle()
        pending.schedule(at: date)
        let inactiveEdit = WKExtendedRuntimeSession.latest!
        pending.edit(to: changed)
        WKApplication.shared().applicationState = .background
        inactiveEdit.end(.none)
        await settle()
        expect(WKExtendedRuntimeSession.latest === inactiveEdit && pending.errorMessage?.contains("Replacement not set") == true,
               "Inactive replacement is refused after confirmed old cancellation")
        WKApplication.shared().applicationState = .active
        var movingClock = now
        let delayed = AlarmCoordinator(owner: owner, store: freshStore, now: { movingClock })
        delayed.schedule(at: date)
        let lateEdit = WKExtendedRuntimeSession.latest!
        delayed.edit(to: changed)
        movingClock = changed.addingTimeInterval(1)
        lateEdit.end(.none)
        await settle()
        expect(WKExtendedRuntimeSession.latest === lateEdit && delayed.errorMessage?.contains("Replacement not set") == true,
               "Expired replacement is refused rather than rolled to another day")
        let foreignDefaults = UserDefaults(suiteName: "Cumulus.ForeignAlarm.\(UUID())")!
        let foreignOwner = ExperimentSessionOwner(defaults: foreignDefaults)
        let foreign = AlarmCoordinator(owner: foreignOwner, store: MemoryAlarmStore())
        let foreignSession = WKExtendedRuntimeSession(); foreignSession.state = .running
        foreign.attach(foreignSession)
        foreign.refreshState()
        expect(foreignSession.haptics == 0 && foreignOwner.current == .unresolved && foreign.isUnverified,
               "Unknown configuration never fabricates an alarm or haptic")
        for index in 0..<100 { store.value?.record("Synthetic \(index)", at: now) }
        expect(store.value?.events.count == 40, "History bound")
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let fileStore = AlarmFileStore(url: directory.appendingPathComponent("alarm.json"))
        try fileStore.save(store.value!)
        let loaded = try fileStore.load()
        expect(loaded?.events.count == 40, "Atomic file round trip")
        var savedEdit = store.value!
        savedEdit.phase = .cancellationRequested
        savedEdit.replacementFireDate = changed
        try fileStore.save(savedEdit)
        let loadedEdit = try fileStore.load()
        expect(loadedEdit?.replacementFireDate == changed, "Pending replacement survives file round trip")
        var legacy = try JSONSerialization.jsonObject(with: Data(contentsOf: fileStore.url)) as! [String: Any]
        legacy.removeValue(forKey: "replacementFireDate")
        try JSONSerialization.data(withJSONObject: legacy).write(to: fileStore.url)
        let loadedLegacy = try fileStore.load()
        expect(loadedLegacy?.replacementFireDate == nil, "Older records without pending replacement remain readable")
        try Data("invalid".utf8).write(to: fileStore.url)
        do { _ = try fileStore.load(); preconditionFailure("Corrupt data accepted") } catch {}
        let unrelated = directory.appendingPathComponent("research-sentinel.txt")
        try Data("Preserve research data".utf8).write(to: unrelated)
        try fileStore.clear()
        let cleared = try fileStore.load()
        expect(cleared == nil && FileManager.default.fileExists(atPath: unrelated.path), "Deletion removes only alarm record")
        print("PASS: alarm bounds/DST, scheduling/edit/cancel/stop, recovery, late callbacks, expiry, storage and history")
    }
}
