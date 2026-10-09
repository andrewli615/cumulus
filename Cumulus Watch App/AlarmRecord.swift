import Foundation

struct AlarmRecord: Codable {
    enum Phase: String, Codable {
        case requesting, scheduled, hapticRequested, cancellationRequested, stopRequested
        case cancelled, stopped, ended, failed

        var pending: Bool {
            switch self {
            case .requesting, .scheduled, .hapticRequested, .cancellationRequested, .stopRequested: true
            default: false
            }
        }
    }
    struct Event: Codable, Identifiable {
        let id: UUID
        let alarmID: UUID
        let fireDate: Date
        let date: Date
        let message: String
    }
    let id: UUID
    let fireDate: Date
    let createdAt: Date
    var phase: Phase = .requesting
    var hapticRequestedAt: Date?
    var events: [Event] = []

    mutating func record(_ message: String, at date: Date) {
        events.append(Event(id: UUID(), alarmID: id, fireDate: fireDate, date: date,
                            message: String(message.prefix(500))))
        events = Array(events.suffix(40))
    }
    func validate() throws {
        let dates = [fireDate, createdAt] + [hapticRequestedAt].compactMap { $0 }
            + events.flatMap { [$0.fireDate, $0.date] }
        guard dates.allSatisfy({ $0.timeIntervalSince1970.isFinite }),
              events.count <= 40, Set(events.map(\.id)).count == events.count,
              events.allSatisfy({ $0.message.count <= 500 }),
              phase != .hapticRequested || hapticRequestedAt != nil else { throw AlarmStorageError.invalid }
    }
}

enum AlarmTime {
    static let maximumDelay: TimeInterval = 36 * 60 * 60
    static func isValid(_ date: Date, now: Date) -> Bool {
        let delay = date.timeIntervalSince(now)
        return delay.isFinite && delay > 0 && delay <= maximumDelay
    }
    static func next(hour: Int, minute: Int, after now: Date, calendar: Calendar = .current) -> Date? {
        guard (0..<24).contains(hour), (0..<60).contains(minute) else { return nil }
        // Resolve skipped local times forward; choose the first occurrence of a repeated time.
        return calendar.nextDate(after: now, matching: DateComponents(hour: hour, minute: minute, second: 0),
                                 matchingPolicy: .nextTimePreservingSmallerComponents,
                                 repeatedTimePolicy: .first, direction: .forward)
    }
}

enum AlarmStorageError: Error { case invalid }

@MainActor
protocol AlarmStorage {
    func load() throws -> AlarmRecord?
    func save(_ record: AlarmRecord) throws
    func clear() throws
}

@MainActor
struct AlarmFileStore: AlarmStorage {
    let url: URL
    init(url: URL? = nil) {
        self.url = url ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Cumulus/Alarm/record.json")
    }
    func load() throws -> AlarmRecord? {
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        let size = try url.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0
        guard size <= 64_000 else { throw AlarmStorageError.invalid }
        let record = try JSONDecoder().decode(AlarmRecord.self, from: Data(contentsOf: url))
        try record.validate()
        return record
    }
    func save(_ record: AlarmRecord) throws {
        try record.validate()
        let data = try JSONEncoder().encode(record)
        guard data.count <= 64_000 else { throw AlarmStorageError.invalid }
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try data.write(to: url, options: .atomic)
    }
    func clear() throws {
        if FileManager.default.fileExists(atPath: url.path) { try FileManager.default.removeItem(at: url) }
    }
}
