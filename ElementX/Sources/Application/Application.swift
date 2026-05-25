//
// Copyright 2025 Element Creations Ltd.
// Copyright 2022-2025 New Vector Ltd.
//
// SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial.
// Please see LICENSE files in the repository root for full details.
//

import AVFoundation
import Compound
import SwiftUI
import UIKit

@main
struct Application: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @Environment(\.openURL) private var openURL
    @ObservedObject private var appThemeService = AppThemeService.shared
    
    private var appCoordinator: AppCoordinatorProtocol!

    init() {
        let coordinator: AppCoordinatorProtocol
        
        if ProcessInfo.isRunningUITests {
            coordinator = UITestsAppCoordinator(appDelegate: appDelegate)
        } else if ProcessInfo.isRunningUnitTests {
            coordinator = UnitTestsAppCoordinator(appDelegate: appDelegate)
        } else if ProcessInfo.isRunningAccessibilityTests {
            coordinator = AccessibilityTestsAppCoordinator(appDelegate: appDelegate)
        } else {
            coordinator = AppCoordinator(appDelegate: appDelegate)
        }
        
        appCoordinator = coordinator
        
        SceneDelegate.windowManager = coordinator.windowManager
        GlobalMediaPlayerController.shared.openRoomAction = { roomID in
            let encodedRoomID = roomID.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? roomID
            if let url = URL(string: "https://matrix.to/#/\(encodedRoomID)") {
                _ = coordinator.handleDeepLink(url, isExternalURL: false)
            }
        }
    }

    var body: some Scene {
        WindowGroup {
            appCoordinator.toPresentable()
                .tint(appThemeService.accentColor)
                .scaleEffect(appThemeService.uiScale, anchor: .top)
                .statusBarHidden(shouldHideStatusBar)
                .overlay(alignment: .top) {
                    if #available(iOS 26, *), ProcessInfo.processInfo.isiOSAppOnMac {
                        // Fake an old-school titlebar to reduce the "floaty-ness" of everything with liquid glass.
                        Divider().ignoresSafeArea()
                    }
                }
                .overlay(alignment: .topTrailing) {
                    GlobalMiniMediaPlayerOverlay(controller: GlobalMediaPlayerController.shared)
                }
                .environment(\.openURL, OpenURLAction { url in
                    if appCoordinator.handleDeepLink(url, isExternalURL: false) {
                        return .handled
                    }
                    
                    if appCoordinator.handlePotentialPhishingAttempt(url: url, openURLAction: { url in
                        openURL(url, isExternalURL: false)
                    }) {
                        return .handled
                    }

                    return .systemAction
                })
                .onOpenURL { url in
                    openURL(url, isExternalURL: true)
                }
                .onContinueUserActivity("INStartVideoCallIntent") { userActivity in
                    // `INStartVideoCallIntent` is to be replaced with `INStartCallIntent`
                    // but calls from Recents still send it ¯\_(ツ)_/¯
                    appCoordinator.handleUserActivity(userActivity)
                }
                .task {
                    appCoordinator.start()
                }
        }
    }
    
    // MARK: - Private
    
    private func openURL(_ url: URL, isExternalURL: Bool) {
        if !appCoordinator.handleDeepLink(url, isExternalURL: isExternalURL) {
            openURLInSystemBrowser(url)
        }
    }

    /// Hide the status bar so it doesn't interfere with the screenshot tests
    private var shouldHideStatusBar: Bool {
        ProcessInfo.isRunningUITests
    }
    
    /// https://github.com/element-hq/element-x-ios/issues/1824
    /// Avoid opening universal links in other app variants and infinite loops between them
    private func openURLInSystemBrowser(_ originalURL: URL) {
        guard var urlComponents = URLComponents(url: originalURL, resolvingAgainstBaseURL: true) else {
            openURL(originalURL)
            return
        }
        
        var queryItems = urlComponents.queryItems ?? []
        queryItems.append(.init(name: "no_universal_links", value: "true"))
        
        urlComponents.queryItems = queryItems
        
        guard let url = urlComponents.url else {
            openURL(originalURL)
            return
        }
        
        openURL(url)
    }
}

private struct GlobalMiniMediaPlayerOverlay: View {
    @ObservedObject var controller: GlobalMediaPlayerController
    
