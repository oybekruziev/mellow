import Foundation
import Observation

@MainActor @Observable
final class DailyStats {
    private(set) var count: Int
    private(set) var dayKey: String
    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored private let calendar: Calendar

    init(defaults: UserDefaults = .standard, calendar: Calendar = .autoupdatingCurrent, now: Date = .now) {
        self.defaults = defaults
        self.calendar = calendar
        count = max(0, defaults.integer(forKey: "todayCount"))
        dayKey = defaults.string(forKey: "todayKey") ?? ""
        resetIfNeeded(at: now)
    }
    private func key(for date: Date) -> String {
        let c = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", c.year!, c.month!, c.day!)
    }
    func resetIfNeeded(at date: Date) {
        let next = key(for: date)
        guard dayKey != next else { return }
        dayKey = next
        count = 0
        save()
    }
    func earnFlower(at date: Date) {
        resetIfNeeded(at: date)
        count += 1
        save()
    }
    private func save() {
        defaults.set(count, forKey: "todayCount")
        defaults.set(dayKey, forKey: "todayKey")
    }
    var label: String {
        count == 0 ? "No flowers yet today" : "\(count) \(count == 1 ? "session" : "sessions") today"
    }
}
