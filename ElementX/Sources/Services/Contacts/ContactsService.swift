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
    var tags: [String]
    var isFavorite: Bool
    var updatedAt: Date?
    var lastInteractionAt: Date?
    var syncEmailToServer: Bool
    var syncPhoneToServer: Bool
    
    init(roomID: String,
         alias: String,
         userID: String? = nil,
         email: String? = nil,
         phone: String? = nil,
         tags: [String] = [],
         isFavorite: Bool = false,
         updatedAt: Date? = nil,
         lastInteractionAt: Date? = nil,
         syncEmailToServer: Bool = true,
         syncPhoneToServer: Bool = true) {
        self.roomID = roomID
        self.alias = alias
        self.userID = userID
        self.email = email
        self.phone = phone
        self.tags = tags
        self.isFavorite = isFavorite
        self.updatedAt = updatedAt
        self.lastInteractionAt = lastInteractionAt
        self.syncEmailToServer = syncEmailToServer
        self.syncPhoneToServer = syncPhoneToServer
    }
    
    enum CodingKeys: String, CodingKey {
        case roomID
        case alias
        case userID
        case email
        case phone
        case tags
        case isFavorite
        case updatedAt
        case lastInteractionAt
        case syncEmailToServer
        case syncPhoneToServer
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        roomID = try container.decode(String.self, forKey: .roomID)
        alias = try container.decode(String.self, forKey: .alias)
        userID = try container.decodeIfPresent(String.self, forKey: .userID)
        email = try container.decodeIfPresent(String.self, forKey: .email)
        phone = try container.decodeIfPresent(String.self, forKey: .phone)
        tags = try container.decodeIfPresent([String].self, forKey: .tags) ?? []
        isFavorite = try container.decodeIfPresent(Bool.self, forKey: .isFavorite) ?? false
        updatedAt = try container.decodeIfPresent(Date.self, forKey: .updatedAt)
        lastInteractionAt = try container.decodeIfPresent(Date.self, forKey: .lastInteractionAt)
        syncEmailToServer = try container.decodeIfPresent(Bool.self, forKey: .syncEmailToServer) ?? true
        syncPhoneToServer = try container.decodeIfPresent(Bool.self, forKey: .syncPhoneToServer) ?? true
    }
    
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
        
        let tokens = trimmedQuery
            .split(whereSeparator: \.isWhitespace)
            .map { String($0).lowercased() }
        
        return sortedContacts(contacts.filter { contact in
            let indexedValues = [
                contact.alias,
                contact.roomID,
                contact.userID ?? "",
                contact.email ?? "",
                contact.phone ?? "",
                contact.tags.joined(separator: " ")
            ].map { $0.lowercased() }
            
            return tokens.allSatisfy { token in
                indexedValues.contains { $0.contains(token) }
            }
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
                       phone: String? = nil,
                       tags: [String] = [],
                       isFavorite: Bool = false,
                       syncEmailToServer: Bool = true,
                       syncPhoneToServer: Bool = true) async -> Bool {
        guard let clientProxy else {
            return false
        }
        
        let trimmedAlias = alias.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedAlias.isEmpty else {
            return false
        }
        
        let normalizedUserID = userID?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
        let normalizedEmail = normalizedEmail(email)
        let normalizedPhone = normalizedPhone(phone)
        let normalizedTags = normalizedTags(tags)
        
        if let rawEmail = email?.nilIfEmpty,
           normalizedEmail == nil,
           !rawEmail.isEmpty {
            return false
        }
        
        if let rawPhone = phone?.nilIfEmpty,
           normalizedPhone == nil,
           !rawPhone.isEmpty {
            return false
        }
        
        let normalizedRoomID = resolveRoomID(for: roomID, userID: normalizedUserID, clientProxy: clientProxy)
        
        var contact = ManagedContact(roomID: normalizedRoomID,
                                     alias: trimmedAlias,
                                     userID: normalizedUserID,
                                     email: normalizedEmail,
                                     phone: normalizedPhone,
                                     tags: normalizedTags,
                                     isFavorite: isFavorite,
                                     updatedAt: .now,
                                     lastInteractionAt: contact(forRoomID: normalizedRoomID)?.lastInteractionAt,
                                     syncEmailToServer: syncEmailToServer,
                                     syncPhoneToServer: syncPhoneToServer)
        contact = hydratedContact(contact, clientProxy: clientProxy)
        let duplicateRoomIDs = duplicateRoomIDs(for: contact, excluding: Set([roomID, normalizedRoomID]))
        
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
            for duplicateRoomID in duplicateRoomIDs {
                _ = await clientProxy.deleteContact(roomID: duplicateRoomID)
                pendingDeletes.remove(duplicateRoomID)
                pendingUpserts[duplicateRoomID] = nil
                contacts.removeAll { $0.roomID == duplicateRoomID }
            }
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
            for duplicateRoomID in duplicateRoomIDs {
                pendingDeletes.insert(duplicateRoomID)
                pendingUpserts[duplicateRoomID] = nil
                contacts.removeAll { $0.roomID == duplicateRoomID }
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
            let localContactsByRoomID = Dictionary(uniqueKeysWithValues: self.contacts.map { ($0.roomID, $0) })
            var hydratedContacts = contacts.map { remoteContact in
                let hydrated = hydratedContact(remoteContact, clientProxy: clientProxy)
                return mergeLocalMetadata(remoteContact: hydrated, localContact: localContactsByRoomID[remoteContact.roomID])
            }
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
            if lhs.isFavorite != rhs.isFavorite {
                return lhs.isFavorite
            }
            
            if lhs.alias.localizedCaseInsensitiveCompare(rhs.alias) == .orderedSame {
                return (lhs.updatedAt ?? .distantPast) > (rhs.updatedAt ?? .distantPast)
            }
            
            return lhs.alias.localizedCaseInsensitiveCompare(rhs.alias) == .orderedAscending
        }
    }
    
    private func duplicateRoomIDs(for contact: ManagedContact, excluding excludedRoomIDs: Set<String>) -> [String] {
        contacts.compactMap { existing in
            guard !excludedRoomIDs.contains(existing.roomID) else {
                return nil
            }
            
            let hasSameUserID = contact.userID != nil && existing.userID == contact.userID
            let hasSameEmail = contact.email != nil && existing.email?.caseInsensitiveCompare(contact.email ?? "") == .orderedSame
            let hasSamePhone = contact.phone != nil && existing.phone == contact.phone
            
            return (hasSameUserID || hasSameEmail || hasSamePhone) ? existing.roomID : nil
        }
    }
    
    private func mergeLocalMetadata(remoteContact: ManagedContact, localContact: ManagedContact?) -> ManagedContact {
        guard let localContact else {
            return remoteContact
        }
        
        var merged = remoteContact
        merged.tags = localContact.tags
        merged.isFavorite = localContact.isFavorite
        let localUpdatedAt = localContact.updatedAt ?? .distantPast
        let remoteUpdatedAt = remoteContact.updatedAt ?? .distantPast
        let mergedUpdatedAt = max(localUpdatedAt, remoteUpdatedAt)
        merged.updatedAt = mergedUpdatedAt == .distantPast ? nil : mergedUpdatedAt
        merged.lastInteractionAt = localContact.lastInteractionAt ?? remoteContact.lastInteractionAt
        merged.syncEmailToServer = localContact.syncEmailToServer
        merged.syncPhoneToServer = localContact.syncPhoneToServer
        
        if !localContact.syncEmailToServer {
            merged.email = localContact.email
        }
        
        if !localContact.syncPhoneToServer {
            merged.phone = localContact.phone
        }
        
        return merged
    }
    
    private func normalizedEmail(_ value: String?) -> String? {
        guard let value = value?.nilIfEmpty else {
            return nil
        }
        
        let normalized = value.lowercased()
        let parts = normalized.split(separator: "@", omittingEmptySubsequences: false)
        guard parts.count == 2,
              !parts[0].isEmpty,
              !parts[1].isEmpty,
              parts[1].contains(".") else {
            return nil
        }
        
        return normalized
    }
    
    private func normalizedPhone(_ value: String?) -> String? {
        guard let value = value?.nilIfEmpty else {
            return nil
        }
        
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        var digits = trimmed.filter(\.isNumber)
        if trimmed.hasPrefix("+") {
            digits = "+\(digits)"
        } else if trimmed.hasPrefix("00"), digits.count > 2 {
            digits = "+\(digits.dropFirst(2))"
        }
        
        let digitCount = digits.filter(\.isNumber).count
        guard digitCount >= 7 else {
            return nil
        }
        
        return digits
    }
    
    private func normalizedTags(_ tags: [String]) -> [String] {
        let normalizedValues = tags
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
            .filter { !$0.isEmpty }
        return Array(Set(normalizedValues)).sorted()
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
