//
// Copyright 2025 Element Creations Ltd.
// Copyright 2022-2025 New Vector Ltd.
//
// SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial
// Please see LICENSE files in the repository root for full details.
//
    
import Compound
import SwiftUI

struct UserDetailsEditScreen: View {
    @Bindable var context: UserDetailsEditScreenViewModel.Context
    @FocusState private var focus: Bool

    private let profileBannerHeight: CGFloat = 156
    private let avatarRingWidth: CGFloat = 4

    var body: some View {
        Form {
            Section {
                profileHeader
            } footer: {
                Text(context.viewState.userID)
                    .font(.compound.bodySM)
                    .foregroundStyle(.compound.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.top, 4)
            }
            .listRowInsets(EdgeInsets())
            .listRowBackground(Color.clear)

            nameSection
            bioSection
            statusSection
        }
        .compoundList()
        .scrollDismissesKeyboard(.immediately)
        .navigationTitle(L10n.screenEditProfileTitle)
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(context.viewState.canSave)
        .toolbar {
            toolbar
            shareToolbarItem
        }
        .alert(item: $context.alertInfo)
        .sheet(isPresented: $context.bannerPickerPresented) {
            ProfileBannerPickerSheet(isSetkaPlusActive: context.viewState.isSetkaPlusActive,
                                     suggestedBanners: context.viewState.suggestedProfileBanners,
                                     onSelectCustomBanner: {
                                         context.send(viewAction: .displayBackgroundMediaPicker)
                                     },
                                     onSelectSuggestedBanner: { banner in
                                         context.send(viewAction: .applyBackgroundGradient(banner.value))
                                     },
                                     onDismiss: {
                                         context.send(viewAction: .dismissBannerPicker)
                                     })
        }
        .sheet(isPresented: $context.setkaPlusStatusPickerPresented) {
            SetkaPlusStatusPickerSheet(isSetkaPlusActive: context.viewState.isSetkaPlusActive,
                                       selectedEmoji: context.viewState.selectedStatusGlyph,
                                       selectedStickerID: context.viewState.bindings.selectedSetkaPlusStatus?.stickerID,
                                       emojiPacks: context.viewState.setkaPlusEmojiPacks,
                                       mediaProvider: context.mediaProvider,
                                       onSelectEmoji: { emoji in
                                           context.send(viewAction: .setSetkaPlusStatusEmoji(emoji))
                                       },
                                       onSelectSticker: { packID, stickerID in
                                           context.send(viewAction: .setSetkaPlusStatusSticker(packID: packID, stickerID: stickerID))
                                       },
                                       onClear: {
                                           context.send(viewAction: .clearSetkaPlusStatusEmoji)
                                       })
        }
    }

    // MARK: - Private

    @ToolbarContentBuilder
    private var toolbar: some ToolbarContent {
        ToolbarItem(placement: .cancellationAction) {
            if context.viewState.canSave {
                Button(L10n.actionCancel) {
                    context.send(viewAction: .cancel)
                }
            }
        }
        ToolbarItem(placement: .confirmationAction) {
            Button(L10n.actionSave) {
                context.send(viewAction: .save)
                focus = false
            }
            .disabled(!context.viewState.canSave)
        }
    }

    private var profileHeader: some View {
        let avatarSize = Avatars.Size.user(on: .editUserDetails).value
        let avatarOverlap = avatarSize / 2

        return ZStack(alignment: .bottom) {
            bannerBackground
                .frame(height: profileBannerHeight)
                .clipped()
                .overlay {
                    LinearGradient(colors: [.clear, .black.opacity(0.35)],
                                   startPoint: .center,
                                   endPoint: .bottom)
                }
                .overlay(alignment: .topTrailing) {
                    bannerEditControl
                        .padding(12)
                }
                .accessibilityElement(children: .contain)

            avatarControl
                .padding(.bottom, 4)
        }
        .frame(height: profileBannerHeight + avatarOverlap)
    }

    @ViewBuilder
    private var bannerBackground: some View {
        ProfileBannerBackground(previewValue: context.viewState.resolvedBackgroundPreview,
                                profileColorHex: nil,
                                mediaProvider: context.mediaProvider)
    }

