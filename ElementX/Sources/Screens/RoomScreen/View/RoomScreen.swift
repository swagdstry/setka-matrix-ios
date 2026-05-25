//
// Copyright 2025 Element Creations Ltd.
// Copyright 2022-2025 New Vector Ltd.
//
// SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial
// Please see LICENSE files in the repository root for full details.
//

import Combine
import Compound
import CryptoKit
import SwiftUI
import UIKit
import UniformTypeIdentifiers
import WysiwygComposer

struct RoomScreen: View {
    @ObservedObject private var context: RoomScreenViewModelType.Context
    @ObservedObject private var timelineContext: TimelineViewModelType.Context
    @ObservedObject private var composerContext: ComposerToolbarViewModel.Context
    @ObservedObject private var mediaPlayerController = GlobalMediaPlayerController.shared
    @ObservedObject private var roomWallpaperService = RoomWallpaperService.shared
    @ObservedObject private var appThemeService = AppThemeService.shared
    @StateObject private var recordingOverlayController = RoomRecordingOverlayController()
    @State private var setkaPlusComposerPickerData: SetkaPlusComposerPickerData?
    @State private var setkaPickerDragOffset: CGFloat = 0
    @State private var setkaUploadTarget: SetkaPackUploadTarget?
    @State private var showSetkaUploadImporter = false
    @State private var setkaSharePayload: SetkaSharePayload?
    let composerToolbar: ComposerToolbar
    let timelineActions: AnyPublisher<TimelineViewModelAction, Never>
    @Environment(\.accessibilityVoiceOverEnabled) private var isVoiceOverEnabled
    @Environment(\.colorScheme) private var colorScheme

    init(context: RoomScreenViewModelType.Context,
         timelineContext: TimelineViewModelType.Context,
         composerToolbar: ComposerToolbar,
         timelineActions: AnyPublisher<TimelineViewModelAction, Never>) {
        self.context = context
        self.timelineContext = timelineContext
        composerContext = composerToolbar.context
        self.composerToolbar = composerToolbar
        self.timelineActions = timelineActions
    }

    var body: some View {
        contentView
            .sentryTrace("\(Self.self)")
    }

    private var contentView: some View {
        baseTimelineView
            .onReceive(timelineActions, perform: handleAction)
            .overlay(alignment: .bottom) {
                if let data = setkaPlusComposerPickerData {
                    SetkaPlusComposerPickerSheet(packs: timelineContext.viewState.setkaPlusStickerPacks.isEmpty ? data.packs : timelineContext.viewState.setkaPlusStickerPacks,
                                                 mediaProvider: context.mediaProvider,
                                                 onSendSticker: { packID, stickerID in
                                                     timelineContext.send(viewAction: .sendSetkaPlusSticker(packID: packID, stickerID: stickerID))
                                                     setkaPlusComposerPickerData = nil
                                                 },
                                                 onInsertUnicodeEmoji: { text in
                                                     composerContext.send(viewAction: .insertText(text))
                                                 },
                                                 onInsertCustomEmoji: { sticker in
                                                     insertCustomEmojiIntoComposer(sticker)
                                                 },
                                                 onCreateStickerPack: { name, kind in
                                                     timelineContext.send(viewAction: .createSetkaPlusStickerPack(name: name, kind: kind))
                                                 },
                                                 onDeleteStickerPack: { packID in
                                                     timelineContext.send(viewAction: .deleteSetkaPlusStickerPack(packID: packID))
                                                 },
                                                 onDeleteSticker: { packID, stickerID in
                                                     timelineContext.send(viewAction: .deleteSetkaPlusSticker(packID: packID, stickerID: stickerID))
                                                 },
                                                 onSharePack: { packID in
                                                     timelineContext.send(viewAction: .shareSetkaPlusStickerPack(packID: packID))
                                                 },
                                                 onUploadToPack: { packID, kind in
                                                     setkaUploadTarget = .init(packID: packID, kind: kind)
                                                     showSetkaUploadImporter = true
                                                 },
                                                 onDismiss: {
                                                     setkaPlusComposerPickerData = nil
                                                 })
                                                 .padding(.horizontal, 8)
                                                 .padding(.bottom, 4)
                                                 .offset(y: max(0, setkaPickerDragOffset))
                                                 .gesture(
                                                     DragGesture(minimumDistance: 8)
                                                         .onChanged { value in
                                                             if value.translation.height > 0 {
                                                                 setkaPickerDragOffset = value.translation.height
                                                             }
                                                         }
                                                         .onEnded { value in
                                                             let shouldDismiss = value.translation.height > 90 || value.predictedEndTranslation.height > 140
                                                             if shouldDismiss {
                                                                 setkaPlusComposerPickerData = nil
                                                             }
                                                             setkaPickerDragOffset = 0
                                                         }
                                                 )
                                                 .transition(.move(edge: .bottom).combined(with: .opacity))
                                                 .onDisappear {
                                                     setkaPickerDragOffset = 0
                                                 }
                }
            }
            .sheet(item: $setkaSharePayload) { payload in
                AppActivityView(activityItems: [payload.url], onCancel: {
                    setkaSharePayload = nil
                }, onComplete: { _ in
                    setkaSharePayload = nil
                })
            }
            .fileImporter(isPresented: $showSetkaUploadImporter,
                          allowedContentTypes: [.image],
                          allowsMultipleSelection: false) { result in
                guard let target = setkaUploadTarget else {
                    return
                }

                switch result {
                case .success(let urls):
                    guard let originalURL = urls.first else {
                        return
                    }

                    let uploadURL = persistImportedSetkaMediaURL(originalURL)
                    timelineContext.send(viewAction: .uploadSetkaPlusMedia(packID: target.packID,
                                                                           kind: target.kind,
                                                                           mediaURL: uploadURL))
                case .failure(let error):
                    MXLog.error("Failed selecting Setka upload media with error: \(error)")
                }

                setkaUploadTarget = nil
            }
            .overlay { recordingOverlay }
            .onAppear {
                GlobalMediaPlayerController.shared.setCurrentRoomID(timelineContext.viewState.roomID)
            }
            .onDisappear {
                if GlobalMediaPlayerController.shared.currentRoomID == timelineContext.viewState.roomID {
                    GlobalMediaPlayerController.shared.setCurrentRoomID(nil)
                }
            }
            .onChange(of: composerContext.viewState.composerMode, initial: true) { _, newValue in
                handleComposerModeChange(newValue)
            }
            .task(id: timelineContext.viewState.roomID) {
                await roomWallpaperService.refreshFromServer(roomID: timelineContext.viewState.roomID)
            }
            .environmentObject(recordingOverlayController)
    }