    var body: some View {
        VStack(alignment: .trailing, spacing: 12) {
            if controller.shouldShowFloatingVideoNote {
                MiniPlayerVideoNoteOverlayView(controller: controller)
                    .transition(.asymmetric(insertion: .scale(scale: 0.88, anchor: .topTrailing).combined(with: .opacity),
                                            removal: .scale(scale: 0.84, anchor: .topTrailing).combined(with: .opacity)))
            }
        }
        .padding(.top, 12)
        .padding(.horizontal, 12)
        .animation(.spring(response: 0.34, dampingFraction: 0.86).disabledDuringTests(), value: controller.shouldShowFloatingVideoNote)
    }
}

struct InlineMiniMediaPlayerView: View {
    enum DisplayMode {
        case expanded
        case compact
    }
    
    @ObservedObject var controller: GlobalMediaPlayerController
    @Environment(\.colorScheme) private var colorScheme
    var displayMode: DisplayMode = .expanded
    var onExpand: (() -> Void)?
    
    @State private var sliderValue = 0.0
    @State private var isQueuePresented = false
    
    private var playerState: AudioPlayerState? {
        controller.activeAudio?.playerState
    }
    
    var body: some View {
        if let activeAudio = controller.activeAudio,
           let playerState {
            InlineMiniAudioPlayerContent(controller: controller,
                                         activeAudio: activeAudio,
                                         playerState: playerState,
                                         displayMode: displayMode,
                                         colorScheme: colorScheme,
                                         onExpand: onExpand,
                                         isQueuePresented: $isQueuePresented)
                .transition(playerTransition)
                .sheet(isPresented: $isQueuePresented) {
                    ElementNavigationStack {
                        List(activeAudio.queue) { item in
                            Button {
                                controller.selectAudioItem(item.itemID)
                                isQueuePresented = false
                            } label: {
                                HStack(spacing: 8) {
                                    Text(item.title)
                                        .foregroundStyle(.compound.textPrimary)
                                    Spacer()
                                    if item.itemID == activeAudio.queue[activeAudio.currentIndex].itemID {
                                        Image(systemName: "speaker.wave.2.fill")
                                            .foregroundStyle(.compound.textActionPrimary)
                                    }
                                }
                            }
                        }
                        .navigationTitle(L10n.commonAudio)
                    }
                }
        } else if let activeVideoNote = controller.activeVideoNote {
            videoNoteContent(activeVideoNote: activeVideoNote)
                .transition(playerTransition)
        }
    }
    
    private var playerTransition: AnyTransition {
        .asymmetric(insertion: .move(edge: .top).combined(with: .opacity),
                    removal: .move(edge: .top).combined(with: .opacity))
    }
}

private struct InlineMiniAudioPlayerContent: View {
    @ObservedObject var controller: GlobalMediaPlayerController
    let activeAudio: GlobalMediaPlayerController.ActiveAudioPresentation
    @ObservedObject var playerState: AudioPlayerState
    let displayMode: InlineMiniMediaPlayerView.DisplayMode
    let colorScheme: ColorScheme
    let onExpand: (() -> Void)?
    @Binding var isQueuePresented: Bool
    
    @State private var sliderValue = 0.0
    @State private var isScrubbingSlider = false
    
    var body: some View {
        switch displayMode {
        case .compact:
            compactAudioPlayer
        case .expanded:
            expandedAudioPlayer
        }
    }
    
