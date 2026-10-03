import SwiftUI
import AppKit

enum Palette {
    static let primary = Color("labelPrimary")
    static let secondary = Color("labelSecondary")
    static let tertiary = Color("labelTertiary")
    static let focus = Color("tintFocus")
    static let focusPressed = Color("tintFocusPressed")
    static let rest = Color("tintBreak")
    static let onTint = Color("onTint")
    static let separator = Color("separator")
    static let track = Color("progressTrack")

    // Translucent fills from the Figma glass layers. Dark values keep the same hierarchy over a dark backdrop.
    static let panelWash = Color(light: .white.withAlphaComponent(0.30), dark: .white.withAlphaComponent(0.03))
    static let panelEdge = Color(light: .white.withAlphaComponent(0.65), dark: .white.withAlphaComponent(0.15))
    static let control = Color(light: .white.withAlphaComponent(0.75), dark: .white.withAlphaComponent(0.13))
    static let controlEdge = Color(light: .white.withAlphaComponent(0.70), dark: .white.withAlphaComponent(0.12))
    static let field = Color(light: .white.withAlphaComponent(0.42), dark: .white.withAlphaComponent(0.07))
    static let section = Color(light: .white.withAlphaComponent(0.55), dark: .white.withAlphaComponent(0.06))
    static let segmentTrack = Color(light: .black.withAlphaComponent(0.06), dark: .white.withAlphaComponent(0.08))
    static let segmentThumb = Color(light: .white.withAlphaComponent(0.95), dark: .white.withAlphaComponent(0.22))
    static let hover = Color(light: .black.withAlphaComponent(0.06), dark: .white.withAlphaComponent(0.10))
    static let tile = Color(light: .white.withAlphaComponent(0.35), dark: .white.withAlphaComponent(0.05))
    static let tileSelected = Color(light: .white.withAlphaComponent(0.85), dark: .white.withAlphaComponent(0.14))
}

extension Color {
    init(light: NSColor, dark: NSColor) {
        self.init(nsColor: NSColor(name: nil) { appearance in
            appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua ? dark : light
        })
    }
}

enum Icon: String {
    case settings, compact, hide, play, pause, stop, check, cup, close, minus, plus
    case music, skip, expand, instagram, linkedin, x, threads, globe, mail
}

struct IconImage: View {
    let icon: Icon
    var size: CGFloat = 14
    init(_ icon: Icon, size: CGFloat = 14) { self.icon = icon; self.size = size }
    var body: some View {
        Image("icon-\(icon.rawValue)").renderingMode(.template).resizable().scaledToFit()
            .frame(width: size, height: size).accessibilityHidden(true)
    }
}

// MARK: - Surfaces

struct GlassSurface: ViewModifier {
    var radius: CGFloat = 26
    /// Shared by the panel and the compact capsule so the glass morphs between them.
    var namespace: Namespace.ID? = nil
    func body(content: Content) -> some View {
        content.background {
            if let namespace {
                GlassBackground(radius: radius).matchedGeometryEffect(id: "glass", in: namespace)
            } else {
                GlassBackground(radius: radius)
            }
        }
    }
}

struct GlassBackground: View {
    var radius: CGFloat = 26
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    var body: some View {
        let shape = RoundedRectangle(cornerRadius: radius, style: .continuous)
        ZStack {
            if reduceTransparency {
                shape.fill(Color(nsColor: .windowBackgroundColor))
            } else {
                shape.fill(Palette.panelWash).glassEffect(.regular, in: shape)
            }
            shape.strokeBorder(Palette.panelEdge, lineWidth: 0.75)
        }
        .compositingGroup()
        .shadow(color: .black.opacity(0.16), radius: 16, x: 0, y: 12)
        .shadow(color: .black.opacity(0.10), radius: 3, x: 0, y: 2)
    }
}

/// Grouped inset section used by Settings.
struct SectionSurface: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(Palette.section, in: .rect(cornerRadius: 14, style: .continuous))
            .overlay { RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(Palette.controlEdge, lineWidth: 0.5) }
    }
}

// MARK: - Buttons

/// Prominent tinted control: the single primary action of a view.
struct TintedStyle: ButtonStyle {
    var tint: Color = Palette.focus
    var pressScale: CGFloat = 0.96
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(Palette.onTint)
            .background {
                Capsule().fill(tint).brightness(configuration.isPressed ? -0.08 : 0)
                    .shadow(color: .black.opacity(0.16), radius: 4, x: 0, y: 3)
            }
            .overlay {
                Capsule().strokeBorder(LinearGradient(colors: [.white.opacity(0.45), .white.opacity(0), .black.opacity(0.12)],
                    startPoint: .top, endPoint: .bottom), lineWidth: 1)
            }
            .scaleEffect(configuration.isPressed && !reduceMotion ? pressScale : 1)
            .animation(.spring(response: 0.18, dampingFraction: 0.7), value: configuration.isPressed)
            .contentShape(Capsule())
    }
}