    private func handleAction(_ action: TimelineViewModelAction) {
        if case let .displaySetkaPlusComposerPicker(packs) = action {
            setkaPlusComposerPickerData = .init(packs: packs)
        } else if case let .displaySetkaPlusShareSheet(packName, url) = action {
            setkaSharePayload = .init(packName: packName, url: url)
        } else if case .displayVideoNoteRecorder = action {
            recordingOverlayController.beginRecording(.video)
        }
    }

    private func persistImportedSetkaMediaURL(_ url: URL) -> URL {
        let destinationURL = URL.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension(url.pathExtension)

        do {
            if FileManager.default.fileExists(atPath: destinationURL.path(percentEncoded: false)) {
                try FileManager.default.removeItem(at: destinationURL)
            }
            try FileManager.default.copyItem(at: url, to: destinationURL)
            return destinationURL
        } catch {
            MXLog.error("Failed persisting imported Setka media with error: \(error)")
            return url
        }
    }

    private func insertCustomEmojiIntoComposer(_ sticker: SetkaPlusStickerItem) {
        let token = ":\(normalizedSetkaEmojiTokenName(sticker.name)): "
        composerContext.send(viewAction: .insertText(token))
    }

    private func normalizedSetkaEmojiTokenName(_ name: String) -> String {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let spacesNormalized = trimmed.replacingOccurrences(of: " ", with: "_")
        let replaced = spacesNormalized.replacingOccurrences(of: "[^A-Za-z0-9_]+", with: "_", options: .regularExpression)
        let collapsed = replaced.replacingOccurrences(of: "_+", with: "_", options: .regularExpression)
        let normalized = collapsed.trimmingCharacters(in: CharacterSet(charactersIn: "_"))
        return normalized.isEmpty ? "emoji" : normalized
    }
    
    private var baseTimelineView: some View {
        TimelineView(timelineContext: timelineContext)
            .overlay(alignment: .bottomTrailing) {
                TimelineScrollToBottomButton(isVisible: isAtBottomAndLive) {
                    timelineContext.send(viewAction: .scrollToBottom)
                }
                .accessibilityIdentifier(A11yIdentifiers.roomScreen.scrollToBottom)
            }
            .background(roomWallpaperBackground.ignoresSafeArea())
            .safeAreaInset(edge: .top, spacing: 0) {
                if mediaPlayerController.shouldShowAudioOverlay ||
                    mediaPlayerController.activeVideoNote?.roomID == timelineContext.viewState.roomID {
                    InlineMiniMediaPlayerView(controller: mediaPlayerController)
                        .padding(.horizontal, 12)
                        .padding(.top, 8)
                        .padding(.bottom, 4)
                        .transition(.move(edge: .top).combined(with: .opacity))
                }
            }
            .topBanner(pinnedItemsBanner, isVisible: context.viewState.shouldShowPinnedEventsBanner && !isVoiceOverEnabled)
            // This can overlay on top of the pinnedItemsBanner
            .topBanner(knockRequestsBanner, isVisible: context.viewState.shouldSeeKnockRequests)
            .safeAreaInset(edge: .top) {
                // When VoiceOver is enabled, the table view isn't reversed and the scroll gestures
                // don't trigger meaning the banner never hides itself and so the .overlay layout
                // above permanently obscures the top of the timeline. So whenever VoiceOver is
                // enabled we use a safe area inset to vertically stack it above the timeline.
                if context.viewState.shouldShowPinnedEventsBanner, isVoiceOverEnabled {
                    pinnedItemsBanner
                }
            }
            .safeAreaInset(edge: .bottom, spacing: 0) {
                bottomContent
            }
            .toolbarRole(RoomHeaderView.toolbarRole)
            .navigationTitle(L10n.screenRoomTitle) // Hidden but used for back button text.
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { toolbar }
            .toolbarBackground(.visible, for: .navigationBar) // Fix the toolbar's background.
            .overlay { loadingIndicator }
            .alert(item: $context.alertInfo)
            .timelineMediaPreview(viewModel: $context.mediaPreviewViewModel)
            .track(screen: .Room)
            .animation(.spring(response: 0.34, dampingFraction: 0.86).disabledDuringTests(),
                       value: mediaPlayerController.shouldShowAudioOverlay)
            .animation(.spring(response: 0.34, dampingFraction: 0.86).disabledDuringTests(),
                       value: mediaPlayerController.activeVideoNote?.roomID == timelineContext.viewState.roomID)
    }
    
