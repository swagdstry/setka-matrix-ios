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

struct VideoRoomTimelineView: View {
    @Environment(\.timelineContext) private var context
    @ObservedObject private var mediaPlayerController = GlobalMediaPlayerController.shared
    let timelineItem: VideoRoomTimelineItem
    
    private let videoNoteSize: CGFloat = 220
    private let expandedVideoNoteSize: CGFloat = 260
    
    private var hasMediaCaption: Bool {
        timelineItem.content.caption != nil && !timelineItem.content.isVideoNote
    }
    
    private var roomID: String? {
        context?.viewState.roomID
    }
    
    private var activeVideoNote: GlobalMediaPlayerController.ActiveVideoNotePresentation? {
        guard let roomID,
              mediaPlayerController.isInlineVideoNoteExpanded(itemID: timelineItem.id, roomID: roomID) else {
            return nil
        }
        
        return mediaPlayerController.activeVideoNote
    }
    
    private var isExpanded: Bool {
        activeVideoNote != nil
    }
    
    private var isLoadingVideo: Bool {
        activeVideoNote?.isLoading == true
    }
    
    private var isPlaying: Bool {
        activeVideoNote?.isPlaying == true
    }
    
    private var videoNoteProgress: Double {
        activeVideoNote?.progress ?? 0
    }
    
    var body: some View {
        TimelineStyler(timelineItem: timelineItem) {
            VStack(alignment: .leading, spacing: 4) {
                thumbnail
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(L10n.commonVideo)
                    .onTapGesture {
                        handleTap()
                    }
                
                if let attributedCaption = timelineItem.content.formattedCaption, !timelineItem.content.isVideoNote {
                    FormattedBodyText(attributedString: attributedCaption,
                                      additionalWhitespacesCount: timelineItem.additionalWhitespaces(),
                                      boostFontSize: timelineItem.shouldBoost)
                } else if let caption = timelineItem.content.caption, !timelineItem.content.isVideoNote {
                    FormattedBodyText(text: caption,
                                      additionalWhitespacesCount: timelineItem.additionalWhitespaces(),
                                      boostFontSize: timelineItem.shouldBoost)
                }
            }
        }
    }
    
    @ViewBuilder
    var thumbnail: some View {
        if timelineItem.content.isVideoNote {
            videoNoteThumbnail
        } else {
            regularThumbnail
        }
    }
    
    var playIcon: some View {
        Image(systemName: "play.circle.fill")
            .resizable()
            .frame(width: 50, height: 50)
            .background(.ultraThinMaterial, in: Circle())
            .foregroundColor(.white)
    }
    
    var placeholder: some View {
        Rectangle()
            .foregroundColor(timelineItem.isOutgoing ? .compound._bgBubbleOutgoing : .compound._bgBubbleIncoming)
            .opacity(0.3)
    }
    
    @ViewBuilder
    private var regularThumbnail: some View {
        if let thumbnailSource = timelineItem.content.thumbnailInfo?.source {
            LoadableImage(mediaSource: thumbnailSource,
                          mediaType: .timelineItem(uniqueID: timelineItem.id.uniqueID),
                          blurhash: timelineItem.content.blurhash,
                          size: timelineItem.content.thumbnailInfo?.size,
                          mediaProvider: context?.mediaProvider) { imageView in
                imageView
                    .overlay { playIcon }
            } placeholder: {
                placeholder
            }
            .modifier(VideoThumbnailStyle(isVideoNote: false,
                                          hasMediaCaption: hasMediaCaption,
                                          size: videoNoteSize,
                                          expandedSize: expandedVideoNoteSize,
                                          isExpanded: false,
                                          imageInfo: timelineItem.content.thumbnailInfo))
        } else {
            playIcon
                .modifier(VideoThumbnailStyle(isVideoNote: false,
                                              hasMediaCaption: hasMediaCaption,
                                              size: videoNoteSize,
                                              expandedSize: expandedVideoNoteSize,
                                              isExpanded: false,
                                              imageInfo: timelineItem.content.thumbnailInfo))
        }
    }
    
