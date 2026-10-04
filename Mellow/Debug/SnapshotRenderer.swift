#if DEBUG
import AppKit
import SwiftUI

/// Debug-only: `MELLOW_SNAPSHOT_DIR=/path Mellow` renders every panel state to PNG and quits.
@MainActor
enum SnapshotRenderer {
    static func runIfRequested() -> Bool {
        guard let dir = ProcessInfo.processInfo.environment["MELLOW_SNAPSHOT_DIR"] else { return false }
        FileHandle.standardError.write(Data("snapshot -> \(dir)\n".utf8))
        let url = URL(fileURLWithPath: dir)
        let dark = ProcessInfo.processInfo.environment["MELLOW_SNAPSHOT_DARK"] != nil
        let suite = "uz.oybek.Mellow.snapshot"
        let scenarios: [(String, [SessionEvent], TimeInterval)] = [
            ("1-ready", [], 0), ("2-focus", [.startFocus], 322), ("3-paused", [.startFocus], 322),
            ("4-confirm", [.startFocus, .requestEnd], 322), ("5-complete", [.startFocus], 1501),
            ("6-break", [.startFocus], 1501), ("7-breakover", [.startFocus], 1501),
            ("10-plan", [], 0), ("11-plan-break", [.startFocus], 1501),
            ("14-edge-long", [.startFocus], 5),
            ("15-plan-choose", [.startFocus], 1501), ("16-plan-focus-long", [.startFocus], 5),
        ]
        for (name, events, advance) in scenarios {
            var clock = Date(timeIntervalSinceReferenceDate: 800_000_000)
            // One scratch domain, wiped before every scenario and after the run.
            let defaults = UserDefaults(suiteName: suite)!
            defaults.removePersistentDomain(forName: suite)
            defaults.set(3, forKey: "todayCount")
            let settings = Settings(defaults: defaults)
            settings.lastTask = name == "1-ready" ? "" : "Finish the article"
            let stats = DailyStats(defaults: defaults, now: clock)
            stats.earnFlower(at: clock); stats.earnFlower(at: clock); stats.earnFlower(at: clock)
            if name.contains("plan") {
                settings.lastTask = ""
                settings.addPlanItem("Write the intro", minutes: 25)
                settings.addPlanItem("Reply to design feedback", minutes: 15)
                settings.addPlanItem("Review pull request", minutes: 45)
            }
            if name == "15-plan-choose" { settings.planAutoBreak = false }
            if name == "16-plan-focus-long" { settings.setMinutes(120, for: settings.plan[0].id) }
            if name == "14-edge-long" {
                settings.focusMinutes = 120
                settings.lastTask = "Write the quarterly investor update and reply to every single comment in the doc"
                for _ in 0..<9 { stats.earnFlower(at: clock) }
            }
            let engine = SessionEngine(settings: settings, stats: stats, now: { clock })
            events.forEach { engine.send($0) }
            clock += advance; engine.refresh()
            if name == "3-paused" { engine.send(.pause) }
            if name == "6-break" { engine.send(.startBreak); clock += 1; engine.refresh() }
            if name == "7-breakover" { engine.send(.startBreak); engine.send(.endBreak) }
            let model = AppModel(settings: settings, engine: engine)
            render(PanelView(model: model), to: url.appending(path: "\(name).png"), dark: dark)
            if name == "2-focus" {
                model.compact = true
                render(CompactView(model: model), to: url.appending(path: "8-compact.png"), dark: dark)
            }
            if name == "10-plan" {
                // Ten tasks: names and times for each, scrolled list.
                for i in 4...10 { settings.addPlanItem("Task \(i)", minutes: 25) }
                render(PlanEditorView(model: model).background { GlassBackground() },
                       to: url.appending(path: "17-plan-editor.png"), dark: dark)
                settings.clearPlan()
                render(PlanEditorView(model: model).background { GlassBackground() },
                       to: url.appending(path: "18-plan-editor-new.png"), dark: dark)
            }
            if name == "1-ready" {
                render(SettingsView(model: model).background(.regularMaterial, in: .rect(cornerRadius: 26)),
                       to: url.appending(path: "9-settings.png"), dark: dark)
            }
        }
        // All mascots side by side: loop frame 1, mid-loop, and the last finale frame.
        let grid = VStack(alignment: .leading, spacing: 6) {
            ForEach(CompanionType.allCases) { type in
                HStack(spacing: 6) {
                    Text(type.title).font(.system(size: 11)).frame(width: 50, alignment: .leading)
                    ForEach(1...5, id: \.self) { i in
                        Image(String(format: "%@-loop-%02d", type.rawValue, i)).resizable().frame(width: 56, height: 56)
                    }
                    ForEach(1...5, id: \.self) { i in
                        Image(String(format: "%@-wake-%02d", type.rawValue, i)).resizable().frame(width: 56, height: 56)
                    }
                }
            }
        }
        render(grid.padding(12).background(.white), to: url.appending(path: "12-mascots.png"), dark: false)
        // Motion filmstrip: a poke hop over 0.8 s, then asleep, resting, and the petal burst.
        let base = Date(timeIntervalSinceReferenceDate: 800_000_003)
        let motion = VStack(alignment: .leading, spacing: 4) {
            ForEach(CompanionType.allCases) { type in
                HStack(spacing: 2) {
                    Text(type.title).font(.system(size: 11)).frame(width: 50, alignment: .leading)
                    ForEach(0..<6, id: \.self) { i in
                        motionFrame(type, .working, MascotEvents(poke: base), base.addingTimeInterval(Double(i) * 0.14))
                    }
                    motionFrame(type, .sleeping, MascotEvents(), base.addingTimeInterval(1))
                    motionFrame(type, .working, MascotEvents(), base.addingTimeInterval(2.3))
                    motionFrame(type, .resting, MascotEvents(completed: base), base.addingTimeInterval(0.5))
                }
            }
        }
        render(motion.padding(12).background(.white), to: url.appending(path: "19-motion.png"), dark: false)
        // Onboarding pages.
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        let settings = Settings(defaults: defaults)
        settings.companion = .fox
        let model = AppModel(settings: settings, engine: SessionEngine(settings: settings, stats: DailyStats(defaults: defaults)))
        for step in 0..<4 {
            render(OnboardingView(model: model, step: step).background { GlassBackground() },
                   to: url.appending(path: "13-onboarding-\(step + 1).png"), dark: dark)
        }
        UserDefaults.standard.removePersistentDomain(forName: suite)
        return true
    }