    private var bottomContent: some View {
        VStack(spacing: 0) {
            RoomScreenFooterView(details: context.viewState.footerDetails,
                                 mediaProvider: context.mediaProvider) { action in
                context.send(viewAction: .footerViewAction(action))
            }
            
            composer
                .padding(.top, 8)
                .background(Color.clear.ignoresSafeArea())
                .environmentObject(timelineContext)
                .environmentObject(recordingOverlayController)
                .environment(\.timelineContext, timelineContext)
                // Make sure the reply header honours the hideTimelineMedia setting too.
                .environment(\.shouldAutomaticallyLoadImages, !timelineContext.viewState.hideTimelineMedia)
        }
    }

    @ViewBuilder
    private var recordingOverlay: some View {
        if recordingOverlayController.activeMode == .voice,
           case .recordVoiceMessage(let recorderState) = composerContext.viewState.composerMode {
            // Без блюра для аудио записи
            ZStack {
                Color.black.opacity(0.1)
                    .ignoresSafeArea()
                
                VoiceRecordingOverlay(recorderState: recorderState,
                                      isLocked: recordingOverlayController.isLocked,
                                      lockDragProgress: recordingOverlayController.lockDragProgress,
                                      onDelete: {
                                          composerContext.send(viewAction: .voiceMessage(.deleteRecording))
                                          recordingOverlayController.dismissVoiceRecording()
                                      },
                                      onSend: {
                                          recordingOverlayController.prepareVoiceMessageForSending()
                                          composerContext.send(viewAction: .voiceMessage(.stopRecording))
                                          recordingOverlayController.dismissVoiceRecording()
                                      })
                                      .padding(.horizontal, 24)
                                      .padding(.bottom, 32)
                                      .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
            }
            .transition(.opacity)
        } else if recordingOverlayController.activeMode == .video {
            // С блюром только для видео записи
            RecordingOverlayBackdrop {
                VideoNoteRecorderView(command: recordingOverlayController.videoRecorderCommand,
                                      isLocked: recordingOverlayController.isLocked,
                                      onLock: {
                                          recordingOverlayController.lockRecording(.video)
                                      },
                                      onFinish: { url in
                                          recordingOverlayController.dismissAll()
                                          composerContext.send(viewAction: .sendVideoNote(url))
                                      },
                                      onCancel: {
                                          recordingOverlayController.dismissAll()
                                      })
            }
        }
    }

    private func handleComposerModeChange(_ composerMode: ComposerMode) {
        switch composerMode {
        case .previewVoiceMessage:
            if recordingOverlayController.shouldAutoSendVoiceMessage {
                recordingOverlayController.completeVoiceMessageSending()
                composerContext.send(viewAction: .voiceMessage(.send))
            }
        case .default, .edit, .reply:
            recordingOverlayController.completeVoiceMessageSending()
            if recordingOverlayController.activeMode == .voice {
                recordingOverlayController.dismissVoiceRecording()
            }
        case .recordVoiceMessage:
            break
        }
    }
    
    private var pinnedItemsBanner: some View {
        PinnedItemsBannerView(state: context.viewState.pinnedEventsBannerState,
                              onMainButtonTap: { context.send(viewAction: .tappedPinnedEventsBanner) },
                              onViewAllButtonTap: { context.send(viewAction: .viewAllPins) })
    }
    
    private var knockRequestsBanner: some View {
        KnockRequestsBannerView(requests: context.viewState.displayedKnockRequests,
                                onDismiss: dismissKnockRequestsBanner,
                                onAccept: context.viewState.canAcceptKnocks ? acceptKnockRequest : nil,
                                onViewAll: onViewAllKnockRequests,
                                mediaProvider: context.mediaProvider)
            .padding(.top, 16)
    }
    
    private func dismissKnockRequestsBanner() {
        context.send(viewAction: .dismissKnockRequests)
    }
    
    private func acceptKnockRequest(eventID: String) {
        context.send(viewAction: .acceptKnock(eventID: eventID))
    }
    
    private func onViewAllKnockRequests() {
        context.send(viewAction: .viewKnockRequests)
    }
    
    private var isAtBottomAndLive: Bool {
        timelineContext.isScrolledToBottom && timelineContext.viewState.timelineState.isLive
    }
    
    @ViewBuilder
    private var roomWallpaperBackground: some View {
        let blurRadius = appThemeService.wallpaperBlurRadius
        let overlayOpacity = appThemeService.resolvedTimelineOverlayOpacity(for: colorScheme)
        let defaultWallpaperStyle = appThemeService.resolvedDefaultRoomWallpaperStyle(for: colorScheme)

        GeometryReader { geometry in
            if let imageURL = roomWallpaperService.wallpaperURL(forRoomID: timelineContext.viewState.roomID) ??
                roomWallpaperService.defaultWallpaperURL(themeStyle: defaultWallpaperStyle) {
                if roomWallpaperService.shouldUseMediaProvider(for: imageURL) {
                    LoadableImage(url: imageURL,
                                  mediaProvider: context.mediaProvider,
                                  transformer: { view in
                                      AnyView(view
                                          .scaledToFill()
                                          .frame(width: geometry.size.width, height: geometry.size.height)
                                          .clipped()
                                          .blur(radius: blurRadius))
                                  },
                                  placeholder: {
                                      appThemeService.resolvedHomeBackgroundColor(for: colorScheme)
                                  })
                                  .ignoresSafeArea()
                } else {
                    AsyncImage(url: imageURL) { phase in
                        switch phase {
                        case .success(let image):
                            image
                                .resizable()
                                .scaledToFill()
                                .frame(width: geometry.size.width, height: geometry.size.height)
                                .clipped()
                                .blur(radius: blurRadius)
                        default:
                            appThemeService.resolvedHomeBackgroundColor(for: colorScheme)
                        }
                    }
                    .ignoresSafeArea()
                }
                
                Color.black.opacity(overlayOpacity)
                    .ignoresSafeArea()
            } else {
                appThemeService.resolvedHomeBackgroundColor(for: colorScheme)
            }
        }
    }
    
