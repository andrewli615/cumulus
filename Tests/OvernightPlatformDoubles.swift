import Foundation

#if OVERNIGHT_CHECKS
@MainActor final class WKApplication {
    enum State { case active, inactive, background }
    static let instance = WKApplication()
    static func shared() -> WKApplication { instance }
    var applicationState = State.active
}
@MainActor final class WKInterfaceDevice {
    static let instance = WKInterfaceDevice()
    static func current() -> WKInterfaceDevice { instance }
    var systemVersion = "Synthetic"
    var isBatteryMonitoringEnabled = false
    var batteryReadDelay: TimeInterval = 0
    private var storedBatteryLevel: Float = 0.8
    var batteryLevel: Float {
        get {
            if batteryReadDelay > 0 { Thread.sleep(forTimeInterval: batteryReadDelay) }
            return storedBatteryLevel
        }
        set { storedBatteryLevel = newValue }
    }
}
#endif

enum CMAuthorizationStatus: Sendable { case authorized, denied, restricted, notDetermined }
struct CMAcceleration: Sendable { let x: Double; let y: Double; let z: Double }
struct CMRecordedAccelerometerData: Sendable {
    let startDate: Date
    let timestamp: TimeInterval
    let acceleration: CMAcceleration
    var identifier: UInt64 = 0
}

// These doubles exercise the real streaming worker, not hardware or Core Motion delivery.
final class SyntheticRecorder: @unchecked Sendable {
    enum Output: Sendable { case uniform, startExclusive, dateAnomalies, wallDateStep, sensorRepeat, sensorGap, clockJump, transitionAnomaly, empty, missing, unexpected, excessive, slow }
    static let shared = SyntheticRecorder()
    private let lock = NSLock()
    private var available = true
    private var authorization = CMAuthorizationStatus.authorized
    private var output = Output.uniform
    private var records: [(duration: TimeInterval, date: Date)] = []
    private var recordDelay: TimeInterval = 0
    private var queries: [(Date, Date)] = []
    func configure(available: Bool = true, authorization: CMAuthorizationStatus = .authorized, output: Output = .uniform,
                   recordDelay: TimeInterval = 0) {
        lock.withLock {
            self.available = available; self.authorization = authorization; self.output = output
            self.recordDelay = recordDelay; records = []; queries = []
        }
    }
    func access() -> (Bool, CMAuthorizationStatus) { lock.withLock { (available, authorization) } }
    func record(_ duration: Double) {
        let delay = lock.withLock { records.append((duration, Date())); return recordDelay }
        if delay > 0 { Thread.sleep(forTimeInterval: delay) }
    }
    var recordCount: Int { lock.withLock { records.count } }
    var firstRecordDate: Date? { lock.withLock { records.first?.date } }
    var queryCount: Int { lock.withLock { queries.count } }
    var maximumQuery: Double { lock.withLock { queries.map { $0.1.timeIntervalSince($0.0) }.max() ?? 0 } }
    func data(from start: Date, to end: Date) -> [Any]? {
        let kind = lock.withLock { queries.append((start, end)); return output }
        if kind == .missing { return nil }
        if kind == .empty { return [] }
        if kind == .unexpected { return ["Unexpected object"] }
        if kind == .slow { Thread.sleep(forTimeInterval: 0.04) }
        let rate = kind == .excessive ? 200.0 : 50.0
        let firstIndex = kind == .startExclusive ? 1 : 0
        let queryIndex = queryCount
        let windowStart = lock.withLock { queries[0].0 }
        return (firstIndex...Int(end.timeIntervalSince(start) * rate)).map { index in
            let date = start.addingTimeInterval(Double(index) / rate)
            var measurementDate = date
            if kind == .dateAnomalies {
                if index == 20 { measurementDate = start.addingTimeInterval(Double(index - 1) / rate) }
                if index == 40 { measurementDate = start.addingTimeInterval(Double(index - 2) / rate) }
            }
            if kind == .wallDateStep, date.timeIntervalSince(windowStart) >= 2 { measurementDate = date.addingTimeInterval(-0.06) }
            if kind == .clockJump, date.timeIntervalSince(windowStart) >= 2 { measurementDate = date.addingTimeInterval(-1.1) }
            if kind == .transitionAnomaly, queryIndex == 2, index == 0 {
                measurementDate = date.addingTimeInterval(-1 / rate)
            }
            var sensorTime = kind == .transitionAnomaly && queryIndex == 2 && index == 0
                ? date.timeIntervalSince1970 + 1 / rate : date.timeIntervalSince1970
            if kind == .sensorRepeat, index == 1000 { sensorTime -= 1 / rate }
            return CMRecordedAccelerometerData(startDate: measurementDate, timestamp: sensorTime,
                acceleration: CMAcceleration(x: 0, y: 0, z: 1),
                identifier: UInt64(index / 100))
        }.enumerated().filter { kind != .sensorGap || !(1000...1150).contains($0.offset) }.map(\.element)
    }
}
final class CMSensorRecorder {
    static func authorizationStatus() -> CMAuthorizationStatus { SyntheticRecorder.shared.access().1 }
    static func isAccelerometerRecordingAvailable() -> Bool { SyntheticRecorder.shared.access().0 }
    func recordAccelerometer(forDuration duration: Double) { SyntheticRecorder.shared.record(duration) }
    func accelerometerData(from start: Date, to end: Date) -> NSArray? {
        SyntheticRecorder.shared.data(from: start, to: end).map { $0 as NSArray }
    }
}
final class CMMotionActivityManager {
    static func isActivityAvailable() -> Bool { true }
    func queryActivityStarting(from start: Date, to end: Date, to queue: OperationQueue,
                              withHandler handler: @escaping @Sendable ([Int]?, Error?) -> Void) { handler([], nil) }
}
