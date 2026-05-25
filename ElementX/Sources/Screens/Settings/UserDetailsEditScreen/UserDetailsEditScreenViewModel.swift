//
// Copyright 2025 Element Creations Ltd.
// Copyright 2022-2025 New Vector Ltd.
//
// SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial
// Please see LICENSE files in the repository root for full details.
//

import Combine
import SwiftUI

typealias UserDetailsEditScreenViewModelType = StateStoreViewModelV2<UserDetailsEditScreenViewState, UserDetailsEditScreenViewAction>

class UserDetailsEditScreenViewModel: UserDetailsEditScreenViewModelType, UserDetailsEditScreenViewModelProtocol {
    private enum MediaSelectionTarget {
        case avatar
        case background
    }

    private let actionsSubject: PassthroughSubject<UserDetailsEditScreenViewModelAction, Never> = .init()
    private let clientProxy: ClientProxyProtocol
    private let userIndicatorController: UserIndicatorControllerProtocol
    private let mediaUploadingPreprocessor: MediaUploadingPreprocessor
    private var mediaSelectionTarget: MediaSelectionTarget = .avatar
    
    var actions: AnyPublisher<UserDetailsEditScreenViewModelAction, Never> {
        actionsSubject.eraseToAnyPublisher()
    }
    
    init(userSession: UserSessionProtocol,
         mediaUploadingPreprocessor: MediaUploadingPreprocessor,
         userIndicatorController: UserIndicatorControllerProtocol) {
        clientProxy = userSession.clientProxy
        self.mediaUploadingPreprocessor = mediaUploadingPreprocessor
        self.userIndicatorController = userIndicatorController
        
        super.init(initialViewState: UserDetailsEditScreenViewState(userID: clientProxy.userID,
                                                                    bindings: .init()), mediaProvider: userSession.mediaProvider)
        
        clientProxy.userAvatarURLPublisher
            .receive(on: DispatchQueue.main)
            .weakAssign(to: \.state.currentAvatarURL, on: self)
            .store(in: &cancellables)
        
        clientProxy.userAvatarURLPublisher
            .receive(on: DispatchQueue.main)
            .weakAssign(to: \.state.selectedAvatarURL, on: self)
            .store(in: &cancellables)
        
        clientProxy.userDisplayNamePublisher
            .receive(on: DispatchQueue.main)
            .weakAssign(to: \.state.currentDisplayName, on: self)
            .store(in: &cancellables)
        
        clientProxy.userDisplayNamePublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] displayName in
                guard let self else { return }
                
