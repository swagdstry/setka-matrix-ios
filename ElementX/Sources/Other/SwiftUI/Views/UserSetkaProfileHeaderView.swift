//
// Copyright 2025 Element Creations Ltd.
//
// SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial.
// Please see LICENSE files in the repository root for full details.
//

import Compound
import SwiftUI

struct UserSetkaProfileDisplayData: Equatable {
    let userID: String
    var displayName: String?
    var avatarURL: URL?
    var bio: String?
    var backgroundValue: String?
    var profileColorHex: String?
    var badgeEmojiMXC: String?
    var statusEmojiMXC: String?
    var statusEmojiGlyph: String?
    var lastSeenText: String?
    var showVerifiedBadge = false
}

struct UserSetkaProfileHeaderView: View {
    let data: UserSetkaProfileDisplayData
    let mediaProvider: MediaProviderProtocol?
    var onAvatarTap: ((URL) -> Void)?

    private let bannerHeight: CGFloat = 200
    private let avatarRingWidth: CGFloat = 4

    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                ProfileBannerBackground(previewValue: data.backgroundValue,
                                        profileColorHex: data.profileColorHex,
                                        mediaProvider: mediaProvider)
                    .frame(height: bannerHeight)
                    .frame(maxWidth: .infinity)
                    .clipped()

                LinearGradient(colors: [.black.opacity(0.15), .black.opacity(0.45)],
                               startPoint: .top,
                               endPoint: .bottom)

                VStack(spacing: 10) {
                    avatarStack

                    identityTexts
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 20)
            }
            .frame(height: bannerHeight)

            if let bio = data.bio, !bio.isEmpty {
                Text(bio)
                    .font(.compound.bodyMD)
                    .foregroundStyle(.compound.textPrimary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(14)
                    .background(Color.compound.bgSubtleSecondary, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
                    .padding(.bottom, 4)
            }
        }
    }

    private var avatarStack: some View {
        LoadableAvatarImage(url: data.avatarURL,
                            name: data.displayName,
                            contentID: data.userID,
                            avatarSize: .user(on: .memberDetails),
                            mediaProvider: mediaProvider,
                            onTap: onAvatarTap)
            .overlay {
                Circle()
                    .strokeBorder(Color.compound.bgCanvasDefault, lineWidth: avatarRingWidth)
            }
            .overlay(alignment: .topTrailing) {
                statusBadge
                    .offset(x: 4, y: -4)
            }
            .accessibilityLabel(data.avatarURL != nil ? L10n.a11yViewAvatar : L10n.a11yAvatar)
    }

    @ViewBuilder
    private var statusBadge: some View {
        if let statusEmojiMXC = data.statusEmojiMXC,
           let url = URL(string: statusEmojiMXC) {
            LoadableImage(url: url,
                          mediaProvider: mediaProvider,
                          transformer: { view in
                              AnyView(view.scaledToFit().frame(width: 22, height: 22))
                          },
                          placeholder: {
                              AnyView(ProgressView().frame(width: 22, height: 22))
                          })
                .padding(5)
                .background(Color.compound.bgCanvasDefault.opacity(0.94), in: Circle())
        } else if let glyph = data.statusEmojiGlyph, !glyph.isEmpty {
            Text(glyph)
                .font(.system(size: 16))
                .padding(6)
                .background(Color.compound.bgCanvasDefault.opacity(0.94), in: Circle())
        }
    }

    private var identityTexts: some View {
        VStack(spacing: 4) {
            HStack(spacing: 6) {
                Text(data.displayName ?? data.userID)
                    .font(.compound.headingMDBold)
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                    .textSelection(.enabled)

                if let badgeURL = data.badgeEmojiMXC.flatMap(URL.init(string:)) {
                    LoadableImage(url: badgeURL,
                                  mediaProvider: mediaProvider,
                                  transformer: { view in
                                      AnyView(view.scaledToFit().frame(width: 18, height: 18))
                                  },
                                  placeholder: {
                                      AnyView(ProgressView().frame(width: 18, height: 18))
                                  })
                }
            }

            if let lastSeen = data.lastSeenText, !lastSeen.isEmpty {
                Text(lastSeen)
                    .font(.compound.bodySM)
                    .foregroundStyle(.white.opacity(0.82))
                    .multilineTextAlignment(.center)
            }

            Text(data.userID)
                .font(.compound.bodySM)
                .foregroundStyle(.white.opacity(0.78))
                .multilineTextAlignment(.center)
                .textSelection(.enabled)

            if data.showVerifiedBadge {
                BadgeLabel(title: L10n.commonVerified,
                           icon: \.verified,
                           style: .accent)
            }
        }
    }
}