    private var compactAudioPlayer: some View {
        Button {
            onExpand?()
        } label: {
            HStack(spacing: 10) {
                Capsule()
                    .fill(.compound.textActionPrimary)
                    .frame(width: 32, height: 4)
                Text(activeAudio.title)
                    .font(.compound.bodySMSemibold)
                    .foregroundStyle(.compound.textPrimary)
                    .lineLimit(1)
                Spacer()
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .miniPlayerCard(cornerRadius: 999, colorScheme: colorScheme)
        }
        .buttonStyle(.plain)
        .shadow(color: .black.opacity(0.10), radius: 10, y: 4)
    }
    
    private var expandedAudioPlayer: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 12) {
                previousButton
                primaryPlayPauseButton
                trackTitleButton
                Spacer(minLength: 8)
                queueButton
                speedButton
                nextButton
                closeButton
            }
            progressSlider
        }
        .padding(12)
        .frame(maxWidth: .infinity)
        .miniPlayerCard(cornerRadius: 20, colorScheme: colorScheme)
        .shadow(color: .black.opacity(0.12), radius: 12, y: 4)
    }
    
    private var previousButton: some View {
        Button {
            controller.playPreviousAudio()
        } label: {
            Image(systemName: "backward.fill")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(controller.canPlayPreviousAudio ? .compound.textPrimary : .compound.iconQuaternary)
        }
        .buttonStyle(.plain)
        .disabled(!controller.canPlayPreviousAudio)
    }
    
    private var primaryPlayPauseButton: some View {
        Button {
            if playerState.playbackState != .loading {
                controller.toggleAudioPlayback()
            }
        } label: {
            ZStack {
                Circle()
                    .fill(colorScheme == .dark ? Color.white.opacity(0.18) : Color.black.opacity(0.78))
                    .frame(width: 34, height: 34)
                
                if playerState.playbackState == .loading {
                    ProgressView()
                        .controlSize(.small)
                        .tint(.white)
                } else {
                    Image(systemName: playerState.playbackState == .playing ? "pause.fill" : "play.fill")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(colorScheme == .dark ? .white : Color.white.opacity(0.96))
                }
            }
        }
        .buttonStyle(.plain)
        .disabled(playerState.playbackState == .loading)
    }
    
    private var trackTitleButton: some View {
        Button {
            controller.openActiveMediaRoom()
        } label: {
            VStack(alignment: .leading, spacing: 2) {
                Text(activeAudio.title)
                    .font(.compound.bodyMDSemibold)
                    .foregroundStyle(.compound.textPrimary)
                    .lineLimit(1)
                Text(timeText)
                    .font(.compound.bodyXS)
                    .foregroundStyle(.compound.textSecondary)
                    .monospacedDigit()
            }
        }
        .buttonStyle(.plain)
    }
    
    private var queueButton: some View {
        Button {
            isQueuePresented = true
        } label: {
            Image(systemName: "list.bullet")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.compound.textPrimary)
                .frame(width: 28, height: 28)
        }
        .buttonStyle(.plain)
    }
    
    private var speedButton: some View {
        Button {
            controller.cycleAudioPlaybackSpeed()
        } label: {
            Text(playerState.playbackSpeed.label)
                .font(.compound.bodyXSSemibold)
                .foregroundStyle(.compound.textPrimary)
                .frame(minWidth: 32)
        }
        .buttonStyle(.plain)
    }
    
    private var nextButton: some View {
        Button {
            controller.playNextAudio()
        } label: {
            Image(systemName: "forward.fill")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(controller.canPlayNextAudio ? .compound.textPrimary : .compound.iconQuaternary)
        }
        .buttonStyle(.plain)
        .disabled(!controller.canPlayNextAudio)
    }
    
    private var closeButton: some View {
        Button {
            controller.closeAudioPlayer()
        } label: {
            Image(systemName: "xmark")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(.compound.textPrimary)
                .frame(width: 28, height: 28)
                .background(colorScheme == .dark ? Color.white.opacity(0.14) : Color.black.opacity(0.08), in: Circle())
        }
        .buttonStyle(.plain)
    }
    
    private var progressSlider: some View {
        Slider(value: Binding {
            isScrubbingSlider ? sliderValue : playerState.progress
        } set: { newValue in
            sliderValue = newValue
        }, in: 0...1, onEditingChanged: { editing in
            isScrubbingSlider = editing
            
            if editing {
                sliderValue = playerState.progress
                return
            }
            
            let finalValue = sliderValue
            Task { await controller.seekAudio(to: finalValue) }
        })
        .tint(.compound.textActionPrimary)
        .onAppear {
            sliderValue = playerState.progress
        }
        .onChange(of: playerState.progress) { _, newValue in
            guard !isScrubbingSlider else { return }
            sliderValue = newValue
        }
    }
    
    private var timeText: String {
        let current = max(0, Int(playerState.duration * playerState.progress))
        let duration = max(0, Int(playerState.duration))
        return "\(formattedTime(current)) / \(formattedTime(duration))"
    }
    
    private func formattedTime(_ seconds: Int) -> String {
        String(format: "%d:%02d", seconds / 60, seconds % 60)
    }
}

