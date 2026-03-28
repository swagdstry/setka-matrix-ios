//
// Copyright 2025 Element Creations Ltd.
// Copyright 2025 New Vector Ltd.
//
// SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial.
// Please see LICENSE files in the repository root for full details.
//

import Foundation
import SwiftUI

struct ManagedContact: Identifiable, Codable, Equatable, Hashable {
    let roomID: String
    var alias: String
    var userID: String?
    var email: String?
    var phone: String?
    
    var id: String {
        roomID
    }
    
    var subtitle: String {
        userID ?? roomID
    }
    
    var hasExtendedDetails: Bool {
        !(email?.isEmpty ?? true) || !(phone?.isEmpty ?? true)
    }
}

@MainActor
final class ContactsService: ObservableObject {
    static let shared = ContactsService()
    
    @Published private(set) var contacts = [ManagedContact]()
    @Published private(set) var isLoading = false
    
    private weak var clientProxy: ClientProxyProtocol?
    private var configuredUserID: String?
    private var refreshTask: Task<Void, Never>?
    private var syncTask: Task<Void, Never>?
    private var isSyncInProgress = false
    private var isSyncRequested = false
    private var pendingUpserts = [String: ManagedContact]()
    private var pendingDeletes = Set<String>()
    private let cacheStore = ContactsCacheStore()
    
    private init() { }
    
    func configure(clientProxy: ClientProxyProtocol) {
        self.clientProxy = clientProxy
        
        guard configuredUserID != clientProxy.userID else {
            if contacts.isEmpty {
                contacts = sortedContacts(cacheStore.loadContacts(forUserID: clientProxy.userID))
                refresh()
            }
            schedulePendingSync()
            return
        }
        
        if let configuredUserID {
            cacheStore.saveContacts(contacts, forUserID: configuredUserID)
        }
        
        configuredUserID = clientProxy.userID
        pendingUpserts.removeAll()
        pendingDeletes.removeAll()
        contacts = sortedContacts(cacheStore.loadContacts(forUserID: clientProxy.userID))
        refresh()
        schedulePendingSync()
    }
    
    func refresh() {
        refreshTask?.cancel()
        refreshTask = Task { [weak self] in
            await self?.loadContacts()
        }
    }
    
    func filteredContacts(query: String) -> [ManagedContact] {
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedQuery.isEmpty else {
            return sortedContacts(contacts)
        }
        
        return sortedContacts(contacts.filter { contact in
            contact.alias.localizedCaseInsensitiveContains(trimmedQuery) ||
                contact.roomID.localizedCaseInsensitiveContains(trimmedQuery) ||
                (contact.userID?.localizedCaseInsensitiveContains(trimmedQuery) ?? false) ||
                (contact.email?.localizedCaseInsensitiveContains(trimmedQuery) ?? false) ||
                (contact.phone?.localizedCaseInsensitiveContains(trimmedQuery) ?? false)
        })
    }
    
    func contact(forRoomID roomID: String) -> ManagedContact? {
        contacts.first { $0.roomID == roomID }
    }
    
    func alias(forRoomID roomID: String) -> String? {
        guard let alias = contact(forRoomID: roomID)?.alias.nilIfEmpty else {
            return nil
        }
        return alias
    }
    
    func preferredName(forRoomID roomID: String, fallback: String) -> String {
        alias(forRoomID: roomID) ?? fallback
    }
    
