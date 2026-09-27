import SwiftUI

struct ContentView: View {
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var motion = MotionMonitor()
    @StateObject private var heart = HeartRateReader()

    private var isMonitoring: Bool {
        motion.isMonitoring || heart.isMonitoring
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                Text("Cumulus").font(.headline)
                Text("Data probe").font(.title3)
                Text(isMonitoring ? "Monitoring requested" : "Collection stopped")
                    .font(.caption)

                Button(isMonitoring ? "Stop monitoring" : "Start monitoring") {
                    if isMonitoring {
                        stop()
                    } else {
                        motion.start()
                        heart.start()
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(!isMonitoring && (heart.isRequestingAccess || scenePhase != .active))

                Text("Foreground only. Stops in the background. No alarm is set.")
                    .font(.caption2)

                Divider()
                motionSection
                Divider()
                heartSection

                Text("Readings stay in memory. Nothing is exported or saved by this probe.")
                    .font(.caption2)
            }
            .padding(.horizontal, 8)
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .background {
                stop(reason: "Stopped on background entry")
            }
        }
    }

    private var motionSection: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text("Motion").font(.headline)
            Text(motion.status).font(.caption)
            if let reading = motion.latest {
                Text("\(motion.isMonitoring ? "Latest" : "Retained") acceleration (g)")
                    .font(.caption2)
                Text(String(format: "x %.3f\ny %.3f\nz %.3f", reading.x, reading.y, reading.z))
                    .monospacedDigit()
                    .accessibilityLabel(String(format: "Acceleration. X %.3f, Y %.3f, Z %.3f g", reading.x, reading.y, reading.z))
                TimelineView(.periodic(from: .now, by: 1)) { _ in
                    // Both timestamps use uptime; no calendar conversion is needed.
                    let age = ProcessInfo.processInfo.systemUptime - reading.timestamp
                    Text(age >= 0 ? String(format: "Sample age: %.1f s", age) : "Sample clock mismatch")
                        .font(.caption2)
                }
            }
            Text("Samples: \(motion.sampleCount)").font(.caption2)
            if let rate = motion.observedRate {
                Text(String(format: "Observed average: %.1f Hz", rate)).font(.caption2)
            }
            Text("Requested: 10 Hz. Includes gravity.").font(.caption2)
        }
    }

    private var heartSection: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text("Heart rate").font(.headline)
            Text(heart.status).font(.caption)
            if let reading = heart.latest {
                Text("\(reading.beatsPerMinute, specifier: "%.0f") bpm")
                    .font(.title3).monospacedDigit()
                Text(heart.isMonitoring ? "Latest readable record" : "Retained record; collection stopped")
                    .font(.caption2)
                TimelineView(.periodic(from: .now, by: 1)) { context in
                    let age = context.date.timeIntervalSince(reading.endDate)
                    Text(age >= 0 ? String(format: "Sample age: %.0f s", age) : "Sample date is in the future")
                        .font(.caption)
                }
                Text("Measured through \(reading.endDate.formatted(date: .omitted, time: .standard))")
                    .font(.caption2)
                Text("Received \(reading.receivedAt.formatted(date: .omitted, time: .standard))")
                    .font(.caption2)
                Text("Source: \(reading.source)").font(.caption2)
            }
            Text("Reads stored heart data. Does not start continuous heart sensing.")
                .font(.caption2)
        }
    }

    private func stop(reason: String = "Stopped") {
        motion.stop(reason: reason)
        heart.stop(reason: reason)
    }
}

#Preview {
    ContentView()
}
