//
// Copyright 2026 Element Creations Ltd.
//
// SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial.
// Please see LICENSE files in the repository root for full details.
//

import Compound
import Foundation
import SwiftUI

struct SetkaPackLinkCardView: View {
    struct PackData: Identifiable, Hashable {
        let url: URL
        let version: Int
        let shareToken: String
        let name: String
        let authorID: String
        let packID: String
        let avatarMXCURL: String?
        let stickers: [SetkaPlusStickerItem]

        var id: String {
            packID
        }

        static func == (lhs: Self, rhs: Self) -> Bool {
            lhs.packID == rhs.packID
        }

        func hash(into hasher: inout Hasher) {
            hasher.combine(packID)
        }
    }

    let pack: PackData
    let mediaProvider: MediaProviderProtocol?
    let onOpen: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                avatar
                VStack(alignment: .leading, spacing: 4) {
                    Text(pack.name)
                        .font(.compound.bodyMDSemibold)
                        .foregroundStyle(.compound.textPrimary)
                        .lineLimit(2)
                    
                    Text("Создатель: \(pack.authorID)")
                        .font(.compound.bodySM)
                        .foregroundStyle(.compound.textSecondary)
                        .lineLimit(1)
                }
                Spacer(minLength: 0)
            }

            Button {
                onOpen()
            } label: {
                Text("Посмотреть")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.compound(.secondary))
        }
        .padding(12)
        .background(Color.compound.bgSubtleSecondary, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    @ViewBuilder
    private var avatar: some View {
        if let mxc = pack.avatarMXCURL,
           let url = URL(string: mxc) {
            LoadableImage(url: url,
                          mediaProvider: mediaProvider,
                          transformer: { view in
                              AnyView(view
                                  .scaledToFill()
                                  .frame(width: 40, height: 40)
                                  .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous)))
                          },
                          placeholder: {
                              AnyView(RoundedRectangle(cornerRadius: 10, style: .continuous)
                                  .fill(Color.compound.bgSubtlePrimary)
                                  .frame(width: 40, height: 40))
                          })
        } else {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.compound.bgSubtlePrimary)
                .frame(width: 40, height: 40)
                .overlay {
                    Text("✨")
                        .font(.system(size: 18))
                }
        }
    }
}

struct SetkaPackPreviewSheet: View {
    let pack: SetkaPackLinkCardView.PackData
    let resolvedPack: SetkaPlusStickerPack?
    let mediaProvider: MediaProviderProtocol?
    let onAdd: (String) -> Void

    var body: some View {
        ElementNavigationStack {
            Form {
                Section {
                    avatar
                        .frame(maxWidth: .infinity, alignment: .center)
                    Text(pack.name)
                        .font(.compound.headingSM)
                        .foregroundStyle(.compound.textPrimary)
                    Text("Создатель: \(pack.authorID)")
                        .font(.compound.bodySM)
                        .foregroundStyle(.compound.textSecondary)
                    Text("ID: \(pack.packID)")
                        .font(.compound.bodySM)
                        .foregroundStyle(.compound.textSecondary)
                }

                Section("Содержимое") {
                    if let packToRender = resolvedPack ?? fallbackPack {
                        LazyVGrid(columns: [.init(.adaptive(minimum: 72), spacing: 10)], spacing: 10) {
                            ForEach(packToRender.stickers) { sticker in
                                stickerPreview(sticker)
                            }
                        }
                    } else {
                        Text("Не удалось загрузить содержимое пака.")
                            .font(.compound.bodySM)
                            .foregroundStyle(.compound.textSecondary)
                    }
                }

                Section {
                    Button {
                        onAdd(pack.packID)
                    } label: {
                        Text(resolvedPack == nil ? "Добавить" : "Уже добавлен")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.compound(.primary))
                    .disabled(resolvedPack != nil)
                }
            }
            .compoundList()
            .navigationTitle("Стикерпак")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private var fallbackPack: SetkaPlusStickerPack? {
        guard !pack.stickers.isEmpty else {
            return nil
        }

        return .init(id: pack.packID,
                     name: pack.name,
                     kind: "sticker",
                     stickers: pack.stickers,
                     createdAt: nil,
                     updatedAt: nil)
    }

    @ViewBuilder
    private func stickerPreview(_ sticker: SetkaPlusStickerItem) -> some View {
        if let url = URL(string: sticker.mxcURL) {
            LoadableImage(url: url,
                          mediaProvider: mediaProvider,
                          transformer: { view in
                              AnyView(view
                                  .scaledToFit()
                                  .frame(width: 72, height: 72)
                                  .background(Color.compound.bgSubtleSecondary, in: RoundedRectangle(cornerRadius: 8, style: .continuous)))
                          },
                          placeholder: {
                              AnyView(RoundedRectangle(cornerRadius: 8, style: .continuous)
                                  .fill(Color.compound.bgSubtleSecondary)
                                  .frame(width: 72, height: 72))
                          })
        }
    }

    @ViewBuilder
    private var avatar: some View {
        if let mxc = pack.avatarMXCURL,
           let url = URL(string: mxc) {
            LoadableImage(url: url,
                          mediaProvider: mediaProvider,
                          transformer: { view in
                              AnyView(view
                                  .scaledToFill()
                                  .frame(width: 96, height: 96)
                                  .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous)))
                          },
                          placeholder: {
                              AnyView(Color.compound.bgSubtlePrimary
                                  .frame(width: 96, height: 96)
                                  .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous)))
                          })
        } else {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.compound.bgSubtlePrimary)
                .frame(width: 96, height: 96)
                .overlay {
                    Text("✨")
                        .font(.system(size: 34))
                }
        }
    }
}

