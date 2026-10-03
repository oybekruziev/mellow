import Foundation
import Observation

@MainActor @Observable
final class Settings {
    @ObservationIgnored let defaults: UserDefaults
    var focusMinutes: Int { didSet { defaults.set(focusMinutes, forKey: "focusMinutes") } }
    var breakMinutes: Int { didSet { defaults.set(breakMinutes, forKey: "breakMinutes") } }
    var soundOn: Bool { didSet { defaults.set(soundOn, forKey: "soundOn") } }
    var keepOnTop: Bool { didSet { defaults.set(keepOnTop, forKey: "keepOnTop") } }
    var appearance: AppAppearance { didSet { defaults.set(appearance.rawValue, forKey: "appearance") } }
    var companion: CompanionType { didSet { defaults.set(companion.rawValue, forKey: "companion") } }
    var lastTask: String { didSet { defaults.set(lastTask, forKey: "lastTask") } }
    var plan: [PlanItem] { didSet { defaults.set(try? JSONEncoder().encode(plan), forKey: "plan") } }
    var musicDuringFocus: Bool { didSet { defaults.set(musicDuringFocus, forKey: "musicDuringFocus") } }
    var musicVolume: Double { didSet { defaults.set(musicVolume, forKey: "musicVolume") } }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        focusMinutes = min(120, max(1, defaults.object(forKey: "focusMinutes") as? Int ?? 25))
        breakMinutes = min(60, max(1, defaults.object(forKey: "breakMinutes") as? Int ?? 5))
        soundOn = defaults.object(forKey: "soundOn") as? Bool ?? true
        keepOnTop = defaults.object(forKey: "keepOnTop") as? Bool ?? true
        appearance = AppAppearance(rawValue: defaults.string(forKey: "appearance") ?? "") ?? .system
        companion = CompanionType(rawValue: defaults.string(forKey: "companion") ?? "") ?? .plant
        lastTask = defaults.string(forKey: "lastTask") ?? ""
        plan = defaults.data(forKey: "plan").flatMap { try? JSONDecoder().decode([PlanItem].self, from: $0) } ?? []
        musicDuringFocus = defaults.object(forKey: "musicDuringFocus") as? Bool ?? false
        musicVolume = min(1, max(0, defaults.object(forKey: "musicVolume") as? Double ?? 0.6))
    }

    // MARK: Plan editing

    var pendingPlan: [PlanItem] { plan.filter { !$0.done } }

    func addPlanItem(_ title: String, minutes: Int) {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        plan.append(PlanItem(title: trimmed, minutes: min(120, max(1, minutes))))
    }
    func removePlanItem(_ id: PlanItem.ID) { plan.removeAll { $0.id == id } }
    func setMinutes(_ minutes: Int, for id: PlanItem.ID) {
        guard let index = plan.firstIndex(where: { $0.id == id }) else { return }
        plan[index].minutes = min(120, max(1, minutes))
    }
    func clearPlan() { plan.removeAll() }
}
