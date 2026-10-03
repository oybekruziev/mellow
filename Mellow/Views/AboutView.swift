import SwiftUI

/// The author of Mellow. Paste a profile link into `url` (with or without https://);
/// until then the icon stays visible but inactive.
enum Creator {
    static let name = "Oybek Ruziev"
    static let links: [(icon: Icon, title: String, url: String)] = [
        (.instagram, "Instagram", ""),
        (.x, "X (Twitter)", ""),
        (.linkedin, "LinkedIn", ""),
        (.threads, "Threads", ""),
        (.youtube, "YouTube", ""),
    ]
    static func url(_ text: String) -> URL? {
        let text = text.trimmingCharacters(in: .whitespaces)
        guard !text.isEmpty else { return nil }
        return URL(string: text.contains("://") ? text : "https://\(text)")
    }
}

/// Round social buttons for the author's profiles.
struct SocialLinks: View {
    var size: CGFloat = 30
    var body: some View {
        HStack(spacing: 6) {
            ForEach(Creator.links, id: \.title) { link in
                let destination = Creator.url(link.url)
                let icon = IconImage(link.icon, size: size * 0.5)
                    .frame(width: size, height: size)
                    .background(Palette.control, in: Circle())
                    .overlay { Circle().strokeBorder(Palette.controlEdge, lineWidth: 0.5) }
                Group {
                    if let destination {
                        Link(destination: destination) { icon }.buttonStyle(PressableStyle())
                    } else {
                        icon.opacity(0.55)
                    }
                }
                .foregroundStyle(Palette.primary)
                .help(destination == nil ? "\(link.title) — coming soon" : link.title)
                .accessibilityLabel(link.title)
            }
        }
    }
}

/// Subtle press feedback for icon links.
struct PressableStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.92 : 1)
            .animation(.snappy(duration: 0.18), value: configuration.isPressed)
    }
}

struct MadeBySection: View {
    var onReplayWelcome: (() -> Void)? = nil
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image("flower-icon").resizable().scaledToFit().frame(width: 16, height: 16)
                Text("Made by \(Creator.name)").font(.system(size: 13, weight: .semibold))
                Spacer()
                Text("Free · v\(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0")")
                    .font(.system(size: 11)).foregroundStyle(Palette.secondary)
            }
            SocialLinks()
            Text("Mellow is free. Music: “Public Domain Lofi” by HoliznaCC0 (CC0). Icons: Lucide (ISC).")
                .font(.system(size: 11)).foregroundStyle(Palette.secondary)
                .fixedSize(horizontal: false, vertical: true)
            if let onReplayWelcome {
                Button("Show Welcome Again", action: onReplayWelcome)
                    .buttonStyle(.plain).font(.system(size: 11, weight: .medium)).foregroundStyle(Palette.focus)
            }
        }
        .padding(.horizontal, 12).padding(.vertical, 10)
        .modifier(SectionSurface())
    }
}

/// Thin volume slider drawn like the Figma progress capsule.
struct VolumeSlider: View {
    @Binding var value: Double
    var body: some View {
        GeometryReader { geometry in
            let width = geometry.size.width
            ZStack(alignment: .leading) {
                Capsule().fill(Palette.track).frame(height: 4)
                Capsule().fill(Palette.focus).frame(width: max(4, width * value), height: 4)
                Circle().fill(.white).frame(width: 14, height: 14)
                    .shadow(color: .black.opacity(0.25), radius: 1.5, x: 0, y: 0.5)
                    .offset(x: (width - 14) * value)
            }
            .frame(maxHeight: .infinity)
            .contentShape(Rectangle())
            .gesture(DragGesture(minimumDistance: 0).onChanged { drag in
                value = min(1, max(0, drag.location.x / width))
            })
        }
        .frame(height: 18)
        .accessibilityElement()
        .accessibilityLabel("Music volume")
        .accessibilityValue("\(Int(value * 100)) percent")
        .accessibilityAdjustableAction { direction in
            value = min(1, max(0, value + (direction == .increment ? 0.1 : -0.1)))
        }
    }
}
