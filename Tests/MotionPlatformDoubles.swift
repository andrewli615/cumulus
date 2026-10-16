import Foundation

struct CMAcceleration: Sendable { let x: Double; let y: Double; let z: Double }
struct CMAccelerometerData: Sendable { let acceleration: CMAcceleration; let timestamp: TimeInterval }
@MainActor final class CMMotionManager {
    static var latest: CMMotionManager?
    var isAccelerometerAvailable = true
    var accelerometerUpdateInterval: TimeInterval = 0
    var callback: (@Sendable (CMAccelerometerData?, Error?) -> Void)?
    var stops = 0
    var starts = 0
    init() { Self.latest = self }
    func startAccelerometerUpdates(to queue: OperationQueue, withHandler callback: @escaping @Sendable (CMAccelerometerData?, Error?) -> Void) {
        starts += 1
        self.callback = callback
    }
    func stopAccelerometerUpdates() { stops += 1 }
}
