import SwiftUI

/// The task plan shown in Ready: each task has its own length; breaks run between tasks.
struct PlanList: View {
    @Bindable var settings: Settings
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ScrollView {
                VStack(spacing: 0) {
                    ForEach(Array(settings.plan.enumerated()), id: \.element.id) { offset, item in
                        if offset > 0 { Palette.separator.frame(height: 0.5).padding(.leading, 30) }
                        PlanRow(item: item, number: offset + 1, settings: settings)
                    }
                }
            }
            .scrollIndicators(.never)
            .frame(height: rowsHeight(min(settings.plan.count, 4)))
            .modifier(SectionSurface())
            HStack {
                Text(summary).font(.system(size: 11)).foregroundStyle(Palette.secondary)
                Spacer()
                Button("Clear") { withAnimation(.snappy) { settings.clearPlan() } }
                    .buttonStyle(.plain).font(.system(size: 11, weight: .medium)).foregroundStyle(Palette.secondary)
                    .help("Clear Plan")
            }
            .padding(.horizontal, 4)
        }
    }
    /// Rows are 30 pt with 0.5 pt separators between them; more than four rows scroll.
    private func rowsHeight(_ rows: Int) -> CGFloat { CGFloat(rows) * 30 + CGFloat(max(0, rows - 1)) * 0.5 }
    private var summary: String {
        let pending = settings.pendingPlan
        let focus = pending.reduce(0) { $0 + $1.minutes }
        let total = focus + max(0, pending.count - 1) * settings.breakMinutes
        let duration = total >= 60 ? "\(total / 60)h \(total % 60)m" : "\(total) min"
        let tasks = pending.count == 1 ? "1 task" : "\(pending.count) tasks"
        return pending.count > 1 ? "\(tasks) · \(duration) with breaks" : "\(tasks) · \(duration)"
    }
}

private struct PlanRow: View {
    let item: PlanItem
    let number: Int
    @Bindable var settings: Settings
    @State private var hover = false
    var body: some View {
        HStack(spacing: 8) {
            ZStack {
                Circle().strokeBorder(item.done ? Palette.focus : Palette.secondary.opacity(0.5), lineWidth: 1.2)
                if item.done {
                    Circle().fill(Palette.focus)
                    IconImage(.check, size: 9).foregroundStyle(Palette.onTint)
                } else {
                    Text("\(number)").font(.system(size: 10, weight: .semibold, design: .rounded)).foregroundStyle(Palette.secondary)
                }
            }
            .frame(width: 18, height: 18)
            Text(item.title)
                .font(.system(size: 13)).lineLimit(1).truncationMode(.tail)
                .strikethrough(item.done, color: Palette.secondary)
                .foregroundStyle(item.done ? Palette.secondary : Palette.primary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .help(item.title)
            if hover && !item.done {
                stepButton(.minus, delta: -5)
            }
            Text("\(item.minutes)m").font(.system(size: 12, weight: .medium)).monospacedDigit()
                .foregroundStyle(Palette.secondary)
                .contentTransition(.numericText(value: Double(item.minutes)))
            if hover && !item.done {
                stepButton(.plus, delta: 5)
            }
            Button { withAnimation(.snappy) { settings.removePlanItem(item.id) } } label: {
                IconImage(.close, size: 12).foregroundStyle(Palette.secondary).frame(width: 18, height: 18).contentShape(Rectangle())
            }
            .buttonStyle(.plain).opacity(hover ? 1 : 0).help("Remove Task")
            .accessibilityLabel("Remove \(item.title)")
        }
        .padding(.leading, 8).padding(.trailing, 6)
        .frame(height: 30)
        .contentShape(Rectangle())
        .onHover { hover = $0 }
        .animation(.easeOut(duration: 0.12), value: hover)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("\(item.title), \(item.minutes) minutes\(item.done ? ", done" : "")")
        // Keyboard and VoiceOver users can't hover, so the length is also adjustable directly.
        .accessibilityAdjustableAction { direction in
            guard !item.done else { return }
            switch direction {
            case .increment: settings.setMinutes(item.minutes + 5, for: item.id)
            case .decrement: settings.setMinutes(item.minutes - 5, for: item.id)
            @unknown default: break
            }
        }
    }
    private func stepButton(_ icon: Icon, delta: Int) -> some View {
        Button {
            withAnimation(.snappy(duration: 0.2)) { settings.setMinutes(item.minutes + delta, for: item.id) }
        } label: {
            IconImage(icon, size: 10).foregroundStyle(Palette.secondary).frame(width: 16, height: 18).contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(delta > 0 ? "Longer" : "Shorter")
        .accessibilityLabel(delta > 0 ? "Make \(item.title) longer" : "Make \(item.title) shorter")
    }
}

/// Play/pause + skip for the bundled lofi music.
struct MusicControl: View {
    let music: MusicPlayer
    var body: some View {
        if !music.tracks.isEmpty {
            HStack(spacing: 2) {
                if music.isPlaying {
                    Equalizer().frame(width: 12, height: 10).padding(.trailing, 2)
                        .transition(.opacity.combined(with: .scale(scale: 0.6)))
                    Button { music.next() } label: {
                        IconImage(.skip, size: 11).frame(width: 22, height: 22)
                    }
                    .buttonStyle(ToolbarStyle()).help("Next Track").accessibilityLabel("Next Track")
                }
                Button { withAnimation(.snappy) { music.toggle() } } label: {
                    IconImage(music.isPlaying ? .pause : .music, size: 12).frame(width: 22, height: 22)
                }
                .buttonStyle(ToolbarStyle())
                .help(music.isPlaying ? "Pause Music — \(music.current?.title ?? "")" : "Play Lofi Music")
                .accessibilityLabel(music.isPlaying ? "Pause Music" : "Play Music")
            }
        }
    }
}

private struct Equalizer: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.panelAnimating) private var animating
    var body: some View {
        TimelineView(.animation(minimumInterval: 1 / 12, paused: reduceMotion || !animating)) { context in
            let t = context.date.timeIntervalSinceReferenceDate
            HStack(alignment: .bottom, spacing: 2) {
                ForEach(0..<3) { bar in
                    Capsule().fill(Palette.focus)
                        .frame(width: 2.5, height: 3 + 7 * abs(sin(t * (2.2 + Double(bar) * 0.7) + Double(bar))))
                }
            }
            .frame(maxHeight: .infinity, alignment: .bottom)
        }
        .accessibilityHidden(true)
    }
}
