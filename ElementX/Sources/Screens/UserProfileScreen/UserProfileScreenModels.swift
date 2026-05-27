//
// Copyright 2025 Element Creations Ltd.
// Copyright 2022-2025 New Vector Ltd.
//
// SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial
// Please see LICENSE files in the repository root for full details.
//

import Foundation

enum UserProfileScreenViewModelAction {
    case openDirectChat(roomID: String)
    case startCall(roomProxy: JoinedRoomProxyProtocol)
    case dismiss
    case editProfile
}

struct UserProfileScreenViewState: BindableState {
    let userID: String
    let isOwnUser: Bool
    let isPresentedModally: Bool
    let showEditProfileButton: Bool
    
    var userProfile: UserProfileProxy?
    var isVerified: Bool?
    var permalink: URL?
    var dmRoomID: String?
    var setkaPlusStatusEmoji: String?
    var bio: String?
    var backgroundURL: URL?
    /// Raw background value from server (`mxc://…`, `linear:…`, or local path).
    var backgroundValue: String?
    var lastSeenText: String?
    var profileColorHex: String?
    var badgeEmojiMXC: String?
    var statusEmojiMXC: String?
    var email: String?
    var phone: String?

    var bindings: UserProfileScreenViewStateBindings
    
    var showVerifiedBadge: Bool {
        isVerified == true // We purposely show the badge on your own account for consistency with Web.
    }

    var profileDisplayData: UserSetkaProfileDisplayData {
        let profile = userProfile ?? UserProfileProxy(userID: userID)
        return .init(userID: userID,
                     displayName: profile.displayName,
                     avatarURL: profile.avatarURL,
                     bio: bio,
                     backgroundValue: backgroundValue ?? backgroundURL?.absoluteString,
                     profileColorHex: profileColorHex,
                     badgeEmojiMXC: badgeEmojiMXC,
                     statusEmojiMXC: statusEmojiMXC,
                     statusEmojiGlyph: setkaPlusStatusEmoji,
                     lastSeenText: lastSeenText,
                     showVerifiedBadge: showVerifiedBadge)
    }
}

struct UserProfileScreenViewStateBindings {
    var alertInfo: AlertInfo<UserProfileScreenAlertType>?
    var inviteConfirmationUser: UserProfileProxy?
    
    /// A media item that will be previewed with QuickLook.
    var mediaPreviewItem: MediaPreviewItem?
}

enum UserProfileScreenViewAction {
    case displayAvatar(URL)
    case openDirectChat
    case createDirectChat
    case startCall(roomID: String)
    case dismiss
    case editProfile
}

enum UserProfileScreenAlertType: Hashable {
    case failedOpeningDirectChat
    case unknown
}
