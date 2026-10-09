import Foundation

@main struct OvernightChecks {
    static let origin = Date(timeIntervalSince1970: 1_000_000)
    static func expect(_ condition: @autoclosure () -> Bool, _ message: String) { precondition(condition(), message) }
    static func uniform(duration: Double = 1200) -> OvernightMotionSummary {
        var summary = OvernightMotionSummary(start: origin, end: origin.addingTimeInterval(duration))
        for index in 0..<Int(duration * 50) {
            summary.receive(date: origin.addingTimeInterval(Double(index) / 50), uptime: 1000 + Double(index) / 50,
                            axesFinite: true, chunkStart: origin)
        }
        return summary
    }
    static func read(_ recorder: OvernightMotionRecorder, duration: Double = 1200,
                     cancellation: OvernightRetrievalCancellation = .init()) async -> OvernightRetrievalResult {
        await withCheckedContinuation { continuation in
            recorder.retrieve(start: origin, end: origin.addingTimeInterval(duration), cancellation: cancellation,
                              progress: { _, _ in }, completion: { continuation.resume(returning: $0) })
        }
    }
    @MainActor static func settle(_ coordinator: OvernightMotionCoordinator) async {
        for _ in 0..<200 {
            if !coordinator.isRetrieving { return }
            try? await Task.sleep(for: .milliseconds(10))
        }
        fatalError("Retrieval did not finish")
    }
    static func invalid(_ archive: OvernightMotionArchive, _ message: String) {
        do { try archive.validate(); fatalError(message) } catch {}
    }
    static func invalid(_ summary: OvernightMotionSummary, _ message: String) throws {
        do { try summary.validate(); fatalError(message) } catch OvernightArchiveError.invalid {}
    }

