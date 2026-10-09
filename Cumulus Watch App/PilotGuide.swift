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

struct OvernightGuide: Sendable {
    let title: String
    let instruction: String
    let target: Date?

    init(trial: OvernightMotionTrial, now: Date) {
        let deadline = trial.end.addingTimeInterval(300)
        if trial.clockDiscontinuity || trial.phase == .uncertain {
            title = "Timing uncertain"
            instruction = "Preserve this trial. Do not restart recording. Wait the full reservation before acknowledging it; uncertainty prevents qualification."
            target = nil
        } else if now < trial.reservationEnd {
            title = "Return at the reserved end"
            instruction = "Leave using the Digital Crown. Wear the Watch without charging or other Cumulus trials. Return at the time below; battery is captured before retrieval."
            target = trial.reservationEnd
        } else if trial.mode == .comparison {
            title = "Complete the comparison"
            instruction = "Save actual charging and interruptions and inspect return battery timing. No motion query is needed. A late return, uncertain clock or changed setup cannot provide a matching baseline."
            target = nil
        } else if trial.firstUsefulReadAt != nil {
            title = "Review this recording"
            instruction = "Inspect sample timing, visibility, battery and errors separately. Save actual charging and interruptions. A software pass does not establish sleep staging or alarm reliability."
            target = nil
        } else if now <= deadline {
            title = "Retrieve before the deadline"
            instruction = "Read the whole window now and remain in Cumulus until completion. Retry an incomplete read while time remains. Completion must occur by the time below; do not wait until that time to start."
            target = deadline
        } else {
            title = "Later retrieval is diagnostic"
            instruction = "The five-minute visibility deadline passed. Retrieve now, retry at end + 10 minutes if incomplete, and preserve all attempts. Later useful data cannot prove earlier availability."
            target = now < trial.end.addingTimeInterval(600) ? trial.end.addingTimeInterval(600) : nil
        }
    }
}