    @ViewBuilder
    private var composer: some View {
        if context.viewState.hasSuccessor {
            tombstonedDialogue
        } else if context.viewState.canSendMessage, !ProcessInfo.isRunningAccessibilityTests {
            // We are not sure why but when wrapped in the room screen the composer toolbar breaks the accessibility tests
            composerToolbar
        } else {
            ComposerDisabledView()
        }
    }
    
    private var tombstonedDialogue: some View {
        VStack(spacing: 16) {
            Text(L10n.screenRoomTimelineTombstonedRoomMessage)
                .font(.compound.bodyMD)
                .foregroundStyle(.compound.textPrimary)
            
            Button {
                context.send(viewAction: .displaySuccessorRoom)
            } label: {
                Text(L10n.screenRoomTimelineTombstonedRoomAction)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.compound(.primary, size: .medium))
        }
        .padding(.top, 16)
        .padding(.horizontal, 16)
        .padding(.bottom, 12)
        .highlight(gradient: .compound.info, borderColor: .compound.borderInfoSubtle)
    }
    
    @ViewBuilder
    private var loadingIndicator: some View {
        if timelineContext.viewState.showLoading {
            ProgressView()
                .progressViewStyle(.circular)
                .tint(.compound.textPrimary)
                .padding(16)
                .background(.ultraThickMaterial)
                .cornerRadius(8)
        }
    }
    
    @ToolbarContentBuilder
    private var toolbar: some ToolbarContent {
        // .principal + .primaryAction works better than .navigation leading + trailing
        // as the latter disables interaction in the action button for rooms with long names
        ToolbarItem(placement: .principal) {
            RoomHeaderView(roomName: context.viewState.roomTitle,
                           roomSubtitle: context.viewState.roomSubtitle,
                           roomAvatar: context.viewState.roomAvatar,
                           dmRecipientVerificationState: context.viewState.dmRecipientVerificationState,
                           roomHistorySharingState: context.viewState.roomHistorySharingState,
                           mediaProvider: context.mediaProvider) {
                context.send(viewAction: .displayRoomDetails)
            }
        }
        
        if !ProcessInfo.processInfo.isiOSAppOnMac {
            ToolbarItem(placement: .primaryAction) {
                if context.viewState.shouldShowCallButton {
                    callButton
                        .disabled(!context.viewState.canJoinCall)
                }
            }
        }
    }
    
    @ViewBuilder
    private var callButton: some View {
        if context.viewState.hasOngoingCall {
            JoinCallButton {
                context.send(viewAction: .displayCall)
            }
            .accessibilityIdentifier(A11yIdentifiers.roomScreen.joinCall)
        } else {
            Button {
                context.send(viewAction: .displayCall)
            } label: {
                CompoundIcon(context.viewState.shouldUseVideoCallButton ? \.videoCallSolid : \.voiceCallSolid)
            }
            .accessibilityLabel(L10n.a11yStartCall)
            .accessibilityIdentifier(A11yIdentifiers.roomScreen.joinCall)
        }
    }
}

private struct SetkaPackUploadTarget: Identifiable {
    let packID: String
    let kind: String

    var id: String {
        "\(packID)|\(kind)"
    }
}

private struct SetkaSharePayload: Identifiable {
    let packName: String
    let url: URL

    var id: String {
        "\(packName)|\(url.absoluteString)"
    }
}

private struct SetkaPlusComposerPickerData: Identifiable {
    let id = UUID()
    let packs: [SetkaPlusStickerPack]
}

final class RoomRecordingOverlayController: ObservableObject {
    enum GestureResult {
        case stopVoice
        case stopVideo
        case keepLocked
        case none
    }
    
    struct VideoRecorderCommand: Equatable {
        enum Kind: Equatable {
            case start
            case finish
            case cancel
        }
        
        let kind: Kind
        private let id = UUID()
    }
    
    @Published var selectedMode: MediaRecordingMode = .voice
    @Published var activeMode: MediaRecordingMode?
    @Published var isLocked = false
    @Published var lockDragProgress: CGFloat = 0
    @Published var shouldAutoSendVoiceMessage = false
    @Published var videoRecorderCommand: VideoRecorderCommand?
    
    func beginRecording(_ mode: MediaRecordingMode) {
        selectedMode = mode
        activeMode = mode
        isLocked = false
        lockDragProgress = 0
        shouldAutoSendVoiceMessage = false
        
        if mode == .video {
            videoRecorderCommand = .init(kind: .start)
        }
    }
    
    func lockRecording(_ mode: MediaRecordingMode) {
        guard activeMode == mode else { return }
        isLocked = true
        lockDragProgress = 1
    }
    
    func updateLockDragProgress(for mode: MediaRecordingMode, progress: CGFloat) {
        guard activeMode == mode, !isLocked else { return }
        lockDragProgress = min(max(progress, 0), 1)
    }
    
    func finishGesture(for mode: MediaRecordingMode) -> GestureResult {
        guard activeMode == mode else { return .none }
        
        if isLocked {
            return .keepLocked
        }
        
        switch mode {
        case .voice:
            activeMode = nil
            lockDragProgress = 0
            return .stopVoice
        case .video:
            videoRecorderCommand = .init(kind: .finish)
            lockDragProgress = 0
            return .stopVideo
        }
    }
    
