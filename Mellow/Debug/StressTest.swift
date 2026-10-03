#if DEBUG
import AppKit

/// Debug-only: `MELLOW_STRESS=<cycles> Mellow` drives the real panel through compact/expand,
/// hide/show, settings and session changes, then exits 0. A crash exits non-zero.
@MainActor
enum StressTest {
    static func runIfRequested(_ model: AppModel) {
        guard let value = ProcessInfo.processInfo.environment["MELLOW_STRESS"], let cycles = Int(value) else { return }
        let wasOnboarded = model.settings.onboarded
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(1.5))
            if model.onboarding { model.finishOnboarding() }
            for cycle in 0..<cycles {
                let fixed = ProcessInfo.processInfo.environment["MELLOW_STRESS_PAUSE"].flatMap(Double.init)
                let pause = fixed ?? [0.05, 0.2, 0.45, 0.7][cycle % 4]
                switch cycle % 9 {
                case 0: model.act(.startFocus)
                case 3: model.hidePanel()
                case 4: model.showPanel()
                case 5: model.replayOnboarding()
                case 6: model.finishOnboarding(); model.openSettings()
                case 7: model.settingsOpen = false; model.primaryAction()
                case 8: model.endAction(); model.act(.confirmEnd)
                default: break
                }
                model.toggleCompact()
                try? await Task.sleep(for: .seconds(pause))
            }
            model.settings.onboarded = wasOnboarded // leave the real preferences as they were
            FileHandle.standardError.write(Data("stress: \(cycles) cycles ok\n".utf8))
            exit(0)
        }
    }
}
#endif