    func upsertContact(roomID: String,
                       alias: String,
                       userID: String?,
                       email: String? = nil,
                       phone: String? = nil) async -> Bool {
        guard let clientProxy else {
            return false
        }
        
        let trimmedAlias = alias.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedAlias.isEmpty else {
            return false
        }
        
        let normalizedUserID = userID?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
        let normalizedRoomID = resolveRoomID(for: roomID, userID: normalizedUserID, clientProxy: clientProxy)
        
        var contact = ManagedContact(roomID: normalizedRoomID,
                                     alias: trimmedAlias,
                                     userID: normalizedUserID,
                                     email: email?.nilIfEmpty,
                                     phone: phone?.nilIfEmpty)
        contact = hydratedContact(contact, clientProxy: clientProxy)
        
        switch await clientProxy.saveContact(contact) {
        case .success:
            if normalizedRoomID != roomID {
                _ = await clientProxy.deleteContact(roomID: roomID)
                contacts.removeAll { $0.roomID == roomID }
            }
            
            pendingUpserts[roomID] = nil
            pendingDeletes.remove(roomID)
            pendingUpserts[normalizedRoomID] = nil
            pendingDeletes.remove(normalizedRoomID)
            updateLocalContact(contact)
            refresh()
            return true
        case .failure(let error):
            MXLog.error("Failed saving contact for roomID \(normalizedRoomID): \(error)")
            pendingUpserts[roomID] = nil
            pendingDeletes.remove(roomID)
            pendingUpserts[normalizedRoomID] = contact
            pendingDeletes.remove(normalizedRoomID)
            if normalizedRoomID != roomID {
                contacts.removeAll { $0.roomID == roomID }
            }
            updateLocalContact(contact)
            schedulePendingSync()
            return true
        }
    }
    
    func deleteContact(roomID: String) async -> Bool {
        guard let clientProxy else {
            return false
        }
        
        switch await clientProxy.deleteContact(roomID: roomID) {
        case .success:
            pendingDeletes.remove(roomID)
            pendingUpserts[roomID] = nil
            contacts.removeAll { $0.roomID == roomID }
            persistContactsCache()
            refresh()
            return true
        case .failure(let error):
            MXLog.error("Failed deleting contact for roomID \(roomID): \(error)")
            pendingDeletes.insert(roomID)
            pendingUpserts[roomID] = nil
            contacts.removeAll { $0.roomID == roomID }
            persistContactsCache()
            schedulePendingSync()
            return true
        }
    }
    
    private func loadContacts() async {
        guard let clientProxy else {
            persistContactsCache()
            return
        }
        
        isLoading = true
        defer { isLoading = false }
        
        switch await clientProxy.fetchContacts() {
        case .success(let contacts):
            var hydratedContacts = contacts.map { hydratedContact($0, clientProxy: clientProxy) }
            hydratedContacts.removeAll { pendingDeletes.contains($0.roomID) }
            
            for pendingContact in pendingUpserts.values {
                if let index = hydratedContacts.firstIndex(where: { $0.roomID == pendingContact.roomID }) {
                    hydratedContacts[index] = pendingContact
                } else {
                    hydratedContacts.append(pendingContact)
                }
            }
            
            self.contacts = sortedContacts(hydratedContacts)
            persistContactsCache()
            schedulePendingSync()
        case .failure(let error):
            MXLog.error("Failed loading contacts: \(error)")
            if contacts.isEmpty {
                contacts = sortedContacts(cacheStore.loadContacts(forUserID: clientProxy.userID))
            }
            schedulePendingSync()
        }
    }
    
    private func hydratedContact(_ contact: ManagedContact, clientProxy: ClientProxyProtocol) -> ManagedContact {
        var contact = contact
        
        if contact.alias.isEmpty {
            contact.alias = clientProxy.roomSummaryForIdentifier(contact.roomID)?.name ?? contact.userID ?? contact.roomID
        }
        
        return contact
    }
    
    private func resolveRoomID(for roomID: String, userID: String?, clientProxy: ClientProxyProtocol) -> String {
        let trimmedRoomID = roomID.trimmingCharacters(in: .whitespacesAndNewlines)
        
        if trimmedRoomID.hasPrefix("!") {
            return trimmedRoomID
        }
        
        let fallbackUserID: String?
        if let userID, !userID.isEmpty {
            fallbackUserID = userID
        } else if trimmedRoomID.hasPrefix("@") {
            fallbackUserID = trimmedRoomID
        } else {
            fallbackUserID = nil
        }
        
        guard let fallbackUserID,
              case let .success(.some(resolvedRoomID)) = clientProxy.directRoomForUserID(fallbackUserID) else {
            return trimmedRoomID
        }
        
        return resolvedRoomID
    }
    
