//
// Copyright 2025 Element Creations Ltd.
// Copyright 2023-2025 New Vector Ltd.
//
// SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial.
// Please see LICENSE files in the repository root for full details.
//

import AVFoundation
import Combine
import Foundation
import SwiftUI

class MediaPlayerProvider: MediaPlayerProviderProtocol {
    private lazy var audioPlayer = AudioPlayer()
    private var audioPlayerStates: [String: AudioPlayerState] = [:]
    
    var player: AudioPlayerProtocol {
        audioPlayer
    }
    
    deinit {
        audioPlayerStates = [:]
    }
    
    // MARK: - AudioPlayer
    
    func playerState(for id: AudioPlayerStateIdentifier) -> AudioPlayerState? {
        guard let audioPlayerStateID = audioPlayerStateID(for: id) else {
            MXLog.error("Failed to build an ID using: \(id)")
            return nil
        }
        return audioPlayerStates[audioPlayerStateID]
    }
    
    func register(audioPlayerState: AudioPlayerState) {
        guard let audioPlayerStateID = audioPlayerStateID(for: audioPlayerState.id) else {
            MXLog.error("Failed to build a key to register this audioPlayerState: \(audioPlayerState)")
            return
        }
        audioPlayerStates[audioPlayerStateID] = audioPlayerState
    }
    
    func unregister(audioPlayerState: AudioPlayerState) {
        guard let audioPlayerStateID = audioPlayerStateID(for: audioPlayerState.id) else {
            MXLog.error("Failed to build a key to register this audioPlayerState: \(audioPlayerState)")
            return
        }
        audioPlayerStates[audioPlayerStateID] = nil
    }
    
    func detachAllStates(except exception: AudioPlayerState?) {
        for key in audioPlayerStates.keys {
            if let exception, key == audioPlayerStateID(for: exception.id) {
                continue
            }
            audioPlayerStates[key]?.detachAudioPlayer()
        }
    }
    
    // MARK: - Private
    
    private func audioPlayerStateID(for identifier: AudioPlayerStateIdentifier) -> String? {
        switch identifier {
        case .timelineItemIdentifier(let timelineItemIdentifier):
            return timelineItemIdentifier.eventID ?? timelineItemIdentifier.transactionID ?? timelineItemIdentifier.uniqueID.value
        case .recorderPreview:
            return "recorderPreviewAudioPlayerState"
        }
    }
}

@MainActor
final class GlobalMediaPlayerController: ObservableObject {
    static let shared = GlobalMediaPlayerController()
    
    struct ActiveAudioPresentation {
        struct QueueItem: Identifiable {
            let itemID: TimelineItemIdentifier
            let title: String
            
            var id: TimelineItemIdentifier {
                itemID
            }
        }
        
        let playerState: AudioPlayerState
        let title: String
        let roomID: String
        let queue: [QueueItem]
        let currentIndex: Int
        let playItem: @MainActor (TimelineItemIdentifier) -> Void
    }
    
    struct ActiveVideoNotePresentation {
        let itemID: TimelineItemIdentifier
        let roomID: String
        let filename: String
        let source: MediaSourceProxy
        let mediaProvider: MediaProviderProtocol
        var player: AVPlayer?
        var isLoading = false
        var isPlaying = false
        var progress = 0.0
        var duration = 0.0
        var offset: CGSize = .zero
    }
    
    let mediaPlayerProvider = MediaPlayerProvider()
    
    @Published private(set) var activeAudio: ActiveAudioPresentation?
    @Published private(set) var activeVideoNote: ActiveVideoNotePresentation?
    @Published private(set) var currentRoomID: String?
    @Published private(set) var isHomeScreenVisible = false
    
    var openRoomAction: ((String) -> Void)?
    private var audioPlaybackObserver: AnyCancellable?
    private var previousObservedPlaybackState: AudioPlayerPlaybackState?
    private var videoNoteTimeObserver: Any?
    private let playerTransitionAnimation = Animation.spring(response: 0.34, dampingFraction: 0.86).disabledDuringTests()
    
    private init() { }
    
    var shouldShowAudioOverlay: Bool {
        activeAudio != nil
    }
    
    var shouldShowFloatingVideoNote: Bool {
        guard let activeVideoNote else { return false }
        return !isHomeScreenVisible && activeVideoNote.roomID != currentRoomID
    }
    
    func setCurrentRoomID(_ roomID: String?) {
        currentRoomID = roomID
    }
    
    func setHomeScreenVisible(_ isVisible: Bool) {
        isHomeScreenVisible = isVisible
    }
    
