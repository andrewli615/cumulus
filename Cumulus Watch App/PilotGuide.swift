import Foundation

struct PilotGuide: Sendable {
    let title: String
    let instruction: String
    let target: Date?

    init(trial: OvernightMotionTrial, now: Date) {
        let blockEnd = trial.start.addingTimeInterval(600)
        let deadline = blockEnd.addingTimeInterval(240)
        let fullRead = trial.end.addingTimeInterval(300)
        if trial.clockDiscontinuity || trial.phase == .uncertain {
            title = "Timing uncertain"
            instruction = "Clock uncertainty prevents a trustworthy countdown. Preserve the trial and inspect its history."
            target = nil
        } else if now < blockEnd {
            title = "Return at ten minutes"
            instruction = "Leave using the Digital Crown. Return at the time below and read the fixed 9–10-minute block. No automatic probe runs."
            target = blockEnd
        } else if now <= deadline && trial.latestProbe?.useful != true {
            let lastAttempt = trial.observations.last(where: { $0.pilotProbe })
            let next = lastAttempt.map { $0.requestedAt.addingTimeInterval(30) } ?? blockEnd
            title = now < next ? "Next block probe" : "Read the pilot block now"
            instruction = "Repeat the same block every 30 seconds through minute 14. Query completion must fall within that window; starting just before the deadline is insufficient."
            target = min(next, deadline)
        } else if trial.latestProbe?.useful != true, now < fullRead,
                  trial.observations.last(where: { $0.pilotProbe })?.requestedAt ?? .distantPast < trial.start.addingTimeInterval(1200) {
            let sixMinutesAfterBlock = trial.start.addingTimeInterval(960)
            let tenMinutesAfterBlock = trial.start.addingTimeInterval(1200)
            let last = trial.observations.last(where: { $0.pilotProbe })?.requestedAt
            let next = now >= tenMinutesAfterBlock || last.map({ $0 >= sixMinutesAfterBlock }) == true
                ? tenMinutesAfterBlock : sixMinutesAfterBlock
            title = now < next ? "Later diagnostic probe" : "Read a late diagnostic block"
            instruction = "Timely visibility is not established. After a failed early window, probe at minutes 16 and 20. These reads describe later availability; they cannot satisfy the four-minute visibility criterion."
            target = next
        } else if now < fullRead {
            title = "Whole-window read at end + 5 minutes"
            instruction = trial.firstUsefulProbeAt.map { $0 <= deadline } == true && trial.latestProbe?.useful == true
                ? "Early block observed useful. Keep the trial; the full-window criteria still need checking."
                : "Timely block visibility is not established. Continue the full-window read for diagnostics; a later successful probe cannot establish the earlier deadline."
            target = fullRead
        } else {
            title = trial.fullSummary?.meetsTimingCriteria == true ? "Review the recorded criteria" : "Retrieve the whole window"
            instruction = trial.fullSummary == nil ? "Read the full 20-minute window now. Retry at end + 10 minutes if incomplete. Do not start another recording for the retry."
                : "Review timing failures, order anomalies, conditions, and probe history. The guide does not change the experiment criteria or declare overnight feasibility."
            target = trial.fullSummary == nil ? fullRead : nil
        }
    }
}
