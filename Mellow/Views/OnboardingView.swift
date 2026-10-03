import SwiftUI

/// First-run setup inside the panel: welcome → companion → rhythm → sound & look.
/// Every choice writes straight to Settings, so leaving early keeps what was picked.
struct OnboardingView: View {
    @Bindable var model: AppModel
    @State private var step: Int
    init(model: AppModel, step: Int = 0) {
        self.model = model
        _step = State(initialValue: step)
    }
    @State private var forward = true
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private let steps = 4

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            ZStack(alignment: .topLeading) {
                page.id(step).transition(pageTransition)
            }
            .frame(maxWidth: .infinity, alignment: .topLeading)
            footer
        }
        .font(.system(size: 13)).foregroundStyle(Palette.primary)
        .padding(.horizontal, 14).padding(.top, 14).padding(.bottom, 14)
        .frame(width: 300, alignment: .leading)
        .onDisappear { if model.music.isPlaying && !model.engine.phase.isRunning { model.music.pause() } }
    }

    // MARK: Pages

    @ViewBuilder private var page: some View {
        switch step {
        case 0: welcome
        case 1:
            VStack(alignment: .leading, spacing: 12) {
                heading("Pick a companion", "It keeps you company while you focus and celebrates when you finish.")
                HStack {
                    Spacer()
                    CompanionView(type: model.settings.companion, phase: .focusing(running: true), progress: 0.5, size: 92)
                        .id(model.settings.companion)
                        .transition(AnyTransition(.blurReplace).combined(with: .scale(scale: 0.9)))
                    Spacer()
                }
                .frame(height: 92)
                CompanionSection(settings: model.settings)
            }
        case 2:
            VStack(alignment: .leading, spacing: 12) {
                heading("Set your rhythm", "How long to focus, how long to rest. You can change this any time.")
                presets
                TimerSection(settings: model.settings)
                BehaviorSection(settings: model.settings)
            }
        default:
            VStack(alignment: .leading, spacing: 12) {
                heading("Sound & look", "Soft lofi can play while you focus. Try the preview.")
                MusicSection(model: model, showsPreview: true)
                AppearanceSection(settings: model.settings)
            }
        }
    }

    private var welcome: some View {
        VStack(spacing: 14) {
            Image("mellow-logo").resizable().scaledToFit().frame(width: 72, height: 72)
                .shadow(color: Color("tintFlower").opacity(0.25), radius: 12, y: 4)
                .padding(.top, 6)
            VStack(spacing: 6) {
                Text("Welcome to Mellow").font(.system(size: 20, weight: .semibold)).tracking(-0.3)
                Text("A calm little focus timer. Write one task, start the clock, and grow a flower for every session.")
                    .font(.system(size: 13)).foregroundStyle(Palette.secondary)
                    .multilineTextAlignment(.center).fixedSize(horizontal: false, vertical: true)
            }
            VStack(spacing: 8) {
                Text("Made by \(Creator.name)").font(.system(size: 12, weight: .medium)).foregroundStyle(Palette.secondary)
                SocialLinks(size: 32)
            }
            .padding(.vertical, 12).frame(maxWidth: .infinity)
            .modifier(SectionSurface())
        }
        .frame(maxWidth: .infinity)
    }

    private var presets: some View {
        SegmentedPicker(options: [15, 25, 45, 60].map { ($0, "\($0) min") },
                        selection: $model.settings.focusMinutes, label: "Focus length")
    }

    private func heading(_ title: String, _ detail: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title).font(.system(size: 17, weight: .semibold)).tracking(-0.17)
            Text(detail).font(.system(size: 12)).foregroundStyle(Palette.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: Footer

    private var footer: some View {
        HStack(spacing: 8) {
            if step > 0 {
                PushButton(title: "Back") { go(to: step - 1) }
                    .transition(.opacity.combined(with: .scale(scale: 0.9)))
            } else {
                Button("Skip") { model.finishOnboarding() }
                    .buttonStyle(.plain).font(.system(size: 12, weight: .medium)).foregroundStyle(Palette.secondary)
                    .help("Skip — use the defaults")
                    .transition(.opacity)
            }
            Spacer(minLength: 0)
            dots
            Spacer(minLength: 0)
            if step < steps - 1 {
                PushButton(title: step == 0 ? "Get Started" : "Next", tint: Palette.focus) { go(to: step + 1) }
            } else {
                PushButton(title: "Start", icon: .play, tint: Palette.focus) { model.finishOnboarding() }
            }
        }
        .animation(.snappy(duration: 0.25), value: step)
    }

    private var dots: some View {
        HStack(spacing: 5) {
            ForEach(0..<steps, id: \.self) { index in
                Capsule().fill(index == step ? Palette.focus : Palette.secondary.opacity(0.35))
                    .frame(width: index == step ? 14 : 6, height: 6)
            }
        }
        .animation(.spring(duration: 0.35, bounce: 0.25), value: step)
        .accessibilityElement()
        .accessibilityLabel("Step \(step + 1) of \(steps)")
    }

    private var pageTransition: AnyTransition {
        guard !reduceMotion else { return .opacity }
        let edge: Edge = forward ? .trailing : .leading
        return .asymmetric(
            insertion: .move(edge: edge).combined(with: .opacity),
            removal: .move(edge: edge == .trailing ? .leading : .trailing).combined(with: .opacity))
    }

    private func go(to next: Int) {
        forward = next > step
        if step == 3 && model.music.isPlaying { model.music.pause() }
        withAnimation(reduceMotion ? .easeInOut(duration: 0.2) : .spring(duration: 0.45, bounce: 0.12)) { step = next }
    }
}
