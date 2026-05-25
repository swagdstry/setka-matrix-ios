//
// Copyright 2026 Element Creations Ltd.
//
// SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial.
// Please see LICENSE files in the repository root for full details.
//

import SwiftUI
import AVKit

struct VideoNoteRoomTimelineView: View {
    let text: String
    
    @State private var player = AVPlayer()
    @State private var isPlaying = true
    @State private var progress: Double = 0
    @State private var opacity: CGFloat = 0
    
    var body: some View {
        if let url = extractURL() {
            ZStack {
                // Кружок как в Telegram
                Circle()
                    .fill(Color.black.opacity(0.8))
                    .frame(width: 200, height: 200)
                    .overlay {
                        // Видео внутри кружка
                        VideoPlayer(player: player)
                            .onAppear {
                                player = AVPlayer(url: url)
                                player.isMuted = true
                                player.play()
                            }
                            .onTapGesture {
                                toggle()
                            }
                            .clipShape(Circle())
                            .frame(width: 180, height: 180)
                        
                        // Кнопка play/pause
                        if !isPlaying {
                            Image(systemName: "play.fill")
                                .font(.system(size: 30))
                                .foregroundColor(.white)
                        }
                    }
                    .overlay {
                        // Флаг в правом нижнем углу как в Telegram
                        VStack(spacing: 0) {
                            Spacer()
                            HStack(spacing: 0) {
                                Spacer()
                                Image(systemName: "flag.fill")
                                    .font(.system(size: 16))
                                    .foregroundColor(.white)
                                    .padding(4)
                            }
                        }
                        .padding(8)
                    }
                    .opacity(opacity)
                    .onAppear {
                        withAnimation(.easeOut(duration: 0.3)) {
                            opacity = 1
                        }
                    }
            }
            .frame(width: 200, height: 200)
        }
    }
    
    private func extractURL() -> URL? {
        let cleaned = text
            .replacingOccurrences(of: "[video_note:", with: "")
            .replacingOccurrences(of: "]", with: "")
        return URL(string: cleaned)
    }
    
    private func toggle() {
        isPlaying.toggle()
        if isPlaying {
            player.play()
        } else {
            player.pause()
        }
    }
}
