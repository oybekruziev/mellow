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

/// Owns the floating panel window.
///
/// The window is a fixed transparent canvas, and the glass panel is drawn in its top-right corner.
/// SwiftUI morphs the glass inside the canvas, so the window never resizes during an animation and
/// nothing gets clipped. Outside the glass the window lets clicks fall through to the apps behind it
/// (`ignoresMouseEvents` follows the pointer).
@MainActor
final class PanelController: NSObject, NSWindowDelegate {
    let panel: FloatingPanel
    private let model: AppModel
    static let shadowInset: CGFloat = 32
    private var inset: CGFloat { Self.shadowInset }
    /// Canvas size: wide enough for the 300 pt panel, tall enough for the tallest content so far.
    private static let minimumCanvas = CGSize(width: 300 + shadowInset * 2, height: 620)
    /// Size of the glass as last laid out (the final size, not the animated one).
    private var contentSize = CGSize(width: 300, height: 248)
    private var pendingGrowth = false
    /// Suppresses position saving while the frame is changed by code.
    private var programmaticMove = false
    /// The panel's home position (top-right corner of the glass) while it is tucked away.
    private var homeTopRight: NSPoint?
    /// True from hide() until the panel is ordered out or show() takes over.
    private var hiding = false
    private var mouseMonitors: [Any] = []
    private var reduceMotion: Bool { NSWorkspace.shared.accessibilityDisplayShouldReduceMotion }

