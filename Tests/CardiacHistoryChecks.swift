import Foundation

struct HKSampleType: Hashable, Sendable {
    enum Identifier: Hashable { case heartRate, heartRateVariabilitySDNN, heartbeatSeries }
    let identifier: Identifier
    init(_ identifier: Identifier) { self.identifier = identifier }
}
typealias HKQuantityType = HKSampleType
struct HKSeriesType {
    static func heartbeat() -> HKSampleType { HKSampleType(.heartbeatSeries) }
}
struct HKUnit {
    enum Prefix { case milli }
    let name: String
    static func count() -> Self { Self(name: "count") }
    static func minute() -> Self { Self(name: "minute") }
    static func secondUnit(with: Prefix) -> Self { Self(name: "ms") }
    func unitDivided(by unit: Self) -> Self { Self(name: name + "/" + unit.name) }
}
struct HKQuantity {
    let value: Double
    let unit: String
    func doubleValue(for requested: HKUnit) -> Double {
        precondition(requested.name == unit)
        return value
    }
}
class HKQuery {
    static func predicateForSamples(withStart: Date, end: Date, options: [Int]) -> NSPredicate {
        precondition(end.timeIntervalSince(withStart) == 86400 && options.isEmpty)
        return NSPredicate(value: true)
    }
}
let HKSampleSortIdentifierStartDate = "startDate"
class HKSample {
    struct Revision {
        struct Source { let name: String; let bundleIdentifier: String }
        let source: Source
    }
    let uuid = UUID()
    let startDate: Date
    let endDate: Date
    let sourceRevision: Revision
    init(start: Date, end: Date, source: String = "Synthetic source", identifier: String = "test.source") {
        startDate = start
        endDate = end
        sourceRevision = Revision(source: Revision.Source(name: source, bundleIdentifier: identifier))
    }
}
final class HKQuantitySample: HKSample {
    let quantity: HKQuantity
    let count: Int
    init(start: Date, end: Date, value: Double = 65, count: Int = 1, unit: String = "count/minute") {
        self.quantity = HKQuantity(value: value, unit: unit)
        self.count = count
        super.init(start: start, end: end)
    }
}
final class HKHeartbeatSeriesSample: HKSample {
    let count: UInt
    init(start: Date, end: Date, count: UInt) {
        self.count = count
        super.init(start: start, end: end)
    }
}
final class HKSampleQuery: HKQuery {
    let callback: @Sendable (HKSampleQuery, [HKSample]?, Error?) -> Void
    let type: HKSampleType
    let limit: Int
    init(sampleType: HKSampleType, predicate: NSPredicate, limit: Int, sortDescriptors: [NSSortDescriptor], resultsHandler: @escaping @Sendable (HKSampleQuery, [HKSample]?, Error?) -> Void) {
        precondition(sortDescriptors.count == 1 && !sortDescriptors[0].ascending)
        type = sampleType
        self.limit = limit
        callback = resultsHandler
    }
}
@MainActor final class HKHealthStore {
    static var available = true
    static var authorizationError = false
    static var authorizationDelay = false
    static var requests = 0
    static var queries: [HKSampleQuery] = []
    static var stops = 0
    static func isHealthDataAvailable() -> Bool { available }
    func requestAuthorization(toShare: Set<HKSampleType>, read: Set<HKSampleType>) async throws {
        precondition(toShare.isEmpty && read == Set(CardiacKind.allCases.map(\.sampleType)))
        Self.requests += 1
        if Self.authorizationDelay { try await Task.sleep(for: .milliseconds(100)) }
        if Self.authorizationError { throw NSError(domain: "Synthetic authorization", code: 1) }
    }
    func execute(_ query: HKSampleQuery) { Self.queries.append(query) }
    func stop(_ query: HKSampleQuery) { Self.stops += 1 }
}

@main struct Checks {
    static func record(_ a: Double, _ b: Double, source: String = "a", count: Int = 1) -> CardiacRecord {
        CardiacRecord(id: UUID(), start: Date(timeIntervalSince1970: a), end: Date(timeIntervalSince1970: b),
            source: source, sourceIdentifier: source, value: 65, count: count)
    }

