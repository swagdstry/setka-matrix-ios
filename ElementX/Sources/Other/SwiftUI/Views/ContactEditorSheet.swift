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
        
        var id: String {
            roomID
        }
        
        init(roomID: String,
             userID: String?,
             alias: String,
             email: String? = nil,
             phone: String? = nil) {
            self.roomID = roomID
            self.userID = userID
            self.alias = alias
            self.email = email ?? ""
            self.phone = phone ?? ""
        }
        
        init(contact: ManagedContact) {
            self.init(roomID: contact.roomID,
                      userID: contact.userID,
                      alias: contact.alias,
                      email: contact.email,
                      phone: contact.phone)
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
