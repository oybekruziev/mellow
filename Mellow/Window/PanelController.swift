import AppKit
import SwiftUI

final class FloatingPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}

final class PanelHostingView<Content: View>: NSHostingView<Content> {
    override var mouseDownCanMoveWindow: Bool { false }
    // The panel never becomes key on its own, so the first click must still reach SwiftUI.
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
}

@MainActor
final class PanelController: NSObject, NSWindowDelegate {
    let panel: FloatingPanel
    private let model: AppModel
    /// Suppresses position saving while the frame is changed by code.
    private var programmaticMove = false
    private var contentSize = CGSize(width: 300, height: 248)
    private var shrinkWork: DispatchWorkItem?
    /// Where the panel lives while it is tucked into the menu bar.
    private var homeOrigin: NSPoint?
    /// True from hide() until the panel is ordered out or show() takes over.
    private var hiding = false
    static let shadowInset: CGFloat = 32
    private var shadowInset: CGFloat { Self.shadowInset }
    private var reduceMotion: Bool { NSWorkspace.shared.accessibilityDisplayShouldReduceMotion }

    init(model: AppModel) {
        self.model = model
        panel = FloatingPanel(contentRect: NSRect(x: 0, y: 0, width: 364, height: 312),
            styleMask: [.nonactivatingPanel, .fullSizeContentView, .borderless], backing: .buffered, defer: false)
        super.init()
        panel.isFloatingPanel = true
        panel.level = model.settings.keepOnTop ? .floating : .normal
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.isMovableByWindowBackground = false
        panel.hidesOnDeactivate = false
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = false
        panel.title = "Mellow"
        panel.delegate = self
        let host = PanelHostingView(rootView: PanelRootView(model: model))
        host.sizingOptions = []
        panel.contentView = host
        let screen = NSScreen.main ?? NSScreen.screens.first!
        let frame = screen.visibleFrame
        let key = "panelOrigin.\(screen.localizedName)"
        if let origin = model.settings.defaults.array(forKey: key) as? [Double], origin.count == 2 {
            panel.setFrameOrigin(NSPoint(x: origin[0], y: origin[1]))
        } else {
            panel.setFrameOrigin(NSPoint(x: frame.maxX - 300 - 18 - shadowInset, y: frame.maxY - 14 - panel.frame.height + shadowInset))
        }
        clampToScreen()
    }

    // MARK: Show / hide — the panel slides up into the menu bar item and back out of it.

    func show() {
        if panel.isVisible && !hiding { return }
        hiding = false
        if reduceMotion {
            model.dismissing = false
            if !panel.isVisible { panel.alphaValue = 0; panel.orderFrontRegardless() }
            NSAnimationContext.runAnimationGroup { $0.duration = 0.2; panel.animator().alphaValue = 1 }
            return
        }
        let home = homeOrigin ?? panel.frame.origin
        if !panel.isVisible {
            var transaction = Transaction(); transaction.disablesAnimations = true
            withTransaction(transaction) { model.dismissing = true }
            setOrigin(tuckedOrigin(from: home))
            panel.alphaValue = 1
            panel.orderFrontRegardless()
        }
        homeOrigin = nil
        // Let the tucked state render once before animating out of it.
        DispatchQueue.main.async { [self] in
            withAnimation(.spring(response: 0.45, dampingFraction: 0.82)) { model.dismissing = false }
            animateOrigin(to: home, duration: 0.4, timing: .init(controlPoints: 0.2, 0.9, 0.25, 1)) { [self] in
                if !hiding { clampToScreen() }
            }
        }
    }

    func hide() {
        guard panel.isVisible, !hiding else { return }
        hiding = true
        shrinkWork?.cancel()
        if reduceMotion {
            NSAnimationContext.runAnimationGroup { $0.duration = 0.2; panel.animator().alphaValue = 0 } completionHandler: { [self] in
                MainActor.assumeIsolated {
                    guard hiding else { return } // show() won the race
                    hiding = false
                    panel.orderOut(nil)
                }
            }
            return
        }
        let home = panel.frame.origin
        homeOrigin = home
        withAnimation(.easeIn(duration: 0.3)) { model.dismissing = true }
        animateOrigin(to: tuckedOrigin(from: home), duration: 0.3, timing: .init(name: .easeIn)) { [self] in
            guard hiding else { return } // show() won the race
            hiding = false
            panel.orderOut(nil)
            setOrigin(home)
        }
    }

