import AppKit
import CoreGraphics
import SwiftUI

enum PanelPresentation: Equatable {
    case compact
    case expanded

    var showsCompactPanel: Bool { self == .compact }
    var showsExpandedPanel: Bool { self == .expanded }
    var toggled: Self { self == .compact ? .expanded : .compact }
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
        presentation = .compact
        applyPresentation(animated: false)
    }

    func expand(animated: Bool) {
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
        compactPanel.setFrame(geometry.compactFrame, display: true)
        expandedPanel.setFrame(geometry.expandedFrame, display: true)

        let shownPanel = presentation.showsCompactPanel ? compactPanel : expandedPanel
        let hiddenPanel = presentation.showsCompactPanel ? expandedPanel : compactPanel
        hiddenPanel.orderOut(nil)
        if animated {
            shownPanel.alphaValue = 0
            shownPanel.orderFrontRegardless()
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.16
                shownPanel.animator().alphaValue = 1
            }
        } else {
            shownPanel.alphaValue = 1
            shownPanel.orderFrontRegardless()
        }
        if presentation.showsExpandedPanel {
            expandedPanel.makeKeyAndOrderFront(nil)
        }
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
