//
// Copyright 2026 Element Creations Ltd.
//
// SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial.
// Please see LICENSE files in the repository root for full details.
//

import AVKit
import SwiftUI

struct VideoNoteRoomTimelineView: View {
    let text: String
    
    @State private var player = AVPlayer()
    @State private var isPlaying = true
    @State private var progress: Double = 0
    
    var body: some View {
        if let url = extractURL() {
            ZStack {
                VideoPlayer(player: player)
                    .onAppear {
                        player = AVPlayer(url: url)
                        player.isMuted = true
                        player.play()
                    }
                    .onTapGesture {
                        toggle()
                    }
                
                if !isPlaying {
                    Image(systemName: "play.fill")
                        .font(.system(size: 40))
                        .foregroundColor(.white)
                }
            }
            .frame(width: 200, height: 200)
            .clipShape(Circle())
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
        isPlaying ? player.play() : player.pause()
    }
}
