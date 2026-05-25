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
    enum Kind: String, CaseIterable, Identifiable {
        case stickers
        case emoji

        var id: String { rawValue }
    }

    private struct HeaderPack: Identifiable {
        let id: String
        let name: String
        let kind: Kind
        let stickers: [SetkaPlusStickerItem]
        let isStockEmoji: Bool
    }

    let packs: [SetkaPlusStickerPack]
    let mediaProvider: MediaProviderProtocol?
    let onSendSticker: (_ packID: String, _ stickerID: String) -> Void
    let onInsertUnicodeEmoji: (_ text: String) -> Void
    let onInsertCustomEmoji: (_ sticker: SetkaPlusStickerItem) -> Void
    let onCreateStickerPack: (_ name: String, _ kind: String) -> Void
    let onDeleteStickerPack: (_ packID: String) -> Void
    let onDeleteSticker: (_ packID: String, _ stickerID: String) -> Void
    let onSharePack: (_ packID: String) -> Void
    let onUploadToPack: (_ packID: String, _ kind: String) -> Void
    let onDismiss: () -> Void

    @State private var selectedKind: Kind = .stickers
    @State private var selectedPackID: String?
    @State private var isCreatePackAlertPresented = false
    @State private var newPackName = ""

    private let stockEmojiPackID = "__setka_stock_emoji__"
    private let stockEmoji = [
        "😂", "😭", "🤣", "😍", "😊", "🤔", "😡", "😱",
        "👍", "👎", "👏", "🙏", "🔥", "❤️", "💯", "✨",
        "🎉", "🤝", "👀", "🙌", "👌", "🤯", "😴", "🥳",
        "😇", "🤖", "🐱", "🐶", "🌈", "⭐", "🍕", "☕"
    ]

    private var headerPacks: [HeaderPack] {
        switch selectedKind {
        case .stickers:
            return packs
                .filter { $0.kind.lowercased() == "sticker" }
                .map { HeaderPack(id: $0.id, name: $0.name, kind: Kind.stickers, stickers: $0.stickers, isStockEmoji: false) }
        case .emoji:
            let custom = packs
                .filter { $0.kind.lowercased() == "emoji" }
                .map { HeaderPack(id: $0.id, name: $0.name, kind: Kind.emoji, stickers: $0.stickers, isStockEmoji: false) }
            return [HeaderPack(id: stockEmojiPackID, name: "Emoji", kind: Kind.emoji, stickers: [], isStockEmoji: true)] + custom
        }
    }

    private var selectedPack: HeaderPack? {
        let resolved = headerPacks.first(where: { $0.id == selectedPackID }) ?? headerPacks.first
        return resolved
    }

    var body: some View {
        VStack(spacing: 10) {
            handle

            headerRow

            content
                .frame(maxHeight: 280)

            kindSwitcher
        }
        .padding(.horizontal, 14)
        .padding(.top, 10)
        .padding(.bottom, 12)
        .background(Color.compound.bgCanvasDefault, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .onChange(of: selectedKind, initial: true) { _, _ in
            selectedPackID = headerPacks.first?.id
        }
        .alert("Новый стикерпак",
               isPresented: $isCreatePackAlertPresented,
               actions: {
                   TextField("Название пака", text: $newPackName)
                   Button("Отмена", role: .cancel) { }
                   Button("Создать") {
                       let trimmed = newPackName.trimmingCharacters(in: .whitespacesAndNewlines)
                       guard !trimmed.isEmpty else { return }
                       onCreateStickerPack(trimmed, "sticker")
                   }
               },
               message: {
                   Text("Введите название нового стикерпакa.")
               })
    }

    private var handle: some View {
        RoundedRectangle(cornerRadius: 2)
            .fill(Color.compound.iconSecondary.opacity(0.5))
            .frame(width: 36, height: 4)
            .padding(.top, 2)
            .onTapGesture { onDismiss() }
    }

    private var headerRow: some View {
        HStack(spacing: 8) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(headerPacks) { pack in
                        Button {
                            selectedPackID = pack.id
                        } label: {
                            packHeaderIcon(pack: pack, selected: selectedPack?.id == pack.id)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            if selectedKind == .stickers {
                Button {
                    newPackName = ""
                    isCreatePackAlertPresented = true
                } label: {
                    CompoundIcon(\.plus)
                        .frame(width: 30, height: 30)
                }
                .buttonStyle(.plain)
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                if let pack = selectedPack {
                    if pack.isStockEmoji {
                        emojiGrid
                    } else {
                        if pack.kind == .stickers {
                            stickerActions(pack)
                        }
                        stickerGrid(pack)
                    }
                } else {
                    Text("Паков пока нет")
                        .font(.compound.bodySM)
                        .foregroundStyle(.compound.textSecondary)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.vertical, 20)
                }
            }
        }
    }

    private var kindSwitcher: some View {
        HStack(spacing: 6) {
            switchButton(title: "Стикеры", selected: selectedKind == .stickers) {
                selectedKind = .stickers
            }
            switchButton(title: "Emoji", selected: selectedKind == .emoji) {
                selectedKind = .emoji
            }
        }
        .padding(4)
        .background(Color.compound.bgSubtleSecondary, in: Capsule())
    }

    private func switchButton(title: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.compound.bodySMSemibold)
                .foregroundStyle(selected ? Color.compound.textPrimary : Color.compound.textSecondary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(selected ? Color.compound.bgCanvasDefault : Color.clear, in: Capsule())
        }
        .buttonStyle(.plain)
    }

    private func stickerActions(_ pack: HeaderPack) -> some View {
        HStack(spacing: 10) {
            Text(pack.name)
                .font(.compound.bodyMDSemibold)
                .foregroundStyle(.compound.textPrimary)
            Spacer()
            Button {
                onUploadToPack(pack.id, "sticker")
            } label: {
                CompoundIcon(\.plus)
                    .frame(width: 24, height: 24)
            }
            .buttonStyle(.plain)
            Button {
                onSharePack(pack.id)
            } label: {
                CompoundIcon(\.shareIos)
                    .frame(width: 24, height: 24)
            }
            .buttonStyle(.plain)
            Button(role: .destructive) {
                onDeleteStickerPack(pack.id)
            } label: {
                CompoundIcon(\.delete)
                    .frame(width: 24, height: 24)
            }
            .buttonStyle(.plain)
        }
    }

    private func stickerGrid(_ pack: HeaderPack) -> some View {
        LazyVGrid(columns: [.init(.adaptive(minimum: 68), spacing: 8)], spacing: 8) {
            ForEach(pack.stickers) { sticker in
                Button {
                    if pack.kind == .stickers {
                        onSendSticker(pack.id, sticker.id)
                    } else {
                        onInsertCustomEmoji(sticker)
                    }
                } label: {
                    stickerTile(sticker)
                }
                .contextMenu {
                    if pack.kind == .stickers {
                        Button(role: .destructive) {
                            onDeleteSticker(pack.id, sticker.id)
                        } label: { Text("Удалить стикер") }
                    }
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var emojiGrid: some View {
        LazyVGrid(columns: [.init(.adaptive(minimum: 44), spacing: 8)], spacing: 8) {
            ForEach(stockEmoji, id: \.self) { emoji in
                Button {
                    onInsertUnicodeEmoji("\(emoji) ")
                } label: {
                    Text(emoji)
                        .font(.system(size: 26))
                        .frame(width: 44, height: 44)
                        .background(Color.compound.bgSubtleSecondary, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
                .buttonStyle(.plain)
            }
        }
    }

    @ViewBuilder
    private func packHeaderIcon(pack: HeaderPack, selected: Bool) -> some View {
        let preview = pack.stickers.first
        ZStack {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(selected ? Color.compound.bgSubtlePrimary : Color.compound.bgSubtleSecondary)
                .frame(width: 44, height: 44)
            if let preview {
                stickerPreview(sticker: preview)
                    .frame(width: 36, height: 36)
            } else {
                CompoundIcon(pack.kind == .stickers ? \.sticker : \.reactionAdd)
                    .frame(width: 24, height: 24)
            }
        }
    }

    private func stickerTile(_ sticker: SetkaPlusStickerItem) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.compound.bgSubtleSecondary)
            stickerPreview(sticker: sticker)
                .padding(6)
        }
        .frame(width: 68, height: 68)
    }

    @ViewBuilder
    private func stickerPreview(sticker: SetkaPlusStickerItem) -> some View {
        if let url = URL(string: sticker.mxcURL) {
            LoadableImage(url: url,
                          mediaProvider: mediaProvider,
                          transformer: { AnyView($0.scaledToFit()) },
                          placeholder: { AnyView(Color.clear) })
        } else {
            Text("✨")
                .font(.system(size: 24))
        }
    }

    private func normalizedEmojiTokenName(_ name: String) -> String {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let replaced = trimmed.replacingOccurrences(of: "[^a-z0-9]+", with: "_", options: .regularExpression)
        let collapsed = replaced.replacingOccurrences(of: "_{2,}", with: "_", options: .regularExpression)
        let normalized = collapsed.trimmingCharacters(in: CharacterSet(charactersIn: "_"))
        return normalized.isEmpty ? "emoji" : normalized
    }
}
