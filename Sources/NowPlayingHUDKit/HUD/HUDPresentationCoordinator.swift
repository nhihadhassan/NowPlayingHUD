import AppKit
import SwiftUI

/// Owns the HUD panel(s), the presentation state machine, hover detection, artwork loading, and
/// screen positioning — the single place that turns "a playback event happened" into "the HUD is
/// on screen, showing the right thing, in the right place."
///
/// Normally this manages exactly one `HUDPanel`. It manages more than one only when the user has
/// chosen "All Displays" for monitor behavior, in which case every display gets an identical,
/// synchronized panel sharing the same `HUDContentModel` — hovering over any one of them expands
/// all of them together. This is a deliberate simplification for a secondary, optional mode; the
/// default (and every other monitor-behavior option) only ever has one panel on screen.
@MainActor
public final class HUDPresentationCoordinator: HUDInteracting {
    private struct PanelInstance {
        let panel: HUDPanel
        let hostingView: NSHostingView<HUDRootView>
        let hoverTracker: HUDHoverTracker
        var screenID: String
    }

    private let preferences: PreferencesStore
    private let playback: PlaybackCoordinator
    private let artworkService: ArtworkService
    public let contentModel = HUDContentModel()

    private var instances: [PanelInstance] = []
    private var stateMachine = HUDStateMachine()

    private var dismissalTask: Task<Void, Never>?
    private var graceTask: Task<Void, Never>?
    private var artworkTask: Task<Void, Never>?
    private var eventTask: Task<Void, Never>?
    private var screenObserver: NSObjectProtocol?
    private var sleepObserver: NSObjectProtocol?

    private var lastKnownSnapshot: PlaybackSnapshot?
    private var lastArtworkKey: String?
    private var manualControlDeadline: ContinuousClock.Instant?

    /// "Disable automatic HUD temporarily", from the menu bar's context menu. Distinct from
    /// `preferences.automaticHUDEnabled`, which is the persistent Settings toggle.
    public private(set) var isTemporarilyDisabled = false

    public init(preferences: PreferencesStore, playback: PlaybackCoordinator, artworkService: ArtworkService) {
        self.preferences = preferences
        self.playback = playback
        self.artworkService = artworkService
    }

