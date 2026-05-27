//
// Copyright 2025 Element Creations Ltd.
// Copyright 2022-2025 New Vector Ltd.
//
// SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial
// Please see LICENSE files in the repository root for full details.
//

import Foundation

enum UserDetailsEditScreenViewModelAction {
    case dismiss
    case displayCameraPicker
    case displayMediaPicker
    case displayFilePicker
}

struct UserDetailsEditScreenViewState: BindableState {
    let userID: String
    
    var currentAvatarURL: URL?
    var selectedAvatarURL: URL?
    
    var currentDisplayName: String?
    var currentBio: String?
    var currentBackgroundURLString: String?
    var currentSetkaPlusStatus: SetkaPlusStatusEmoji?
    var setkaPlusEmojiPacks: [SetkaPlusStickerPack] = []
    var isSetkaPlusActive = false
    var shareURL: URL?
    var suggestedProfileBanners = ProfileSuggestedBanner.defaultPresets
    
    var localMedia: MediaInfo?
    var localBackgroundMedia: MediaInfo?
    
    var bindings: UserDetailsEditScreenViewStateBindings
    
    var nameDidChange: Bool {
        bindings.name != currentDisplayName
    }
    
    var bioDidChange: Bool {
        bindings.bio.trimmingCharacters(in: .whitespacesAndNewlines) != (currentBio ?? "")
    }
    
    var backgroundDidChange: Bool {
        bindings.backgroundURLString.trimmingCharacters(in: .whitespacesAndNewlines) != (currentBackgroundURLString ?? "")
    }
    
    var statusDidChange: Bool {
        bindings.selectedSetkaPlusStatus != currentSetkaPlusStatus
    }
      
    var avatarDidChange: Bool {
        localMedia != nil || selectedAvatarURL != currentAvatarURL
    }

    var backgroundMediaDidChange: Bool {
        localBackgroundMedia != nil
    }
    
    var canSave: Bool {
        !bindings.name.isEmpty && (avatarDidChange || nameDidChange || bioDidChange || backgroundDidChange || backgroundMediaDidChange || statusDidChange)
    }
    
    var showDeleteImageAction: Bool {
        localMedia != nil || selectedAvatarURL != nil
    }
    
    var selectedStatusGlyph: String? {
        SetkaPlusStatusDisplay.glyph(for: bindings.selectedSetkaPlusStatus)
    }

    var resolvedBackgroundPreview: String? {
        if let localBackground = localBackgroundMedia?.thumbnailURL?.absoluteString {
            return localBackground
        }
        let trimmed = bindings.backgroundURLString.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}

struct UserDetailsEditScreenViewStateBindings {
    var name = ""
    var bio = ""
    var backgroundURLString = ""
    var showMediaSheet = false
    var showBackgroundMediaSheet = false
    var bannerPickerPresented = false
    var setkaPlusStatusPickerPresented = false
    var selectedSetkaPlusStatus: SetkaPlusStatusEmoji?
    
    var alertInfo: AlertInfo<UserDetailsEditScreenAlertType>?
}

enum UserDetailsEditScreenAlertType {
    case failedProcessingMedia
    case unsavedChanges
    case saveError
    case unknown
}

enum UserDetailsEditScreenViewAction {
    case cancel
    case save
    case presentMediaSource
    case displayCameraPicker
    case displayMediaPicker
    case displayBackgroundMediaPicker
    case dismissBannerPicker
    case removeImage
    case applyBackgroundGradient(String)
    case setSetkaPlusStatusEmoji(String)
    case setSetkaPlusStatusSticker(packID: String, stickerID: String)
    case clearSetkaPlusStatusEmoji
}