                state.bindings.name = displayName ?? ""
            }
            .store(in: &cancellables)
        
        Task {
            await self.clientProxy.loadUserAvatarURL()
            await self.clientProxy.loadUserDisplayName()
            await self.loadSetkaPlusProfile()
        }
    }
    
    // MARK: - Public
    
    override func process(viewAction: UserDetailsEditScreenViewAction) {
        switch viewAction {
        case .cancel:
            showUnsavedChangesAlert() // The cancel button is only shown when there are unsaved changes.
        case .save:
            Task { await saveUserDetails() }
        case .presentMediaSource:
            state.bindings.showMediaSheet = true
        case .displayCameraPicker:
            actionsSubject.send(.displayCameraPicker)
        case .displayMediaPicker:
            mediaSelectionTarget = .avatar
            actionsSubject.send(.displayMediaPicker)
        case .displayBackgroundMediaPicker:
            mediaSelectionTarget = .background
            actionsSubject.send(.displayMediaPicker)
        case .removeImage:
            state.localMedia = nil
            state.selectedAvatarURL = nil
        case .applyBackgroundGradient(let gradient):
            state.localBackgroundMedia = nil
            state.bindings.backgroundURLString = gradient
        case .setSetkaPlusStatusEmoji(let emoji):
            state.bindings.selectedSetkaPlusStatus = .init(emoji: emoji, packID: nil, stickerID: nil, updatedAt: nil)
            state.bindings.setkaPlusStatusPickerPresented = false
        case .setSetkaPlusStatusSticker(let packID, let stickerID):
            state.bindings.selectedSetkaPlusStatus = .init(emoji: nil, packID: packID, stickerID: stickerID, updatedAt: nil)
            state.bindings.setkaPlusStatusPickerPresented = false
        case .clearSetkaPlusStatusEmoji:
            state.bindings.selectedSetkaPlusStatus = .init(emoji: nil, packID: nil, stickerID: nil, updatedAt: nil)
            state.bindings.setkaPlusStatusPickerPresented = false
        }
    }
    
    func didSelectMediaURL(url: URL) {
        Task {
            let userIndicatorID = UUID().uuidString
            defer { userIndicatorController.retractIndicatorWithId(userIndicatorID) }
            userIndicatorController.submitIndicator(UserIndicator(id: userIndicatorID,
                                                                  type: .modal(progress: .indeterminate, interactiveDismissDisabled: true, allowsInteraction: false),
                                                                  title: L10n.commonLoading,
                                                                  persistent: true))
            
            guard case let .success(maxUploadSize) = await clientProxy.maxMediaUploadSize else {
                MXLog.error("Failed to get max upload size")
                state.bindings.alertInfo = .init(id: .unknown)
                return
            }
            let mediaResult = await mediaUploadingPreprocessor.processMedia(at: url, maxUploadSize: maxUploadSize)
            
            switch mediaResult {
            case .success(.image):
                let media = try? mediaResult.get()
                switch mediaSelectionTarget {
                case .avatar:
                    state.localMedia = media
                case .background:
                    state.localBackgroundMedia = media
                    if let previewURL = media?.thumbnailURL?.absoluteString {
                        state.bindings.backgroundURLString = previewURL
                    }
                }
            case .failure, .success:
                state.bindings.alertInfo = .init(id: .failedProcessingMedia)
            }
        }
    }
    
    // MARK: - Private
    
    private func showUnsavedChangesAlert() {
        state.bindings.alertInfo = .init(id: .unsavedChanges,
                                         title: L10n.dialogUnsavedChangesTitle,
                                         message: L10n.dialogUnsavedChangesDescription,
                                         primaryButton: .init(title: L10n.actionSave) { Task { await self.saveUserDetails() } },
                                         secondaryButton: .init(title: L10n.actionDiscard, role: .cancel) { self.actionsSubject.send(.dismiss) })
    }
    
    private func saveUserDetails() async {
        let userIndicatorID = UUID().uuidString
        defer {
            userIndicatorController.retractIndicatorWithId(userIndicatorID)
        }
        userIndicatorController.submitIndicator(UserIndicator(id: userIndicatorID,
                                                              type: .modal(progress: .indeterminate, interactiveDismissDisabled: true, allowsInteraction: false),
                                                              title: L10n.screenEditProfileUpdatingDetails,
                                                              persistent: true))
        
        let avatarDidChange = state.avatarDidChange
        let localMedia = state.localMedia
        let selectedAvatarURL = state.selectedAvatarURL
        let nameDidChange = state.nameDidChange
        let displayName = state.bindings.name
        let bioDidChange = state.bioDidChange
        let backgroundDidChange = state.backgroundDidChange
        let backgroundMediaDidChange = state.backgroundMediaDidChange
        let localBackgroundMedia = state.localBackgroundMedia
        let bio = state.bindings.bio.trimmingCharacters(in: .whitespacesAndNewlines)
        let background = state.bindings.backgroundURLString.trimmingCharacters(in: .whitespacesAndNewlines)
        let statusDidChange = state.statusDidChange
        let selectedStatus = state.bindings.selectedSetkaPlusStatus
        
        do {
            try await withThrowingTaskGroup(of: Void.self) { group in
                if avatarDidChange {
                    group.addTask {
                        if let localMedia {
                            try await self.clientProxy.setUserAvatar(media: localMedia).get()
                        } else if selectedAvatarURL == nil {
                            try await self.clientProxy.removeUserAvatar().get()
                        }
                    }
                }
                
                if nameDidChange {
                    group.addTask {
                        try await self.clientProxy.setUserDisplayName(displayName).get()
                    }
                }
                
                if bioDidChange || backgroundDidChange || backgroundMediaDidChange {
                    group.addTask {
                        var resolvedBackground = background
                        if let localBackgroundMedia {
                            resolvedBackground = try await self.clientProxy.uploadMedia(localBackgroundMedia).get()
                        }

                        let update = SetkaPlusUserProfileUpdate(bio: bio.isEmpty ? nil : bio,
                                                                backgroundURL: resolvedBackground.isEmpty ? nil : resolvedBackground)
                        try await self.clientProxy.updateSetkaPlusUserProfileDetails(update).get()
                    }
                }
                
                if statusDidChange {
                    group.addTask {
                        _ = try await self.clientProxy.updateSetkaPlusStatusEmoji(emoji: selectedStatus?.emoji,
                                                                                  packID: selectedStatus?.packID,
                                                                                  stickerID: selectedStatus?.stickerID).get()
                    }
                }
                
                try await group.waitForAll()
            }
            
            actionsSubject.send(.dismiss)
        } catch {
            state.bindings.alertInfo = .init(id: .saveError,
                                             title: L10n.screenEditProfileErrorTitle,
                                             message: L10n.screenEditProfileError)
        }
    }
    
    private func loadSetkaPlusProfile() async {
        async let detailsResult = clientProxy.fetchSetkaPlusUserProfileDetails(userID: clientProxy.userID)
        async let statusResult = clientProxy.fetchSetkaPlusStatusEmoji(userID: nil)
        async let packsResult = clientProxy.fetchSetkaPlusStickerPacks()
        
        if case let .success(details) = await detailsResult {
            state.currentBio = details.bio
            state.currentBackgroundURLString = details.backgroundURL
            state.shareURL = details.shareURL.flatMap(URL.init(string:))
            state.bindings.bio = details.bio ?? ""
            state.bindings.backgroundURLString = details.backgroundURL ?? ""
        }
        
        if case let .success(status) = await statusResult {
            state.currentSetkaPlusStatus = status
            state.bindings.selectedSetkaPlusStatus = status
        }
        
        if case let .success(packs) = await packsResult {
            state.setkaPlusEmojiPacks = packs
        }
    }
}
