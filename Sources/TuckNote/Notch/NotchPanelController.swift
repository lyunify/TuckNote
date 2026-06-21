import AppKit
import CoreGraphics
import SwiftUI

enum PanelPresentation: Equatable {
    case compact
    case expanded

    var showsCompactPanel: Bool { self == .compact }
    var showsExpandedPanel: Bool { self == .expanded }
    var toggled: Self { self == .compact ? .expanded : .compact }
    static let statusMenuShow = Self.expanded
}

struct HoverDwellState {
    let duration: TimeInterval
    private var enteredAt: TimeInterval?

    init(duration: TimeInterval) {
        self.duration = duration
    }

    mutating func update(isInside: Bool, now: TimeInterval) -> Bool {
        guard isInside else {
            enteredAt = nil
            return false
        }
        guard let enteredAt else {
            self.enteredAt = now
            return false
        }
        return now >= enteredAt + duration
    }
}

struct PanelSpringSpecification: Equatable {
    let mass: CGFloat
    let stiffness: CGFloat
    let damping: CGFloat
    let initialVelocity: CGFloat

    static let panel = Self(mass: 1, stiffness: 320, damping: 28, initialVelocity: 0)

    func makeAnimation(from transform: CATransform3D) -> CASpringAnimation {
        let animation = CASpringAnimation(keyPath: "transform")
        animation.mass = mass
        animation.stiffness = stiffness
        animation.damping = damping
        animation.initialVelocity = initialVelocity
        animation.fromValue = NSValue(caTransform3D: transform)
        animation.toValue = NSValue(caTransform3D: CATransform3DIdentity)
        animation.duration = animation.settlingDuration
        return animation
    }
}

struct PanelReducedMotionSpecification: Equatable {
    enum Curve: Equatable {
        case easeOut
    }

    let duration: TimeInterval
    let curve: Curve
    let fades: Bool
    let resizes: Bool

    static let panel = Self(duration: 0.120, curve: .easeOut, fades: true, resizes: true)
}

enum PanelAnimationSpec: Equatable {
    case spring(PanelSpringSpecification)
    case reducedMotion(PanelReducedMotionSpecification)

    static func make(reduceMotion: Bool) -> Self {
        reduceMotion
            ? .reducedMotion(.panel)
            : .spring(.panel)
    }
}

@MainActor
final class NotchPanelController {
    private static let hoverPollInterval: TimeInterval = 1.0 / 30.0

    private let store: NoteStore
    private let imageStore: ImageStore
    private let settings: AppSettings
    private let compactPanel: NSPanel
    private let expandedPanel: NSPanel
    private var presentation = PanelPresentation.compact
    nonisolated(unsafe) private var localMonitor: Any?
    nonisolated(unsafe) private var globalMonitor: Any?
    nonisolated(unsafe) private var hoverTimer: Timer?
    private var hoverDwell = HoverDwellState(duration: 0.120)

    init(store: NoteStore, imageStore: ImageStore, settings: AppSettings) {
        self.store = store
        self.imageStore = imageStore
        self.settings = settings
        compactPanel = Self.makePanel()
        expandedPanel = Self.makePanel()

        let compactView = CompactHostingView(rootView: CompactNotchView())
        compactView.onMouseDown = { [weak self] in
            guard let self, self.settings.triggerMode == .click else { return }
            self.expand(animated: true)
        }
        compactPanel.contentView = compactView
        expandedPanel.contentView = NSHostingView(
            rootView: NotebookView(store: store, imageStore: imageStore)
        )

        installEventMonitors()
        startHoverPolling()
    }

    deinit {
        if let localMonitor { NSEvent.removeMonitor(localMonitor) }
        if let globalMonitor { NSEvent.removeMonitor(globalMonitor) }
        hoverTimer?.invalidate()
    }

    func showCompact() {
        guard store.isLoaded else { return }
        presentation = .compact
        applyPresentation(animated: false)
    }

    func expand(animated: Bool) {
        guard store.isLoaded else { return }
        guard presentation != .expanded || !expandedPanel.isVisible else { return }
        presentation = .expanded
        applyPresentation(animated: animated)
    }

    func collapse(animated: Bool) {
        guard presentation != .compact || !compactPanel.isVisible else { return }
        presentation = .compact
        applyPresentation(animated: animated)
    }

    func toggle() {
        guard store.isLoaded else { return }
        presentation = presentation.toggled
        applyPresentation(animated: true)
    }

