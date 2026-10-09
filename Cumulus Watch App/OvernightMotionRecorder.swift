import CoreMotion
import Foundation

final class OvernightRetrievalCancellation: @unchecked Sendable {
    private let lock = NSLock()
    private var stopped = false
    func cancel() { lock.lock(); stopped = true; lock.unlock() }
    var isCancelled: Bool { lock.lock(); defer { lock.unlock() }; return stopped }
}

struct OvernightRecorderAccess: Sendable {
    let available: Bool
    let authorization: String
    var canRecord: Bool { available && authorization == "Authorized" }
}

struct OvernightRetrievalResult: Sendable {
    let summary: OvernightMotionSummary
    let completedAt: Date
    let cancelled: Bool
    let error: String?
}

final class OvernightMotionRecorder: @unchecked Sendable {
    private let recorder = CMSensorRecorder()
    private let activity = CMMotionActivityManager()
    private let queue = DispatchQueue(label: "Cumulus.overnightRetrieval", qos: .utility)

    func access() -> OvernightRecorderAccess {
        let status: String
        switch CMSensorRecorder.authorizationStatus() {
        case .authorized: status = "Authorized"
        case .denied: status = "Denied"
        case .restricted: status = "Restricted"
        case .notDetermined: status = "Not determined"
        @unknown default: status = "Unknown"
        }
        return OvernightRecorderAccess(available: CMSensorRecorder.isAccelerometerRecordingAvailable(), authorization: status)
    }

    func requestAccess(completion: @escaping @Sendable (String?) -> Void) {
        guard CMMotionActivityManager.isActivityAvailable() else {
            completion("Activity access request unavailable; check Motion & Fitness settings and the foreground probe.")
            return
        }
        let now = Date()
        activity.queryActivityStarting(from: now.addingTimeInterval(-1), to: now, to: .main) { _, error in
            completion(error?.localizedDescription)
        }
    }

    func record(duration: TimeInterval) { recorder.recordAccelerometer(forDuration: duration) }

    func retrieve(start: Date, end: Date, cancellation: OvernightRetrievalCancellation,
                  progress: @escaping @Sendable (Int, Int) -> Void,
                  completion: @escaping @Sendable (OvernightRetrievalResult) -> Void) {
        queue.async { [self] in
            var summary = OvernightMotionSummary(start: start, end: end)
            let duration = end.timeIntervalSince(start)
            guard duration > 0, duration <= 28800 else {
                completion(OvernightRetrievalResult(summary: summary, completedAt: Date(), cancelled: false, error: "Invalid retrieval window"))
                return
            }
            let total = Int(ceil(duration / 600))
            var cursor = start
            var chunks = 0
            var enumerated = 0
            var previousAcceptedQueryIndex: Int?
            let safetyLimit = Int(duration * 100) + 1000
            while cursor < end {
                if cancellation.isCancelled { break }
                let chunkEnd = min(end, cursor.addingTimeInterval(600))
                autoreleasepool {
                    if let list = recorder.accelerometerData(from: cursor, to: chunkEnd) {
                        var seen = 0
                        var previousInput: (date: Date, uptime: TimeInterval, batch: UInt64)?
                        var iterator = NSFastEnumerationIterator(list)
                        while let object = iterator.next() {
                            if cancellation.isCancelled { break }
                            enumerated += 1
                            if enumerated > safetyLimit { summary.aborted = true; break }
                            guard let sample = object as? CMRecordedAccelerometerData else {
                                summary.unexpectedObjects += 1
                                previousInput = nil
                                continue
                            }
                            seen += 1
                            // Copy the API values before the accumulator filters or rejects a row.
                            let date = sample.startDate
                            let uptime = sample.timestamp
                            let batch = sample.identifier
                            let axes = sample.acceleration
                            let finite = date.timeIntervalSince1970.isFinite && uptime.isFinite && uptime >= 0
                            let failsOrder = summary.last.map { date <= $0 } == true
                                || summary.lastUptime.map { uptime <= $0 } == true
                            let input = finite && failsOrder ? previousInput.map {
                                OvernightMotionSummary.InputComparison(dateDelta: date.timeIntervalSince($0.date),
                                    sensorDelta: uptime - $0.uptime, batchChanged: batch != $0.batch,
                                    gettersStable: sample.startDate == date && sample.timestamp == uptime)
                            } : nil
                            defer { previousInput = finite ? (date, uptime, batch) : nil }
                            let previousCount = summary.count
                            let position = previousAcceptedQueryIndex.map {
                                OvernightMotionSummary.QueryPosition(queryIndex: chunks + 1, sampleIndex: seen,
                                    previousAcceptedQueryIndex: $0)
                            }
                            summary.receive(date: date, uptime: uptime,
                                axesFinite: axes.x.isFinite && axes.y.isFinite && axes.z.isFinite,
                                chunkStart: cursor, position: position, inputComparison: input)
                            if summary.count > previousCount { previousAcceptedQueryIndex = chunks + 1 }
                        }
                        if seen == 0 { summary.emptyChunks += 1 }
                    } else { summary.nilChunks += 1 }
                }
                chunks += 1
                progress(chunks, total)
                if summary.aborted { break }
                cursor = chunkEnd
            }
            completion(OvernightRetrievalResult(summary: summary, completedAt: Date(), cancelled: cancellation.isCancelled,
                error: summary.aborted ? "Enumeration safety limit reached; evidence incomplete" : nil))
        }
    }
}
