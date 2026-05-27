//
// Copyright 2025 Element Creations Ltd.
// Copyright 2022-2025 New Vector Ltd.
//
// SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial.
// Please see LICENSE files in the repository root for full details.
//

import Compound
import SwiftUI

struct UserProfileScreen: View {
    @Bindable var context: UserProfileScreenViewModel.Context

    var body: some View {
        Form {
            profileSection
            contactDetailsSection
            shareSection
            contactActionsSection
        }
        .compoundList()
        .navigationTitle(L10n.screenRoomMemberDetailsTitle)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { toolbar }
        .alert(item: $context.alertInfo)
        .sheet(item: $context.inviteConfirmationUser) { user in
            SendInviteConfirmationView(userToInvite: user,
                                       mediaProvider: context.mediaProvider) {
                context.send(viewAction: .createDirectChat)
            }
        }
        .track(screen: .User)
        .interactiveQuickLook(item: $context.mediaPreviewItem, allowEditing: false)
    }

    // MARK: - Private

    private var profileSection: some View {
        Section {
            UserSetkaProfileHeaderView(data: context.viewState.profileDisplayData,
                                       mediaProvider: context.mediaProvider) { url in
                context.send(viewAction: .displayAvatar(url))
            }
        }
        .listRowInsets(EdgeInsets())
        .listRowBackground(Color.clear)
    }

    @ViewBuilder
    private var contactDetailsSection: some View {
        if hasContactDetails {
            Section {
                if let email = context.viewState.email, !email.isEmpty {
                    ListRow(label: .plain(title: email), kind: .label)
                }

                if let phone = context.viewState.phone, !phone.isEmpty {
                    ListRow(label: .plain(title: phone), kind: .label)
                }
            }
        }
    }

    private var hasContactDetails: Bool {
        context.viewState.email?.isEmpty == false || context.viewState.phone?.isEmpty == false
    }

    @ViewBuilder
    private var shareSection: some View {
        if context.viewState.permalink != nil {
            Section {
                HStack {
                    Spacer()
                    if let permalink = context.viewState.permalink {
                        ShareLink(item: permalink) {
                            CompoundIcon(\.shareIos, size: .medium, relativeTo: .compound.bodyLG)
                                .foregroundStyle(.compound.iconPrimary)
                                .padding(14)
                                .background(Color.compound.bgCanvasDefaultLevel1, in: Circle())
                        }
                        .accessibilityLabel(L10n.actionShare)
                    }
                    Spacer()
                }
                .listRowBackground(Color.clear)
            }
        }
    }

    @ViewBuilder
    private var contactActionsSection: some View {
        if hasContactActions {
            Section {
                let columns = Array(repeating: GridItem(.flexible(), spacing: 8), count: contactActionCount)

                LazyVGrid(columns: columns, spacing: 8) {
                    if context.viewState.userProfile != nil, !context.viewState.isOwnUser {
                        Button {
                            context.send(viewAction: .openDirectChat)
                        } label: {
                            CompoundIcon(\.chat)
                        }
                        .buttonStyle(FormActionButtonStyle(title: L10n.commonMessage))
                        .accessibilityIdentifier(A11yIdentifiers.roomMemberDetailsScreen.directChat)
                    }

                    if let roomID = context.viewState.dmRoomID {
                        Button {
                            context.send(viewAction: .startCall(roomID: roomID))
                        } label: {
                            CompoundIcon(\.videoCall)
                        }
                        .buttonStyle(FormActionButtonStyle(title: L10n.actionCall))
                    }
                }
                .padding(.vertical, 4)
            }
        }
    }

    private var hasContactActions: Bool {
        (context.viewState.userProfile != nil && !context.viewState.isOwnUser) || context.viewState.dmRoomID != nil
    }

    private var contactActionCount: Int {
        var count = 0
        if context.viewState.userProfile != nil, !context.viewState.isOwnUser { count += 1 }
        if context.viewState.dmRoomID != nil { count += 1 }
        return max(count, 1)
    }

    @ToolbarContentBuilder
    private var toolbar: some ToolbarContent {
        if context.viewState.isOwnUser, context.viewState.showEditProfileButton {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    context.send(viewAction: .editProfile)
                } label: {
                    CompoundIcon(\.editSolid)
                }
                .accessibilityLabel("Edit profile")
            }
        }

        if context.viewState.isPresentedModally {
            ToolbarItem(placement: .confirmationAction) {
                Button(L10n.actionDone) {
                    context.send(viewAction: .dismiss)
                }
            }
        }
    }
}

// MARK: - Previews

struct UserProfileScreen_Previews: PreviewProvider, TestablePreview {
    static let verifiedUserViewModel = makeViewModel(userID: RoomMemberProxyMock.mockDan.userID)
    static let otherUserViewModel = makeViewModel(userID: RoomMemberProxyMock.mockAlice.userID)
    static let accountOwnerViewModel = makeViewModel(userID: RoomMemberProxyMock.mockMe.userID)

    static var previews: some View {
        UserProfileScreen(context: verifiedUserViewModel.context)
            .snapshotPreferences(expect: verifiedUserViewModel.context.observe(\.viewState.isVerified).map { $0 != nil })
            .previewDisplayName("Verified User")

        UserProfileScreen(context: otherUserViewModel.context)
            .snapshotPreferences(expect: otherUserViewModel.context.observe(\.viewState.isVerified).map { $0 != nil })
            .previewDisplayName("Other User")

        UserProfileScreen(context: accountOwnerViewModel.context)
            .snapshotPreferences(expect: accountOwnerViewModel.context.observe(\.viewState.isVerified).map { $0 != nil })
            .previewDisplayName("Account Owner")
    }

    static func makeViewModel(userID: String) -> UserProfileScreenViewModel {
        let clientProxyMock = ClientProxyMock(.init())

        clientProxyMock.userIdentityForFallBackToServerClosure = { userID, _ in
            let identity = switch userID {
            case RoomMemberProxyMock.mockDan.userID:
                UserIdentityProxyMock(configuration: .init(verificationState: .verified))
            default:
                UserIdentityProxyMock(configuration: .init())
            }

            return .success(identity)
        }

        if userID != RoomMemberProxyMock.mockMe.userID {
            clientProxyMock.directRoomForUserIDReturnValue = .success("roomID")
        }

        return UserProfileScreenViewModel(userID: userID,
                                          isPresentedModally: false,
                                          showEditProfileButton: userID == RoomMemberProxyMock.mockMe.userID,
                                          userSession: UserSessionMock(.init(clientProxy: clientProxyMock)),
                                          userIndicatorController: ServiceLocator.shared.userIndicatorController,
                                          analytics: ServiceLocator.shared.analytics)
    }
}