    static func coverageChecks() {
        let snapshot = CardiacSnapshot(records: [record(50, 70), record(-10, 20, count: 3), record(10, 30),
            record(100, 120), record(0, 100, source: "b")], isTruncated: false, readAt: Date(), error: nil, rejectedRecords: 0)
        let sources = snapshot.coverage(start: Date(timeIntervalSince1970: 0), end: Date(timeIntervalSince1970: 100))
        precondition(sources.count == 2)
        precondition(sources[0].recordCount == 4 && sources[0].groupedRecordCount == 1)
        precondition(sources[0].largestUncoveredInterval == 30)
        precondition(sources[0].firstStart == Date(timeIntervalSince1970: -10))
        precondition(sources[0].latestEnd == Date(timeIntervalSince1970: 120))
        precondition(sources[1].largestUncoveredInterval == 0)
        let nested = CardiacSnapshot(records: [record(0, 100), record(20, 30)], isTruncated: true, readAt: Date(), error: nil, rejectedRecords: 0)
        precondition(nested.coverage(start: Date(timeIntervalSince1970: 0), end: Date(timeIntervalSince1970: 100))[0].largestUncoveredInterval == 0)
        let single = CardiacSnapshot(records: [record(20, 20)], isTruncated: false, readAt: Date(), error: nil, rejectedRecords: 0)
        precondition(single.coverage(start: Date(timeIntervalSince1970: 0), end: Date(timeIntervalSince1970: 100))[0].largestUncoveredInterval == 80)
        precondition(CardiacSnapshot(records: [], isTruncated: false, readAt: nil, error: nil, rejectedRecords: 0).coverage(start: Date(), end: Date()).isEmpty)
    }

    @MainActor static func settle() async { try? await Task.sleep(for: .milliseconds(30)) }
    @MainActor static func start(_ reader: CardiacHistoryReader) async -> [HKSampleQuery] {
        HKHealthStore.queries = []
        reader.refresh()
        await settle()
        precondition(HKHealthStore.queries.count == 3)
        precondition(HKHealthStore.queries.map(\.limit) == [2001, 501, 51])
        return HKHealthStore.queries
    }