    private var bannerEditControl: some View {
        Button {
            context.bannerPickerPresented = true
        } label: {
            editOverlayBadge
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Изменить фон профиля")
    }

    private var avatarControl: some View {
        Button {
            context.send(viewAction: .presentMediaSource)
        } label: {
            OverridableAvatarImage(overrideURL: context.viewState.localMedia?.thumbnailURL,
                                   url: context.viewState.selectedAvatarURL,
                                   name: context.viewState.currentDisplayName,
                                   contentID: context.viewState.userID,
                                   shape: .circle,
                                   avatarSize: .user(on: .editUserDetails),
                                   mediaProvider: context.mediaProvider)
                .overlay {
                    Circle()
                        .strokeBorder(Color.compound.bgCanvasDefault, lineWidth: avatarRingWidth)
                }
                .overlay(alignment: .bottomTrailing) {
                    editOverlayBadge
                        .offset(x: 2, y: 2)
                }
                .confirmationDialog("", isPresented: $context.showMediaSheet) {
                    mediaActionSheet
                }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(L10n.a11yEditAvatar)
    }

    private var nameSection: some View {
        Section {
            ListRow(label: .plain(title: L10n.screenEditProfileDisplayNamePlaceholder),
                    kind: .textField(text: $context.name, axis: .horizontal))
                .focused($focus)
        } header: {
            Text(L10n.screenEditProfileDisplayName)
                .compoundListSectionHeader()
        }
    }

    private var bioSection: some View {
        Section {
            ListRow(label: .plain(title: "Биография"),
                    kind: .textField(text: $context.bio, axis: .vertical))
                .lineLimit(3...)
        } header: {
            Text("О себе")
                .compoundListSectionHeader()
        }
    }

    private var statusSection: some View {
        Section {
            Button {
                context.setkaPlusStatusPickerPresented = true
            } label: {
                HStack(spacing: 12) {
                    Text("Статус Setka Plus")
                        .font(.compound.bodyLG)
                        .foregroundStyle(.compound.textPrimary)
                    Spacer()
                    Text(context.viewState.selectedStatusGlyph ?? "Не выбран")
                        .font(.compound.bodyMD)
                        .foregroundStyle(.compound.textSecondary)
                    CompoundIcon(\.chevronRight, size: .small, relativeTo: .compound.bodyLG)
                        .foregroundStyle(.compound.iconTertiary)
                }
            }
        }
    }

    private var editOverlayBadge: some View {
        CompoundIcon(\.editSolid, size: .xSmall, relativeTo: .compound.bodyLG)
            .foregroundStyle(.white)
            .padding(6)
            .background(.black.opacity(0.55), in: Circle())
    }

    @ToolbarContentBuilder
    private var shareToolbarItem: some ToolbarContent {
        if let shareURL = context.viewState.shareURL {
            ToolbarItem(placement: .primaryAction) {
                ShareLink(item: shareURL)
            }
        }
    }

    @ViewBuilder
    private var mediaActionSheet: some View {
        Button {
            context.send(viewAction: .displayCameraPicker)
        } label: {
            Text(L10n.actionTakePhoto)
        }
        Button {
            context.send(viewAction: .displayMediaPicker)
        } label: {
            Text(L10n.actionChoosePhoto)
        }

        if context.viewState.showDeleteImageAction {
            Button(role: .destructive) {
                context.send(viewAction: .removeImage)
            } label: {
                Text(L10n.actionRemove)
            }
        }
    }
}

// MARK: - Previews

struct UserDetailsEditScreen_Previews: PreviewProvider, TestablePreview {
    static let viewModel = UserDetailsEditScreenViewModel(userSession: UserSessionMock(.init(clientProxy: ClientProxyMock(.init(userID: "@stefan:matrix.org")))),
                                                          mediaUploadingPreprocessor: .init(appSettings: ServiceLocator.shared.settings),
                                                          userIndicatorController: UserIndicatorControllerMock.default)

    static var previews: some View {
        ElementNavigationStack {
            UserDetailsEditScreen(context: viewModel.context)
        }
    }
}
