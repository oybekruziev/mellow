import Foundation
import Observation

@MainActor @Observable
final class SessionEngine {
    private(set) var phase: SessionPhase = .ready
    private(set) var remaining: TimeInterval = 0
    private(set) var total: TimeInterval = 0
    private(set) var task = "Focus time"
    private(set) var endDate: Date?
    private(set) var completedAt: Date?
    /// The plan task this focus session belongs to, if it was started from the plan.
    private(set) var planItemID: PlanItem.ID?
    let settings: Settings
    let stats: DailyStats
    @ObservationIgnored private let now: () -> Date
    @ObservationIgnored var onCompletion: ((Bool) -> Void)?

    init(settings: Settings, stats: DailyStats, now: @escaping () -> Date = { .now }) {
        self.settings = settings
        self.stats = stats
        self.now = now
    }
    var progress: Double { total > 0 ? min(1, max(0, 1 - remaining / total)) : 0 }
    var stage: Int { CompanionType.stage(at: progress) }
    var displaySeconds: TimeInterval {
        guard phase == .ready || phase == .breakOver else { return remaining }
        return Double((settings.pendingPlan.first?.minutes ?? settings.focusMinutes) * 60)
    }
    /// 1-based position of the running plan task, with the plan size.
    var planPosition: (index: Int, count: Int)? {
        guard let planItemID, let index = settings.plan.firstIndex(where: { $0.id == planItemID }) else { return nil }
        return (index + 1, settings.plan.count)
    }
    var formattedTime: String { Self.format(displaySeconds, long: displaySeconds > 3600 || total > 3600) }
    static func format(_ seconds: TimeInterval, long: Bool = false) -> String {
        let s = max(0, Int(ceil(seconds)))
        return long ? String(format: "%d:%02d:%02d", s / 3600, s / 60 % 60, s % 60)
            : String(format: "%02d:%02d", s / 60, s % 60)
    }
    func refresh() {
        let date = now()
        stats.resetIfNeeded(at: date)
        guard phase.isRunning, let endDate else { return }
        let left = max(0, endDate.timeIntervalSince(date))
        // Publish only when the displayed second changes: the UI redraws once a second, not on every tick.
        if left == 0 || ceil(left) != ceil(remaining) { remaining = left }
        guard left == 0 else { return }
        let wasBreak = phase.isBreak
        self.endDate = nil
        phase = wasBreak ? .breakOver : .complete
        if !wasBreak {
            stats.earnFlower(at: date)
            completedAt = date
            if let index = settings.plan.firstIndex(where: { $0.id == planItemID }) {
                settings.plan[index].done = true
                // Inside a plan the break starts by itself; the next task waits for the user.
                if !settings.pendingPlan.isEmpty { begin(minutes: settings.breakMinutes, isBreak: true) }
            }
        }
        // NOTE: a focus timer that expires under the end confirmation still earns its flower.
        onCompletion?(wasBreak)
    }
    @discardableResult func send(_ event: SessionEvent) -> Bool {
        refresh()
        switch (phase, event) {
        case (.ready, .startFocus):
            if !startNextPlanItem() {
                let trimmed = settings.lastTask.trimmingCharacters(in: .whitespacesAndNewlines)
                task = trimmed.isEmpty ? "Focus time" : trimmed
                planItemID = nil
                begin(minutes: settings.focusMinutes, isBreak: false)
            }
        case (.focusing(true), .pause): freeze(); phase = .focusing(running: false)
        case (.onBreak(true), .pause): freeze(); phase = .onBreak(running: false)
        case (.focusing(false), .resume): resumeClock(); phase = .focusing(running: true)
        case (.onBreak(false), .resume): resumeClock(); phase = .onBreak(running: true)
        case (.focusing(let running), .requestEnd): phase = .confirmEnd(resumeRunning: running)
        case (.confirmEnd(let running), .keepGoing): phase = .focusing(running: running)
        case (.confirmEnd, .confirmEnd), (.complete, .later): reset()
        case (.complete, .startBreak): begin(minutes: settings.breakMinutes, isBreak: true)
        case (.onBreak, .endBreak): endDate = nil; remaining = 0; phase = .breakOver
        case (.breakOver, .newSession):
            // NOTE: next-session length settings take precedence over the old session length.
            if !startNextPlanItem() { planItemID = nil; begin(minutes: settings.focusMinutes, isBreak: false) }
        default: return false
        }
        return true
    }
    private func startNextPlanItem() -> Bool {
        guard let next = settings.pendingPlan.first else { return false }
        task = next.title
        planItemID = next.id
        begin(minutes: next.minutes, isBreak: false)
        return true
    }
    private func begin(minutes: Int, isBreak: Bool) {
        total = Double(minutes * 60)
        remaining = total
        endDate = now().addingTimeInterval(total)
        phase = isBreak ? .onBreak(running: true) : .focusing(running: true)
    }
    private func freeze() {
        if let endDate { remaining = max(0, endDate.timeIntervalSince(now())) }
        endDate = nil
    }
    private func resumeClock() { endDate = now().addingTimeInterval(remaining) }
    private func reset() {
        phase = .ready; endDate = nil; remaining = 0; total = 0; planItemID = nil
        if !settings.plan.isEmpty && settings.pendingPlan.isEmpty { settings.clearPlan() }
    }
}
