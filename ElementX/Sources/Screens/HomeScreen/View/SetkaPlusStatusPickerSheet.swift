//
// Copyright 2026 Element Creations Ltd.
// Copyright 2026 New Vector Ltd.
//
// SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial.
// Please see LICENSE files in the repository root for full details.
//

import Compound
import SwiftUI

struct SetkaPlusStatusPickerSheet: View {
    let isSetkaPlusActive: Bool
    let selectedEmoji: String?
    let selectedStickerID: String?
    let emojiPacks: [SetkaPlusStickerPack]
    let mediaProvider: MediaProviderProtocol?
    let onSelectEmoji: (String) -> Void
    let onSelectSticker: (String, String) -> Void
    let onClear: () -> Void

    private let quickEmoji = ["😀", "😎", "🔥", "💎", "🚀", "🎯", "❤️", "👍", "😴", "🎉", "🫡", "👀"]

    var body: some View {
        ElementNavigationStack {
            Form {
                if isSetkaPlusActive {
                    Section {
                        LazyVGrid(columns: [.init(.adaptive(minimum: 44), spacing: 10)], spacing: 10) {
                            ForEach(quickEmoji, id: \.self) { emoji in
                                Button {
                                    onSelectEmoji(emoji)
                                } label: {
                                    Text(emoji)
                                        .font(.system(size: 28))
                                        .frame(width: 44, height: 44)
                                        .background(selectedEmoji == emoji ? Color.compound.bgActionPrimaryRest.opacity(0.18) : Color.clear)
                                        .clipShape(.rect(cornerRadius: 10))
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    } header: {
                        Text(SetkaPlusL10n.statusPickerQuickEmoji)
                    }

                    if !emojiPacks.isEmpty {
                        Section {
                            ForEach(emojiPacks) { pack in
                                VStack(alignment: .leading, spacing: 8) {
                                    Text(pack.name)
                                        .font(.compound.bodyMDSemibold)
                                        .foregroundColor(.compound.textPrimary)

                                    ScrollView(.horizontal, showsIndicators: false) {
                                        HStack(spacing: 8) {
                                            ForEach(pack.stickers) { sticker in
                                                Button {
                                                    onSelectSticker(pack.id, sticker.id)
                                                } label: {
                                                    stickerPreview(sticker)
                                                        .frame(width: 36, height: 36)
                                                        .background(selectedStickerID == sticker.id ? Color.compound.bgActionPrimaryRest.opacity(0.18) : Color.compound.bgSubtlePrimary)
                                                        .clipShape(.rect(cornerRadius: 8))
                                                }
                                                .buttonStyle(.plain)
                                                .accessibilityLabel("\(pack.name) \(sticker.name)")
                                            }
                                        }
                                    }
                                }
                                .padding(.vertical, 4)
                            }
                        } header: {
                            Text(SetkaPlusL10n.statusPickerCustomEmoji)
                        }
                    }

                    Section {
                        Button(SetkaPlusL10n.statusPickerClear, role: .destructive) {
                            onClear()
                        }
                    }
                } else {
                    Section {
                        Text(SetkaPlusL10n.subscriptionRequiredForStatus)
                            .font(.compound.bodyMD)
                    }
                }
            }
            .navigationTitle(SetkaPlusL10n.statusPickerTitle)
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    @ViewBuilder
    private func stickerPreview(_ sticker: SetkaPlusStickerItem) -> some View {
        if let url = URL(string: sticker.mxcURL) {
            LoadableImage(url: url,
                          mediaProvider: mediaProvider,
                          transformer: { AnyView($0.scaledToFit()) },
                          placeholder: { AnyView(Color.clear) })
                .padding(4)
        } else {
            Text("✨")
        }
    }
}
