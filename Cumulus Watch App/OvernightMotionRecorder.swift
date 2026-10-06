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
            let safetyLimit = Int(duration * 100) + 1000
            while cursor < end {
                if cancellation.isCancelled { break }
                let chunkEnd = min(end, cursor.addingTimeInterval(600))
                autoreleasepool {
                    if let list = recorder.accelerometerData(from: cursor, to: chunkEnd) {
                        var seen = 0
                        var iterator = NSFastEnumerationIterator(list)
                        while let object = iterator.next() {
                            if cancellation.isCancelled { break }
                            enumerated += 1
                            if enumerated > safetyLimit { summary.aborted = true; break }
                            guard let sample = object as? CMRecordedAccelerometerData else {
                                summary.unexpectedObjects += 1
                                continue
                            }
                            seen += 1
                            summary.receive(date: sample.startDate, uptime: sample.timestamp,
                                axesFinite: sample.acceleration.x.isFinite && sample.acceleration.y.isFinite && sample.acceleration.z.isFinite,
                                chunkStart: cursor)
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
