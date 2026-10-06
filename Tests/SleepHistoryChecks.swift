import Foundation

enum HKCategoryValueSleepAnalysis: Int { case inBed = 0, asleepUnspecified = 1, awake = 2, asleepCore = 3, asleepDeep = 4, asleepREM = 5 }
struct HKCategoryType: Hashable, Sendable {
    enum Identifier { case sleepAnalysis }
    init(_ identifier: Identifier) {}
}
class HKQuery {
    static func predicateForSamples(withStart: Date, end: Date, options: [Int]) -> NSPredicate {
        precondition(options.isEmpty && withStart < end)
        return NSPredicate(value: true)
    }
}
let HKSampleSortIdentifierStartDate = "startDate"
class HKSample { }
final class HKCategorySample: HKSample {
    let uuid = UUID()
    let value: Int
    let startDate = Date(timeIntervalSince1970: 100)
    let endDate = Date(timeIntervalSince1970: 200)
    struct Revision { struct Source { let name = "Synthetic source"; let bundleIdentifier = "test.source" }; let source = Source() }
    let sourceRevision = Revision()
    init(_ value: Int) { self.value = value }
}
final class HKSampleQuery: HKQuery {
    let callback: @Sendable (HKSampleQuery, [HKSample]?, Error?) -> Void
    let limit: Int
    init(sampleType: HKCategoryType, predicate: NSPredicate, limit: Int, sortDescriptors: [NSSortDescriptor], resultsHandler: @escaping @Sendable (HKSampleQuery, [HKSample]?, Error?) -> Void) {
        self.limit = limit
        self.callback = resultsHandler
    }
}
@MainActor final class HKHealthStore {
    static var available = true
    static var authorizationError = false
    static var authorizationDelay = false
    static var query: HKSampleQuery?
    static var stops = 0
    static func isHealthDataAvailable() -> Bool { available }
    func requestAuthorization(toShare: Set<HKCategoryType>, read: Set<HKCategoryType>) async throws {
        precondition(toShare.isEmpty && read.count == 1)
        if Self.authorizationDelay { try await Task.sleep(for: .milliseconds(100)) }
        if Self.authorizationError { throw NSError(domain: "Synthetic authorization", code: 1) }
    }
    func execute(_ query: HKSampleQuery) { Self.query = query }
    func stop(_ query: HKSampleQuery) { Self.stops += 1 }
}
@main struct Checks {
    @MainActor static func settle() async { try? await Task.sleep(for: .milliseconds(30)) }
    @MainActor static func main() async {
        let reader = SleepStageReader()
        HKHealthStore.available = false
        reader.refresh()
        precondition(reader.status.contains("unavailable") && !reader.isLoading)
        HKHealthStore.available = true
        reader.refresh()
        await settle()
        let emptyQuery = HKHealthStore.query!
        precondition(emptyQuery.limit == 501)
        emptyQuery.callback(emptyQuery, [], nil)
        await settle()
        precondition(reader.intervals.isEmpty && reader.status == "No readable sleep records in this window" && reader.refreshedAt != nil)
        reader.refresh()
        await settle()
        let fullQuery = HKHealthStore.query!
        fullQuery.callback(fullQuery, (0..<501).map { HKCategorySample($0 % 7) }, nil)
        await settle()
        precondition(reader.intervals.count == 500 && reader.isTruncated)
        precondition(reader.intervals[0].category == "In bed" && reader.intervals[1].category == "Asleep (unspecified)")
        precondition(reader.intervals[2].category == "Awake" && reader.intervals[3].category == "Core")
        precondition(reader.intervals[4].category == "Deep" && reader.intervals[5].category == "REM" && reader.intervals[6].category.contains("Unknown"))
        precondition(reader.intervals[0].sourceIdentifier == "test.source" && reader.intervals[0].start == Date(timeIntervalSince1970: 100))
        reader.refresh()
        await settle()
        let oldQuery = HKHealthStore.query!
        reader.clear()
        oldQuery.callback(oldQuery, [HKCategorySample(3)], nil)
        await settle()
        precondition(reader.intervals.isEmpty && reader.refreshedAt == nil && HKHealthStore.stops == 1)
        reader.refresh()
        await settle()
        let failedQuery = HKHealthStore.query!
        failedQuery.callback(failedQuery, nil, NSError(domain: "Synthetic read", code: 2))
        await settle()
        precondition(reader.status.contains("Read error") && !reader.isLoading && reader.intervals.isEmpty)
        HKHealthStore.authorizationError = true
        reader.refresh()
        await settle()
        precondition(reader.status.contains("Access request failed") && !reader.isRequestingAccess)
        HKHealthStore.authorizationError = false
        HKHealthStore.authorizationDelay = true
        HKHealthStore.query = nil
        reader.refresh()
        reader.clear()
        reader.refresh()
        precondition(reader.isRequestingAccess)
        try? await Task.sleep(for: .milliseconds(150))
        precondition(HKHealthStore.query == nil && !reader.isRequestingAccess && reader.intervals.isEmpty)
        print("PASS: read-only request, unavailable/empty/error states, categories, source/date preservation, truncation, cancellation and late authorization/query callbacks")
    }
}