    func isInlineVideoNoteExpanded(itemID: TimelineItemIdentifier, roomID: String) -> Bool {
        guard let activeVideoNote else { return false }
        return activeVideoNote.itemID == itemID && activeVideoNote.roomID == roomID
    }
    
    var canPlayPreviousAudio: Bool {
        guard let activeAudio else { return false }
        return activeAudio.currentIndex > 0
    }
    
    var canPlayNextAudio: Bool {
        guard let activeAudio else { return false }
        return activeAudio.currentIndex < activeAudio.queue.count - 1
    }
    
    func presentAudio(playerState: AudioPlayerState,
                      title: String,
                      roomID: String,
                      queue: [ActiveAudioPresentation.QueueItem],
                      currentIndex: Int,
                      playItem: @escaping @MainActor (TimelineItemIdentifier) -> Void) {
        stopVideoNote()
        withAnimation(playerTransitionAnimation) {
            activeAudio = .init(playerState: playerState,
                                title: title,
                                roomID: roomID,
                                queue: queue,
                                currentIndex: currentIndex,
                                playItem: playItem)
        }
        observeAudioPlayback(for: playerState)
    }
    
    func closeAudioPlayer() {
        mediaPlayerProvider.player.stop()
        activeAudio?.playerState.detachAudioPlayer()
        audioPlaybackObserver = nil
        previousObservedPlaybackState = nil
        withAnimation(playerTransitionAnimation) {
            activeAudio = nil
        }
    }
    
    func toggleAudioPlayback() {
        guard let activeAudio else { return }
        
        if activeAudio.playerState.playbackState == .playing {
            mediaPlayerProvider.player.pause()
        } else {
            mediaPlayerProvider.player.play()
        }
    }
    
    func seekAudio(to progress: Double) async {
        guard let activeAudio else { return }
        await activeAudio.playerState.updateState(progress: progress)
    }
    
    func cycleAudioPlaybackSpeed() {
        guard let activeAudio else { return }
        activeAudio.playerState.setPlaybackSpeed(activeAudio.playerState.playbackSpeed.next)
        objectWillChange.send()
    }
    
    func playPreviousAudio() {
        guard let activeAudio,
              activeAudio.currentIndex > 0 else {
            return
        }
        
        activeAudio.playItem(activeAudio.queue[activeAudio.currentIndex - 1].itemID)
    }
    
    func playNextAudio() {
        guard let activeAudio,
              activeAudio.currentIndex < activeAudio.queue.count - 1 else {
            return
        }
        
        activeAudio.playItem(activeAudio.queue[activeAudio.currentIndex + 1].itemID)
    }
    
    func selectAudioItem(_ itemID: TimelineItemIdentifier) {
        activeAudio?.playItem(itemID)
    }
    
    func openActiveMediaRoom() {
        if let roomID = activeAudio?.roomID ?? activeVideoNote?.roomID {
            openRoomAction?(roomID)
        }
    }
    
    func startVideoNotePlayback(itemID: TimelineItemIdentifier,
                                roomID: String,
                                filename: String,
                                source: MediaSourceProxy,
                                mediaProvider: MediaProviderProtocol) {
        closeAudioPlayer()
        
        if let activeVideoNote,
           activeVideoNote.itemID == itemID,
           activeVideoNote.roomID == roomID {
            if activeVideoNote.player == nil {
                loadVideoNote()
            } else {
                toggleVideoNotePlayback()
            }
            return
        }
        
        stopVideoNote()
        withAnimation(playerTransitionAnimation) {
            activeVideoNote = .init(itemID: itemID,
                                    roomID: roomID,
                                    filename: filename,
                                    source: source,
                                    mediaProvider: mediaProvider,
                                    isLoading: true)
        }
        loadVideoNote()
    }
    
    func toggleVideoNotePlayback() {
        guard var activeVideoNote,
              let player = activeVideoNote.player else {
            return
        }
        
        if activeVideoNote.isPlaying {
            player.pause()
            activeVideoNote.isPlaying = false
        } else {
            player.play()
            activeVideoNote.isPlaying = true
        }
        
        self.activeVideoNote = activeVideoNote
    }
    
    func updateVideoNoteOffset(_ offset: CGSize) {
        guard var activeVideoNote else { return }
        activeVideoNote.offset = offset
        self.activeVideoNote = activeVideoNote
    }
    
    func seekVideoNote(to progress: Double) {
        guard var activeVideoNote,
              let player = activeVideoNote.player else {
            return
        }
        
        let clampedProgress = max(0, min(progress, 1))
        let duration = resolvedDuration(for: player, currentDuration: activeVideoNote.duration)
        let targetTime = CMTime(seconds: duration * clampedProgress, preferredTimescale: 600)
        
        player.seek(to: targetTime, toleranceBefore: .zero, toleranceAfter: .zero)
        activeVideoNote.progress = clampedProgress
        activeVideoNote.duration = duration
        self.activeVideoNote = activeVideoNote
    }
    