    func prepareVoiceMessageForSending() {
        shouldAutoSendVoiceMessage = true
    }
    
    func completeVoiceMessageSending() {
        shouldAutoSendVoiceMessage = false
    }
    
    func dismissVoiceRecording() {
        if activeMode == .voice {
            activeMode = nil
        }
        isLocked = false
        lockDragProgress = 0
    }
    
    func dismissAll() {
        activeMode = nil
        isLocked = false
        lockDragProgress = 0
        shouldAutoSendVoiceMessage = false
    }
}

@MainActor
final class RoomWallpaperService: ObservableObject {
    enum Wallpaper: String, CaseIterable {
        case none
        case light
        case dark
        
        var title: String {
            switch self {
            case .none:
                L10n.actionReset
            case .light:
                L10n.commonLight
            case .dark:
                L10n.commonDark
            }
        }
        
        var metadata: RoomWallpaperMetadata? {
            switch self {
            case .none:
                nil
            case .light, .dark:
                .init(type: "theme",
                      theme: rawValue,
                      image: nil,
                      data: nil,
                      contentType: nil)
            }
        }
    }
    
    static let shared = RoomWallpaperService()
    
    @Published private var wallpapers = [String: RoomWallpaperMetadata]()
    @Published private var cachedWallpaperFilePaths = [String: String]()
    @Published private var cachedWallpaperSourceURLs = [String: String]()
    private static let userDefaultsKey = "io.element.elementx.room_wallpapers"
    private static let cachedWallpaperPathsKey = "io.element.elementx.room_wallpapers.cached_paths"
    private static let cachedWallpaperSourceURLsKey = "io.element.elementx.room_wallpapers.cached_source_urls"
    private static let wallpaperCacheDirectory = "RoomWallpaperCache"
    private static let lightWallpaperPath = "themes/element/img/backgrounds/light_bg.png"
    private static let darkWallpaperPath = "themes/element/img/backgrounds/dark_bg.png"
    private weak var clientProxy: ClientProxyProtocol?
    private var homeserverBaseURL: URL?
    private var webBaseURL: URL?
    private var inFlightPrefetchRoomIDs = Set<String>()
    
    private init() {
        loadFromStorage()
        
        Task { [weak self] in
            await self?.prewarmCachedWallpapers()
        }
    }
    
    func configure(clientProxy: ClientProxyProtocol) {
        self.clientProxy = clientProxy
        let baseString = clientProxy.homeserver.hasSuffix("/") ? String(clientProxy.homeserver.dropLast()) : clientProxy.homeserver
        homeserverBaseURL = URL(string: baseString)
        webBaseURL = derivedWebBaseURL(from: baseString)
    }
    
    func wallpaper(forRoomID roomID: String) -> Wallpaper {
        guard let metadata = wallpapers[roomID] else {
            return .none
        }
        
        if metadata.type == "theme",
           let theme = metadata.theme,
           let wallpaper = Wallpaper(rawValue: theme) {
            return wallpaper
        }
        
        return .none
    }
    
    func wallpaperTitle(forRoomID roomID: String) -> String {
        if wallpaperURL(forRoomID: roomID) != nil, wallpaper(forRoomID: roomID) == .none {
            return L10n.commonImage
        }
        
        return wallpaper(forRoomID: roomID).title
    }
    
    func wallpaperURL(forRoomID roomID: String) -> URL? {
        guard let metadata = wallpapers[roomID] else {
            return nil
        }
        
        let expectedSourceURL = expectedSourceURLString(for: metadata)
        
        if let cachedPath = cachedWallpaperFilePaths[roomID] {
            let cachedURL = URL(fileURLWithPath: cachedPath)
            let cachedSource = cachedWallpaperSourceURLs[roomID]
            if FileManager.default.fileExists(atPath: cachedURL.path(percentEncoded: false)),
               cachedSource == expectedSourceURL {
                return cachedURL
            }
            
            clearCachedWallpaper(forRoomID: roomID)
        }
        
        return wallpaperRemoteURL(for: metadata)
    }
    
    func defaultWallpaperURL(themeStyle: String) -> URL? {
        let normalizedStyle = themeStyle.lowercased()
        let presetPath: String
        
        switch normalizedStyle {
        case Wallpaper.dark.rawValue:
            presetPath = Self.darkWallpaperPath
        case Wallpaper.light.rawValue:
            presetPath = Self.lightWallpaperPath
        default:
            return nil
        }
        
        return resolveURL(pathOrURL: presetPath)
    }
    
    func setWallpaper(_ wallpaper: Wallpaper, forRoomID roomID: String) {
        let previousSourceURL = wallpapers[roomID].flatMap(expectedSourceURLString)
        let nextSourceURL = wallpaper.metadata.flatMap(expectedSourceURLString)
        if previousSourceURL != nextSourceURL {
            clearCachedWallpaper(forRoomID: roomID)
        }
        
        if wallpaper == .none {
            wallpapers[roomID] = nil
        } else {
            wallpapers[roomID] = wallpaper.metadata
        }
        
        persistToStorage()
        
        Task { [weak self] in
            if let metadata = wallpaper.metadata {
                await self?.prefetchWallpaperIfNeeded(for: metadata, roomID: roomID)
            }
            await self?.syncWallpaper(metadata: wallpaper.metadata, roomID: roomID)
        }
    }
    
