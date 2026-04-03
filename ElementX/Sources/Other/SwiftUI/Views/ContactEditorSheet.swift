//
// Copyright 2025 Element Creations Ltd.
// Copyright 2025 New Vector Ltd.
//
// SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial.
// Please see LICENSE files in the repository root for full details.
//

import Compound
import SwiftUI

struct ContactEditorSheet: View {
    struct Draft: Identifiable, Equatable {
        let roomID: String
        let userID: String?
        var alias: String
        var email: String
        var phone: String
        var tags: String
        var isFavorite: Bool
        var syncEmailToServer: Bool
        var syncPhoneToServer: Bool
        
        var id: String {
            roomID
        }
        
        var normalizedTags: [String] {
            tags
                .split(separator: ",")
                .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
        }
        
        init(roomID: String,
             userID: String?,
             alias: String,
             email: String? = nil,
             phone: String? = nil,
             tags: [String] = [],
             isFavorite: Bool = false,
             syncEmailToServer: Bool = true,
             syncPhoneToServer: Bool = true) {
            self.roomID = roomID
            self.userID = userID
            self.alias = alias
            self.email = email ?? ""
            self.phone = phone ?? ""
            self.tags = tags.joined(separator: ", ")
            self.isFavorite = isFavorite
            self.syncEmailToServer = syncEmailToServer
            self.syncPhoneToServer = syncPhoneToServer
        }
        
        init(contact: ManagedContact) {
            self.init(roomID: contact.roomID,
                      userID: contact.userID,
                      alias: contact.alias,
                      email: contact.email,
                      phone: contact.phone,
                      tags: contact.tags,
                      isFavorite: contact.isFavorite,
                      syncEmailToServer: contact.syncEmailToServer,
                      syncPhoneToServer: contact.syncPhoneToServer)
        }
    }
    
    let title: String
    @Binding var draft: Draft
    let onCancel: () -> Void
    let onSave: () -> Void
    
    var body: some View {
        ElementNavigationStack {
            Form {
                Section {
                    TextField(L10n.commonName, text: $draft.alias)
                        .textInputAutocapitalization(.words)
                        .autocorrectionDisabled(false)
                    
                    ListRow(label: .plain(title: draft.roomID), kind: .label)
                    
                    if let userID = draft.userID, !userID.isEmpty {
                        ListRow(label: .plain(title: userID), kind: .label)
                    }
                } footer: {
                    Text(UntranslatedL10n.screenContactsEditorFooter)
                        .compoundListSectionFooter()
                }
                
                Section {
                    TextField(UntranslatedL10n.screenContactsEditorEmail, text: $draft.email)
                        .keyboardType(.emailAddress)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    
                    TextField(UntranslatedL10n.screenContactsEditorPhone, text: $draft.phone)
                        .keyboardType(.phonePad)
                    
                    Toggle("Favorite", isOn: $draft.isFavorite)
                    TextField("Tags (comma-separated)", text: $draft.tags)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                }
                
                Section {
                    Toggle("Sync email to server", isOn: $draft.syncEmailToServer)
                    Toggle("Sync phone to server", isOn: $draft.syncPhoneToServer)
                    
                    if !draft.syncEmailToServer || !draft.syncPhoneToServer {
                        Text("Disabled fields are stored only on this device.")
                            .compoundListSectionFooter()
                    }
                }
            }
            .compoundList()
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.actionCancel) {
                        onCancel()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button(L10n.actionSave) {
                        onSave()
                    }
                    .disabled(draft.alias.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }
}