    private static func makePanel() -> NSPanel {
        let panel = NotchPanel(
            contentRect: .zero,
            styleMask: [.borderless, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.level = .statusBar
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        panel.hidesOnDeactivate = false
        panel.hasShadow = true
        panel.isMovable = false
        return panel
    }

    private func applyPresentation(animated: Bool) {
        let geometry = geometryForCurrentScreen()
        let shownPanel = presentation.showsCompactPanel ? compactPanel : expandedPanel
        let hiddenPanel = presentation.showsCompactPanel ? expandedPanel : compactPanel
        let targetFrame = presentation.showsCompactPanel
            ? geometry.compactFrame
            : geometry.expandedFrame
        let initialFrame = presentation.showsCompactPanel
            ? geometry.expandedFrame
            : geometry.compactFrame

        compactPanel.setFrame(geometry.compactFrame, display: true)
        expandedPanel.setFrame(geometry.expandedFrame, display: true)
        hiddenPanel.contentView?.layer?.removeAnimation(forKey: "panelSpring")
        hiddenPanel.orderOut(nil)
        if animated {
            let spec = PanelAnimationSpec.make(
                reduceMotion: NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
            )
            switch spec {
            case let .reducedMotion(specification):
                shownPanel.setFrame(initialFrame, display: false)
                shownPanel.alphaValue = specification.fades ? 0 : 1
                shownPanel.orderFrontRegardless()
                NSAnimationContext.runAnimationGroup { context in
                    context.duration = specification.duration
                    switch specification.curve {
                    case .easeOut:
                        context.timingFunction = CAMediaTimingFunction(name: .easeOut)
                    }
                    shownPanel.animator().alphaValue = 1
                    if specification.resizes {
                        shownPanel.animator().setFrame(targetFrame, display: true)
                    }
                }
            case let .spring(specification):
                shownPanel.setFrame(targetFrame, display: true)
                shownPanel.alphaValue = 1
                shownPanel.orderFrontRegardless()
                animateSpring(
                    in: shownPanel,
                    from: initialFrame,
                    to: targetFrame,
                    specification: specification
                )
            }
        } else {
            shownPanel.setFrame(targetFrame, display: true)
            shownPanel.alphaValue = 1
            shownPanel.orderFrontRegardless()
        }
        if presentation.showsExpandedPanel {
            expandedPanel.makeKeyAndOrderFront(nil)
        }
    }

    private func animateSpring(
        in panel: NSPanel,
        from initialFrame: CGRect,
        to targetFrame: CGRect,
        specification: PanelSpringSpecification
    ) {
        guard targetFrame.width > 0, targetFrame.height > 0, let contentView = panel.contentView
        else { return }
        contentView.wantsLayer = true
        guard let layer = contentView.layer else { return }
        layer.removeAnimation(forKey: "panelSpring")
        layer.transform = CATransform3DIdentity
        let initialTransform = CATransform3DMakeScale(
            initialFrame.width / targetFrame.width,
            initialFrame.height / targetFrame.height,
            1
        )
        layer.add(
            specification.makeAnimation(from: initialTransform),
            forKey: "panelSpring"
        )
    }

    private func geometryForCurrentScreen() -> NotchGeometry {
        let screen = Self.preferredScreen()
        return NotchGeometry(
            screenFrame: screen.frame,
            visibleFrame: screen.visibleFrame,
            safeAreaInsets: screen.safeAreaInsets,
            auxiliaryTopLeftArea: screen.auxiliaryTopLeftArea,
            auxiliaryTopRightArea: screen.auxiliaryTopRightArea
        )
    }

    private static func preferredScreen() -> NSScreen {
        if let builtIn = NSScreen.screens.first(where: { screen in
            guard let number = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")]
                    as? NSNumber else { return false }
            return CGDisplayIsBuiltin(CGDirectDisplayID(number.uint32Value)) != 0
        }) {
            return builtIn
        }

        let mouseLocation = NSEvent.mouseLocation
        return NSScreen.screens.first(where: { $0.frame.contains(mouseLocation) })
            ?? NSScreen.main
            ?? NSScreen.screens[0]
    }

    private func installEventMonitors() {
        localMonitor = NSEvent.addLocalMonitorForEvents(
            matching: [.keyDown, .leftMouseDown]
        ) { [weak self] event in
            guard let self, self.presentation == .expanded else { return event }
            if event.type == .keyDown, event.keyCode == 53 {
                self.collapse(animated: true)
                return nil
            }
            if event.type == .leftMouseDown,
               !self.expandedPanel.frame.contains(NSEvent.mouseLocation) {
                self.collapse(animated: true)
            }
            return event
        }
        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: .leftMouseDown) {
            [weak self] _ in
            Task { @MainActor in
                guard let self, self.presentation == .expanded else { return }
                if !self.expandedPanel.frame.contains(NSEvent.mouseLocation) {
                    self.collapse(animated: true)
                }
            }
        }
    }

    private func startHoverPolling() {
        hoverTimer = Timer.scheduledTimer(
            withTimeInterval: Self.hoverPollInterval,
            repeats: true
        ) { [weak self] _ in
            Task { @MainActor in self?.pollHover() }
        }
    }

    private func pollHover(now: TimeInterval = ProcessInfo.processInfo.systemUptime) {
        let isInside = settings.triggerMode == .hover
            && presentation == .compact
            && compactPanel.isVisible
            && compactPanel.frame.contains(NSEvent.mouseLocation)
        if hoverDwell.update(isInside: isInside, now: now) {
            hoverDwell = HoverDwellState(duration: 0.120)
            expand(animated: true)
        }
    }
}

@MainActor
private final class CompactHostingView<Content: View>: NSHostingView<Content> {
    var onMouseDown: (() -> Void)?

    override func mouseDown(with event: NSEvent) {
        onMouseDown?()
    }
}

private final class NotchPanel: NSPanel {
    override var canBecomeKey: Bool { true }
}