private extension InlineMiniMediaPlayerView {
    @ViewBuilder
    func videoNoteContent(activeVideoNote: GlobalMediaPlayerController.ActiveVideoNotePresentation) -> some View {
        switch displayMode {
        case .compact:
            Button {
                onExpand?()
            } label: {
                HStack(spacing: 10) {
                    Circle()
                        .fill(.compound.textActionPrimary)
                        .frame(width: 8, height: 8)
                    Text(L10n.commonVideo)
                        .font(.compound.bodySMSemibold)
                        .foregroundStyle(.compound.textPrimary)
                    Spacer()
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .miniPlayerCard(cornerRadius: 999, colorScheme: colorScheme)
            }
            .buttonStyle(.plain)
        case .expanded:
            HStack(spacing: 12) {
                Group {
                    if let player = activeVideoNote.player {
                        MiniPlayerVideoLayerView(player: player)
                    } else {
                        Circle()
                            .fill(.compound.bgSubtlePrimary)
                            .overlay {
                                ProgressView()
                            }
                    }
                }
                .frame(width: 44, height: 44)
                .clipShape(Circle())
                
                Button {
                    controller.openActiveMediaRoom()
                } label: {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(L10n.commonVideo)
                            .font(.compound.bodyMDSemibold)
                            .foregroundStyle(.compound.textPrimary)
                        Text(activeVideoNote.filename)
                            .font(.compound.bodyXS)
                            .foregroundStyle(.compound.textSecondary)
                            .lineLimit(1)
                    }
                }
                .buttonStyle(.plain)
                
                Spacer()
                
                Button {
                    controller.toggleVideoNotePlayback()
                } label: {
                    Image(systemName: activeVideoNote.isPlaying ? "pause.fill" : "play.fill")
                        .foregroundStyle(.compound.textPrimary)
                }
                .buttonStyle(.plain)
                
                Button {
                    controller.stopVideoNote()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(.compound.textPrimary)
                        .frame(width: 28, height: 28)
                        .background(Color.compound.bgSubtlePrimary, in: Circle())
                }
                .buttonStyle(.plain)
            }
            .padding(12)
            .frame(maxWidth: .infinity)
            .miniPlayerCard(cornerRadius: 20, colorScheme: colorScheme)
            .shadow(color: .black.opacity(0.12), radius: 12, y: 4)
        }
    }
}

private extension View {
    @ViewBuilder
    func miniPlayerCard(cornerRadius: CGFloat, colorScheme: ColorScheme) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        let theme = AppThemeService.shared.currentTheme
        let useGlass = AppThemeService.shared.shouldUseLiquidGlass && theme.enableBlurEffects
        
        if #available(iOS 26, *), useGlass {
            background(Color.clear, in: shape)
                .glassEffect(.regular.interactive(), in: shape)
                .overlay {
                    shape
                        .stroke(colorScheme == .dark ? Color.white.opacity(0.18) : Color.white.opacity(0.38), lineWidth: 0.5)
                }
        } else {
            background(theme.enableBlurEffects ? AnyShapeStyle(.ultraThinMaterial)
                : AnyShapeStyle(colorScheme == .dark ? Color.black.opacity(0.35) : Color.white.opacity(0.82)), in: shape)
                .overlay {
                    shape
                        .stroke(colorScheme == .dark ? Color.white.opacity(0.14) : Color.black.opacity(0.08), lineWidth: 0.5)
                }
        }
    }
}

private struct MiniPlayerVideoNoteOverlayView: View {
    @ObservedObject var controller: GlobalMediaPlayerController
    @GestureState private var dragOffset: CGSize = .zero
    