    private var videoNoteThumbnail: some View {
        ZStack {
            videoNoteSurface
            
            if isExpanded {
                VideoNoteScrubberOverlay(progress: videoNoteProgress) { progress in
                    mediaPlayerController.seekVideoNote(to: progress)
                }
                .padding(2)
            }
            
            if isLoadingVideo {
                ProgressView()
                    .controlSize(.large)
                    .tint(.white)
            } else if !isExpanded {
                playIcon
            } else if !isPlaying {
                Image(systemName: "play.fill")
                    .font(.system(size: 34, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(18)
                    .background(.ultraThinMaterial, in: Circle())
            }
            
            if isExpanded {
                VStack {
                    HStack {
                        Spacer()
                        
                        Button {
                            collapseVideoNote()
                        } label: {
                            Image(systemName: "xmark")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundStyle(.white)
                                .padding(10)
                                .background(.ultraThinMaterial, in: Circle())
                        }
                        .buttonStyle(.plain)
                        .padding(10)
                    }
                    
                    Spacer()
                }
            }
        }
        .modifier(VideoThumbnailStyle(isVideoNote: true,
                                      hasMediaCaption: false,
                                      size: videoNoteSize,
                                      expandedSize: expandedVideoNoteSize,
                                      isExpanded: isExpanded,
                                      imageInfo: timelineItem.content.thumbnailInfo))
        .animation(.easeInOut(duration: 0.22).disabledDuringTests(), value: isExpanded)
        .animation(.easeInOut(duration: 0.18).disabledDuringTests(), value: isLoadingVideo)
    }
    
    @ViewBuilder
    private var videoNoteSurface: some View {
        if let player = activeVideoNote?.player {
            InlineVideoPlayerView(player: player)
                .overlay {
                    Circle()
                        .fill(.black.opacity(isExpanded ? 0.08 : 0.18))
                }
                .onReceive(NotificationCenter.default.publisher(for: .AVPlayerItemDidPlayToEndTime,
                                                                object: player.currentItem)) { _ in
                    mediaPlayerController.handleVideoNotePlaybackEnded()
                }
        } else if let thumbnailSource = timelineItem.content.thumbnailInfo?.source {
            LoadableImage(mediaSource: thumbnailSource,
                          mediaType: .timelineItem(uniqueID: timelineItem.id.uniqueID),
                          blurhash: timelineItem.content.blurhash,
                          size: timelineItem.content.thumbnailInfo?.size,
                          mediaProvider: context?.mediaProvider) { imageView in
                imageView
            } placeholder: {
                placeholder
            }
        } else {
            placeholder
        }
    }
    
    private func handleTap() {
        guard timelineItem.content.isVideoNote else {
            context?.send(viewAction: .mediaTapped(itemID: timelineItem.id))
            return
        }
        
        if isExpanded {
            mediaPlayerController.toggleVideoNotePlayback()
        } else {
            expandVideoNote()
        }
    }
    
    private func expandVideoNote() {
        guard let roomID,
              let mediaProvider = context?.mediaProvider else {
            return
        }
        
        mediaPlayerController.startVideoNotePlayback(itemID: timelineItem.id,
                                                     roomID: roomID,
                                                     filename: timelineItem.content.filename,
                                                     source: timelineItem.content.videoInfo.source,
                                                     mediaProvider: mediaProvider)
    }
    
    private func collapseVideoNote() {
        mediaPlayerController.stopVideoNote()
    }
}

private struct VideoThumbnailStyle: ViewModifier {
    let isVideoNote: Bool
    let hasMediaCaption: Bool
    let size: CGFloat
    let expandedSize: CGFloat
    let isExpanded: Bool
    let imageInfo: ImageInfoProxy?
    
    func body(content: Content) -> some View {
        if isVideoNote {
            content
                .frame(width: isExpanded ? expandedSize : size,
                       height: isExpanded ? expandedSize : size)
                .clipShape(Circle())
        } else {
            content
                .timelineMediaFrame(imageInfo: imageInfo)
                .clipShape(RoundedRectangle(cornerRadius: hasMediaCaption ? 6 : 0))
        }
    }
}

private struct InlineVideoPlayerView: UIViewRepresentable {
    let player: AVPlayer
    
    func makeUIView(context: Context) -> PlayerView {
        let view = PlayerView()
        view.playerLayer.videoGravity = .resizeAspectFill
        view.playerLayer.player = player
        return view
    }
    
    func updateUIView(_ view: PlayerView, context: Context) {
        if view.playerLayer.player !== player {
            view.playerLayer.player = player
        }
    }
}

private final class PlayerView: UIView {
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

private struct VideoNoteScrubberOverlay: View {
    let progress: Double
    let onSeek: (Double) -> Void
    
    var body: some View {
        GeometryReader { geometry in
            let size = min(geometry.size.width, geometry.size.height)
            let lineWidth = max(8, size * 0.045)
            
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
                    .offset(knobOffset(in: size))
                    .shadow(color: .black.opacity(0.18), radius: 3, y: 1)
            }
            .contentShape(Circle())
            .simultaneousGesture(DragGesture(minimumDistance: 4)
                .onChanged { value in
                    guard isNearScrubber(value.location, in: geometry.size, lineWidth: lineWidth) else { return }
                    onSeek(progress(for: value.location, in: geometry.size))
                })
        }
        .allowsHitTesting(true)
    }
    
    private func knobOffset(in size: CGFloat) -> CGSize {
        let radius = (size / 2) - max(8, size * 0.045) / 2
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
        return abs(distance - radius) <= max(18, lineWidth * 2.2)
    }
}

struct VideoRoomTimelineView_Previews: PreviewProvider, TestablePreview {
    static let viewModel = TimelineViewModel.mock
    
    static var previews: some View {
        ScrollView {
            VStack(spacing: 20.0) {
                VideoRoomTimelineView(timelineItem: makeTimelineItem())
                VideoRoomTimelineView(timelineItem: makeTimelineItem(isEdited: true))
                VideoRoomTimelineView(timelineItem: makeTimelineItem(isVideoNote: true))
                
                // Blurhash item?
                
                VideoRoomTimelineView(timelineItem: makeTimelineItem(caption: "This is a great video 😎"))
                VideoRoomTimelineView(timelineItem: makeTimelineItem(caption: "This is a great video with a really long multiline caption",
                                                                     isEdited: true))
            }
        }
        .environmentObject(viewModel.context)
        .environment(\.timelineContext, viewModel.context)
        .previewLayout(.fixed(width: 390, height: 975))
        .padding(.bottom, 20)
    }
    
    private static func makeTimelineItem(caption: String? = nil,
                                         isEdited: Bool = false,
                                         isVideoNote: Bool = false) -> VideoRoomTimelineItem {
        VideoRoomTimelineItem(id: .randomEvent,
                              timestamp: .mock,
                              isOutgoing: false,
                              isEditable: false,
                              canBeRepliedTo: true,
                              sender: .init(id: "Bob"),
                              content: .init(filename: "video.mp4",
                                             caption: caption,
                                             videoInfo: .mockVideo,
                                             thumbnailInfo: .mockVideoThumbnail,
                                             blurhash: "L%KUc%kqS$RP?Ks,WEf8OlrqaekW",
                                             isVideoNote: isVideoNote),
                              properties: .init(isEdited: isEdited))
    }
}