    @MainActor static func main() async throws {
        var guided = OvernightMotionTrial(mode: .pilot, start: origin, uptime: 1000, configuration: .init(), battery: nil)
        guided.phase = .requested
        expect(PilotGuide(trial: guided, now: origin.addingTimeInterval(599)).target == origin.addingTimeInterval(600), "Guide uses original fixed block")
        expect(PilotGuide(trial: guided, now: origin.addingTimeInterval(600)).title == "Read the pilot block now", "Probe opens at ten minutes")
        expect(PilotGuide(trial: guided, now: origin.addingTimeInterval(841)).instruction.contains("not established"), "Missing timely probe remains unknown")
        expect(PilotGuide(trial: guided, now: origin.addingTimeInterval(1500)).title == "Retrieve the whole window", "Full retrieval target at end plus five")
        expect(PilotGuide(trial: guided, now: origin.addingTimeInterval(841)).target == origin.addingTimeInterval(960), "Late diagnostic probe at minute sixteen")
        guided.observations = [.init(pilotProbe: true, requestedAt: origin.addingTimeInterval(960), completedAt: origin.addingTimeInterval(961),
                                    count: 0, useful: false, first: nil, last: nil, nilChunks: 0, emptyChunks: 1, cancelled: false, error: nil)]
        expect(PilotGuide(trial: guided, now: origin.addingTimeInterval(970)).target == origin.addingTimeInterval(1200), "Next late probe at minute twenty")
        guided.clockDiscontinuity = true
        expect(PilotGuide(trial: guided, now: origin).target == nil, "Clock uncertainty removes countdown")
        let good = uniform()
        try good.validate()
        expect(good.count == 60_000 && good.buckets.count == 40 && good.buckets.allSatisfy { $0.count == 1500 }, "Exact bucket boundaries at 50 Hz")
        expect(good.meetsTimingCriteria, "Uniform pilot passes timing criteria")
        expect(good.timingFailures.isEmpty, "Passing data has no failed criteria")
        var lateStart = OvernightMotionSummary(start: origin, end: origin.addingTimeInterval(1200))
        for index in 271..<60_000 {
            lateStart.receive(date: origin.addingTimeInterval(Double(index) / 50), uptime: 1000 + Double(index) / 50,
                              axesFinite: true, chunkStart: origin)
        }
        expect(!lateStart.meetsTimingCriteria && lateStart.timingFailures == ["Leading gap exceeds 5 s"],
               "A 5.42-second leading gap fails only its original threshold and is explained")
        var anomalies = OvernightMotionSummary(start: origin, end: origin.addingTimeInterval(60))
        anomalies.receive(date: origin.addingTimeInterval(29), uptime: 29, axesFinite: true, chunkStart: origin)
        anomalies.receive(date: origin.addingTimeInterval(32), uptime: 32, axesFinite: true, chunkStart: origin)
        expect(anomalies.maximumGap == 3 && anomalies.buckets[1].maximumGap == 3, "Cross-bucket gaps remain visible")
        anomalies.receive(date: origin.addingTimeInterval(32), uptime: 32, axesFinite: true, chunkStart: origin.addingTimeInterval(32))
        expect(anomalies.boundaryDuplicates == 1 && anomalies.count == 2, "Only identified boundary overlap is deduplicated")
        anomalies.receive(date: origin.addingTimeInterval(32), uptime: 32, axesFinite: true, chunkStart: origin)
        expect(anomalies.outOfOrder == 1 && anomalies.buckets[1].outOfOrder == 1, "Unexpected duplicate is an anomaly")
        anomalies.receive(date: origin.addingTimeInterval(60), uptime: 60, axesFinite: true, chunkStart: origin)
        anomalies.receive(date: origin.addingTimeInterval(33), uptime: .nan, axesFinite: true, chunkStart: origin)
        anomalies.receive(date: origin.addingTimeInterval(34), uptime: 34, axesFinite: false, chunkStart: origin)
        expect(anomalies.outsideWindow == 1 && anomalies.invalid == 2, "Half-open window and invalid inputs")
        anomalies.receive(date: origin.addingTimeInterval(35), uptime: 40, axesFinite: true, chunkStart: origin)
        expect(anomalies.clockDiscontinuity && !anomalies.meetsTimingCriteria, "Uptime/wall-clock mismatch fails timing")
        expect(OvernightMotionSummary(start: origin, end: origin.addingTimeInterval(-10)).buckets.isEmpty, "Invalid window cannot allocate a negative range")
        expect(OvernightMotionSummary(start: origin, end: origin.addingTimeInterval(28800)).buckets.count == 960, "Eight-hour bucket bound")

        var orderTypes = OvernightMotionSummary(start: origin, end: origin.addingTimeInterval(60))
        let acceptedDate = origin.addingTimeInterval(10)
        orderTypes.receive(date: acceptedDate, uptime: 1010, axesFinite: true, chunkStart: origin)
        orderTypes.receive(date: acceptedDate, uptime: 1010, axesFinite: true, chunkStart: acceptedDate)
        expect(orderTypes.boundaryDuplicates == 1 && orderTypes.orderAnomalyCounts?.total == 0,
               "Expected chunk overlap is excluded from the anomaly breakdown")
        orderTypes.receive(date: acceptedDate, uptime: 1010, axesFinite: true, chunkStart: origin)
        orderTypes.receive(date: origin.addingTimeInterval(9), uptime: 1011, axesFinite: true, chunkStart: origin)
        orderTypes.receive(date: origin.addingTimeInterval(11), uptime: 1009, axesFinite: true, chunkStart: origin)
        orderTypes.receive(date: origin.addingTimeInterval(9), uptime: 1009, axesFinite: true, chunkStart: origin)
        let orderCounts = orderTypes.orderAnomalyCounts!
        expect(orderCounts.exactTimeRepeats == 1 && orderCounts.dateOnly == 1
            && orderCounts.sensorTimeOnly == 1 && orderCounts.bothTimes == 1,
               "Order counters distinguish repeated time pairs and each nonincreasing time field")
        expect(orderTypes.count == 1 && orderTypes.outOfOrder == 4 && orderTypes.buckets[0].outOfOrder == 4
            && orderCounts.total == orderTypes.outOfOrder && orderTypes.last == acceptedDate && orderTypes.lastUptime == 1010,
               "Rejected samples retain the existing total and last accepted timestamps")
        try orderTypes.validate()
        let encodedOrder = try JSONEncoder().encode(orderTypes)
        let decodedOrder = try JSONDecoder().decode(OvernightMotionSummary.self, from: encodedOrder)
        try decodedOrder.validate()
        expect(decodedOrder.orderAnomalyCounts?.exactTimeRepeats == 1 && decodedOrder.orderAnomalyCounts?.total == 4,
               "New order counters survive persistence")
        var legacyOrderJSON = try JSONSerialization.jsonObject(with: encodedOrder) as! [String: Any]
        legacyOrderJSON.removeValue(forKey: "orderAnomalyCounts")
        legacyOrderJSON.removeValue(forKey: "orderDiagnostics")
        let legacyOrder = try JSONDecoder().decode(OvernightMotionSummary.self,
            from: JSONSerialization.data(withJSONObject: legacyOrderJSON))
        try legacyOrder.validate()
        expect(legacyOrder.orderAnomalyCounts == nil && legacyOrder.orderDiagnostics == nil && legacyOrder.outOfOrder == 4
            && !legacyOrder.meetsTimingCriteria && legacyOrder.timingFailures.contains("Sample order anomalies"),
               "Older summaries preserve their failure without inventing a breakdown")
        var invalidCounts = orderTypes
        invalidCounts.orderAnomalyCounts!.dateOnly = -1
        try invalid(invalidCounts, "Negative order subtype accepted")
        invalidCounts = orderTypes
        invalidCounts.orderAnomalyCounts!.dateOnly = 2
        try invalid(invalidCounts, "Order breakdown different from its recorded total accepted")
        invalidCounts = orderTypes
        invalidCounts.orderAnomalyCounts!.dateOnly = Int.max
        try invalid(invalidCounts, "Unbounded order subtype accepted")

        var detailed = OvernightMotionSummary(start: origin, end: origin.addingTimeInterval(1200))
        detailed.receive(date: origin.addingTimeInterval(10), uptime: 1010, axesFinite: true, chunkStart: origin)
        detailed.receive(date: origin.addingTimeInterval(10), uptime: 1010.02, axesFinite: true, chunkStart: origin,
            position: .init(queryIndex: 1, sampleIndex: 2, previousAcceptedQueryIndex: 1))
        detailed.receive(date: origin.addingTimeInterval(9.98), uptime: 1010.04, axesFinite: true, chunkStart: origin,
            position: .init(queryIndex: 1, sampleIndex: 3, previousAcceptedQueryIndex: 1))
        detailed.receive(date: origin.addingTimeInterval(11), uptime: 1010, axesFinite: true, chunkStart: origin)
        detailed.receive(date: origin.addingTimeInterval(12), uptime: 1009, axesFinite: true, chunkStart: origin.addingTimeInterval(600),
            position: .init(queryIndex: 2, sampleIndex: 1, previousAcceptedQueryIndex: 1))
        let detail = detailed.orderDiagnostics!
        expect(detail.repeatedDates == 1 && detail.backwardDates == 1 && detail.repeatedSensorTimes == 1
            && detail.backwardSensorTimes == 1 && detail.withinQuery == 2 && detail.acrossQueries == 1
            && detail.unknownPosition == 1, "Repeats, reversals and query comparisons remain distinct")
        expect(detail.examples[0].dateDelta == 0 && abs(detail.examples[1].dateDelta + 0.02) < 0.000001
            && abs(detail.examples[1].sensorDelta - 0.04) < 0.000001,
            "Rejected rows compare with the last accepted sample, not the previous rejected row")
        expect(detailed.count == 1 && detailed.outOfOrder == 4 && detailed.last == origin.addingTimeInterval(10),
            "Diagnostics do not change acceptance or advance accepted time")
        try detailed.validate()
        let detailRoundTrip = try JSONDecoder().decode(OvernightMotionSummary.self, from: JSONEncoder().encode(detailed))
        try detailRoundTrip.validate()
        expect(detailRoundTrip.orderDiagnostics?.examples[3].position?.sampleIndex == 1, "Query examples survive persistence")
        var previousBuildJSON = try JSONSerialization.jsonObject(with: JSONEncoder().encode(detailed)) as! [String: Any]
        previousBuildJSON.removeValue(forKey: "orderDiagnostics")
        let previousBuildSummary = try JSONDecoder().decode(OvernightMotionSummary.self,
            from: JSONSerialization.data(withJSONObject: previousBuildJSON))
        try previousBuildSummary.validate()
        expect(previousBuildSummary.orderDiagnostics == nil && previousBuildSummary.orderAnomalyCounts?.dateOnly == 2,
            "Build-6 summaries retain counters without invented timing differences")
        for _ in 0..<100 {
            detailed.receive(date: origin.addingTimeInterval(10), uptime: 1010.02, axesFinite: true, chunkStart: origin)
        }
        try detailed.validate()
        expect(detailed.orderDiagnostics?.examples.count == 12 && detailed.orderDiagnostics?.total == 104
            && detailed.orderDiagnostics?.repeatedDates == 101, "Example cap preserves totals beyond truncation")
        var badDetail = detailed
        badDetail.orderDiagnostics!.examples.append(detail.examples[0])
        try invalid(badDetail, "Too many examples accepted")
        badDetail = detailed
        badDetail.orderDiagnostics!.backwardDates = -1
        try invalid(badDetail, "Negative diagnostic count accepted")
        badDetail = detailed
        badDetail.orderDiagnostics!.examples[0] = .init(relativeSeconds: 10, dateDelta: .nan, sensorDelta: 0.02, position: nil)
        try invalid(badDetail, "Nonfinite diagnostic delta accepted")
        badDetail = detailed
        badDetail.orderDiagnostics!.examples[0] = .init(relativeSeconds: 10, dateDelta: 0, sensorDelta: 0.02,
            position: .init(queryIndex: 3, sampleIndex: 2, previousAcceptedQueryIndex: 1))
        try invalid(badDetail, "Query outside retrieval window accepted")

        let recorder = OvernightMotionRecorder()
        SyntheticRecorder.shared.configure()
        let result = await read(recorder)
        expect(result.summary.count == 60_000 && result.summary.boundaryDuplicates == 1 && result.summary.meetsTimingCriteria, "Actual worker deduplicates inclusive chunk boundaries")
        expect(SyntheticRecorder.shared.queryCount == 2 && SyntheticRecorder.shared.maximumQuery <= 600, "Ten-minute queries")
        expect(result.summary.orderDiagnostics?.total == 0, "Expected inclusive-boundary overlap stays out of diagnostic failures")
        SyntheticRecorder.shared.configure(output: .startExclusive)
        let startExclusive = await read(recorder)
        expect(startExclusive.summary.count == 59_999 && startExclusive.summary.boundaryDuplicates == 0
            && startExclusive.summary.meetsTimingCriteria, "Open-start SDK endpoint interpretation preserves timing criteria")
        SyntheticRecorder.shared.configure(output: .dateAnomalies)
        let dateFailures = await read(recorder)
        try dateFailures.summary.validate()
        expect(dateFailures.summary.orderDiagnostics?.repeatedDates == 2 && dateFailures.summary.orderDiagnostics?.backwardDates == 2
            && dateFailures.summary.orderDiagnostics?.withinQuery == 4 && dateFailures.summary.orderDiagnostics?.acrossQueries == 0,
            "Actual worker supplies positions for within-query date-only failures")
        expect(dateFailures.summary.orderDiagnostics?.examples[0].position?.sampleIndex == 21
            && dateFailures.summary.orderDiagnostics?.examples[2].position?.queryIndex == 2,
            "Worker records one-based typed sample rows in each query")
        SyntheticRecorder.shared.configure(output: .transitionAnomaly)
        let transition = await read(recorder)
        try transition.summary.validate()
        expect(transition.summary.orderDiagnostics?.acrossQueries == 1
            && transition.summary.orderDiagnostics?.examples[0].position?.sampleIndex == 1,
            "First row comparing with an earlier query is distinguishable from within-query failure")
        SyntheticRecorder.shared.configure()
        let fullNight = await read(recorder, duration: 28800)
        try fullNight.summary.validate()
        expect(fullNight.summary.count == 1_440_000 && fullNight.summary.buckets.count == 960
            && fullNight.summary.boundaryDuplicates == 47 && fullNight.summary.meetsTimingCriteria,
            "Eight-hour stream stays bounded and keeps cross-chunk timing")
        var largeSummary = fullNight.summary
        for row in 1...20 {
            largeSummary.receive(date: largeSummary.last!, uptime: largeSummary.lastUptime! + 0.02,
                axesFinite: true, chunkStart: origin.addingTimeInterval(28200),
                position: .init(queryIndex: 48, sampleIndex: 30000 + row, previousAcceptedQueryIndex: 48))
        }
        try largeSummary.validate()
        var largeTrial = OvernightMotionTrial(mode: .overnight, start: origin, uptime: 1000, configuration: .init(), battery: nil)
        largeTrial.phase = .elapsed
        largeTrial.requestCount = 1
        largeTrial.fullSummary = largeSummary
        var largeRead = OvernightMotionTrial.Observation(pilotProbe: false, requestedAt: largeTrial.end,
            completedAt: largeTrial.end, count: largeSummary.count, useful: false,
            first: largeSummary.first, last: largeSummary.last, nilChunks: 0, emptyChunks: 0, cancelled: false, error: nil)
        largeRead.orderDiagnostics = largeSummary.orderDiagnostics
        largeTrial.observations = Array(repeating: largeRead, count: 40)
        try OvernightMotionArchive(trials: [largeTrial]).validate()
        let largePayload = try TestReport.encodeDiagnostics(largeTrial)
        expect(largePayload.count <= 350_000, "960 buckets and 40 reads with capped examples fit the existing archive payload limit")
        let largeDecoder = JSONDecoder()
        largeDecoder.dateDecodingStrategy = .secondsSince1970
        let restoredLargeTrial = try largeDecoder.decode(OvernightMotionTrial.self, from: largePayload)
        try OvernightMotionArchive(trials: [restoredLargeTrial]).validate()
        expect(restoredLargeTrial.observations.last?.orderDiagnostics?.total == 20, "Per-read examples survive archived payload decoding")
        SyntheticRecorder.shared.configure(output: .missing)
        let missing = await read(recorder)
        expect(missing.summary.nilChunks == 2 && missing.error == nil, "Nil results do not invent API errors")
        SyntheticRecorder.shared.configure(output: .empty)
        let empty = await read(recorder)
        expect(empty.summary.emptyChunks == 2 && empty.summary.nilChunks == 0, "Empty differs from nil")
        SyntheticRecorder.shared.configure(output: .unexpected)
        let unexpected = await read(recorder)
        expect(unexpected.summary.unexpectedObjects == 2, "Unexpected objects retained as diagnostics")
        SyntheticRecorder.shared.configure(output: .excessive)
        let excessive = await read(recorder, duration: 60)
        expect(excessive.summary.aborted && excessive.error != nil && excessive.summary.count <= 7000, "Bound enumeration work")
        let flag = OvernightRetrievalCancellation()
        flag.cancel()
        let cancelled = await read(recorder, cancellation: flag)
        expect(cancelled.cancelled, "Cancellation before retrieval")
        let invalidWindow = await read(recorder, duration: .nan)
        expect(invalidWindow.error != nil, "Invalid retrieval window reported explicitly")

        var trial = OvernightMotionTrial(mode: .pilot, start: origin, uptime: 1000, configuration: .init(), battery: 0.8)
        trial.phase = .elapsed
        trial.requestCount = 1
        trial.fullSummary = good
        trial.firstUsefulProbeAt = origin.addingTimeInterval(840)
        trial.latestProbe = .init(pilotProbe: true, requestedAt: origin.addingTimeInterval(839),
            completedAt: origin.addingTimeInterval(840), count: 3000, useful: true,
            first: origin.addingTimeInterval(540), last: origin.addingTimeInterval(599.98),
            nilChunks: 0, emptyChunks: 0, cancelled: false, error: nil)
        expect(trial.pilotQualified, "Pilot visibility threshold is inclusive")
        trial.firstUsefulProbeAt = origin.addingTimeInterval(840.01)
        expect(!trial.pilotQualified, "Late pilot cannot unlock overnight")
        trial.firstUsefulProbeAt = origin.addingTimeInterval(700)
        var archive = OvernightMotionArchive()
        archive.append(trial)
        archive.updatePilotEvidence()
        var invalidatedPilot = archive
        invalidatedPilot.trials[0].clockDiscontinuity = true
        invalidatedPilot.updatePilotEvidence()
        expect(invalidatedPilot.pilotEvidence == nil && invalidatedPilot.trials[0].morningVisibility.contains("inconclusive"), "Uncertainty in the trial's recording/retrieval evidence invalidates its pass")
        var missingProbe = trial
        missingProbe.latestProbe = nil
        expect(!missingProbe.pilotQualified, "A first-success date without its latest probe cannot qualify a pilot")
        var contradictedPilot = OvernightMotionArchive(trials: [trial])
        contradictedPilot.updatePilotEvidence()
        contradictedPilot.trials[0].latestProbe = .init(pilotProbe: true, requestedAt: origin.addingTimeInterval(900),
            completedAt: origin.addingTimeInterval(901), count: 0, useful: false,
            first: nil, last: nil, nilChunks: 1, emptyChunks: 0, cancelled: false, error: nil)
        contradictedPilot.updatePilotEvidence()
        expect(!contradictedPilot.trials[0].pilotQualified && contradictedPilot.pilotEvidence == nil,
            "A newer incomplete probe revokes qualification despite an earlier timely success")
        expect(contradictedPilot.trials[0].firstUsefulProbeAt == trial.firstUsefulProbeAt
            && contradictedPilot.trials[0].fullSummary?.count == good.count,
            "Revoking qualification retains the earlier visibility date and full summary")
        for _ in 0..<4 {
            var finished = OvernightMotionTrial(mode: .comparison, start: origin, uptime: 1000, configuration: .init(), battery: nil)
            finished.phase = .elapsed
            for n in 0..<45 { finished.record("Event \(n)") }
            expect(finished.events.count == 40 && finished.eventsTruncated, "Forty-event bound")
            archive.append(finished)
        }
        try archive.validate()
        expect(archive.trials.count == 3 && archive.pilotEvidence != nil, "Three-trial bound preserves compact pilot evidence")
        var malformed = archive
        malformed.trials[0].requestCount = 2
        invalid(malformed, "Overlapping request count accepted")
        malformed = archive
        malformed.trials[0].fullSummary = good
        malformed.trials[0].fullSummary!.buckets[0].count = Int.max
        invalid(malformed, "Unbounded count accepted")
        malformed = archive
        malformed.trials[0].configuration.watchModel = String(repeating: "x", count: 129)
        invalid(malformed, "Unbounded settings accepted")
        try JSONDecoder().decode(OvernightMotionArchive.self, from: JSONEncoder().encode(archive)).validate()

        let suite = "Cumulus.overnight.synthetic.\(UUID())"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let owner = ExperimentSessionOwner(defaults: defaults)
        SyntheticRecorder.shared.configure(authorization: .notDetermined)
        let reportDirectory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer {
            try? FileManager.default.removeItem(at: reportDirectory)
            try? FileManager.default.removeItem(at: reportDirectory.appendingPathExtension("deleted-through"))
        }
        let testArchive = TestArchiveStore(directory: reportDirectory)
        let coordinator = OvernightMotionCoordinator(owner: owner, defaults: defaults, testArchive: testArchive)
        coordinator.requestAccess()
        try? await Task.sleep(for: .milliseconds(20))
        expect(!coordinator.access.canRecord, "Activity callback is not recorder authorization")
        coordinator.start(.pilot, configuration: .init())
        expect(SyntheticRecorder.shared.recordCount == 0, "No unauthorized request")
        for permission in [CMAuthorizationStatus.denied, .restricted] {
            SyntheticRecorder.shared.configure(authorization: permission)
            coordinator.start(.pilot, configuration: .init())
            expect(SyntheticRecorder.shared.recordCount == 0 && coordinator.latest == nil, "Denied or restricted cannot start")
        }
        SyntheticRecorder.shared.configure(available: false)
        coordinator.start(.pilot, configuration: .init())
        expect(SyntheticRecorder.shared.recordCount == 0 && coordinator.latest == nil, "Unavailable recorder cannot start")
        SyntheticRecorder.shared.configure()
        WKApplication.shared().applicationState = .background
        coordinator.start(.pilot, configuration: .init())
        expect(coordinator.latest == nil, "Active app required")
        WKApplication.shared().applicationState = .active
        coordinator.start(.overnight, configuration: .init())
        expect(coordinator.latest == nil, "Overnight requires qualified pilot")
        WKInterfaceDevice.current().batteryReadDelay = 0.1
        SyntheticRecorder.shared.configure(recordDelay: 0.1)
        coordinator.start(.pilot, configuration: .init())
        WKInterfaceDevice.current().batteryReadDelay = 0
        expect(coordinator.latest?.requestCount == 1 && owner.current == .overnightMotion, "One fixed request reserves shared ownership")
        let timed = coordinator.latest!
        let call = timed.recorderCall!
        let apiEntry = SyntheticRecorder.shared.firstRecordDate!
        expect(timed.start.timeIntervalSince(call.preparedAt) >= 0.09 && apiEntry >= timed.start
            && apiEntry.timeIntervalSince(timed.start) < 0.1, "Slow preparation is excluded from the recorder-call window")
        var firstSample = OvernightMotionSummary(start: timed.start, end: timed.end)
        firstSample.receive(date: apiEntry.addingTimeInterval(0.02), uptime: timed.startUptime + 0.02,
                            axesFinite: true, chunkStart: timed.start)
        expect(firstSample.leadingGap! < 0.1, "Leading gap measures the sample against API entry, not battery preparation")
        expect(timed.reservationEnd > timed.end && call.returnedUptime - timed.startUptime >= 0.09,
               "A slow recorder call extends the reservation beyond the sample window")
        coordinator.refreshClock(now: timed.end, uptime: timed.startUptime + 1200)
        expect(coordinator.hasReservation && owner.current == .overnightMotion, "Ownership cannot end before API return plus duration")
        let expirySuite = suite + ".expiry"
        let expiryDefaults = UserDefaults(suiteName: expirySuite)!
        defer { expiryDefaults.removePersistentDomain(forName: expirySuite) }
        expiryDefaults.set(try JSONEncoder().encode(OvernightMotionArchive(trials: [timed])), forKey: "overnightMotion.v1")
        let expiryOwner = ExperimentSessionOwner(defaults: expiryDefaults)
        expect(expiryOwner.claim(.overnightMotion), "Synthetic pending reservation is owned")
        let expiry = OvernightMotionCoordinator(owner: expiryOwner, defaults: expiryDefaults)
        expiry.refreshClock(now: timed.reservationEnd.addingTimeInterval(1), uptime: timed.reservationEndUptime + 1)
        expect(expiry.latest?.phase == .elapsed && expiryOwner.current == .none,
               "Ownership is released after the full conservative reservation")
        expect(!coordinator.canRetrieve(pilotProbe: true, now: timed.start.addingTimeInterval(599.99))
            && coordinator.canRetrieve(pilotProbe: true, now: timed.start.addingTimeInterval(600)),
            "Time-driven pilot controls use the supplied display date at minute ten")
        coordinator.start(.pilot, configuration: .init())
        expect(SyntheticRecorder.shared.recordCount == 1 && !owner.claim(.alert), "No overlap with other experiments")
        let savedStart = coordinator.latest!.start
        let recovered = OvernightMotionCoordinator(owner: owner, defaults: defaults)
        expect(recovered.latest?.start == savedStart && recovered.latest?.recorderCall?.returnedAt == call.returnedAt
            && recovered.latest?.recovered == true && SyntheticRecorder.shared.recordCount == 1, "Recovery retains call timing and never rearms")
        recovered.refreshClock(now: savedStart.addingTimeInterval(100), uptime: recovered.latest!.startUptime + 10)
        expect(recovered.latest?.phase == .uncertain && recovered.latest?.clockDiscontinuity == true && owner.current == .overnightMotion, "Clock changes preserve blocking reservation")

        defaults.removeObject(forKey: "overnightMotion.v1")
        owner.release(.overnightMotion)
        let comparison = OvernightMotionCoordinator(owner: owner, defaults: defaults)
        comparison.start(.comparison, configuration: .init())
        expect(comparison.latest?.requestCount == 0 && SyntheticRecorder.shared.recordCount == 1, "Comparison never records")
        let comparisonTrial = comparison.latest!
        comparison.refreshClock(now: comparisonTrial.end, uptime: comparisonTrial.startUptime + 28800)
        expect(comparison.latest?.phase == .elapsed && owner.current == .none, "Fixed elapsed window releases ownership")
        comparison.refreshClock(now: comparisonTrial.end.addingTimeInterval(100), uptime: comparisonTrial.startUptime + 28801)
        expect(comparison.latest?.phase == .elapsed && comparison.latest?.clockDiscontinuity == true && !comparison.hasReservation,
               "Clock changes before a final return observation preserve uncertainty without inventing a reservation")

        var oldPending = OvernightMotionTrial(mode: .overnight, start: Date(), uptime: ProcessInfo.processInfo.systemUptime,
                                              configuration: .init(), battery: 0.8)
        oldPending.phase = .requested
        oldPending.requestCount = 1
        defaults.set(try JSONEncoder().encode(OvernightMotionArchive(trials: [oldPending])), forKey: "overnightMotion.v1")
        let oldRecovered = OvernightMotionCoordinator(owner: owner, defaults: defaults)
        expect(oldRecovered.latest?.start == oldPending.start && oldRecovered.latest?.end == oldPending.end
            && oldRecovered.latest?.recorderCall == nil && oldRecovered.hasReservation && oldRecovered.storageError == nil,
            "A legacy in-progress recording retains its dates and missing call timing")
        expect(SyntheticRecorder.shared.recordCount == 1, "Migrating a legacy request does not rearm the recorder")

        // A saved completed request lets tests retrieve real worker output without waiting 20 minutes.
        var completed = OvernightMotionTrial(mode: .pilot, start: Date().addingTimeInterval(-1500),
            uptime: ProcessInfo.processInfo.systemUptime - 1500, configuration: .init(), battery: 0.8)
        completed.phase = .elapsed
        completed.requestCount = 1
        var uncertainRead = completed
        uncertainRead.startUptime += 200
        defaults.set(try JSONEncoder().encode(OvernightMotionArchive(trials: [uncertainRead])), forKey: "overnightMotion.v1")
        SyntheticRecorder.shared.configure()
        let firstUncertainRead = OvernightMotionCoordinator(owner: owner, defaults: defaults)
        firstUncertainRead.retrieve(pilotProbe: false)
        await settle(firstUncertainRead)
        expect(firstUncertainRead.latest?.fullSummary?.count == 60_000
            && firstUncertainRead.latest?.clockDiscontinuity == true
            && firstUncertainRead.latest?.firstUsefulReadAt == nil,
            "A clock change before first retrieval retains diagnostic samples without claiming useful timing")
        defaults.set(try JSONEncoder().encode(OvernightMotionArchive(trials: [completed])), forKey: "overnightMotion.v1")
        SyntheticRecorder.shared.configure()
        let retrieval = OvernightMotionCoordinator(owner: owner, defaults: defaults)
        retrieval.retrieve(pilotProbe: false)
        await settle(retrieval)
        expect(retrieval.latest?.fullSummary?.count == 60_000 && retrieval.latest?.firstUsefulReadAt != nil, "Actual coordinator stores bounded full summary")
        expect(retrieval.latest?.observations.last?.orderDiagnostics?.total == 0, "Completed reads retain their own diagnostics")
        let firstRead = retrieval.latest!.firstUsefulReadAt
        SyntheticRecorder.shared.configure(output: .dateAnomalies)
        retrieval.retrieve(pilotProbe: false)
        await settle(retrieval)
        expect(retrieval.latest?.observations.last?.orderDiagnostics?.backwardDates == 2,
            "Coordinator retains nonzero ordering detail for each failed read")
        SyntheticRecorder.shared.configure()
        retrieval.retrieve(pilotProbe: false)
        await settle(retrieval)
        expect(retrieval.latest?.fullSummary?.count == 60_000 && retrieval.latest?.firstUsefulReadAt == firstRead, "Refresh replaces summary and preserves first availability observation")
        expect(retrieval.latest?.observations.dropLast().last?.orderDiagnostics?.total == 4,
            "Refreshing the latest summary preserves the previous read's diagnostic evidence")
        SyntheticRecorder.shared.configure(output: .slow)
        retrieval.retrieve(pilotProbe: false)
        retrieval.applicationStateChanged("background")
        await settle(retrieval)
        expect(retrieval.latest?.fullSummary?.count == 60_000 && retrieval.latest?.observations.last?.cancelled == true, "Late/cancelled result cannot overwrite prior summary")
        SyntheticRecorder.shared.configure(output: .missing)
        retrieval.retrieve(pilotProbe: true)
        await settle(retrieval)
        expect(retrieval.latest?.latestProbe?.nilChunks == 1 && retrieval.latest?.precedingIncompleteProbeAt != nil, "Pilot incomplete visibility retained")
        var qualified = retrieval.latest!
        qualified.configuration.watchOS = WKInterfaceDevice.current().systemVersion
        qualified.configuration.appBuild = retrieval.build
        qualified.firstUsefulProbeAt = qualified.start.addingTimeInterval(700)
        qualified.latestProbe = .init(pilotProbe: true, requestedAt: qualified.start.addingTimeInterval(699),
            completedAt: qualified.start.addingTimeInterval(700), count: 3000, useful: true,
            first: qualified.start.addingTimeInterval(540), last: qualified.start.addingTimeInterval(599.98),
            nilChunks: 0, emptyChunks: 0, cancelled: false, error: nil)
        var qualification = OvernightMotionArchive(trials: [qualified])
        qualification.updatePilotEvidence()
        var previousBuild = qualification
        previousBuild.trials[0].configuration.appBuild = "Previous app build"
        previousBuild.updatePilotEvidence()
        defaults.set(try JSONEncoder().encode(previousBuild), forKey: "overnightMotion.v1")
        let buildMismatch = OvernightMotionCoordinator(owner: owner, defaults: defaults)
        let requestsBeforeMismatch = SyntheticRecorder.shared.recordCount
        buildMismatch.start(.overnight, configuration: .init())
        expect(!buildMismatch.pilotReady && !buildMismatch.canStart(.overnight)
            && SyntheticRecorder.shared.recordCount == requestsBeforeMismatch,
            "A qualifying pilot from another app build cannot issue an overnight request")
        expect(buildMismatch.storageError == nil && buildMismatch.latest?.start == qualified.start
            && buildMismatch.latest?.fullSummary?.count == qualified.fullSummary?.count
            && buildMismatch.latest?.firstUsefulProbeAt == qualified.firstUsefulProbeAt,
            "A build mismatch preserves the original pilot evidence for inspection")
        var previousOS = qualification
        previousOS.trials[0].configuration.watchOS = "Previous watchOS"
        previousOS.updatePilotEvidence()
        defaults.set(try JSONEncoder().encode(previousOS), forKey: "overnightMotion.v1")
        let osMismatch = OvernightMotionCoordinator(owner: owner, defaults: defaults)
        osMismatch.start(.overnight, configuration: .init())
        expect(!osMismatch.pilotReady && !osMismatch.canStart(.overnight)
            && SyntheticRecorder.shared.recordCount == requestsBeforeMismatch,
            "A qualifying pilot from another watchOS cannot issue an overnight request")
        defaults.set(try JSONEncoder().encode(qualification), forKey: "overnightMotion.v1")
        SyntheticRecorder.shared.configure()
        let unlocked = OvernightMotionCoordinator(owner: owner, defaults: defaults)
        expect(unlocked.canStart(.overnight), "Qualified pilot unlocks overnight on matching OS/build")
        SyntheticRecorder.shared.configure(output: .missing)
        unlocked.retrieve(pilotProbe: true)
        await settle(unlocked)
        expect(!unlocked.pilotReady && !unlocked.canStart(.overnight)
            && unlocked.latest?.latestProbe?.useful == false,
            "Actual incomplete retrieval closes the overnight gate")
        expect(unlocked.latest?.firstUsefulProbeAt == qualified.firstUsefulProbeAt
            && unlocked.latest?.fullSummary?.count == 60_000,
            "The coordinator retains earlier successful evidence alongside the conflicting probe")
        let rejectedAfterRelaunch = OvernightMotionCoordinator(owner: owner, defaults: defaults)
        expect(!rejectedAfterRelaunch.pilotReady && !rejectedAfterRelaunch.canStart(.overnight),
            "Revoked qualification remains revoked after relaunch")
        SyntheticRecorder.shared.configure()
        unlocked.retrieve(pilotProbe: true)
        await settle(unlocked)
        expect(unlocked.pilotReady && unlocked.canStart(.overnight)
            && unlocked.latest?.firstUsefulProbeAt == qualified.firstUsefulProbeAt,
            "A usable retry restores qualification using the retained early visibility observation")
        SyntheticRecorder.shared.configure(output: .slow)
        unlocked.retrieve(pilotProbe: true)
        unlocked.applicationStateChanged("background")
        await settle(unlocked)
        expect(unlocked.pilotReady && unlocked.latest?.latestProbe?.useful == true
            && unlocked.latest?.observations.last?.cancelled == true,
            "A cancelled probe retains qualification and cannot replace completed evidence")
        SyntheticRecorder.shared.configure()
        unlocked.refreshClock(now: Date().addingTimeInterval(86400), uptime: 100)
        expect(unlocked.latest?.clockDiscontinuity == false && unlocked.pilotReady && unlocked.latest?.firstUsefulReadAt == firstRead,
               "A reboot after completed retrieval cannot rewrite past evidence or remove qualification")
        var lateClock = qualification
        lateClock.trials[0].startUptime += 200
        defaults.set(try JSONEncoder().encode(lateClock), forKey: "overnightMotion.v1")
        let laterRead = OvernightMotionCoordinator(owner: owner, defaults: defaults)
        laterRead.retrieve(pilotProbe: false)
        await settle(laterRead)
        expect(laterRead.pilotReady && laterRead.latest?.clockDiscontinuity == false
            && laterRead.latest?.firstUsefulReadAt == firstRead && laterRead.latest?.fullSummary?.count == 60_000,
            "A later clock-uncertain read retains the completed summary and first observation")
        expect(laterRead.latest?.observations.last?.clockDiscontinuity == true
            && laterRead.latest?.observations.last?.useful == false, "A new read with uncertain timing cannot claim visibility")
        laterRead.retrieve(pilotProbe: true)
        await settle(laterRead)
        expect(laterRead.pilotReady && laterRead.latest?.latestProbe?.useful == true
            && laterRead.latest?.observations.last?.clockDiscontinuity == true
            && laterRead.latest?.observations.last?.useful == false,
            "A clock-uncertain probe preserves completed qualification without claiming new visibility")
        unlocked.start(.overnight, configuration: .init())
        expect(unlocked.latest?.mode == .overnight && SyntheticRecorder.shared.recordCount == 1, "Qualified overnight issues one request")
        owner.release(.overnightMotion)
        var prepared = OvernightMotionTrial(mode: .pilot, start: Date(), uptime: ProcessInfo.processInfo.systemUptime,
                                           configuration: .init(), battery: nil)
        prepared.record("Request prepared")
        defaults.set(try JSONEncoder().encode(OvernightMotionArchive(trials: [prepared])), forKey: "overnightMotion.v1")
        let interruptedPrepare = OvernightMotionCoordinator(owner: owner, defaults: defaults)
        expect(interruptedPrepare.latest?.phase == .uncertain && interruptedPrepare.hasReservation && SyntheticRecorder.shared.recordCount == 1, "Interrupted preparation preserves uncertainty and never reissues")
        defaults.set(Data("bad archive".utf8), forKey: "overnightMotion.v1")
        let corrupt = OvernightMotionCoordinator(owner: owner, defaults: defaults)
        expect(corrupt.storageError != nil && owner.current == .unresolved && !corrupt.canStart(.comparison), "Corrupt metadata blocks requests")
        owner.reconcile(alertPending: false, motionPending: true, overnightPending: true)
        expect(owner.current == .unresolved, "Conflicting reservations are not guessed away")

        var settings = OvernightMotionTrial.Configuration()
        settings.watchModel = "Synthetic"
        settings.wrist = "Worn, unlocked"; settings.powerMode = "Off"
        settings.sleepFocus = "On"; settings.sleepTracking = "On"
        settings.debuggerDetached = "Yes"; settings.charging = "No"; settings.interruption = "None"
        var baseline = OvernightMotionTrial(mode: .comparison, start: origin, uptime: 1000, configuration: settings, battery: 0.8)
        baseline.phase = .elapsed
        baseline.batteryReturn = .init(date: baseline.end, level: 0.65)
        var night = OvernightMotionTrial(mode: .overnight, start: origin.addingTimeInterval(86400), uptime: 1000, configuration: settings, battery: 0.8)
        night.phase = .elapsed; night.requestCount = 1
        night.batteryReturn = .init(date: night.end, level: 0.6)
        let batteries = OvernightMotionArchive(trials: [baseline, night])
        expect(batteries.batteryAssessment(for: night).hasPrefix("Battery thresholds met"), "Matched battery baseline")
        night.configuration.powerMode = "On"
        expect(batteries.batteryAssessment(for: night).hasPrefix("Comparable baseline not established"), "Settings mismatch is inconclusive")
        night.configuration.charging = "Yes"
        expect(batteries.batteryAssessment(for: night).contains("incomplete"), "Charging cannot pass battery criteria")
        expect(testArchive.errorMessage == nil && !testArchive.reports.isEmpty, "Actual coordinator writes diagnostic reports")
        let saved = try testArchive.report(id: testArchive.reports[0].id)
        expect(saved.diagnostics != nil, "Full typed summary is retained independently of rolling history")
        print("PASS: streaming chunks, timing failures, order anomaly categories and legacy compatibility, recorder-call windows, conservative reservations, time-driven eligibility, legacy recovery, completed evidence across reboot, gaps, clocks, bounds, authorization, pilot gate, conflicting probes, cancellation, summary replacement and battery comparisons")
    }
}