    func setCustomWallpaper(imageData: Data, forRoomID roomID: String) {
        guard let image = UIImage(data: imageData),
              let normalizedData = image.jpegData(compressionQuality: 0.92),
              let localFileURL = customWallpaperFileURL(roomID: roomID) else {
            MXLog.error("Failed preparing custom room wallpaper for roomID \(roomID)")
            return
        }
        
        clearCachedWallpaper(forRoomID: roomID)
        removeExistingLocalWallpaperIfNeeded(forRoomID: roomID)
        
        do {
            try normalizedData.write(to: localFileURL, options: .atomic)
            
            wallpapers[roomID] = .init(type: "local",
                                       theme: nil,
                                       image: localFileURL.absoluteString,
                                       data: nil,
                                       contentType: "image/jpeg")
            persistToStorage()
        } catch {
            MXLog.error("Failed saving custom room wallpaper for roomID \(roomID): \(error)")
        }
    }
    
    func refreshFromServer(roomID: String) async {
        guard !roomID.isEmpty, let clientProxy else {
            return
        }
        
        // Custom wallpapers are intentionally local-only for now.
        if wallpapers[roomID]?.type == "local" {
            return
        }

        switch await clientProxy.fetchRoomWallpaper(roomID: roomID) {
        case .success(let metadata):
            let previousSourceURL = wallpapers[roomID].flatMap(expectedSourceURLString)
            let nextSourceURL = metadata.flatMap(expectedSourceURLString)
            if previousSourceURL != nextSourceURL {
                clearCachedWallpaper(forRoomID: roomID)
            }
            
            if let metadata {
                wallpapers[roomID] = metadata
                await prefetchWallpaperIfNeeded(for: metadata, roomID: roomID)
            } else {
                wallpapers[roomID] = nil
                clearCachedWallpaper(forRoomID: roomID)
            }
            persistToStorage()
        case .failure(let error):
            MXLog.error("Failed loading room wallpaper for roomID \(roomID): \(error)")
        }
    }
    
    private func loadFromStorage() {
        guard let data = UserDefaults.standard.data(forKey: Self.userDefaultsKey),
              let decoded = try? JSONDecoder().decode([String: RoomWallpaperMetadata].self, from: data) else {
            return
        }
        
        wallpapers = decoded
        
        if let cachedData = UserDefaults.standard.data(forKey: Self.cachedWallpaperPathsKey),
           let decodedCachedPaths = try? JSONDecoder().decode([String: String].self, from: cachedData) {
            cachedWallpaperFilePaths = decodedCachedPaths
        }
        
        if let cachedSourcesData = UserDefaults.standard.data(forKey: Self.cachedWallpaperSourceURLsKey),
           let decodedCachedSources = try? JSONDecoder().decode([String: String].self, from: cachedSourcesData) {
            cachedWallpaperSourceURLs = decodedCachedSources
        }
    }
    
    private func persistToStorage() {
        guard let data = try? JSONEncoder().encode(wallpapers),
              let cachedPathsData = try? JSONEncoder().encode(cachedWallpaperFilePaths),
              let cachedSourcesData = try? JSONEncoder().encode(cachedWallpaperSourceURLs) else {
            return
        }
        
        UserDefaults.standard.set(data, forKey: Self.userDefaultsKey)
        UserDefaults.standard.set(cachedPathsData, forKey: Self.cachedWallpaperPathsKey)
        UserDefaults.standard.set(cachedSourcesData, forKey: Self.cachedWallpaperSourceURLsKey)
    }
    
    private func syncWallpaper(metadata: RoomWallpaperMetadata?, roomID: String) async {
        guard let clientProxy else {
            return
        }
        
        if metadata == nil {
            if case let .failure(error) = await clientProxy.deleteRoomWallpaper(roomID: roomID) {
                MXLog.error("Failed deleting room wallpaper for roomID \(roomID): \(error)")
            }
        } else if let metadata {
            if case let .failure(error) = await clientProxy.saveRoomWallpaper(roomID: roomID, metadata: metadata) {
                MXLog.error("Failed saving room wallpaper for roomID \(roomID): \(error)")
            }
        }
    }
    
    private func resolveURL(pathOrURL: String) -> URL? {
        if let absoluteURL = URL(string: pathOrURL), absoluteURL.scheme != nil {
            return absoluteURL
        }
        
        if isThemeAssetPath(pathOrURL), let webBaseURL {
            if pathOrURL.hasPrefix("/") {
                return URL(string: webBaseURL.absoluteString + pathOrURL)
            }
            
            return URL(string: webBaseURL.absoluteString + "/" + pathOrURL)
        }
        
        guard let homeserverBaseURL else {
            return nil
        }
        
        if pathOrURL.hasPrefix("/") {
            return URL(string: homeserverBaseURL.absoluteString + pathOrURL)
        }
        
        return URL(string: homeserverBaseURL.absoluteString + "/" + pathOrURL)
    }
    
    private func wallpaperRemoteURL(for metadata: RoomWallpaperMetadata) -> URL? {
        if let imagePath = metadata.image?.trimmingCharacters(in: .whitespacesAndNewlines),
           !imagePath.isEmpty {
            return resolveURL(pathOrURL: imagePath)
        }
        
        if metadata.type == "theme" {
            let theme = metadata.theme ?? Wallpaper.light.rawValue
            let presetPath = switch theme {
            case Wallpaper.dark.rawValue:
                Self.darkWallpaperPath
            default:
                Self.lightWallpaperPath
            }
            return resolveURL(pathOrURL: presetPath)
        }
        
        return nil
    }
    