    public func start() {
        eventTask = Task { [weak self] in
            guard let self else { return }
            for await event in playback.significantEvents {
                self.handle(event)
            }
        }
        let workspaceCenter = NSWorkspace.shared.notificationCenter
        sleepObserver = workspaceCenter.addObserver(forName: NSWorkspace.willSleepNotification, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in
                guard let self else { return }
                self.apply(self.stateMachine.handle(.forceHide))
            }
        }
        screenObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification, object: nil, queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.repositionIfNeeded()
            }
        }
    }

    public func stop() {
        eventTask?.cancel()
        dismissalTask?.cancel()
        graceTask?.cancel()
        artworkTask?.cancel()
        if let sleepObserver { NSWorkspace.shared.notificationCenter.removeObserver(sleepObserver) }
        if let screenObserver { NotificationCenter.default.removeObserver(screenObserver) }
        for instance in instances { instance.hoverTracker.stop() }
        instances.removeAll()
    }

    // MARK: - Public actions (menu bar / global shortcuts)

    public func showManually() {
        apply(stateMachine.handle(.manualShow))
    }

    public func setAutomaticHUDEnabled(_ enabled: Bool) {
        guard !enabled else { return }
        apply(stateMachine.handle(.forceHide))
    }

    public func setTemporarilyDisabled(_ disabled: Bool) {
        isTemporarilyDisabled = disabled
        if disabled { apply(stateMachine.handle(.forceHide)) }
    }

    /// Marks the next incoming playback event as user-initiated through this app's own UI, so
    /// `HUDPresentationPolicy` classifies it as `.manualControl` rather than its natural kind —
    /// `showOnManualControl` then governs it independent of `showOnTrackChange`/etc.
    public func notifyManualControl() {
        manualControlDeadline = .now.advanced(by: .seconds(2))
    }

    // MARK: - HUDInteracting

    public func perform(_ command: PlaybackCommand) {
        notifyManualControl()
        Task { _ = await playback.perform(command) }
    }

    public func openInPlayer() {
        guard let url = lastKnownSnapshot?.track?.externalURL else { return }
        NSWorkspace.shared.open(url)
    }

    public func copyTrackLink() {
        guard let track = lastKnownSnapshot?.track else { return }
        let link: URL?
        if track.provider == .spotify {
            link = SpotifyScript.shareableLink(forTrackID: track.id)
        } else {
            link = track.externalURL
        }
        guard let link else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(link.absoluteString, forType: .string)
    }

    public func copyTrackAndArtist() {
        guard let track = lastKnownSnapshot?.track else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(track.copyableSummary, forType: .string)
    }

    public func hoverStateChanged(isHovering: Bool) {
        apply(stateMachine.handle(isHovering ? .pointerEntered : .pointerExited))
        if isHovering {
            // No longer needed: the panel is now interactive, so native AppKit/SwiftUI hover
            // events (which drive the exit path) take over from here.
            for instance in instances { instance.hoverTracker.stop() }
        }
        resizeInstances(animated: true)
    }

    public func primaryClickTriggered() {
        switch preferences.primaryClickAction {
        case .openInPlayer: openInPlayer()
        case .expandPlayer: contentModel.isHovering = true; resizeInstances(animated: true)
        case .none: break
        }
    }

    public func dismissRequested() {
        apply(stateMachine.handle(.manualDismiss))
    }

    // MARK: - Playback events

    private func handle(_ event: PlaybackCoordinatorEvent) {
        let changeKind: PlaybackChangeKind
        if let deadline = manualControlDeadline, ContinuousClock.now < deadline {
            changeKind = .manualControl
            manualControlDeadline = nil
        } else {
            changeKind = HUDPresentationPolicy.classify(previous: lastKnownSnapshot, new: event.snapshot)
        }
        lastKnownSnapshot = event.snapshot
        contentModel.apply(event.snapshot)
        loadArtworkIfNeeded(for: event.snapshot.track)

        let shouldPresent = HUDPresentationPolicy.shouldPresent(
            isSignificant: event.isSignificant,
            changeKind: changeKind,
            automaticHUDEnabled: preferences.automaticHUDEnabled,
            temporarilyDisabled: isTemporarilyDisabled,
            showOnTrackChange: preferences.showOnTrackChange,
            showOnPlayResume: preferences.showOnPlayResume,
            showOnPause: preferences.showOnPause,
            showOnManualControl: preferences.showOnManualControl,
            isPlayerFrontmost: isActivePlayerFrontmost(),
            hideWhenPlayerFrontmost: preferences.hideWhenPlayerFrontmost
        )
        guard shouldPresent else { return }
        apply(stateMachine.handle(.significantChange))
    }

    private func isActivePlayerFrontmost() -> Bool {
        guard let provider = playback.activeProvider else { return false }
        return NSWorkspace.shared.frontmostApplication?.bundleIdentifier == provider.bundleIdentifier
    }

    private func loadArtworkIfNeeded(for track: Track?) {
        guard let track else {
            artworkTask?.cancel()
            lastArtworkKey = nil
            contentModel.artworkImage = nil
            contentModel.accent = nil
            return
        }
        let key = "\(track.provider.rawValue)|\(track.id)"
        guard key != lastArtworkKey else { return }
        lastArtworkKey = key
        artworkTask?.cancel()
        artworkTask = Task { [weak self] in
            guard let self else { return }
            let image = await self.artworkService.image(for: track.artwork) { [weak self] trackID in
                await self?.playback.fetchAppleMusicArtwork(trackID: trackID)
            }
            guard !Task.isCancelled else { return }
            self.contentModel.artworkImage = image
            self.contentModel.accent = image.flatMap { AccentExtractor.extractAccent(from: $0) }
        }
    }

    // MARK: - State machine action execution

    private func apply(_ actions: [HUDStateMachine.Action]) {
        for action in actions {
            switch action {
            case .presentFresh:
                presentFresh()
            case .updateInPlace:
                resizeInstances(animated: true)
            case .restartDismissalTimer:
                cancelPendingTimers()
                startDismissalTask()
            case .cancelDismissalTimer:
                cancelPendingTimers()
            case .startHoverGraceTimer:
                cancelPendingTimers()
                startGraceTask()
            case .cancelHoverGraceTimer:
                cancelPendingTimers()
            case .playExitAnimationThenHide:
                cancelPendingTimers()
                exitThenHide()
            case .hideImmediately:
                cancelPendingTimers()
                hideImmediately()
            }
        }
    }

    private func cancelPendingTimers() {
        dismissalTask?.cancel()
        dismissalTask = nil
        graceTask?.cancel()
        graceTask = nil
    }

    private func startDismissalTask() {
        let duration = preferences.displayDurationSeconds
        dismissalTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(duration))
            guard !Task.isCancelled else { return }
            self?.apply(self?.stateMachine.handle(.dismissalTimerFired) ?? [])
        }
    }

    private func startGraceTask() {
        // Re-arm hover detection: the panel just went back to click-through, so re-entry during
        // the grace window needs the same global-monitor mechanism `presentFresh` used initially.
        for instance in instances {
            instance.hoverTracker.start(trackingFrame: { [instance] in instance.panel.frame })
        }
        let delay = preferences.hoverDismissDelaySeconds
        graceTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(delay))
            guard !Task.isCancelled else { return }
            self?.apply(self?.stateMachine.handle(.hoverGraceTimerFired) ?? [])
        }
    }

    // MARK: - Panel lifecycle

    private func presentFresh() {
        rebuildInstances()
        guard !instances.isEmpty else { return }
        contentModel.isHovering = false
        for instance in instances {
            instance.panel.orderFrontRegardless()
            instance.hoverTracker.start(trackingFrame: { [instance] in instance.panel.frame })
        }
        contentModel.isVisible = true
    }

    private func exitThenHide() {
        contentModel.isVisible = false
        let reduceMotion = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
        let delay = reduceMotion ? 0.18 : 0.32
        let capturedInstances = instances
        instances.removeAll()
        Task {
            try? await Task.sleep(for: .seconds(delay))
            for instance in capturedInstances {
                instance.hoverTracker.stop()
                instance.panel.orderOut(nil)
            }
        }
    }

    private func hideImmediately() {
        contentModel.isVisible = false
        for instance in instances {
            instance.hoverTracker.stop()
            instance.panel.orderOut(nil)
        }
        instances.removeAll()
    }

    private func rebuildInstances() {
        for instance in instances { instance.hoverTracker.stop(); instance.panel.orderOut(nil) }
        instances.removeAll()

        let screens = targetScreens()
        for screen in screens {
            let rootView = HUDRootView(content: contentModel, options: currentDisplayOptions(), interactor: self)
            let hostingView = NSHostingView(rootView: rootView)
            let fittingSize = hostingView.fittingSize
            let panel = HUDPanel(contentRect: NSRect(origin: .zero, size: fittingSize))
            panel.updateCollectionBehavior(showOverFullScreenApps: preferences.showOverFullScreenApps)
            panel.contentView = hostingView
            let frame = ScreenPositioningService.frame(
                for: fittingSize, position: preferences.hudPosition,
                edgeOffset: preferences.edgeOffset, on: screen
            )
            panel.setFrame(frame, display: false)
            let tracker = HUDHoverTracker { [weak self] in
                guard let self, self.contentModel.isHovering == false else { return }
                self.hoverStateChanged(isHovering: true)
            }
            instances.append(PanelInstance(panel: panel, hostingView: hostingView, hoverTracker: tracker, screenID: screen.id))
        }
    }

    private func resizeInstances(animated: Bool) {
        guard !instances.isEmpty else { return }
        let screens = Dictionary(uniqueKeysWithValues: targetScreens().map { ($0.id, $0) })
        let reduceMotion = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion

        for instance in instances {
            instance.hostingView.rootView = HUDRootView(content: contentModel, options: currentDisplayOptions(), interactor: self)
            instance.panel.setInteractive(contentModel.isHovering)
            guard let screen = screens[instance.screenID] else { continue }
            let fittingSize = instance.hostingView.fittingSize
            let newFrame = ScreenPositioningService.frame(
                for: fittingSize, position: preferences.hudPosition,
                edgeOffset: preferences.edgeOffset, on: screen
            )
            if animated && !reduceMotion {
                NSAnimationContext.runAnimationGroup { context in
                    context.duration = 0.22
                    context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
                    instance.panel.animator().setFrame(newFrame, display: true)
                }
            } else {
                instance.panel.setFrame(newFrame, display: true)
            }
        }
    }

    private func repositionIfNeeded() {
        guard !instances.isEmpty else { return }
        resizeInstances(animated: false)
    }

    private func targetScreens() -> [ScreenSnapshot] {
        let mouseLocation = NSEvent.mouseLocation
        let mainID = NSScreen.main.map(Self.identifier(for:))
        let snapshots = NSScreen.screens.map(Self.snapshot(from:))
        return ScreenSelection.selectScreens(
            behavior: preferences.monitorBehavior,
            selectedDisplayID: preferences.selectedDisplayID,
            mouseLocation: mouseLocation,
            screens: snapshots,
            mainDisplayID: mainID
        )
    }

    private func currentDisplayOptions() -> HUDDisplayOptions {
        HUDDisplayOptions(
            style: preferences.hudStyle, size: preferences.hudSize,
            showAlbumArt: preferences.showAlbumArt, showTitle: preferences.showTitle,
            showArtist: preferences.showArtist, showAlbum: preferences.showAlbum,
            showProgress: preferences.showProgress, showTime: preferences.showTime,
            showControls: preferences.showControls, hoverToExpand: preferences.hoverToExpand,
            accentFromArtwork: preferences.accentFromArtwork, primaryClickAction: preferences.primaryClickAction
        )
    }

    nonisolated static func identifier(for screen: NSScreen) -> String {
        guard let number = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber else {
            return "unknown"
        }
        return number.stringValue
    }

    nonisolated static func snapshot(from screen: NSScreen) -> ScreenSnapshot {
        let safeAreaTop = screen.safeAreaInsets.top
        let leftAux = screen.auxiliaryTopLeftArea
        let rightAux = screen.auxiliaryTopRightArea
        return ScreenSnapshot(
            id: identifier(for: screen),
            frame: screen.frame,
            visibleFrame: screen.visibleFrame,
            safeAreaInsetTop: safeAreaTop,
            auxiliaryTopLeftArea: (leftAux?.isEmpty == false) ? leftAux : nil,
            auxiliaryTopRightArea: (rightAux?.isEmpty == false) ? rightAux : nil,
            backingScaleFactor: screen.backingScaleFactor
        )
    }
}
