import Combine
import Foundation

@MainActor
final class AlarmTrialStore: ObservableObject {
    let archive: TestArchiveStore
    @Published private(set) var errorMessage: String?
    private let now: () -> Date

    init(archive: TestArchiveStore, now: @escaping () -> Date = Date.init) {
        self.archive = archive
        self.now = now
    }

    func load(_ id: UUID) throws -> AlarmTrial {
        try AlarmTrial.decode(archive.report(id: "fixedalarm-" + id.uuidString.lowercased()))
    }

    @discardableResult
    func capture(_ record: AlarmRecord, importing: Bool = false) -> Bool {
        do {
            let id = "fixedalarm-" + record.id.uuidString.lowercased()
            let trial: AlarmTrial
            if archive.reports.contains(where: { $0.id == id }) {
                var saved = try load(record.id)
                guard try saved.merge(record, capturedAt: now()) else { errorMessage = nil; return true }
                trial = saved
            } else { trial = try AlarmTrial(record: record, capturedAt: now()) }
            let saved = archive.save(try trial.report(), importing: importing)
            // Suppression by a deletion marker is intentional, not a failed alarm.
            if importing, !saved, archive.errorMessage == nil { errorMessage = nil; return true }
            errorMessage = saved ? nil : "Trial report not saved. Live alarm state is separate. Check Saved tests storage."
            return saved
        } catch AlarmTrialError.invalid {
            errorMessage = "Alarm trial identity or evidence could not be verified. Previous report preserved."
        } catch AlarmStorageError.invalid {
            errorMessage = "Alarm evidence has an invalid format. Previous report preserved."
        } catch is DecodingError {
            errorMessage = "Saved alarm trial could not be decoded. Previous report preserved."
        } catch is EncodingError {
            errorMessage = "Alarm trial could not be encoded. Previous report preserved."
        } catch {
            errorMessage = "Alarm trial could not be read or saved. Live alarm state is separate."
        }
        return false
    }

    @discardableResult
    func saveObservations(_ value: AlarmTrial.Observations, for id: UUID, expectedRevision: UUID?) -> Bool {
        do {
            var trial = try load(id)
            try trial.setObservations(value, expectedRevision: expectedRevision, at: now())
            guard archive.save(try trial.report()) else {
                errorMessage = "Observations were not saved. Previous report preserved; check Saved tests storage."
                return false
            }
            errorMessage = nil
            return true
        } catch AlarmTrialError.conflict {
            errorMessage = "Observations changed since this form opened. Go back and reopen before editing."
        } catch AlarmTrialError.invalid {
            errorMessage = "Check battery percentages, observation order and the 200-character settings note."
        } catch is DecodingError {
            errorMessage = "Saved alarm trial could not be decoded. Your draft has not been saved."
        } catch is EncodingError {
            errorMessage = "Observations could not be encoded. Your draft has not been saved."
        } catch {
            errorMessage = "Saved trial is unavailable. Your draft has not been saved."
        }
        return false
    }
}
