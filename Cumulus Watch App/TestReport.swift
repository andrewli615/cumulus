import Foundation

struct TestReport: Codable, Identifiable, Sendable {
    enum Kind: String, Codable, Sendable {
        case foreground, alert, background, sleep, cardiac, overnight
    }
    struct Event: Codable, Sendable {
        let date: Date
        let message: String
    }
    var schemaVersion = 1
    let id: String
    let kind: Kind
    let createdAt: Date
    var updatedAt = Date()
    let title: String
    let status: String
    let metrics: [String: String]
    var captureBuild = "Unknown"
    var captureOS = "Unknown"
    var events: [Event] = []
    var diagnostics: Data?

    func validate() throws {
        guard schemaVersion == 1, id.hasPrefix(kind.rawValue + "-"), id.count <= 100,
              id.allSatisfy({ "abcdefghijklmnopqrstuvwxyz0123456789-".contains($0) }),
              createdAt.timeIntervalSince1970.isFinite, updatedAt.timeIntervalSince1970.isFinite,
              title.count <= 128, status.count <= 500, metrics.count <= 80,
              metrics.allSatisfy({ $0.key.count <= 128 && $0.value.count <= 500 }),
              captureBuild.count <= 128, captureOS.count <= 128, events.count <= 40,
              events.allSatisfy({ $0.date.timeIntervalSince1970.isFinite && $0.message.count <= 500 }),
              (diagnostics?.count ?? 0) <= 350_000 else { throw TestArchiveError.invalid }
    }

    static func encodeDiagnostics<T: Encodable>(_ value: T) throws -> Data {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .secondsSince1970
        return try encoder.encode(value)
    }
}

enum TestArchiveError: Error { case invalid, full, unreadable }
