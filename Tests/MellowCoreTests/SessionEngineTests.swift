import Foundation
import Testing
@testable import MellowCore

@MainActor
private final class Fixture {
    var date = Date(timeIntervalSince1970: 1_780_000_000)
    let defaults: UserDefaults
    let settings: Settings
    let stats: DailyStats
    var engine: SessionEngine!
    init() {
        defaults = UserDefaults(suiteName: "MellowTests.\(UUID().uuidString)")!
        settings = Settings(defaults: defaults)
        stats = DailyStats(defaults: defaults, now: date)
        engine = SessionEngine(settings: settings, stats: stats, now: { [unowned self] in self.date })
    }
    func advance(_ seconds: TimeInterval) { date.addTimeInterval(seconds); engine.refresh() }
    func reach(_ phase: SessionPhase) {
        guard phase != .ready else { return }
        engine.send(.startFocus)
        switch phase {
        case .focusing(false): engine.send(.pause)
        case .confirmEnd(let running):
            if !running { engine.send(.pause) }; engine.send(.requestEnd)
        case .complete, .onBreak, .breakOver:
            advance(engine.total)
            if phase != .complete { engine.send(.startBreak) }
            if phase == .onBreak(running: false) { engine.send(.pause) }
            if phase == .breakOver { engine.send(.endBreak) }
        default: break
        }
    }
}