    private static func motionFrame(_ type: CompanionType, _ mood: MascotMood, _ events: MascotEvents, _ date: Date) -> some View {
        let size: CGFloat = 46
        let pose = MascotMotion.pose(type, mood: mood, events: events, at: date, size: size)
        return Image(String(format: "%@-loop-01", type.rawValue)).resizable().scaledToFit().frame(width: size, height: size)
            .scaleEffect(x: pose.scaleX, y: pose.scaleY, anchor: .bottom)
            .rotationEffect(.degrees(pose.angle), anchor: .bottom)
            .offset(x: pose.dx, y: pose.dy)
            .background { Canvas { c, s in MascotMotion.drawBack(&c, canvas: s, type: type, mood: mood, at: date, size: size) }.frame(width: 92, height: 92) }
            .overlay { Canvas { c, s in MascotMotion.drawFront(&c, canvas: s, type: type, mood: mood, events: events, at: date, size: size) }.frame(width: 92, height: 92) }
            .frame(width: 70, height: 84)
    }

    /// MELLOW_SNAPSHOT_BG=white|black puts the panel on a flat backdrop to check contrast.
    private static func backdrop(dark: Bool) -> AnyView {
        switch ProcessInfo.processInfo.environment["MELLOW_SNAPSHOT_BG"] {
        case "white": AnyView(Color.white)
        case "black": AnyView(Color.black)
        default: AnyView(LinearGradient(colors: dark ? [.indigo.opacity(0.6), .black] : [.gray.opacity(0.55), .gray.opacity(0.4)],
                                        startPoint: .topLeading, endPoint: .bottomTrailing))
        }
    }

    private static func render(_ view: some View, to url: URL, dark: Bool) {
        let content = view
            .padding(32)
            .background(backdrop(dark: dark))
            .environment(\.colorScheme, dark ? .dark : .light)
            .foregroundStyle(Palette.primary)
        let host = NSHostingView(rootView: content)
        host.appearance = NSAppearance(named: dark ? .darkAqua : .aqua)
        host.frame.size = host.fittingSize
        let window = NSWindow(contentRect: host.frame, styleMask: [.borderless], backing: .buffered, defer: false)
        window.contentView = host
        host.layoutSubtreeIfNeeded()
        // cacheDisplay renders Liquid Glass (ImageRenderer does not), but its CPU rasterizer
        // draws a stray 1 px tick at the ends of thin capsule strokes. The live app does not.
        guard let rep = host.bitmapImageRepForCachingDisplay(in: host.bounds) else { return }
        host.cacheDisplay(in: host.bounds, to: rep)
        do { try rep.representation(using: .png, properties: [:])?.write(to: url) } catch { FileHandle.standardError.write(Data("\(error)\n".utf8)) }
    }
}
#endif
