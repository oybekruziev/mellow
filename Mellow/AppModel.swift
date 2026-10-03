import AppKit
import SwiftUI
import Observation

@MainActor @Observable
final class AppModel: NSObject {
    static let shared = AppModel()
    var settings: Settings
    let engine: SessionEngine
    let music: MusicPlayer
    var compact = false
    /// True while the panel is shrinking into (or growing out of) the menu bar.
    var dismissing = false
    var panelVisible = true
    var settingsOpen = false
    var taskFocusRequest = 0
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
        panelController = PanelController(model: self)
        applyAppearance()
        engine.onCompletion = { [weak self] isBreak in
            guard let self else { return }
            if settings.soundOn { playChime() }
            setCompact(false)
            showPanel()
            announce(isBreak ? "Break over" : "Session complete. You grew a flower.")
        }
        ticker = Timer.scheduledTimer(withTimeInterval: 0.25, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.engine.refresh() }
        }
        ticker?.tolerance = 0.05
        if let ticker { RunLoop.main.add(ticker, forMode: .common) }
        NSWorkspace.shared.notificationCenter.addObserver(self, selector: #selector(woke), name: NSWorkspace.didWakeNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(displaysChanged), name: NSApplication.didChangeScreenParametersNotification, object: nil)
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            let handled = MainActor.assumeIsolated { self?.handleKey(event) == nil }
            return handled ? nil : event
        }
        showPanel()
    }
    @objc private func woke() { engine.refresh(); panelController?.clampToScreen() }
    @objc private func displaysChanged() { panelController?.clampToScreen() }
    func showPanel() { panelVisible = true; panelController?.show() }
    func hidePanel() { settingsOpen = false; panelVisible = false; panelController?.hide() }
    func togglePanel() { panelVisible ? hidePanel() : showPanel() }
    func toggleCompact() { settingsOpen = false; setCompact(!compact); showPanel() }
    func setCompact(_ value: Bool) {
        guard compact != value else { return }
        let reduceMotion = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
        withAnimation(reduceMotion ? .easeInOut(duration: 0.15) : .spring(response: 0.42, dampingFraction: 0.82)) { compact = value }
    }
    func openSettings() {
        // Present the popover only once the panel has finished appearing or expanding,
        // otherwise it anchors to a button that is still moving.
        let settle = !panelVisible || compact || dismissing
        setCompact(false)
        showPanel()
        if settle {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in self?.settingsOpen = true }
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
        if engine.phase.isBreak { act(.endBreak) }
        else if engine.send(.requestEnd) { setCompact(false); showPanel() }
    }
    func act(_ event: SessionEvent) {
        guard engine.send(event) else { return }
        switch event {
        case .startFocus, .newSession: announce("Focus started, \(Int(engine.total / 60)) minutes")
        case .startBreak: announce("Break started")
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
            case "l":
                guard engine.phase == .ready else { return event }
                setCompact(false); showPanel(); panelController?.panel.makeKey(); taskFocusRequest += 1
            default: return event
            }
            return nil
        }
        guard NSApp.keyWindow === panelController?.panel else { return event }
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
        if key == " " { primaryAction(); return nil }
        if engine.phase == .ready, let index = ["1", "2", "3"].firstIndex(of: key) {
            settings.focusMinutes = [15, 25, 45][index]; return nil
        }
        return event
    }
}