@Suite @MainActor
struct SessionEngineTests {
    @Test func allAllowedAndRejectedTransitions() {
        let transitions: [(SessionPhase, SessionEvent, SessionPhase)] = [
            (.ready, .startFocus, .focusing(running: true)),
            (.focusing(running: true), .pause, .focusing(running: false)),
            (.focusing(running: false), .resume, .focusing(running: true)),
            (.focusing(running: true), .requestEnd, .confirmEnd(resumeRunning: true)),
            (.focusing(running: false), .requestEnd, .confirmEnd(resumeRunning: false)),
            (.confirmEnd(resumeRunning: true), .keepGoing, .focusing(running: true)),
            (.confirmEnd(resumeRunning: false), .keepGoing, .focusing(running: false)),
            (.confirmEnd(resumeRunning: true), .confirmEnd, .ready),
            (.confirmEnd(resumeRunning: false), .confirmEnd, .ready),
            (.complete, .startBreak, .onBreak(running: true)),
            (.complete, .later, .ready),
            (.onBreak(running: true), .pause, .onBreak(running: false)),
            (.onBreak(running: false), .resume, .onBreak(running: true)),
            (.onBreak(running: true), .endBreak, .breakOver),
            (.onBreak(running: false), .endBreak, .breakOver),
            (.breakOver, .newSession, .focusing(running: true))
        ]
        let phases: [SessionPhase] = [.ready, .focusing(running: true), .focusing(running: false),
            .confirmEnd(resumeRunning: true), .confirmEnd(resumeRunning: false), .complete,
            .onBreak(running: true), .onBreak(running: false), .breakOver]
        for phase in phases {
            for event in SessionEvent.allCases {
                let f = Fixture(); f.reach(phase)
                let target = transitions.first { $0.0 == phase && $0.1 == event }?.2
                #expect(f.engine.send(event) == (target != nil), "\(phase) / \(event)")
                #expect(f.engine.phase == (target ?? phase))
            }
        }
    }
    @Test func pauseResumePreservesTime() {
        let f = Fixture(); f.engine.send(.startFocus); f.advance(22.4); f.engine.send(.pause)
        let left = f.engine.remaining
        f.advance(600); #expect(f.engine.remaining == left)
        f.engine.send(.resume); f.advance(1)
        #expect(abs(f.engine.remaining - (left - 1)) < 0.001)
    }
    @Test func sleepCompletionIsExactlyOnceAndBreakNeverEarnsFlower() {
        let f = Fixture(); var completions: [Bool] = []
        f.engine.onCompletion = { completions.append($0) }
        f.engine.send(.startFocus); f.advance(1800)
        #expect(f.engine.phase == .complete); #expect(f.stats.count == 1)
        f.engine.refresh(); #expect(f.stats.count == 1)
        f.engine.send(.startBreak); f.advance(400)
        #expect(f.engine.phase == .breakOver); #expect(f.stats.count == 1)
        #expect(completions == [false, true])
    }
    @Test func confirmingEndKeepsClockAndCompletionWins() {
        let f = Fixture(); f.engine.send(.startFocus); f.engine.send(.requestEnd)
        f.advance(1501); #expect(f.engine.phase == .complete); #expect(f.stats.count == 1)
        #expect(!f.engine.send(.confirmEnd))
    }
    @Test func earlyEndKeepsTaskAndFlowers() {
        let f = Fixture(); f.settings.lastTask = "  Write a chapter  "
        f.engine.send(.startFocus); #expect(f.engine.task == "Write a chapter")
        f.engine.send(.requestEnd); f.engine.send(.confirmEnd)
        #expect(f.stats.count == 0); #expect(f.settings.lastTask == "  Write a chapter  ")
    }
    @Test func emptyTaskAndFormatting() {
        let f = Fixture(); f.settings.lastTask = " \n "
        f.engine.send(.startFocus); #expect(f.engine.task == "Focus time")
        #expect(SessionEngine.format(0.1) == "00:01")
        #expect(SessionEngine.format(0) == "00:00")
        #expect(SessionEngine.format(3661, long: true) == "1:01:01")
    }
    @Test func companionStages() {
        for (progress, expected) in [(0.0, 1), (0.249, 1), (0.25, 2), (0.5, 3), (0.75, 4), (0.999, 4), (1, 4)] {
            #expect(CompanionType.stage(at: progress) == expected)
        }
    }
    @Test func settingsOnlyAffectNextSessionAndPersist() {
        let f = Fixture(); f.engine.send(.startFocus); f.advance(10)
        let end = f.engine.endDate
        f.settings.focusMinutes = 45; f.settings.breakMinutes = 8; f.settings.companion = .candle
        #expect(f.engine.endDate == end); #expect(f.engine.total == 1500)
        #expect(f.engine.remaining == 1490)
        f.advance(1490); f.engine.send(.startBreak); #expect(f.engine.total == 480)
        f.engine.send(.endBreak); f.engine.send(.newSession); #expect(f.engine.total == 2700)
        let restored = Settings(defaults: f.defaults)
        #expect(restored.focusMinutes == 45); #expect(restored.breakMinutes == 8)
        #expect(restored.companion == .candle)
    }
    @Test func midnightResetUsesLocalDate() {
        let f = Fixture()
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 5 * 3600)!
        let night = calendar.date(from: DateComponents(year: 2026, month: 10, day: 3, hour: 23, minute: 59))!
        let stats = DailyStats(defaults: f.defaults, calendar: calendar, now: night)
        stats.earnFlower(at: night); #expect(stats.count == 1)
        stats.resetIfNeeded(at: night.addingTimeInterval(61))
        #expect(stats.count == 0); #expect(stats.dayKey == "2026-10-04")
    }

    @Test func planRunsTasksInOrderWithAutomaticBreaks() {
        let f = Fixture()
        f.settings.breakMinutes = 5
        f.settings.addPlanItem("Write intro", minutes: 10)
        f.settings.addPlanItem("  ", minutes: 10)
        f.settings.addPlanItem("Review", minutes: 20)
        #expect(f.settings.plan.count == 2)
        #expect(f.engine.displaySeconds == 600)

        f.engine.send(.startFocus)
        #expect(f.engine.task == "Write intro" && f.engine.total == 600)
        #expect(f.engine.planPosition?.index == 1 && f.engine.planPosition?.count == 2)

        f.advance(600)
        #expect(f.engine.phase == .onBreak(running: true))
        #expect(f.engine.total == 300 && f.stats.count == 1)
        #expect(f.settings.plan[0].done)

        f.advance(300)
        #expect(f.engine.phase == .breakOver)
        #expect(f.engine.displaySeconds == 1200)
        #expect(f.engine.send(.newSession))
        #expect(f.engine.task == "Review" && f.engine.total == 1200)

        f.advance(1200)
        #expect(f.engine.phase == .complete)
        #expect(f.stats.count == 2)
        f.engine.send(.later)
        #expect(f.settings.plan.isEmpty)
    }

    @Test func endingAPlanTaskEarlyKeepsItPending() {
        let f = Fixture()
        f.settings.addPlanItem("Write intro", minutes: 10)
        f.engine.send(.startFocus)
        f.engine.send(.requestEnd)
        f.engine.send(.confirmEnd)
        #expect(f.engine.phase == .ready)
        #expect(f.settings.pendingPlan.count == 1 && f.stats.count == 0)
    }

    @Test func newSessionAfterAFinishedPlanUsesTheTaskField() {
        let f = Fixture()
        f.settings.addPlanItem("Only task", minutes: 10)
        f.settings.lastTask = "Inbox"
        f.engine.send(.startFocus); f.advance(600)
        #expect(f.engine.phase == .complete)
        f.engine.send(.startBreak); f.engine.send(.endBreak)
        #expect(f.engine.send(.newSession))
        #expect(f.engine.task == "Inbox" && f.settings.plan.isEmpty)
    }

    @Test func sessionThatEndedBeforeMidnightDoesNotCountForTheNextDay() {
        let f = Fixture()
        f.engine.send(.startFocus)
        f.advance(36 * 3600) // the Mac slept through the end and into another day
        #expect(f.engine.phase == .complete)
        #expect(f.stats.count == 0)
    }
}
