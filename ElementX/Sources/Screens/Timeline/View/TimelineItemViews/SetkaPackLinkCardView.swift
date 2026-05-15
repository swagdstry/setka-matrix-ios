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
        let name: String
        let authorID: String
        let packID: String
        let avatarMXCURL: String?

        var id: String {
            packID
        }
    }

    let pack: PackData
    let mediaProvider: MediaProviderProtocol?
    let onOpen: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(pack.name)
                .font(.compound.bodyMDSemibold)
                .foregroundStyle(.compound.textPrimary)
                .lineLimit(2)

            Text("Создатель: \(pack.authorID)")
                .font(.compound.bodySM)
                .foregroundStyle(.compound.textSecondary)
                .lineLimit(1)

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
}

struct SetkaPackPreviewSheet: View {
    let pack: SetkaPackLinkCardView.PackData
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

                Section {
                    Text("Содержимое пака будет загружаться с сервера в следующем шаге.")
                        .font(.compound.bodySM)
                        .foregroundStyle(.compound.textSecondary)
                }

                Section {
                    Button {
                        onAdd(pack.packID)
                    } label: {
                        Text("Добавить")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.compound(.primary))
                }
            }
            .compoundList()
            .navigationTitle("Стикерпак")
            .navigationBarTitleDisplayMode(.inline)
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
                     name: payload.name ?? "Стикерпак",
                     authorID: payload.userID ?? "unknown",
                     packID: payload.packID ?? payload.name ?? url.absoluteString,
                     avatarMXCURL: payload.avatarMXCURL)
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

        enum CodingKeys: String, CodingKey {
            case avatarMXCURL = "i"
            case name = "n"
            case packID = "p"
            case userID = "u"
        }
    }
}
