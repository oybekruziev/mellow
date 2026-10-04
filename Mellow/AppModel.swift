import AppKit
import SwiftUI
import Observation

@MainActor @Observable
final class AppModel: NSObject {
    static let shared = AppModel()
    var settings: Settings
    let engine: SessionEngine
    let music: MusicPlayer
    let updater = Updater()
    /// Set when Mellow quits to relaunch into an update; the running session was already confirmed.
    @ObservationIgnored var relaunching = false
    var compact = false
    /// First-run setup is showing in the panel.
    var onboarding = false
    /// The plan editor is showing in place of the panel.
    var planEditing = false
    /// True while the panel is shrinking into (or growing out of) the menu bar.
    var dismissing = false
    var panelVisible = true
    var settingsOpen = false
    var taskFocusRequest = 0
    /// Set when ⌘L expands the capsule: the task field is focused once the panel appears.
    @ObservationIgnored var pendingTaskFocus = false
    @ObservationIgnored var panelController: PanelController?
    @ObservationIgnored private var ticker: Timer?
    @ObservationIgnored private var keyMonitor: Any?

    override convenience init() {
        let settings = Settings()
        self.init(settings: settings, engine: SessionEngine(settings: settings, stats: DailyStats()))
    }
    init(settings: Settings, engine: SessionEngine) {
        self.settings = settings
        self.engine = engine
        music = MusicPlayer(volume: settings.musicVolume)
        super.init()
    }
    func start() {
        guard panelController == nil else { return }
        onboarding = !settings.onboarded
        panelController = PanelController(model: self)
        applyAppearance()
        engine.onCompletion = { [weak self] isBreak in
            guard let self else { return }
            if settings.soundOn { playChime() }
            setCompact(false)
            showPanel()
            announce(isBreak ? "Break over" : "Session complete. \(settings.companion.completionTitle)")
        }
        observeRunning()
        updater.isBusy = { [weak self] in self?.engine.phase.isActive ?? false }
        updater.willRelaunch = { [weak self] in self?.relaunching = true }
        updater.start()
        NSWorkspace.shared.notificationCenter.addObserver(self, selector: #selector(woke), name: NSWorkspace.didWakeNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(dayChanged), name: .NSCalendarDayChanged, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(displaysChanged), name: NSApplication.didChangeScreenParametersNotification, object: nil)
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            let handled = MainActor.assumeIsolated { self?.handleKey(event) == nil }
            return handled ? nil : event
        }
        showPanel()
    }
    @objc private func woke() { engine.refresh(); panelController?.clampToScreen() }
    @objc private func dayChanged() { engine.refresh() }
    /// The clock ticks only while a timer runs, so an idle Mellow doesn't wake the CPU.
    private func observeRunning() {
        let running = withObservationTracking { engine.phase.isRunning } onChange: { [weak self] in
            Task { @MainActor in self?.observeRunning() }
        }
        if running, ticker == nil {
            let timer = Timer(timeInterval: 0.25, repeats: true) { [weak self] _ in
                MainActor.assumeIsolated { self?.engine.refresh() }
            }
            timer.tolerance = 0.05
            RunLoop.main.add(timer, forMode: .common)
            ticker = timer
        } else if !running {
            ticker?.invalidate()
            ticker = nil
        }
    }
    @objc private func displaysChanged() { panelController?.clampToScreen() }
    func showPanel() { panelVisible = true; panelController?.show() }
    func hidePanel() {
        settingsOpen = false; panelVisible = false
        // The onboarding music preview has no control once the panel is gone.
        if onboarding && music.isPlaying { music.pause() }
        panelController?.hide()
    }
    func togglePanel() { panelVisible ? hidePanel() : showPanel() }
    func toggleCompact() {
        guard !onboarding else { return }
        settingsOpen = false; setCompact(!compact); showPanel()
    }
    func finishOnboarding() {
        settings.onboarded = true
        if music.isPlaying && !settings.musicDuringFocus { music.pause() }
        withAnimation(morph) { onboarding = false }
    }
    func replayOnboarding() {
        if engine.phase.isActive { return } // never interrupt a running session
        showPanel()
        withAnimation(morph) { compact = false; planEditing = false; onboarding = true }
    }
    /// The plan can be edited whenever no timer is counting down.
    var canEditPlan: Bool { engine.phase == .ready || engine.phase == .breakOver }
    func openPlanEditor() {
        guard canEditPlan, !onboarding else { return }
        settingsOpen = false
        showPanel()
        withAnimation(morph) { compact = false; planEditing = true }
    }
    func closePlanEditor() {
        guard planEditing else { return }
        withAnimation(morph) { planEditing = false }
    }
    static let focusPresets = [15, 25, 45, 60]
    /// The spring used for every panel shape change.
    var morph: Animation {
        NSWorkspace.shared.accessibilityDisplayShouldReduceMotion ? .easeInOut(duration: 0.2) : .spring(duration: 0.5, bounce: 0.14)
    }
    func setCompact(_ value: Bool) {
        guard compact != value else { return }
        withAnimation(morph) { compact = value }
    }
    func openSettings() {
        // Onboarding already shows every setting, and the popover's button isn't on screen.
        guard !onboarding else { showPanel(); return }
        // Present the popover only once the panel has finished appearing or expanding,
        // otherwise it anchors to a button that is still moving.
        let settle = !panelVisible || compact || dismissing || planEditing
        closePlanEditor()
        setCompact(false)
        showPanel()
        if settle {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                guard let self, panelVisible, !compact, !onboarding, !planEditing else { return }
                settingsOpen = true
            }
        } else {
            settingsOpen = true
        }
    }
    /// The compact capsule's single button: the same primary action, but anything that needs
    /// a decision (confirm end, completion) opens the full panel instead.
    func compactAction() {
        switch engine.phase {
        case .confirmEnd, .complete: setCompact(false)
        default: primaryAction()
        }
    }
    func primaryAction() {
        switch engine.phase {
        case .ready: act(.startFocus)
        case .focusing(true), .onBreak(true): act(.pause)
        case .focusing(false), .onBreak(false): act(.resume)
        case .confirmEnd: act(.keepGoing)
        case .complete: act(.startBreak)
        case .breakOver: act(.newSession)
        }
    }
    func endAction() {
        if case .confirmEnd = engine.phase { setCompact(false); showPanel(); return }
        if engine.phase.isBreak { act(.endBreak) }
        else if engine.send(.requestEnd) { setCompact(false); showPanel() }
    }
    func act(_ event: SessionEvent) {
        if onboarding && event == .startFocus { finishOnboarding() }
        guard engine.send(event) else { return }
        switch event {
        case .startFocus, .newSession: announce("Focus started, \(Int(engine.total / 60)) minutes")
        case .startBreak: announce("Break started")
        case .nextTask: announce("Next task: \(engine.task)")
        case .extend: announce("\(SessionEngine.extendMinutes) more minutes")
        default: break
        }
    }
    /// With "Play music during focus" on, music follows a running focus session.
    func syncMusic() {
        guard settings.musicDuringFocus else { return }
        switch engine.phase {
        case .focusing(true), .confirmEnd(true): music.play()
        default: music.pause()
        }
    }
    func applyAppearance() {
        NSApp.appearance = switch settings.appearance {
        case .system: nil
        case .light: NSAppearance(named: .aqua)
        case .dark: NSAppearance(named: .darkAqua)
        }
    }
    func checkForUpdates() {
        settingsOpen = false
        if let release = updater.available { updater.offer(release) }
        else { Task { await updater.check(userInitiated: true) } }
    }
    func playChime() { NSSound(named: "Glass")?.play() }
    func announce(_ text: String) {
        guard let view = panelController?.panel.contentView else { return }
        NSAccessibility.post(element: view, notification: .announcementRequested,
            userInfo: [.announcement: text, .priority: NSAccessibilityPriorityLevel.medium.rawValue])
    }
    private func handleKey(_ event: NSEvent) -> NSEvent? {
        let command = event.modifierFlags.contains(.command)
        let textEditing = NSApp.keyWindow?.firstResponder is NSTextView
        let key = event.charactersIgnoringModifiers ?? ""
        if command {
            switch key {
            case ",": openSettings()
            case "m": toggleCompact()
            case "w": hidePanel()
            case ".": endAction()
            case "q": NSApp.terminate(nil)
            case "p":
                guard canEditPlan, !onboarding else { return event }
                openPlanEditor()
            case "l":
                guard engine.phase == .ready else { return event }
                pendingTaskFocus = compact || planEditing
                closePlanEditor()
                setCompact(false); showPanel(); panelController?.panel.makeKey(); taskFocusRequest += 1
            default: return event
            }
            return nil
        }
        guard NSApp.keyWindow === panelController?.panel, !onboarding else { return event }
        if planEditing {
            if event.keyCode == 53 { closePlanEditor(); return nil }
            return event
        }
        if event.keyCode == 53 {
            if settingsOpen { settingsOpen = false }
            else if case .confirmEnd = engine.phase { act(.keepGoing) }
            else if engine.phase == .complete { act(.later) }
            else { return event }
            return nil
        }
        guard !settingsOpen else { return event }
        if event.keyCode == 36 && !textEditing { primaryAction(); return nil }
        guard !textEditing else { return event }
        // In the end confirmation Space belongs to whichever button has keyboard focus.
        if key == " " {
            if case .confirmEnd = engine.phase { return event }
            primaryAction(); return nil
        }
        if engine.phase == .ready, settings.pendingPlan.isEmpty, let index = ["1", "2", "3", "4"].firstIndex(of: key) {
            settings.focusMinutes = Self.focusPresets[index]; return nil
        }
        return event
    }
}