enum SetkaPackLinkParser {
    static func extractSetkaPackURLs(from text: String) -> [URL] {
        let pattern = #"https://web\.setka-matrix\.ru/#/setka-pack/[^\s<>()]+"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else {
            return []
        }
        
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        return regex.matches(in: text, options: [], range: range).compactMap { match in
            guard let matchRange = Range(match.range, in: text) else {
                return nil
            }
            return URL(string: String(text[matchRange]))
        }
    }
    
    static func parse(url: URL) -> SetkaPackLinkCardView.PackData? {
        guard url.absoluteString.contains("/#/setka-pack/"),
              let fragment = url.fragment else {
            return nil
        }

        let marker = "setka-pack/"
        guard let range = fragment.range(of: marker) else {
            return nil
        }

        let encodedToken = String(fragment[range.upperBound...])
        let parts = encodedToken.split(separator: ".")
        guard parts.count >= 3,
              parts[0].hasPrefix("v"),
              let version = Int(parts[0].dropFirst()) else {
            return nil
        }

        let payloadPart = String(parts[1])
        guard let payloadData = decodeBase64URL(payloadPart),
              let payload = try? JSONDecoder().decode(Payload.self, from: payloadData) else {
            return nil
        }

        return .init(url: url,
                     version: version,
                     shareToken: encodedToken,
                     name: payload.name ?? "Стикерпак",
                     authorID: payload.userID ?? "unknown",
                     packID: payload.packID ?? payload.name ?? url.absoluteString,
                     avatarMXCURL: payload.avatarMXCURL,
                     stickers: payload.stickers)
    }

    private static func decodeBase64URL(_ value: String) -> Data? {
        var base64 = value
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        let remainder = base64.count % 4
        if remainder > 0 {
            base64.append(String(repeating: "=", count: 4 - remainder))
        }
        return Data(base64Encoded: base64)
    }

    private struct Payload: Decodable {
        let avatarMXCURL: String?
        let name: String?
        let packID: String?
        let userID: String?
        let stickers: [SetkaPlusStickerItem]

        enum CodingKeys: String, CodingKey {
            case avatarMXCURL = "i"
            case avatarMXCURLFull = "avatar_mxc_url"
            case name = "n"
            case nameFull = "name"
            case packID = "p"
            case packIDFull = "pack_id"
            case userID = "u"
            case userIDFull = "user_id"
            case stickers = "s"
            case stickersFull = "stickers"
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            avatarMXCURL = try container.decodeIfPresent(String.self, forKey: .avatarMXCURL) ??
                container.decodeIfPresent(String.self, forKey: .avatarMXCURLFull)
            name = try container.decodeIfPresent(String.self, forKey: .name) ??
                container.decodeIfPresent(String.self, forKey: .nameFull)
            packID = try container.decodeIfPresent(String.self, forKey: .packID) ??
                container.decodeIfPresent(String.self, forKey: .packIDFull)
            userID = try container.decodeIfPresent(String.self, forKey: .userID) ??
                container.decodeIfPresent(String.self, forKey: .userIDFull)
            let payloadStickers = try container.decodeIfPresent([PayloadSticker].self, forKey: .stickers) ??
                container.decodeIfPresent([PayloadSticker].self, forKey: .stickersFull) ?? []
            stickers = payloadStickers.compactMap(\.setkaPlusStickerItem)
        }
    }

    private struct PayloadSticker: Decodable {
        let id: String?
        let name: String?
        let mxcURL: String?
        let mimeType: String?
        let width: Int?
        let height: Int?
        let size: Int?

        enum CodingKeys: String, CodingKey {
            case id
            case idShort = "i"
            case name
            case nameShort = "n"
            case mxcURL = "mxc_url"
            case mxcURLShort = "u"
            case mimeType = "mime_type"
            case mimeTypeShort = "m"
            case width
            case widthShort = "w"
            case height
            case heightShort = "h"
            case size
            case sizeShort = "z"
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            id = try container.decodeIfPresent(String.self, forKey: .id) ??
                container.decodeIfPresent(String.self, forKey: .idShort)
            name = try container.decodeIfPresent(String.self, forKey: .name) ??
                container.decodeIfPresent(String.self, forKey: .nameShort)
            mxcURL = try container.decodeIfPresent(String.self, forKey: .mxcURL) ??
                container.decodeIfPresent(String.self, forKey: .mxcURLShort)
            mimeType = try container.decodeIfPresent(String.self, forKey: .mimeType) ??
                container.decodeIfPresent(String.self, forKey: .mimeTypeShort)
            width = try container.decodeIfPresent(Int.self, forKey: .width) ??
                container.decodeIfPresent(Int.self, forKey: .widthShort)
            height = try container.decodeIfPresent(Int.self, forKey: .height) ??
                container.decodeIfPresent(Int.self, forKey: .heightShort)
            size = try container.decodeIfPresent(Int.self, forKey: .size) ??
                container.decodeIfPresent(Int.self, forKey: .sizeShort)
        }

        var setkaPlusStickerItem: SetkaPlusStickerItem? {
            guard let id = id?.trimmingCharacters(in: .whitespacesAndNewlines),
                  !id.isEmpty,
                  let name = name?.trimmingCharacters(in: .whitespacesAndNewlines),
                  !name.isEmpty,
                  let mxcURL = mxcURL?.trimmingCharacters(in: .whitespacesAndNewlines),
                  !mxcURL.isEmpty else {
                return nil
            }

            return .init(id: id,
                         name: name,
                         mxcURL: mxcURL,
                         mimeType: mimeType,
                         width: width,
                         height: height,
                         size: size)
        }
    }
}