    private func prefetchWallpaperIfNeeded(for metadata: RoomWallpaperMetadata, roomID: String) async {
        if let cachedPath = cachedWallpaperFilePaths[roomID],
           FileManager.default.fileExists(atPath: cachedPath) {
            return
        }
        
        guard let remoteURL = wallpaperRemoteURL(for: metadata),
              let scheme = remoteURL.scheme?.lowercased(),
              ["http", "https"].contains(scheme),
              !shouldUseMediaProvider(for: remoteURL) else {
            return
        }
        
        await cacheWallpaper(from: remoteURL, roomID: roomID)
    }
    
    private func prewarmCachedWallpapers() async {
        for (roomID, metadata) in wallpapers {
            await prefetchWallpaperIfNeeded(for: metadata, roomID: roomID)
        }
    }
    
    private func cacheWallpaper(from remoteURL: URL, roomID: String) async {
        guard !inFlightPrefetchRoomIDs.contains(roomID) else { return }
        inFlightPrefetchRoomIDs.insert(roomID)
        defer { inFlightPrefetchRoomIDs.remove(roomID) }
        
        do {
            let (data, response) = try await URLSession.shared.data(from: remoteURL)
            guard let httpResponse = response as? HTTPURLResponse,
                  (200..<300).contains(httpResponse.statusCode),
                  UIImage(data: data) != nil,
                  let localFileURL = wallpaperCacheFileURL(roomID: roomID, remoteURL: remoteURL) else {
                return
            }
            
            try data.write(to: localFileURL, options: .atomic)
            cachedWallpaperFilePaths[roomID] = localFileURL.path(percentEncoded: false)
            cachedWallpaperSourceURLs[roomID] = remoteURL.absoluteString
            persistToStorage()
        } catch {
            MXLog.warning("Failed caching room wallpaper for roomID \(roomID): \(error)")
        }
    }
    
    private func wallpaperCacheFileURL(roomID: String, remoteURL: URL) -> URL? {
        guard let cacheDirectory = wallpaperCacheDirectoryURL() else {
            return nil
        }
        
        let digest = SHA256.hash(data: Data(remoteURL.absoluteString.utf8))
            .map { String(format: "%02x", $0) }
            .joined()
        let fileExtension = remoteURL.pathExtension.isEmpty ? "jpg" : remoteURL.pathExtension
        let safeRoomID = roomID.replacingOccurrences(of: "[^a-zA-Z0-9_-]", with: "_", options: .regularExpression)
        return cacheDirectory.appendingPathComponent("\(safeRoomID)-\(digest).\(fileExtension)")
    }
    
    private func wallpaperCacheDirectoryURL() -> URL? {
        do {
            let baseURL = try FileManager.default.url(for: .cachesDirectory,
                                                      in: .userDomainMask,
                                                      appropriateFor: nil,
                                                      create: true)
            let directoryURL = baseURL.appendingPathComponent(Self.wallpaperCacheDirectory, isDirectory: true)
            try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)
            return directoryURL
        } catch {
            MXLog.warning("Failed preparing wallpaper cache directory: \(error)")
            return nil
        }
    }
    
    private func clearCachedWallpaper(forRoomID roomID: String) {
        guard let cachedPath = cachedWallpaperFilePaths[roomID] else {
            return
        }
        
        do {
            let fileURL = URL(fileURLWithPath: cachedPath)
            if FileManager.default.fileExists(atPath: cachedPath) {
                try FileManager.default.removeItem(at: fileURL)
            }
        } catch {
            MXLog.warning("Failed removing cached wallpaper for roomID \(roomID): \(error)")
        }
        
        cachedWallpaperFilePaths[roomID] = nil
        cachedWallpaperSourceURLs[roomID] = nil
    }
    
    private func expectedSourceURLString(for metadata: RoomWallpaperMetadata) -> String? {
        wallpaperRemoteURL(for: metadata)?.absoluteString
    }
    
    private func customWallpaperFileURL(roomID: String) -> URL? {
        guard let cacheDirectory = wallpaperCacheDirectoryURL() else {
            return nil
        }
        
        let safeRoomID = roomID.replacingOccurrences(of: "[^a-zA-Z0-9_-]", with: "_", options: .regularExpression)
        return cacheDirectory.appendingPathComponent("custom-\(safeRoomID).jpg")
    }
    
    private func removeExistingLocalWallpaperIfNeeded(forRoomID roomID: String) {
        guard let existingMetadata = wallpapers[roomID],
              existingMetadata.type == "local",
              let imagePath = existingMetadata.image,
              let localURL = URL(string: imagePath),
              localURL.isFileURL else {
            return
        }
        
        do {
            let path = localURL.path(percentEncoded: false)
            if FileManager.default.fileExists(atPath: path) {
                try FileManager.default.removeItem(at: localURL)
            }
        } catch {
            MXLog.warning("Failed removing previous custom wallpaper for roomID \(roomID): \(error)")
        }
    }
    
    private func isThemeAssetPath(_ path: String) -> Bool {
        let normalized = path.hasPrefix("/") ? String(path.dropFirst()) : path
        return normalized.hasPrefix("themes/element/img/backgrounds/")
    }
    
    private func derivedWebBaseURL(from homeserver: String) -> URL? {
        guard var components = URLComponents(string: homeserver),
              let host = components.host else {
            return nil
        }
        
        if host.hasPrefix("matrix.") {
            components.host = "web." + host.dropFirst("matrix.".count)
            return components.url
        }
        
        return nil
    }
    
    func shouldUseMediaProvider(for url: URL) -> Bool {
        guard let scheme = url.scheme?.lowercased() else {
            return false
        }
        
        if scheme == "mxc" {
            return true
        }
        
        return url.path.contains("/_matrix/media/")
    }
}

private struct RecordingOverlayBackdrop<Content: View>: View {
    @ViewBuilder let content: Content
    