    func finishVideoNoteDrag() {
        guard let activeVideoNote else { return }
        
        if abs(activeVideoNote.offset.width) > 140 || abs(activeVideoNote.offset.height) > 180 {
            stopVideoNote()
            return
        }
        
        updateVideoNoteOffset(.zero)
    }
    
    func stopVideoNote() {
        removeVideoNoteTimeObserver()
        activeVideoNote?.player?.pause()
        activeVideoNote?.player?.seek(to: .zero)
        withAnimation(playerTransitionAnimation) {
            activeVideoNote = nil
        }
    }
    
    func handleVideoNotePlaybackEnded() {
        guard let player = activeVideoNote?.player else { return }
        
        removeVideoNoteTimeObserver()
        player.seek(to: .zero)
        player.pause()
        withAnimation(playerTransitionAnimation) {
            activeVideoNote = nil
        }
    }
    
    private func loadVideoNote() {
        guard let activeVideoNote else { return }
        
        Task {
            let result = await activeVideoNote.mediaProvider.loadFileFromSource(activeVideoNote.source,
                                                                                filename: activeVideoNote.filename)
            
            await MainActor.run {
                guard var currentVideoNote = self.activeVideoNote,
                      currentVideoNote.itemID == activeVideoNote.itemID,
                      currentVideoNote.roomID == activeVideoNote.roomID else {
                    return
                }
                
                currentVideoNote.isLoading = false
                
                switch result {
                case .success(let handle):
                    guard let fileURL = handle.url else {
                        MXLog.error("Missing URL for global video note player")
                        self.activeVideoNote = nil
                        return
                    }
                    
                    let player = AVPlayer(url: fileURL)
                    player.actionAtItemEnd = .pause
                    currentVideoNote.player = player
                    currentVideoNote.isPlaying = true
                    currentVideoNote.duration = self.resolvedDuration(for: player, currentDuration: 0)
                    withAnimation(self.playerTransitionAnimation) {
                        self.activeVideoNote = currentVideoNote
                    }
                    self.attachVideoNoteTimeObserver(to: player)
                    player.play()
                case .failure(let error):
                    MXLog.error("Failed loading global video note: \(error)")
                    withAnimation(self.playerTransitionAnimation) {
                        self.activeVideoNote = nil
                    }
                }
            }
        }
    }
    
    private func observeAudioPlayback(for playerState: AudioPlayerState) {
        previousObservedPlaybackState = playerState.playbackState
        audioPlaybackObserver = playerState.$playbackState
            .dropFirst()
            .receive(on: DispatchQueue.main)
            .sink { [weak self, weak playerState] playbackState in
                guard let self, let playerState else { return }
                defer { previousObservedPlaybackState = playbackState }
                
                guard previousObservedPlaybackState == .playing,
                      playbackState == .stopped,
                      playerState.progress == 0 else {
                    return
                }
                
                if canPlayNextAudio {
                    playNextAudio()
                } else {
                    closeAudioPlayer()
                }
            }
    }
    
    private func attachVideoNoteTimeObserver(to player: AVPlayer) {
        removeVideoNoteTimeObserver()
        
        let interval = CMTime(seconds: 0.05, preferredTimescale: 600)
        videoNoteTimeObserver = player.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] time in
            guard let self,
                  var activeVideoNote = self.activeVideoNote,
                  activeVideoNote.player === player else {
                return
            }
            
            let duration = self.resolvedDuration(for: player, currentDuration: activeVideoNote.duration)
            let currentSeconds = max(0, time.seconds.isFinite ? time.seconds : 0)
            activeVideoNote.duration = duration
            activeVideoNote.progress = duration > 0 ? min(max(currentSeconds / duration, 0), 1) : 0
            activeVideoNote.isPlaying = player.rate > 0
            self.activeVideoNote = activeVideoNote
        }
    }
    
    private func removeVideoNoteTimeObserver() {
        guard let videoNoteTimeObserver,
              let player = activeVideoNote?.player else {
            videoNoteTimeObserver = nil
            return
        }
        
        player.removeTimeObserver(videoNoteTimeObserver)
        self.videoNoteTimeObserver = nil
    }
    
    private func resolvedDuration(for player: AVPlayer, currentDuration: Double) -> Double {
        if currentDuration > 0 {
            return currentDuration
        }
        
        if let seconds = player.currentItem?.duration.seconds,
           seconds.isFinite,
           seconds > 0 {
            return seconds
        }
        
        return 0
    }
}
