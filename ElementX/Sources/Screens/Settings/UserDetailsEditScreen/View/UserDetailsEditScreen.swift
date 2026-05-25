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
        
    var body: some View {
        Form {
            Section {
                avatar
            } footer: {
                Text(context.viewState.userID)
                    .frame(maxWidth: .infinity)
                    .font(.compound.bodyLG)
                    .foregroundColor(.compound.textPrimary)
                    .padding(.bottom, 16)
            }
            
            nameSection
            bioSection
            backgroundSection
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
        .sheet(isPresented: $context.setkaPlusStatusPickerPresented) {
            SetkaPlusStatusPickerSheet(isSetkaPlusActive: true,
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

    private var avatar: some View {
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
                .overlay(alignment: .bottomTrailing) {
                    avatarOverlayIcon
                }
                .confirmationDialog("", isPresented: $context.showMediaSheet) {
                    mediaActionSheet
                }
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity, alignment: .center)
        .listRowBackground(Color.clear)
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
        }
    }
    
    private var backgroundSection: some View {
        Section {
            backgroundPreview
            ListRow(label: .plain(title: "Фон профиля (URL)"),
                    kind: .textField(text: $context.backgroundURLString, axis: .horizontal))
            Button("Выбрать фон из медиа") {
                context.send(viewAction: .displayBackgroundMediaPicker)
            }
            .buttonStyle(.compound(.secondary))

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    backgroundGradientButton(title: "Синий", value: "linear:#4A90E2,#7B61FF")
                    backgroundGradientButton(title: "Закат", value: "linear:#FF7A59,#FFA94D")
                    backgroundGradientButton(title: "Изумруд", value: "linear:#00B894,#55EFC4")
                    backgroundGradientButton(title: "Графит", value: "linear:#2D3436,#636E72")
                }
            }
        }
    }
    
    private var statusSection: some View {
        Section {
            Button {
                context.setkaPlusStatusPickerPresented = true
            } label: {
                HStack(spacing: 8) {
                    Text("Статус Setka Plus")
                    Spacer()
                    Text(context.viewState.selectedStatusGlyph ?? "Не выбран")
                        .foregroundStyle(.compound.textSecondary)
                }
            }
        }
    }

    @ViewBuilder
    private var backgroundPreview: some View {
        if let preview = context.viewState.resolvedBackgroundPreview,
           let url = URL(string: preview) {
            LoadableImage(url: url,
                          mediaProvider: context.mediaProvider,
                          transformer: { view in
                              AnyView(view
                                  .scaledToFill()
                                  .frame(height: 120)
                                  .frame(maxWidth: .infinity)
                                  .clipped()
                                  .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous)))
                          },
                          placeholder: {
                              AnyView(
                                  RoundedRectangle(cornerRadius: 12, style: .continuous)
                                      .fill(Color.compound.bgSubtleSecondary)
                                      .frame(height: 120)
                              )
                          })
                .listRowInsets(.init(top: 4, leading: 0, bottom: 8, trailing: 0))
        } else if context.backgroundURLString.hasPrefix("linear:") {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(LinearGradient(colors: gradientColors(from: context.backgroundURLString),
                                     startPoint: .topLeading,
                                     endPoint: .bottomTrailing))
                .frame(height: 120)
                .overlay(alignment: .bottomLeading) {
                    Text("Градиентный фон")
                        .font(.compound.bodySMSemibold)
                        .foregroundStyle(.white.opacity(0.9))
                        .padding(10)
                }
        }
    }

    private func backgroundGradientButton(title: String, value: String) -> some View {
        Button(title) {
            context.send(viewAction: .applyBackgroundGradient(value))
        }
        .buttonStyle(.compound(.secondary))
    }

    private func gradientColors(from value: String) -> [Color] {
        let payload = value.replacingOccurrences(of: "linear:", with: "")
        let values = payload.split(separator: ",").map(String.init)
        guard values.count == 2 else {
            return [.blue, .purple]
        }
        return values.compactMap(Color.init(hex:))
    }
    
    @ToolbarContentBuilder
    private var shareToolbarItem: some ToolbarContent {
        if let shareURL = context.viewState.shareURL {
            ToolbarItem(placement: .primaryAction) {
                ShareLink(item: shareURL)
            }
        }
    }
    
    private var avatarOverlayIcon: some View {
        CompoundIcon(\.editSolid, size: .xSmall, relativeTo: .compound.bodyLG)
            .foregroundColor(.white)
            .padding(4)
            .background {
                Circle()
                    .foregroundColor(.black)
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