    var body: some View {
        ZStack {
            BlurEffectView(style: .systemChromeMaterialDark)
                .ignoresSafeArea()
            Color.black.opacity(0.25)
                .ignoresSafeArea()
            
            content
                .padding(.horizontal, 24)
                .padding(.bottom, 32)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
        }
        .transition(.opacity)
    }
}

private struct VoiceRecordingOverlay: View {
    @ObservedObject var recorderState: AudioRecorderState
    let isLocked: Bool
    let lockDragProgress: CGFloat
    let onDelete: () -> Void
    let onSend: () -> Void
    
    var body: some View {
        VStack(spacing: 18) {
            if !isLocked {
                voiceLockHint
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
            
            HStack(spacing: 12) {
                if isLocked {
                    Button(role: .destructive, action: onDelete) {
                        CompoundIcon(\.delete, size: .medium, relativeTo: .compound.headingLG)
                            .foregroundStyle(.compound.iconPrimary)
                            .padding(14)
                            .background(Color.compound.bgSubtleSecondary, in: Circle())
                    }
                }
                
                VoiceMessageRecordingComposer(recorderState: recorderState)
                    .frame(maxWidth: isLocked ? 270 : 360)
                    .animation(.spring(response: 0.3, dampingFraction: 0.86).disabledDuringTests(), value: isLocked)
                
                if isLocked {
                    SendButton(action: onSend)
                        .transition(.scale(scale: 0.9).combined(with: .opacity))
                }
            }
            .animation(.spring(response: 0.3, dampingFraction: 0.86).disabledDuringTests(), value: isLocked)
        }
        .animation(.easeInOut(duration: 0.2).disabledDuringTests(), value: lockDragProgress)
    }
    
    private var voiceLockHint: some View {
        VStack(spacing: 6) {
            Image(systemName: "chevron.up")
                .font(.caption.weight(.bold))
                .foregroundStyle(.white.opacity(0.75))
                .offset(y: -8 * lockDragProgress)
            CompoundIcon(lockDragProgress >= 0.95 ? \.lockSolid : \.lockOff, size: .small, relativeTo: .compound.bodyMD)
                .foregroundStyle(.compound.iconPrimary)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial, in: Capsule())
        .scaleEffect(1 + (0.06 * lockDragProgress))
        .opacity(0.7 + (0.3 * lockDragProgress))
    }
}

// MARK: - Previews

struct RoomScreen_Previews: PreviewProvider, TestablePreview {
    static let recordingOverlayController = RoomRecordingOverlayController()
    static let viewModels = makeViewModels()
    static let readOnlyViewModels = makeViewModels(canSendMessage: false)
    static let tombstonedViewModels = makeViewModels(hasSuccessor: true)

    static var previews: some View {
        ElementNavigationStack {
            RoomScreen(context: viewModels.room.context,
                       timelineContext: viewModels.timeline.context,
                       composerToolbar: ComposerToolbar.mock(),
                       timelineActions: viewModels.timeline.actions)
        }
        .environmentObject(recordingOverlayController)
        .previewDisplayName("Normal")
        
        ElementNavigationStack {
            RoomScreen(context: readOnlyViewModels.room.context,
                       timelineContext: readOnlyViewModels.timeline.context,
                       composerToolbar: ComposerToolbar.mock(),
                       timelineActions: readOnlyViewModels.timeline.actions)
        }
        .environmentObject(recordingOverlayController)
        .previewDisplayName("Read-only")
        .snapshotPreferences(expect: readOnlyViewModels.room.context.$viewState.map { !$0.canSendMessage })
        
        ElementNavigationStack {
            RoomScreen(context: tombstonedViewModels.room.context,
                       timelineContext: tombstonedViewModels.timeline.context,
                       composerToolbar: ComposerToolbar.mock(),
                       timelineActions: tombstonedViewModels.timeline.actions)
        }
        .environmentObject(recordingOverlayController)
        .previewDisplayName("Tombstoned")
        .snapshotPreferences(expect: tombstonedViewModels.room.context.$viewState.map(\.hasSuccessor))
    }
    
    static func makeViewModels(canSendMessage: Bool = true, hasSuccessor: Bool = false) -> ViewModels {
        let roomProxyMock = JoinedRoomProxyMock(.init(id: "stable_id",
                                                      name: "Preview room",
                                                      hasOngoingCall: true,
                                                      successor: hasSuccessor ? .init(roomId: UUID().uuidString, reason: nil) : nil,
                                                      powerLevelsConfiguration: .init(canUserSendMessage: canSendMessage)))
        let roomViewModel = RoomScreenViewModel.mock(roomProxyMock: roomProxyMock)
        let timelineViewModel = TimelineViewModel(roomProxy: roomProxyMock,
                                                  timelineController: MockTimelineController(),
                                                  userSession: UserSessionMock(.init()),
                                                  mediaPlayerProvider: MediaPlayerProviderMock(),
                                                  userIndicatorController: ServiceLocator.shared.userIndicatorController,
                                                  appMediator: AppMediatorMock.default,
                                                  appSettings: ServiceLocator.shared.settings,
                                                  analyticsService: ServiceLocator.shared.analytics,
                                                  emojiProvider: EmojiProvider(appSettings: ServiceLocator.shared.settings),
                                                  linkMetadataProvider: LinkMetadataProvider(),
                                                  timelineControllerFactory: TimelineControllerFactoryMock(.init()))
        
        return .init(room: roomViewModel, timeline: timelineViewModel)
    }
    
    struct ViewModels {
        let room: RoomScreenViewModelProtocol
        let timeline: TimelineViewModelProtocol
    }
}
