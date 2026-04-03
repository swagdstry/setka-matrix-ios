//
// Copyright 2026 Element Creations Ltd.
// Copyright 2026 New Vector Ltd.
//
// SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial.
// Please see LICENSE files in the repository root for full details.
//

import Compound
import SwiftUI

struct SetkaPlusComposerPickerSheet: View {
    enum Tab: String, CaseIterable, Identifiable {
        case emoji
        case stickers
        case gifs

        var id: String {
            rawValue
        }
    }

    let packs: [SetkaPlusStickerPack]
    let mediaProvider: MediaProviderProtocol?
    let onSendEmoji: (String) -> Void
    let onSendSticker: (String, String) -> Void

    @State private var selectedTab: Tab = .emoji

    private let quickEmoji = ["😀", "😎", "🔥", "💎", "🚀", "🎯", "❤️", "👍", "😴", "🎉", "🫡", "👀", "🥳", "🙏", "💬", "✨"]

    var body: some View {
        ElementNavigationStack {
            Form {
                Picker("", selection: $selectedTab) {
                    Text("Emoji").tag(Tab.emoji)
                    Text("Стикеры").tag(Tab.stickers)
                    Text("GIF").tag(Tab.gifs)
                }
                .pickerStyle(.segmented)

                switch selectedTab {
                case .emoji:
                    emojiSection
                case .stickers:
                    stickersSection
                case .gifs:
                    gifsSection
                }
            }
            .navigationTitle("Стикеры и эмодзи")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private var emojiSection: some View {
        Section {
            LazyVGrid(columns: [.init(.adaptive(minimum: 44), spacing: 10)], spacing: 10) {
                ForEach(quickEmoji, id: \.self) { emoji in
                    Button {
                        onSendEmoji(emoji)
                    } label: {
                        Text(emoji)
                            .font(.system(size: 28))
                            .frame(width: 44, height: 44)
                            .background(Color.compound.bgSubtlePrimary.opacity(0.12))
                            .clipShape(.rect(cornerRadius: 10))
                    }
                    .buttonStyle(.plain)
                }
            }
        } header: {
            Text("Быстрые эмодзи")
        }
    }

    private var stickersSection: some View {
        Group {
            let stickerPacks = packs.filter { $0.kind.lowercased() == "sticker" || $0.kind.lowercased() == "emoji" }
            if stickerPacks.isEmpty {
                Section {
                    Text("Стикерпаков пока нет")
                        .font(.compound.bodySM)
                        .foregroundColor(.compound.textSecondary)
                }
            } else {
                ForEach(stickerPacks) { pack in
                    Section {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 10) {
                                ForEach(pack.stickers) { sticker in
                                    Button {
                                        onSendSticker(pack.id, sticker.id)
                                    } label: {
                                        stickerPreview(sticker: sticker)
                                            .frame(width: 72, height: 72)
                                            .background(Color.compound.bgSubtlePrimary.opacity(0.12))
                                            .clipShape(.rect(cornerRadius: 10))
                                    }
                                    .buttonStyle(.plain)
                                    .accessibilityLabel("\(pack.name) \(sticker.name)")
                                }
                            }
                            .padding(.vertical, 2)
                        }
                    } header: {
                        Text(pack.name)
                    }
                }
            }
        }
    }

    private var gifsSection: some View {
        Section {
            Text("GIF-пикер будет добавлен следующим шагом. Сейчас можно отправлять GIF из галереи.")
                .font(.compound.bodySM)
                .foregroundColor(.compound.textSecondary)
        }
    }

    @ViewBuilder
    private func stickerPreview(sticker: SetkaPlusStickerItem) -> some View {
        if let url = URL(string: sticker.mxcURL) {
            LoadableImage(url: url,
                          mediaProvider: mediaProvider,
                          transformer: { AnyView($0.scaledToFit()) },
                          placeholder: { AnyView(Color.clear) })
                .padding(8)
        } else {
            Text("✨")
                .font(.system(size: 28))
        }
    }
}
