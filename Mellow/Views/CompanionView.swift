import SwiftUI

/// The mascot in the panel (46 pt), the compact capsule (36 pt) and the Settings tiles.
///
/// Every companion is a pair of five-frame sprites from the asset catalog:
/// `<type>-loop-01…05` loops at 5 fps while a focus session runs, and
/// `<type>-wake-01…05` (optional) plays once when the session completes, then holds its last frame.
/// Ready shows loop frame 1; a paused session holds frame 1; a break holds the final pose.
struct CompanionView: View {
    let type: CompanionType
    let phase: SessionPhase
    let progress: Double
    var completedAt: Date? = nil
    var size: CGFloat = 46
    var preview = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private static let fps = 5.0
    private var sprite: SpriteFrames { SpriteFrames.for(type) }
    private var finished: Bool { phase == .complete || phase.isBreak }

    var body: some View {
        Group {
            if !preview, !reduceMotion, phase.isRunning, !finished {
                // Redraw only at the sprite's frame rate.
                TimelineView(.periodic(from: .now, by: 1 / Self.fps)) { context in art(frame(at: context.date)) }
            } else if !preview, !reduceMotion, finished, let completedAt,
                      Date.now.timeIntervalSince(completedAt) < Double(sprite.finale.count) / Self.fps {
                // The finale: one redraw per frame, then it stops on the last pose.
                TimelineView(.explicit((0...sprite.finale.count).map { completedAt.addingTimeInterval(Double($0) / Self.fps) })) { context in
                    art(frame(at: context.date))
                }
            } else {
                art(frame(at: .now))
            }
        }
        .frame(width: size, height: size)
        .animation(.easeOut(duration: 0.25), value: type)
        .accessibilityLabel(type.title)
        .help(tooltip)
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
