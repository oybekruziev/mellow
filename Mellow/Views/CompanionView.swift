import SwiftUI

/// The mascot in the panel (46 pt), the compact capsule (36 pt) and the Settings tiles.
///
/// Every companion is a pair of five-frame sprites from the asset catalog:
/// `<type>-loop-01…05` loops at 5 fps while a focus session runs, and
/// `<type>-wake-01…05` (optional) plays once when the session completes, then holds its last frame.
/// Ready shows loop frame 1; a paused session holds frame 1; a break holds the final pose.
/// On top of the sprites, MascotMotion adds breathing, idle actions, reactions and small effects.
struct CompanionView: View {
    let type: CompanionType
    let phase: SessionPhase
    let progress: Double
    var completedAt: Date? = nil
    var size: CGFloat = 46
    var preview = false
    /// The panel's mascot reacts to the pointer and to clicks.
    var interactive = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.panelAnimating) private var animating
    @State private var wake: Date?
    @State private var poke: Date?
    @State private var hovering = false

    private static let fps = 5.0
    private var sprite: SpriteFrames { SpriteFrames.for(type) }
    private var finished: Bool { phase == .complete || phase.isBreak }
    /// Motion and effects run only where they can be seen.
    private var alive: Bool { !preview && !reduceMotion && animating }
    private var mood: MascotMood {
        switch phase {
        case .focusing(true), .confirmEnd(true): .working
        case .focusing(false), .confirmEnd(false), .onBreak(false): .sleeping
        case .onBreak(true), .complete, .breakOver: .resting
        case .ready: .idle
        }
    }

    var body: some View {
        Group {
            if alive {
                // Smooth while a timer runs, calmer otherwise.
                TimelineView(.animation(minimumInterval: phase.isRunning ? 1 / 24 : 1 / 12)) { context in
                    stage(at: context.date)
                }
            } else {
                art(frame(at: .now))
            }
        }
        .frame(width: size, height: size)
        .scaleEffect(interactive && hovering && alive ? 1.07 : 1, anchor: .bottom)
        .animation(.spring(duration: 0.35, bounce: 0.45), value: hovering)
        .onHover { if interactive { hovering = $0 } }
        .simultaneousGesture(TapGesture().onEnded { poke = .now }, including: interactive && alive ? .all : .subviews)
        .onChange(of: phase.isRunning) { _, running in if running { wake = .now } }
        .animation(.easeOut(duration: 0.25), value: type)
        .accessibilityLabel(type.title)
        .help(tooltip)
    }

    private func stage(at date: Date) -> some View {
        let events = MascotEvents(wake: wake, poke: poke, completed: finished ? completedAt : nil)
        let pose = MascotMotion.pose(type, mood: mood, events: events, at: date, size: size)
        let mood = mood
        return art(frame(at: date))
            .scaleEffect(x: pose.scaleX, y: pose.scaleY, anchor: .bottom)
            .rotationEffect(.degrees(pose.angle), anchor: .bottom)
            .offset(x: pose.dx, y: pose.dy)
            .background {
                Canvas { context, canvas in
                    MascotMotion.drawBack(&context, canvas: canvas, type: type, mood: mood, at: date, size: size)
                }
                .frame(width: size * 2, height: size * 2).allowsHitTesting(false)
            }
            .overlay {
                Canvas { context, canvas in
                    MascotMotion.drawFront(&context, canvas: canvas, type: type, mood: mood, events: events, at: date, size: size)
                }
                .frame(width: size * 2, height: size * 2).allowsHitTesting(false)
            }
    }

    private func frame(at date: Date) -> String {
        if preview || phase == .ready { return sprite.loop[0] }
        if finished {
            let last = sprite.finale.count - 1
            guard !reduceMotion, let completedAt else { return sprite.finale[last] }
            return sprite.finale[min(last, max(0, Int(date.timeIntervalSince(completedAt) * Self.fps)))]
        }
        guard phase.isRunning, !reduceMotion else { return sprite.loop[0] }
        return sprite.loop[Int(date.timeIntervalSinceReferenceDate * Self.fps) % sprite.loop.count]
    }

    private func art(_ name: String) -> some View {
        Image(name).resizable().scaledToFit().frame(width: size, height: size)
            .transition(.opacity)
    }

    private var tooltip: String {
        finished ? type.completionTitle : "\(type.title) · \(Int(progress * 100))% done"
    }
}

struct CompanionMenu: View {
    @Bindable var model: AppModel
    var compact = false
    var body: some View {
        Text("Companion")
        ForEach(CompanionType.allCases) { type in
            Button { model.settings.companion = type } label: {
                if model.settings.companion == type { Label(type.title, systemImage: "checkmark") }
                else { Text(type.title) }
            }
        }
        Divider()
        if compact {
            Button("Open Panel") { model.setCompact(false) }
            Button("Hide Panel") { model.hidePanel() }
            Divider()
        }
        Button("Settings…") { model.openSettings() }
    }
}

/// Frame names for a mascot, resolved once per type.
struct SpriteFrames {
    let loop: [String]
    let finale: [String]

    @MainActor private static var cache: [CompanionType: SpriteFrames] = [:]

    @MainActor static func `for`(_ type: CompanionType) -> SpriteFrames {
        if let cached = cache[type] { return cached }
        func frames(_ prefix: String) -> [String]? {
            let names = (1...5).map { String(format: "%@-%@-%02d", type.rawValue, prefix, $0) }
            return names.allSatisfy { NSImage(named: $0) != nil } ? names : nil
        }
        let loop = frames("loop") ?? ["flower-icon"]
        let sprite = SpriteFrames(loop: loop, finale: frames("wake") ?? loop)
        cache[type] = sprite
        return sprite
    }
}