    @MainActor static func main() async {
        coverageChecks()
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer {
            try? FileManager.default.removeItem(at: directory)
            try? FileManager.default.removeItem(at: directory.appendingPathExtension("deleted-through"))
        }
        let archive = TestArchiveStore(directory: directory)
        let reader = CardiacHistoryReader()
        reader.testArchive = archive
        HKHealthStore.available = false
        reader.refresh()
        precondition(reader.status.contains("unavailable") && !reader.isLoading)
        HKHealthStore.available = true
        var queries = await start(reader)
        queries[0].callback(queries[0], [], nil)
        await settle()
        precondition(reader.isLoading && reader.snapshots[.heartRate]?.records.isEmpty == true)
        queries[2].callback(queries[2], [], nil)
        queries[1].callback(queries[1], [], nil)
        await settle()
        precondition(!reader.isLoading && reader.snapshots.count == 3 && reader.snapshots.values.allSatisfy { $0.readAt != nil })

        queries = await start(reader)
        let t = reader.windowEnd!.addingTimeInterval(-100)
        queries[0].callback(queries[0], [HKQuantitySample(start: t, end: t.addingTimeInterval(30), count: 4)], nil)
        queries[1].callback(queries[1], [HKQuantitySample(start: t, end: t, value: 42, unit: "ms")], nil)
        queries[2].callback(queries[2], [HKHeartbeatSeriesSample(start: t, end: t.addingTimeInterval(60), count: 70)], nil)
        await settle()
        precondition(reader.snapshots[.heartRate]?.records[0].count == 4)
        precondition(reader.snapshots[.heartRate]?.records[0].value == 65)
        precondition(reader.snapshots[.hrv]?.records[0].value == 42)
        precondition(reader.snapshots[.heartbeatSeries]?.records[0].count == 70)
        precondition(reader.snapshots[.heartbeatSeries]?.records[0].value == nil)
        precondition(reader.snapshots[.heartRate]?.records[0].sourceIdentifier == "test.source")
        precondition(reader.snapshots[.heartRate]?.records[0].start == t)

        queries = await start(reader)
        for (index, kind) in CardiacKind.allCases.enumerated() {
            let query = queries[index]
            let rows: [HKSample] = (0...kind.limit).map { _ in
                kind == .heartbeatSeries ? HKHeartbeatSeriesSample(start: t, end: t, count: 1)
                    : HKQuantitySample(start: t, end: t, unit: kind == .heartRate ? "count/minute" : "ms")
            }
            query.callback(query, rows, nil)
        }
        await settle()
        for kind in CardiacKind.allCases {
            precondition(reader.snapshots[kind]?.records.count == kind.limit && reader.snapshots[kind]?.isTruncated == true)
        }
        queries = await start(reader)
        queries[0].callback(queries[0], [HKQuantitySample(start: t, end: t, value: .nan),
            HKQuantitySample(start: t, end: t.addingTimeInterval(-1)),
            HKQuantitySample(start: t.addingTimeInterval(1000), end: t.addingTimeInterval(1000))], nil)
        queries[1].callback(queries[1], nil, NSError(domain: "Synthetic read", code: 2))
        queries[2].callback(queries[2], [], nil)
        await settle()
        precondition(reader.snapshots[.heartRate]?.rejectedRecords == 3)
        precondition(reader.snapshots[.hrv]?.error != nil && reader.snapshots[.hrv]?.readAt == nil)
        precondition(reader.snapshots[.heartbeatSeries]?.error == nil && !reader.isLoading)
        precondition(reader.status.contains("errors"))

        queries = await start(reader)
        let before = HKHealthStore.stops
        reader.clear()
        for query in queries { query.callback(query, [], nil) }
        await settle()
        precondition(HKHealthStore.stops == before + 3 && reader.snapshots.isEmpty && reader.windowEnd == nil)
        let old = queries
        queries = await start(reader)
        for query in old { query.callback(query, [], nil) }
        await settle()
        precondition(reader.snapshots.isEmpty && reader.isLoading)
        for query in queries { query.callback(query, [], nil) }
        await settle()
        precondition(reader.snapshots.count == 3)

        HKHealthStore.authorizationError = true
        reader.refresh()
        await settle()
        precondition(reader.status.contains("Access request failed") && !reader.isLoading && !reader.isRequestingAccess)
        HKHealthStore.authorizationError = false
        HKHealthStore.authorizationDelay = true
        HKHealthStore.queries = []
        let requests = HKHealthStore.requests
        reader.refresh()
        reader.clear()
        reader.refresh()
        await settle()
        precondition(reader.isRequestingAccess && HKHealthStore.requests == requests + 1)
        try? await Task.sleep(for: .milliseconds(150))
        precondition(HKHealthStore.queries.isEmpty && reader.snapshots.isEmpty && !reader.isRequestingAccess)
        precondition(archive.errorMessage == nil && archive.reports.count > 3)
        precondition(archive.reports.allSatisfy { $0.diagnostics == nil })
        let reportCount = archive.reports.count
        reader.clear()
        await settle()
        precondition(archive.reports.count == reportCount)
        precondition(archive.reports.contains { $0.metrics["Heart rate grouped records"] != nil })
        let fullArchive = TestArchiveStore(directory: directory.appendingPathComponent("full"), maximumReports: 0)
        let blockedReader = CardiacHistoryReader()
        blockedReader.testArchive = fullArchive
        blockedReader.refresh()
        precondition(!blockedReader.isLoading && blockedReader.status.contains("blocked"))
        print("PASS: source-specific gaps, overlap/boundaries, grouped records, units, bounds, errors, read-only access, cancellation and late callbacks")
    }
}