/// Secondary glass control (Later, End Session, End circle).
struct GlassStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(Palette.primary)
            .background {
                Capsule().fill(Palette.control)
                    .overlay { Capsule().fill(.black.opacity(configuration.isPressed ? 0.06 : 0)) }
                    .shadow(color: .black.opacity(0.12), radius: 1.5, x: 0, y: 1)
            }
            .overlay { Capsule().strokeBorder(Palette.controlEdge, lineWidth: 0.5) }
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.96 : 1)
            .animation(.spring(response: 0.18, dampingFraction: 0.7), value: configuration.isPressed)
            .contentShape(Capsule())
    }
}

/// Borderless toolbar control that shows a soft fill on hover.
struct ToolbarStyle: ButtonStyle {
    @State private var hover = false
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(Palette.secondary)
            .background { Circle().fill(Palette.hover).opacity(hover || configuration.isPressed ? 1 : 0) }
            .contentShape(Circle())
            .onHover { hover = $0 }
            .animation(.easeOut(duration: 0.12), value: hover)
    }
}

struct ToolbarButton: View {
    let icon: Icon
    let title: String
    let action: () -> Void
    var body: some View {
        Button(action: action) { IconImage(icon).frame(width: 28, height: 28) }
            .buttonStyle(ToolbarStyle())
            .help(title).accessibilityLabel(title)
    }
}

struct CircleButton: View {
    let icon: Icon
    let title: String
    var size: CGFloat = 44
    var tint: Color? = Palette.focus
    let action: () -> Void
    var body: some View {
        let label = IconImage(icon, size: size >= 34 && tint != nil ? 18 : 14)
            .frame(width: size, height: size)
            .contentTransition(.opacity)
        Group {
            if let tint {
                Button(action: action) { label }.buttonStyle(TintedStyle(tint: tint, pressScale: 0.94))
            } else {
                Button(action: action) { label }.buttonStyle(GlassStyle())
            }
        }
        .help(title).accessibilityLabel(title)
    }
}

struct PushButton: View {
    let title: String
    var icon: Icon? = nil
    var tint: Color? = nil
    var height: CGFloat = 32
    var fill = false
    let action: () -> Void
    var body: some View {
        let label = HStack(spacing: 6) {
            if let icon { IconImage(icon) }
            Text(title).font(.system(size: 13, weight: tint == nil ? .medium : .semibold)).lineLimit(1)
        }
        .padding(.leading, icon == nil ? 16 : 14).padding(.trailing, 16)
        .frame(maxWidth: fill ? .infinity : nil)
        .frame(height: height)
        .fixedSize(horizontal: !fill, vertical: false)
        Group {
            if let tint { Button(action: action) { label }.buttonStyle(TintedStyle(tint: tint)) }
            else { Button(action: action) { label }.buttonStyle(GlassStyle()) }
        }
        .help(title).accessibilityLabel(title)
    }
}

// MARK: - Inputs

struct SegmentedPicker<Value: Hashable>: View {
    let options: [(value: Value, title: String)]
    @Binding var selection: Value
    var label: String
    @Namespace private var thumb
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var body: some View {
        HStack(spacing: 2) {
            ForEach(options.indices, id: \.self) { index in
                let option = options[index]
                let selected = option.value == selection
                Button {
                    withAnimation(reduceMotion ? nil : .spring(response: 0.3, dampingFraction: 0.85)) { selection = option.value }
                } label: {
                    Text(option.title)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(selected ? Palette.primary : Palette.secondary)
                        .frame(maxWidth: .infinity).frame(height: 24)
                        .background {
                            if selected {
                                RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Palette.segmentThumb)
                                    .shadow(color: .black.opacity(0.12), radius: 1.5, x: 0, y: 1)
                                    .matchedGeometryEffect(id: "thumb", in: thumb)
                            }
                        }
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(option.title)
                .accessibilityAddTraits(selected ? .isSelected : [])
            }
        }
        .padding(2)
        .frame(height: 28)
        .background(Palette.segmentTrack, in: .rect(cornerRadius: 14, style: .continuous))
        .accessibilityElement(children: .contain)
        .accessibilityLabel(label)
    }
}