    /// The window origin that puts the panel's top edge centre on the menu bar item.
    private func tuckedOrigin(from home: NSPoint) -> NSPoint {
        let topCenter = NSPoint(x: home.x + panel.frame.width - shadowInset - contentSize.width / 2,
                                y: home.y + panel.frame.height - shadowInset)
        let target: NSPoint
        if let item = NSApp.windows.first(where: { $0.className.contains("StatusBarWindow") && $0.isVisible }),
           item.frame.width > 0, NSScreen.screens.contains(where: { $0.frame.intersects(item.frame) }) {
            target = NSPoint(x: item.frame.midX, y: item.frame.minY)
        } else {
            let screen = panel.screen ?? NSScreen.main ?? NSScreen.screens[0]
            target = NSPoint(x: topCenter.x, y: screen.frame.maxY)
        }
        return NSPoint(x: home.x + target.x - topCenter.x, y: home.y + target.y - topCenter.y)
    }

    private func setOrigin(_ origin: NSPoint) {
        programmaticMove = true
        panel.setFrameOrigin(origin)
        programmaticMove = false
    }

    private func animateOrigin(to origin: NSPoint, duration: TimeInterval, timing: CAMediaTimingFunction,
                               completion: (@MainActor () -> Void)? = nil) {
        programmaticMove = true
        var frame = panel.frame
        frame.origin = origin
        NSAnimationContext.runAnimationGroup { context in
            context.duration = duration
            context.timingFunction = timing
            panel.animator().setFrame(frame, display: true)
        } completionHandler: { [self] in
            MainActor.assumeIsolated {
                programmaticMove = false
                completion?()
            }
        }
    }

    // MARK: Size — grow at once, shrink after SwiftUI has finished morphing.

    func resize(contentSize: CGSize) {
        self.contentSize = contentSize
        let target = CGSize(width: contentSize.width + shadowInset * 2, height: contentSize.height + shadowInset * 2)
        shrinkWork?.cancel()
        let grown = CGSize(width: max(panel.frame.width, target.width), height: max(panel.frame.height, target.height))
        apply(size: grown)
        guard grown != target else { return }
        let work = DispatchWorkItem { [weak self] in
            MainActor.assumeIsolated { self?.apply(size: target) }
        }
        shrinkWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6, execute: work)
    }

    private func apply(size: CGSize) {
        guard abs(panel.frame.width - size.width) > 0.5 || abs(panel.frame.height - size.height) > 0.5 else { return }
        var frame = panel.frame
        frame.origin.x += frame.width - size.width
        frame.origin.y += frame.height - size.height
        frame.size = size
        programmaticMove = true
        panel.setFrame(frame, display: true)
        programmaticMove = false
        if homeOrigin == nil { clampToScreen() }
    }

    func clampToScreen() {
        guard let screen = panel.screen ?? NSScreen.main else { return }
        let visible = screen.visibleFrame
        var frame = panel.frame
        frame.origin.x = min(max(frame.minX, visible.minX - shadowInset), visible.maxX - frame.width + shadowInset)
        frame.origin.y = min(max(frame.minY, visible.minY - shadowInset), visible.maxY - frame.height + shadowInset)
        programmaticMove = true
        panel.setFrame(frame, display: true)
        programmaticMove = false
        // While tucked away, the clamped spot becomes the place to come back to.
        if homeOrigin != nil && !panel.isVisible { homeOrigin = frame.origin }
    }

    func windowDidMove(_ notification: Notification) {
        guard !programmaticMove, homeOrigin == nil, let screen = panel.screen else { return }
        model.settings.defaults.set([panel.frame.minX, panel.frame.minY], forKey: "panelOrigin.\(screen.localizedName)")
    }
}