    init(model: AppModel) {
        self.model = model
        panel = FloatingPanel(contentRect: NSRect(origin: .zero, size: Self.minimumCanvas),
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
        panel.acceptsMouseMovedEvents = true
        panel.title = "Mellow"
        panel.delegate = self
        // The hosting view sits inside a plain container instead of being the window's content view:
        // as the content view, NSHostingView resizes the window on its own (updateAnimatedWindowSize),
        // which crashed AppKit's layout pass.
        let host = PanelHostingView(rootView: PanelRootView(model: model))
        host.sizingOptions = []
        let container = NSView(frame: NSRect(origin: .zero, size: panel.frame.size))
        host.frame = container.bounds
        host.autoresizingMask = [.width, .height]
        container.addSubview(host)
        panel.contentView = container

        let screen = NSScreen.main ?? NSScreen.screens.first!
        let saved = model.settings.defaults.array(forKey: positionKey(screen)) as? [Double]
        let topRight = saved.flatMap { $0.count == 2 ? NSPoint(x: $0[0], y: $0[1]) : nil }
            ?? NSPoint(x: screen.visibleFrame.maxX - 18, y: screen.visibleFrame.maxY - 14)
        place(topRight: topRight)
        clampToScreen()
        installMouseGate()
    }

    // MARK: Geometry

    /// The glass rectangle in screen coordinates.
    private var glassFrame: NSRect {
        NSRect(x: panel.frame.maxX - inset - contentSize.width, y: panel.frame.maxY - inset - contentSize.height,
               width: contentSize.width, height: contentSize.height)
    }
    private var glassTopRight: NSPoint { NSPoint(x: panel.frame.maxX - inset, y: panel.frame.maxY - inset) }

    private func place(topRight: NSPoint) {
        setOrigin(origin(forTopRight: topRight))
    }
    private func origin(forTopRight point: NSPoint) -> NSPoint {
        NSPoint(x: point.x + inset - panel.frame.width, y: point.y + inset - panel.frame.height)
    }
    private func positionKey(_ screen: NSScreen) -> String { "panelTopRight.\(screen.localizedName)" }

    /// Called from SwiftUI layout with the content's final size. The canvas only ever grows,
    /// and it grows on the next run-loop turn — never inside the layout pass.
    func contentSizeChanged(_ size: CGSize) {
        contentSize = size
        updateMouseGate()
        let needed = CGSize(width: size.width + inset * 2, height: size.height + inset * 2)
        guard needed.width > panel.frame.width || needed.height > panel.frame.height, !pendingGrowth else { return }
        pendingGrowth = true
        DispatchQueue.main.async { [weak self] in
            MainActor.assumeIsolated {
                guard let self else { return }
                self.pendingGrowth = false
                let size = CGSize(width: max(self.panel.frame.width, self.contentSize.width + self.inset * 2),
                                  height: max(self.panel.frame.height, self.contentSize.height + self.inset * 2))
                let topRight = self.glassTopRight
                self.programmaticMove = true
                self.panel.setFrame(NSRect(origin: self.panel.frame.origin, size: size), display: false)
                self.place(topRight: topRight)
                self.programmaticMove = false
            }
        }
    }

    /// Keeps the glass (not the transparent canvas) on screen.
    func clampToScreen() {
        guard let screen = panel.screen ?? NSScreen.main else { return }
        let visible = screen.visibleFrame
        let glass = glassFrame
        var dx: CGFloat = 0, dy: CGFloat = 0
        if glass.maxX > visible.maxX { dx = visible.maxX - glass.maxX }
        if glass.minX + dx < visible.minX { dx = visible.minX - glass.minX }
        if glass.maxY > visible.maxY { dy = visible.maxY - glass.maxY }
        if glass.minY + dy < visible.minY { dy = visible.minY - glass.minY }
        guard dx != 0 || dy != 0 else { return }
        setOrigin(NSPoint(x: panel.frame.minX + dx, y: panel.frame.minY + dy))
        // While tucked away, the clamped spot becomes the place to come back to.
        if homeTopRight != nil && !panel.isVisible { homeTopRight = glassTopRight }
    }

    // MARK: Click-through outside the glass

    private func installMouseGate() {
        let update: (NSEvent) -> Void = { [weak self] _ in MainActor.assumeIsolated { self?.updateMouseGate() } }
        if let global = NSEvent.addGlobalMonitorForEvents(matching: [.mouseMoved, .leftMouseDragged], handler: update) {
            mouseMonitors.append(global)
        }
        if let local = NSEvent.addLocalMonitorForEvents(matching: [.mouseMoved, .leftMouseDragged], handler: { update($0); return $0 }) {
            mouseMonitors.append(local)
        }
    }

    /// The window takes the mouse only while the pointer is over the glass (and not mid-animation).
    func updateMouseGate() {
        let inside = glassFrame.insetBy(dx: -2, dy: -2).contains(NSEvent.mouseLocation)
        let ignore = hiding || model.dismissing || !inside
        if panel.ignoresMouseEvents != ignore { panel.ignoresMouseEvents = ignore }
    }

    // MARK: Show / hide — the panel slides up into the menu bar item and back out of it.

    func show() {
        if panel.isVisible && !hiding { return }
        hiding = false
        if reduceMotion {
            model.dismissing = false
            if !panel.isVisible { panel.alphaValue = 0; panel.orderFrontRegardless() }
            NSAnimationContext.runAnimationGroup { $0.duration = 0.2; panel.animator().alphaValue = 1 }
            updateMouseGate()
            return
        }
        let home = homeTopRight ?? glassTopRight
        if !panel.isVisible {
            var transaction = Transaction(); transaction.disablesAnimations = true
            withTransaction(transaction) { model.dismissing = true }
            setOrigin(origin(forTopRight: tuckedTopRight(from: home)))
            panel.alphaValue = 1
            panel.orderFrontRegardless()
        }
        homeTopRight = nil
        // Let the tucked state render once before animating out of it.
        DispatchQueue.main.async { [self] in
            withAnimation(.spring(duration: 0.55, bounce: 0.18)) { model.dismissing = false }
            animateOrigin(to: origin(forTopRight: home), duration: 0.5, timing: .init(controlPoints: 0.16, 1, 0.3, 1)) { [self] in
                if !hiding { clampToScreen(); updateMouseGate() }
            }
        }
    }

    func hide() {
        guard panel.isVisible, !hiding else { return }
        hiding = true
        panel.ignoresMouseEvents = true
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
        let home = glassTopRight
        homeTopRight = home
        withAnimation(.easeIn(duration: 0.28)) { model.dismissing = true }
        animateOrigin(to: origin(forTopRight: tuckedTopRight(from: home)), duration: 0.32, timing: .init(controlPoints: 0.55, 0, 0.75, 0.3)) { [self] in
            guard hiding else { return } // show() won the race
            hiding = false
            panel.orderOut(nil)
            place(topRight: home)
        }
    }

    /// Where the glass's top-right corner must go so its top-centre meets the menu bar item.
    private func tuckedTopRight(from home: NSPoint) -> NSPoint {
        let topCenter = NSPoint(x: home.x - contentSize.width / 2, y: home.y)
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

    func windowDidMove(_ notification: Notification) {
        guard !programmaticMove, homeTopRight == nil, let screen = panel.screen else { return }
        let point = glassTopRight
        model.settings.defaults.set([Double(point.x), Double(point.y)], forKey: positionKey(screen))
    }
}
