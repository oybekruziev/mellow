import SwiftUI

/// The author of Mellow. Fill in the links; empty ones are hidden.
enum Creator {
    static let name = "Oybek Ruziev"
    static let links: [(icon: Icon, title: String, url: String)] = [
        (.instagram, "Instagram", ""),
        (.x, "X (Twitter)", ""),
        (.threads, "Threads", ""),
        (.linkedin, "LinkedIn", ""),
        (.globe, "Website", ""),
    ]
}

struct MadeBySection: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image("flower-icon").resizable().scaledToFit().frame(width: 16, height: 16)
                Text("Made by \(Creator.name)").font(.system(size: 13, weight: .semibold))
                Spacer()
                Text("Free · v\(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0")")
                    .font(.system(size: 11)).foregroundStyle(Palette.secondary)
            }
            let links = Creator.links.compactMap { link -> (Icon, String, URL)? in
                let text = link.url.trimmingCharacters(in: .whitespaces)
                guard !text.isEmpty else { return nil }
                // Accept "instagram.com/name" as well as full URLs.
                return URL(string: text.contains("://") ? text : "https://\(text)").map { (link.icon, link.title, $0) }
            }
            if !links.isEmpty {
                HStack(spacing: 6) {
                    ForEach(links, id: \.1) { icon, title, url in
                        Link(destination: url) {
                            IconImage(icon, size: 15).frame(width: 30, height: 30)
                                .background(Palette.control, in: Circle())
                                .overlay { Circle().strokeBorder(Palette.controlEdge, lineWidth: 0.5) }
                        }
                        .buttonStyle(.plain).foregroundStyle(Palette.primary)
                        .help(title).accessibilityLabel(title)
                    }
                }
            }
            Text("Mellow is free. Music: “Public Domain Lofi” by HoliznaCC0 (CC0). Icons: Lucide (ISC).")
                .font(.system(size: 11)).foregroundStyle(Palette.secondary)
                .fixedSize(horizontal: false, vertical: true)
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
