import SwiftUI

struct SettingsView: View {
    @Bindable var model: AppModel
    var body: some View {
        // Scrolls only when the screen is too short for the whole popover.
        let maxHeight = (NSScreen.main?.visibleFrame.height ?? 900) - 120
        ViewThatFits(in: .vertical) {
            content
            ScrollView { content }.scrollIndicators(.automatic).frame(height: maxHeight)
        }
        .frame(maxHeight: maxHeight)
        .onExitCommand { model.settingsOpen = false }
    }

    private var content: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Settings").font(.system(size: 17, weight: .semibold)).tracking(-0.17)
                Spacer()
                ToolbarButton(icon: .close, title: "Close") { model.settingsOpen = false }
            }
            CompanionSection(settings: model.settings, showsTip: true)
            TimerSection(settings: model.settings)
            BehaviorSection(settings: model.settings)
            MusicSection(model: model)
            AppearanceSection(settings: model.settings)
            Text("New lengths apply from your next session.")
                .font(.system(size: 12)).foregroundStyle(Palette.secondary)
            MadeBySection(replayDisabled: model.engine.phase.isActive) { model.settingsOpen = false; model.replayOnboarding() }
        }
        .font(.system(size: 13)).foregroundStyle(Palette.primary)
        .padding(.horizontal, 14).padding(.top, 12).padding(.bottom, 16)
        .frame(width: 300)
        .tint(Palette.focus)
    }
}

// MARK: - Sections shared by Settings and onboarding

struct CompanionSection: View {
    @Bindable var settings: Settings
    var showsTip = false
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Companion")
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 4), spacing: 8) {
                ForEach(CompanionType.allCases) { type in tile(type) }
            }
            .onMoveCommand { direction in
                guard direction == .left || direction == .right,
                      let index = CompanionType.allCases.firstIndex(of: settings.companion) else { return }
                let all = CompanionType.allCases
                withAnimation(.snappy) { settings.companion = all[(index + (direction == .right ? 1 : all.count - 1)) % all.count] }
            }
            if showsTip {
                Text("Tip: right-click the companion in the panel to switch.")
                    .font(.system(size: 11)).foregroundStyle(Palette.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.horizontal, 12).padding(.top, 10).padding(.bottom, 12)
        .modifier(SectionSurface())
    }

    private func tile(_ type: CompanionType) -> some View {
        let selected = settings.companion == type
        return Button {
            withAnimation(.snappy(duration: 0.25)) { settings.companion = type }
        } label: {
            VStack(spacing: 4) {
                CompanionView(type: type, phase: .focusing(running: true), progress: 0.5, size: 40, preview: true)
                    .scaleEffect(selected ? 1.06 : 1)
                Text(type.title)
                    .font(.system(size: 12, weight: selected ? .semibold : .regular))
                    .foregroundStyle(selected ? Palette.primary : Palette.secondary)
            }
            .frame(maxWidth: .infinity).frame(height: 72)
            .background(selected ? Palette.tileSelected : Palette.tile, in: .rect(cornerRadius: 14, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(Palette.focus, lineWidth: 2).opacity(selected ? 1 : 0)
            }
            .shadow(color: .black.opacity(selected ? 0.1 : 0), radius: 1.5, x: 0, y: 1)
            .contentShape(.rect(cornerRadius: 14))
        }
        .buttonStyle(PressableStyle())
        .help(type.title).accessibilityLabel(type.title)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}

struct TimerSection: View {
    @Bindable var settings: Settings
    var body: some View {
        VStack(spacing: 0) {
            SettingsRow("Focus length") { MinuteStepper(title: "Focus length", value: $settings.focusMinutes, range: 1...120) }
            Palette.separator.frame(height: 0.5)
            SettingsRow("Break length") { MinuteStepper(title: "Break length", value: $settings.breakMinutes, range: 1...60) }
        }
        .padding(.horizontal, 12)
        .modifier(SectionSurface())
    }
}

struct BehaviorSection: View {
    @Bindable var settings: Settings
    var body: some View {
        VStack(spacing: 0) {
            Toggle("Play sound when done", isOn: $settings.soundOn).toggleStyle(MiniSwitchStyle()).padding(.vertical, 8)
            Palette.separator.frame(height: 0.5)
            Toggle("Keep panel on top", isOn: $settings.keepOnTop).toggleStyle(MiniSwitchStyle()).padding(.vertical, 8)
        }
        .padding(.horizontal, 12)
        .modifier(SectionSurface())
    }
}

struct MusicSection: View {
    @Bindable var model: AppModel
    var showsPreview = false
    var body: some View {
        VStack(spacing: 0) {
            Toggle("Play lofi music during focus", isOn: $model.settings.musicDuringFocus)
                .toggleStyle(MiniSwitchStyle()).padding(.vertical, 8)
            Palette.separator.frame(height: 0.5)
            HStack(spacing: 10) {
                if showsPreview {
                    Button { withAnimation(.snappy) { model.music.toggle() } } label: {
                        IconImage(model.music.isPlaying ? .pause : .play, size: 12).frame(width: 22, height: 22)
                    }
                    .buttonStyle(ToolbarStyle())
                    .help(model.music.isPlaying ? "Stop Preview" : "Preview Music")
                    .accessibilityLabel(model.music.isPlaying ? "Stop Preview" : "Preview Music")
                } else {
                    IconImage(.music, size: 12).foregroundStyle(Palette.secondary)
                }
                VolumeSlider(value: $model.settings.musicVolume)
            }
            .padding(.vertical, 8)
        }
        .padding(.horizontal, 12)
        .modifier(SectionSurface())
    }
}

struct AppearanceSection: View {
    @Bindable var settings: Settings
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Appearance")
            SegmentedPicker(options: AppAppearance.allCases.map { ($0, $0.title) },
                            selection: $settings.appearance, label: "Appearance")
        }
        .padding(.horizontal, 12).padding(.vertical, 10)
        .modifier(SectionSurface())
    }
}

struct SettingsRow<Control: View>: View {
    let title: String
    let control: Control
    init(_ title: String, @ViewBuilder control: () -> Control) {
        self.title = title
        self.control = control()
    }
    var body: some View {
        HStack(spacing: 8) {
            Text(title).frame(maxWidth: .infinity, alignment: .leading)
            control
        }
        .padding(.vertical, 8)
    }
}