    var body: some View {
        if let activeVideoNote = controller.activeVideoNote {
            ZStack(alignment: .topTrailing) {
                Group {
                    if let player = activeVideoNote.player {
                        MiniPlayerVideoLayerView(player: player)
                            .overlay {
                                CircularVideoNoteScrubber(progress: activeVideoNote.progress) { progress in
                                    controller.seekVideoNote(to: progress)
                                }
                                .padding(3)
                            }
                            .onTapGesture {
                                controller.toggleVideoNotePlayback()
                            }
                            .onReceive(NotificationCenter.default.publisher(for: .AVPlayerItemDidPlayToEndTime,
                                                                            object: player.currentItem)) { _ in
                                controller.handleVideoNotePlaybackEnded()
                            }
                    } else {
                        Circle()
                            .fill(Color.compound.bgSubtlePrimary)
                            .overlay {
                                ProgressView()
                            }
                    }
                }
                .frame(width: 140, height: 140)
                .clipShape(Circle())
                
                Button {
                    controller.stopVideoNote()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 28, height: 28)
                        .background(.ultraThinMaterial, in: Circle())
                }
                .buttonStyle(.plain)
                .padding(6)
            }
            .offset(x: activeVideoNote.offset.width + dragOffset.width,
                    y: activeVideoNote.offset.height + dragOffset.height)
            .shadow(color: .black.opacity(0.18), radius: 16, y: 8)
            .gesture(DragGesture()
                .updating($dragOffset) { value, state, _ in
                    state = value.translation
                }
                .onEnded { value in
                    controller.updateVideoNoteOffset(value.translation)
                    controller.finishVideoNoteDrag()
                })
        }
    }
}

private struct MiniPlayerVideoLayerView: UIViewRepresentable {
    let player: AVPlayer
    
    func makeUIView(context: Context) -> MiniPlayerVideoView {
        let view = MiniPlayerVideoView()
        view.playerLayer.videoGravity = .resizeAspectFill
        view.playerLayer.player = player
        return view
    }
    
    func updateUIView(_ view: MiniPlayerVideoView, context: Context) {
        if view.playerLayer.player !== player {
            view.playerLayer.player = player
        }
    }
}

private struct CircularVideoNoteScrubber: View {
    let progress: Double
    let onSeek: (Double) -> Void
    
    var body: some View {
        GeometryReader { geometry in
            let size = min(geometry.size.width, geometry.size.height)
            let lineWidth = max(6, size * 0.04)
            
            ZStack {
                Circle()
                    .stroke(.white.opacity(0.18), lineWidth: lineWidth)
                
                Circle()
                    .trim(from: 0, to: max(progress, 0.001))
                    .stroke(.white,
                            style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                
                Circle()
                    .fill(.white)
                    .frame(width: lineWidth, height: lineWidth)
                    .offset(knobOffset(in: size, lineWidth: lineWidth))
                    .shadow(color: .black.opacity(0.18), radius: 3, y: 1)
            }
            .contentShape(Circle())
            .simultaneousGesture(DragGesture(minimumDistance: 4)
                .onChanged { value in
                    guard isNearScrubber(value.location, in: geometry.size, lineWidth: lineWidth) else { return }
                    onSeek(progress(for: value.location, in: geometry.size))
                })
        }
    }
    
    private func knobOffset(in size: CGFloat, lineWidth: CGFloat) -> CGSize {
        let radius = (size / 2) - lineWidth / 2
        let angle = (progress * .pi * 2) - (.pi / 2)
        return CGSize(width: cos(angle) * radius, height: sin(angle) * radius)
    }
    
    private func progress(for location: CGPoint, in size: CGSize) -> Double {
        let center = CGPoint(x: size.width / 2, y: size.height / 2)
        let angle = atan2(location.y - center.y, location.x - center.x) + (.pi / 2)
        let normalizedAngle = angle < 0 ? angle + (.pi * 2) : angle
        return min(max(normalizedAngle / (.pi * 2), 0), 1)
    }
    
    private func isNearScrubber(_ location: CGPoint, in size: CGSize, lineWidth: CGFloat) -> Bool {
        let center = CGPoint(x: size.width / 2, y: size.height / 2)
        let distance = hypot(location.x - center.x, location.y - center.y)
        let radius = (min(size.width, size.height) / 2) - lineWidth / 2
        return abs(distance - radius) <= max(16, lineWidth * 2.2)
    }
}

private final class MiniPlayerVideoView: UIView {
    override static var layerClass: AnyClass {
        AVPlayerLayer.self
    }
    
    var playerLayer: AVPlayerLayer {
        guard let layer = layer as? AVPlayerLayer else {
            fatalError("Expected AVPlayerLayer")
        }
        return layer
    }
}
