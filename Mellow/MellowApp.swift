import SwiftUI
import AppKit

@main
struct MellowApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate
    @State private var model = AppModel.shared

    var body: some Scene {
        MenuBarExtra {
            MenuBarMenu(model: model)
        } label: {
            MenuBarLabel(engine: model.engine)
        }
        .menuBarExtraStyle(.menu)
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        #if DEBUG
        if SnapshotRenderer.runIfRequested() { exit(0) }
        #endif
        AppModel.shared.start()
        #if DEBUG
        StressTest.runIfRequested(AppModel.shared)
        #endif
    }
    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        guard AppModel.shared.engine.phase.isActive else { return .terminateNow }
        let alert = NSAlert()
        alert.messageText = "Quit Mellow?"
        alert.informativeText = "This session will end without a flower."
        alert.addButton(withTitle: "Cancel")
        alert.addButton(withTitle: "Quit")
        return alert.runModal() == .alertSecondButtonReturn ? .terminateNow : .terminateCancel
    }
}
