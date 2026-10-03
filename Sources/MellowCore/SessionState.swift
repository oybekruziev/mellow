import Foundation

enum SessionPhase: Equatable {
    case ready
    case focusing(running: Bool)
    case confirmEnd(resumeRunning: Bool)
    case complete
    case onBreak(running: Bool)
    case breakOver

    var isRunning: Bool {
        switch self {
        case .focusing(let running), .onBreak(let running), .confirmEnd(let running): running
        default: false
        }
    }
    var isActive: Bool {
        switch self {
        case .focusing, .onBreak, .confirmEnd: true
        default: false
        }
    }
    var isBreak: Bool {
        switch self {
        case .onBreak, .breakOver: true
        default: false
        }
    }
}

enum SessionEvent: CaseIterable {
    case startFocus, pause, resume, requestEnd, keepGoing, confirmEnd
    case startBreak, later, endBreak, newSession
    /// Plan tasks: `finishTask` ends the task early as done, `nextTask` skips the break,
    /// `extend` gives the task that just ran out a few more minutes.
    case finishTask, nextTask, extend
}

enum CompanionType: String, CaseIterable, Identifiable {
    case plant, cat, candle, fox, coffee, moon, cactus
    var id: String { rawValue }
    var title: String { rawValue.capitalized }
    static func stage(at progress: Double) -> Int {
        min(4, max(1, Int(max(0, progress) * 4) + 1))
    }
    var completionTitle: String {
        switch self {
        case .plant: "You grew a flower."
        case .cat: "Your cat woke up."
        case .candle: "The candle burned down."
        case .fox: "Your fox woke up."
        case .coffee: "Your coffee is ready."
        case .moon: "The moon is up."
        case .cactus: "Your cactus bloomed."
        }
    }
    var completionDetail: String {
        self == .plant ? "Nice work. Rest your eyes before the next one." : "Session done — one more flower for today."
    }
}

enum AppAppearance: String, CaseIterable, Identifiable {
    case system, light, dark
    var id: String { rawValue }
    var title: String { rawValue.capitalized }
}

/// One task in the focus plan. A finished task keeps its row (checked) until the plan is cleared.
struct PlanItem: Codable, Identifiable, Equatable {
    var id = UUID()
    var title: String
    var minutes: Int
    var done = false
}
