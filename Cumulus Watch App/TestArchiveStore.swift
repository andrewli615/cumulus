import Combine
import Foundation

@MainActor
final class TestArchiveStore: ObservableObject {
    @Published private(set) var reports: [TestReport] = []
    @Published private(set) var errorMessage: String?
    @Published private(set) var unreadableFiles = 0
    @Published private(set) var storedBytes = 0
    let directory: URL
    private let maximumReports: Int
    private let maximumBytes: Int
    private var fileSizes: [String: Int] = [:]
    private let build: String
    private let os: String
    private var deletedThrough: Date?
    private var isReadable = false
    private var deletionMarker: URL { directory.appendingPathExtension("deleted-through") }

    var canStartNewReport: Bool {
        isReadable && errorMessage == nil && reports.count + unreadableFiles < maximumReports
            && storedBytes <= maximumBytes - 512_000
    }
    var newReportBlockReason: String? {
        canStartNewReport ? nil : "A new test needs readable archive storage, a free report slot, and 512 KB of reserved space. Preserve or delete completed reports before starting."
    }

    init(directory: URL = URL.applicationSupportDirectory.appendingPathComponent("Cumulus/TestArchive"),
         build: String = "Unknown", os: String = "Unknown", maximumReports: Int = 200,
         maximumBytes: Int = 32 * 1024 * 1024) {
        self.directory = directory
        self.build = build
        self.os = os
        self.maximumReports = maximumReports
        self.maximumBytes = maximumBytes
        reload()
    }

    func reload() {
        isReadable = false
        reports = []
        fileSizes = [:]
        unreadableFiles = 0
        storedBytes = 0
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true,
                                                    attributes: [.posixPermissions: 0o700])
            var values = URLResourceValues()
            values.isExcludedFromBackup = true
            var folder = directory
            try folder.setResourceValues(values)
            let marker = deletionMarker
            if FileManager.default.fileExists(atPath: marker.path) {
                let text = try String(contentsOf: marker, encoding: .utf8)
                guard let time = Double(text), time.isFinite else { throw TestArchiveError.invalid }
                deletedThrough = Date(timeIntervalSince1970: time)
            }
            let urls = try FileManager.default.contentsOfDirectory(at: directory,
                includingPropertiesForKeys: [.fileSizeKey, .isRegularFileKey, .isSymbolicLinkKey])
            for url in urls where url.pathExtension == "json" {
                let values = try url.resourceValues(forKeys: [.fileSizeKey, .isRegularFileKey, .isSymbolicLinkKey])
                let size = values.fileSize ?? 0
                storedBytes += size
                guard values.isRegularFile == true, values.isSymbolicLink != true, size <= 512_000 else {
                    unreadableFiles += 1
                    continue
                }
                do {
                    let report = try read(url)
                    guard url.lastPathComponent == report.id + ".json" else { throw TestArchiveError.invalid }
                    var summary = report
                    summary.diagnostics = nil
                    reports.append(summary)
                    fileSizes[report.id] = size
                } catch {
                    unreadableFiles += 1
                }
            }
            reports.sort { $0.updatedAt > $1.updatedAt }
            isReadable = true
            errorMessage = unreadableFiles == 0 ? nil : "Some saved reports could not be read. They were preserved."
        } catch {
            errorMessage = "The test archive could not be opened. Existing files were preserved."
        }
    }

    func save(_ value: TestReport, importing: Bool = false) {
        if importing, let deletedThrough, value.createdAt <= deletedThrough { return }
        do {
            guard isReadable else { throw TestArchiveError.unreadable }
            var report = value
            report.captureBuild = build
            report.captureOS = os
            try report.validate()
            let url = directory.appendingPathComponent(report.id + ".json")
            let existing = fileSizes[report.id]
            if FileManager.default.fileExists(atPath: url.path), existing == nil {
                throw TestArchiveError.unreadable
            }
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .secondsSince1970
            encoder.outputFormatting = [.sortedKeys]
            let data = try encoder.encode(report)
            guard data.count <= 512_000 else { throw TestArchiveError.invalid }
            guard reports.count + unreadableFiles + (existing == nil ? 1 : 0) <= maximumReports,
                  storedBytes - (existing ?? 0) + data.count <= maximumBytes else { throw TestArchiveError.full }
            var options: Data.WritingOptions = [.atomic]
            #if os(watchOS)
            options.insert(.completeFileProtectionUntilFirstUserAuthentication)
            #endif
            try data.write(to: url, options: options)
            storedBytes += data.count - (existing ?? 0)
            fileSizes[report.id] = data.count
            report.diagnostics = nil
            reports.removeAll { $0.id == report.id }
            reports.append(report)
            reports.sort { $0.updatedAt > $1.updatedAt }
            var values = URLResourceValues()
            values.isExcludedFromBackup = true
            var protectedURL = url
            try protectedURL.setResourceValues(values)
            if unreadableFiles > 0, errorMessage == nil { errorMessage = "Unreadable reports remain preserved." }
        } catch TestArchiveError.full {
            errorMessage = "Test archive full. Older reports were kept; this update was not saved. Retrieve or delete reports before continuing."
        } catch {
            errorMessage = "A test archive update failed. Inspect saved reports and storage before relying on the archive."
        }
    }

    func saveDiagnostics<T: Encodable>(_ value: T, report: TestReport, importing: Bool = false) {
        do {
            var report = report
            report.diagnostics = try TestReport.encodeDiagnostics(value)
            save(report, importing: importing)
        } catch {
            errorMessage = "Diagnostic metadata could not be encoded; this report was not saved."
        }
    }

    func report(id: String) throws -> TestReport {
        guard reports.contains(where: { $0.id == id }) else { throw TestArchiveError.invalid }
        return try read(directory.appendingPathComponent(id + ".json"))
    }

    func deleteAll() -> Bool {
        do {
            var options: Data.WritingOptions = [.atomic]
            #if os(watchOS)
            options.insert(.completeFileProtectionUntilFirstUserAuthentication)
            #endif
            try Data(String(Date().timeIntervalSince1970).utf8).write(to: deletionMarker, options: options)
            var marker = deletionMarker
            var values = URLResourceValues()
            values.isExcludedFromBackup = true
            try marker.setResourceValues(values)
            try FileManager.default.removeItem(at: directory)
            reload()
            return errorMessage == nil
        } catch {
            reload()
            errorMessage = "Reports could not be deleted completely. Inspect the remaining archive."
            return false
        }
    }

    private func read(_ url: URL) throws -> TestReport {
        let values = try url.resourceValues(forKeys: [.fileSizeKey, .isRegularFileKey, .isSymbolicLinkKey])
        guard values.isRegularFile == true, values.isSymbolicLink != true,
              (values.fileSize ?? Int.max) <= 512_000 else { throw TestArchiveError.invalid }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .secondsSince1970
        let report = try decoder.decode(TestReport.self, from: Data(contentsOf: url))
        try report.validate()
        return report
    }
}
