//
// Copyright 2025 Element Creations Ltd.
//
// SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial.
// Please see LICENSE files in the repository root for full details.
//

import Compound
import SwiftUI

struct ProfileBannerBackground: View {
    let previewValue: String?
    let profileColorHex: String?
    let mediaProvider: MediaProviderProtocol?

    var body: some View {
        if let preview = previewValue?.trimmingCharacters(in: .whitespacesAndNewlines), !preview.isEmpty {
            if preview.hasPrefix("linear:") {
                LinearGradient(colors: ProfileSuggestedBanner.colors(from: preview),
                               startPoint: .topLeading,
                               endPoint: .bottomTrailing)
            } else if let url = URL(string: preview) {
                LoadableImage(url: url,
                              mediaProvider: mediaProvider,
                              transformer: { view in
                                  AnyView(view.scaledToFill())
                              },
                              placeholder: {
                                  AnyView(placeholder)
                              })
            } else {
                placeholder
            }
        } else if let profileColorHex,
                  let profileColor = Color(hex: profileColorHex) {
            LinearGradient(colors: [profileColor.opacity(0.55), profileColor.opacity(0.2)],
                           startPoint: .topLeading,
                           endPoint: .bottomTrailing)
        } else {
            placeholder
        }
    }

    private var placeholder: some View {
        LinearGradient(colors: [Color.compound.bgSubtleSecondary, Color.compound.bgSubtlePrimary],
                       startPoint: .topLeading,
                       endPoint: .bottomTrailing)
    }
}
