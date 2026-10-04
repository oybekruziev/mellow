import SwiftUI
import AppKit

struct MenuBarLabel: View {
    let engine: SessionEngine
    var body: some View {
        HStack(spacing: 5) {
            Image("menubar-blossom").renderingMode(.template)
            if engine.phase.isActive {
                Text(engine.formattedTime).font(.system(size: 13, weight: .medium)).monospacedDigit()
                    .opacity(engine.phase.isRunning ? 1 : 0.45)
            }
        }
        .accessibilityLabel(engine.phase.isActive ? "Mellow, \(engine.formattedTime) remaining" : "Mellow")
    }
}

struct MenuBarMenu: View {
    @Bindable var model: AppModel
    var body: some View {
        if model.engine.phase.isActive {
            Text("\(status) — \(model.engine.formattedTime) left")
            Text(model.engine.task)
            Divider()
            visibilityButton
            Button(model.engine.phase.isRunning ? "Pause" : "Resume") {
                if case .confirmEnd = model.engine.phase { model.act(.keepGoing) }
                model.primaryAction()
            }
            Button(model.engine.phase.isBreak ? "End Break" : "End Session") { model.endAction() }
        } else {
            Text("Ready to focus")
            Divider()
            Button("Start Focus") {
                if model.engine.phase == .complete { model.act(.later) }
                model.primaryAction(); model.showPanel()
            }
            visibilityButton
        }
        Divider()
        updateItem
        Divider()
        Button(model.settings.pendingPlan.isEmpty ? "Plan Tasks…" : "Edit Plan…") { model.openPlanEditor() }
            .keyboardShortcut("p")
            .disabled(!model.canEditPlan)
        Button("Settings…") { model.openSettings() }.keyboardShortcut(",")
        Divider()
        Button("Quit Mellow") { NSApp.terminate(nil) }.keyboardShortcut("q")
    }
    private var status: String {
        !model.engine.phase.isRunning ? "Paused" : model.engine.phase.isBreak ? "On a break" : "Focusing"
    }
    @ViewBuilder private var updateItem: some View {
        switch model.updater.state {
        case .available(let release):
            Button("Update to Mellow \(release.version)…") { model.checkForUpdates() }
        case .checking:
            Button("Checking for Updates…") {}.disabled(true)
        case .downloading, .installing:
            Button("Installing Update…") {}.disabled(true)
        default:
            Button("Check for Updates…") { model.checkForUpdates() }
        }
    }
    private var visibilityButton: some View {
        Button(model.panelVisible ? "Hide Panel" : "Show Panel") { model.togglePanel() }
    }
}