struct MiniSwitchStyle: ToggleStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    func makeBody(configuration: Configuration) -> some View {
        Button {
            withAnimation(reduceMotion ? nil : .spring(response: 0.25, dampingFraction: 0.8)) { configuration.isOn.toggle() }
        } label: {
            HStack(spacing: 8) {
                configuration.label.frame(maxWidth: .infinity, alignment: .leading)
                Capsule()
                    .fill(configuration.isOn ? Palette.focus : Palette.segmentTrack)
                    .overlay { Capsule().strokeBorder(.black.opacity(configuration.isOn ? 0 : 0.06), lineWidth: 0.5) }
                    .frame(width: 32, height: 18)
                    .overlay(alignment: configuration.isOn ? .trailing : .leading) {
                        Circle().fill(.white).frame(width: 14, height: 14)
                            .shadow(color: .black.opacity(0.2), radius: 1, x: 0, y: 0.5)
                            .padding(2)
                    }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityRepresentation { Toggle(isOn: configuration.$isOn) { configuration.label } }
    }
}

struct MinuteStepper: View {
    let title: String
    @Binding var value: Int
    let range: ClosedRange<Int>
    var body: some View {
        HStack(spacing: 0) {
            step(.minus, by: -1, label: "Decrease \(title)")
            Text("\(value) min")
                .font(.system(size: 12, weight: .medium)).monospacedDigit()
                .contentTransition(.numericText(value: Double(value)))
                .padding(.horizontal, 4)
            step(.plus, by: 1, label: "Increase \(title)")
        }
        .frame(height: 26)
        .background(Palette.control.opacity(0.6), in: Capsule())
        .overlay { Capsule().strokeBorder(Palette.controlEdge, lineWidth: 0.5) }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(title)
        .accessibilityValue("\(value) minutes")
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment: change(by: 1)
            case .decrement: change(by: -1)
            @unknown default: break
            }
        }
    }
    private func step(_ icon: Icon, by delta: Int, label: String) -> some View {
        Button { change(by: delta) } label: {
            IconImage(icon, size: 12).foregroundStyle(Palette.secondary)
                .frame(width: 26, height: 26).contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .buttonRepeatBehavior(.enabled)
        .disabled(!range.contains(value + delta))
        .help(label)
    }
    private func change(by delta: Int) {
        withAnimation(.snappy(duration: 0.2)) { value = min(range.upperBound, max(range.lowerBound, value + delta)) }
    }
}

// MARK: - Panel pieces

struct TodayRow: View {
    let stats: DailyStats
    var justCompleted = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var bloomed = true
    var body: some View {
        let shown = max(1, min(5, stats.count))
        HStack(spacing: 8) {
            HStack(spacing: -3) {
                ForEach(0..<shown, id: \.self) { index in
                    let newest = justCompleted && index == shown - 1
                    Image("flower-icon").resizable().scaledToFit()
                        .frame(width: newest ? 20 : 16, height: newest ? 20 : 16)
                        .opacity(stats.count == 0 ? 0.3 : (newest && !bloomed ? 0 : 1))
                        .scaleEffect(newest && !bloomed && !reduceMotion ? 0.2 : 1)
                }
            }
            if stats.count > 5 {
                Text("+\(stats.count - 5)").font(.system(size: 11, weight: .medium)).foregroundStyle(Palette.secondary)
            }
            Text(stats.label)
                .font(.system(size: justCompleted ? 11 : 12, weight: justCompleted ? .medium : .regular))
                .foregroundStyle(justCompleted ? Palette.primary : Palette.secondary)
                .lineLimit(1)
            Spacer(minLength: 0)
        }
        .frame(height: 20)
        .accessibilityElement(children: .ignore).accessibilityLabel(stats.label)
        .task(id: justCompleted) {
            guard justCompleted else { bloomed = true; return }
            bloomed = false
            try? await Task.sleep(for: .milliseconds(400))
            withAnimation(reduceMotion ? .easeOut(duration: 0.2) : .spring(response: 0.4, dampingFraction: 0.55)) { bloomed = true }
        }
    }
}

struct ProgressCapsule: View {
    let value: Double
    let tint: Color
    var body: some View {
        Capsule().fill(Palette.track)
            .overlay(alignment: .leading) {
                GeometryReader { geometry in
                    Capsule().fill(tint)
                        .frame(width: max(value > 0 ? 6 : 0, geometry.size.width * value))
                }
            }
            .frame(height: 6)
            .animation(.easeInOut(duration: 0.3), value: tint)
            .accessibilityElement()
            .accessibilityLabel("Session progress")
            .accessibilityValue("\(Int(value * 100)) percent")
    }
}
