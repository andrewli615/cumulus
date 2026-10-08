import Foundation

@MainActor final class SyntheticTimingQuery: CardiacTimingQuerying {
    var hold = false
    var fail = false
    var calls = 0
    var continuation: CheckedContinuation<CardiacTimingSummary, Error>?
    func inspect(_ selection: CardiacTimingSelection,
                 progress: @escaping @MainActor (CardiacTimingSummary) -> Void) async throws -> CardiacTimingSummary {
        calls += 1
        if fail { throw NSError(domain: "Synthetic", code: 1) }
        var result = CardiacTimingSummary()
        result.receive(offset: 1, duration: 100)
        result.receive(offset: 2, duration: 100)
        progress(result)
        result.enumerationCompleted = true
        if hold { return try await withCheckedThrowingContinuation { continuation = $0 } }
        return result
    }
}

@main struct CardiacTimingChecks {
    @MainActor static func settle() async { try? await Task.sleep(for: .milliseconds(30)) }
    @MainActor static func main() async throws {
        var timing = CardiacTimingSummary()
        timing.receive(offset: 1, duration: 100)
        timing.receive(offset: 2, duration: 100)
        timing.receive(offset: 10, duration: 100, precededByGap: true)
        timing.receive(offset: 11, duration: 100)
        precondition(timing.received == 4 && timing.accepted == 4 && timing.gapFlags == 1)
        precondition(timing.spacingPairs == 2 && timing.maximumSpacing == 1 && timing.minimumSpacing == 1)
        timing.receive(offset: .nan, duration: 100)
        timing.receive(offset: 20, duration: 100)
        precondition(timing.invalid == 1 && timing.spacingPairs == 2, "Invalid entry breaks adjacency")
        timing.receive(offset: 20, duration: 100)
        timing.receive(offset: 21, duration: 100)
        precondition(timing.orderAnomalies == 1 && timing.spacingPairs == 2, "Order anomaly breaks adjacency")
        timing.receive(offset: 101, duration: 100)
        timing.receive(offset: -1, duration: 100)
        timing.receive(offset: 0, duration: 100, positiveOffset: true)
        timing.receive(offset: 30, duration: 100, valueFinite: false)
        precondition(timing.invalid == 5)
        precondition(timing.metrics(for: .groupedHeartRate)["Preceded-by-gap flags"]!.contains("Not provided"))
        var bounded = CardiacTimingSummary()
        for i in 0...CardiacTimingSummary.maximumEntries { bounded.receive(offset: Double(i), duration: 30_000) }
        precondition(bounded.received == 20_000 && bounded.limitReached && !bounded.enumerationCompleted)
        let query = SyntheticTimingQuery()
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let archive = TestArchiveStore(directory: directory)
        var allowed = true
        let reader = CardiacTimingReader(query: query, archive: archive, canRead: { allowed })
        let selection = CardiacTimingSelection(id: UUID(), kind: .groupedHeartRate, count: 2,
            start: Date(timeIntervalSince1970: 100), end: Date(timeIntervalSince1970: 200))
        reader.read(selection)
        await settle()
        precondition(!reader.isReading && reader.summary?.enumerationCompleted == true && query.calls == 1)
        precondition(archive.reports.count == 1 && archive.reports[0].metrics["Received count matches declared"] == "true")
        precondition(archive.reports[0].diagnostics == nil)
        let bytes = try Data(contentsOf: directory.appendingPathComponent(archive.reports[0].id + ".json"))
        let text = String(decoding: bytes, as: UTF8.self)
        precondition(!text.contains(selection.id.uuidString) && !text.contains("\"value\":") && !text.contains("sourceIdentifier"))
        reader.clear()
        precondition(reader.summary == nil && archive.reports.count == 1)
        query.hold = true
        reader.read(selection)
        await settle()
        precondition(reader.isReading)
        reader.clear()
        let cancelledID = archive.reports[0].id
        precondition(archive.reports[0].status.contains("cancelled"))
        var late = CardiacTimingSummary()
        late.enumerationCompleted = true
        query.continuation?.resume(returning: late)
        await settle()
        precondition(reader.summary == nil && !reader.isReading && archive.reports.first(where: { $0.id == cancelledID })!.status.contains("cancelled"))
        query.hold = false
        query.fail = true
        reader.read(selection)
        await settle()
        precondition(!reader.isReading && reader.status.contains("failed") && reader.errorMessage != nil)
        allowed = false
        let count = query.calls
        reader.read(selection)
        await settle()
        precondition(query.calls == count && reader.status.contains("blocked"))
        let timeoutQuery = SyntheticTimingQuery()
        timeoutQuery.hold = true
        let timeoutReader = CardiacTimingReader(query: timeoutQuery, timeout: .milliseconds(10))
        timeoutReader.read(selection)
        await settle()
        precondition(!timeoutReader.isReading && timeoutReader.status.contains("timed out"))
        timeoutQuery.continuation?.resume(returning: late)
        await settle()
        precondition(timeoutReader.status.contains("timed out") && timeoutReader.summary?.enumerationCompleted == false)
        let fullArchive = TestArchiveStore(directory: directory.appendingPathComponent("full"), maximumReports: 0)
        let blockedReader = CardiacTimingReader(query: query, archive: fullArchive)
        blockedReader.read(selection)
        await settle()
        precondition(query.calls == count && blockedReader.status.contains("blocked"))
        let oversized = CardiacTimingSelection(id: UUID(), kind: .heartbeatSeries, count: 20_001, start: .now, end: .now)
        precondition(!oversized.canInspect, "Oversized declared series are rejected before SDK retrieval")
        let invalid = CardiacTimingSelection(id: UUID(), kind: .groupedHeartRate, count: 1, start: .now, end: .now)
        precondition(!invalid.canInspect)
        print("PASS: internal spacing, flagged gaps, invalid/order rejection, bounds, conditional eligibility, privacy, cancellation and late results")
    }
}