    private func updateLocalContact(_ contact: ManagedContact) {
        if let index = contacts.firstIndex(where: { $0.roomID == contact.roomID }) {
            contacts[index] = contact
        } else {
            contacts.append(contact)
        }
        
        contacts = sortedContacts(contacts)
        persistContactsCache()
    }
    
    private func sortedContacts(_ contacts: [ManagedContact]) -> [ManagedContact] {
        contacts.sorted { lhs, rhs in
            lhs.alias.localizedCaseInsensitiveCompare(rhs.alias) == .orderedAscending
        }
    }
    
    private func persistContactsCache() {
        guard let configuredUserID else {
            return
        }
        
        cacheStore.saveContacts(contacts, forUserID: configuredUserID)
    }
    
    private func schedulePendingSync() {
        guard !pendingDeletes.isEmpty || !pendingUpserts.isEmpty else {
            return
        }
        
        if isSyncInProgress {
            isSyncRequested = true
            return
        }
        
        guard syncTask == nil else {
            return
        }
        
        syncTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(3))
            await self?.flushPendingOperations()
        }
    }
    
    private func flushPendingOperations() async {
        syncTask = nil
        
        guard let clientProxy else {
            return
        }
        
        guard !pendingDeletes.isEmpty || !pendingUpserts.isEmpty else {
            return
        }
        
        isSyncInProgress = true
        defer {
            isSyncInProgress = false
            if isSyncRequested {
                isSyncRequested = false
                schedulePendingSync()
            }
        }
        
        var didChangeServerData = false
        
        let pendingDeleteIDs = Array(pendingDeletes)
        for roomID in pendingDeleteIDs {
            switch await clientProxy.deleteContact(roomID: roomID) {
            case .success:
                pendingDeletes.remove(roomID)
                didChangeServerData = true
            case .failure(let error):
                MXLog.error("Failed syncing contact delete for roomID \(roomID): \(error)")
            }
        }
        
        let pendingUpsertItems = Array(pendingUpserts)
        for (roomID, contact) in pendingUpsertItems {
            switch await clientProxy.saveContact(contact) {
            case .success:
                pendingUpserts[roomID] = nil
                didChangeServerData = true
            case .failure(let error):
                MXLog.error("Failed syncing contact upsert for roomID \(roomID): \(error)")
            }
        }
        
        if didChangeServerData {
            await loadContacts()
        } else if !pendingDeletes.isEmpty || !pendingUpserts.isEmpty {
            schedulePendingSync()
        }
    }
}

private struct ContactsCacheStore {
    private let storageKeyPrefix = "io.element.elementx.contacts.cache."
    
    func loadContacts(forUserID userID: String) -> [ManagedContact] {
        guard !userID.isEmpty else {
            return []
        }
        
        let key = storageKey(forUserID: userID)
        guard let data = UserDefaults.standard.data(forKey: key),
              let contacts = try? JSONDecoder().decode([ManagedContact].self, from: data) else {
            return []
        }
        
        return contacts
    }
    
    func saveContacts(_ contacts: [ManagedContact], forUserID userID: String) {
        guard !userID.isEmpty else {
            return
        }
        
        let key = storageKey(forUserID: userID)
        if contacts.isEmpty {
            UserDefaults.standard.removeObject(forKey: key)
            return
        }
        
        guard let data = try? JSONEncoder().encode(contacts) else {
            return
        }
        
        UserDefaults.standard.set(data, forKey: key)
    }
    
    private func storageKey(forUserID userID: String) -> String {
        "\(storageKeyPrefix)\(userID)"
    }
}

private extension String {
    var nilIfEmpty: String? {
        let trimmedValue = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmedValue.isEmpty ? nil : trimmedValue
    }
}
