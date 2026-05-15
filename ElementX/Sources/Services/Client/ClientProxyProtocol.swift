//
// Copyright 2025 Element Creations Ltd.
// Copyright 2022-2025 New Vector Ltd.
//
// SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial.
// Please see LICENSE files in the repository root for full details.
//

import Combine
import Foundation
import MatrixRustSDK

enum ClientProxyAction {
    case receivedSyncUpdate
    case receivedAuthError(isSoftLogout: Bool)
    case receivedDecryptionError(UnableToDecryptInfo)
    
    var isSyncUpdate: Bool {
        if case .receivedSyncUpdate = self {
            return true
        } else {
            return false
        }
    }
}

enum ClientProxyLoadingState {
    case loading
    case notLoading
}

enum ClientProxyError: Error {
    case sdkError(Error)
    case forbiddenAccess
    
    case invalidMedia
    case invalidServerName
    case invalidResponse
    case failedUploadingMedia(ErrorKind)
    case roomPreviewIsPrivate
    case failedRetrievingUserIdentity
    case failedResolvingRoomAlias
    case roomNotInLocalStore
    case invalidInvite
}

struct RoomWallpaperMetadata: Codable, Equatable {
    let type: String?
    let theme: String?
    let image: String?
    let data: String?
    let contentType: String?
    
    enum CodingKeys: String, CodingKey {
        case type
        case theme
        case image
        case data
        case contentType = "content_type"
    }
}

struct SetkaPlusSubscription: Codable, Equatable {
    let tier: String?
    let status: String?
    let startedAt: Int?
    let expiresAt: Int?
    let updatedAt: Int?
    let isActive: Bool?
    let priceRub: Double?
    let durationDays: Int?
    let planName: String?
    let lastPaymentID: String?
    let paymentProvider: String?
    let amount: Double?
    let currency: String?
    
    enum CodingKeys: String, CodingKey {
        case tier
        case status
        case startedAt = "started_at"
        case expiresAt = "expires_at"
        case updatedAt = "updated_at"
        case isActive = "is_active"
        case priceRub = "price_rub"
        case durationDays = "duration_days"
        case planName = "plan_name"
        case lastPaymentID = "last_payment_id"
        case paymentProvider = "payment_provider"
        case amount
        case currency
    }
}

struct SetkaPlusPlan: Codable, Equatable {
    let id: String
    let name: String
    let priceRub: Double
    let durationDays: Int
    let features: [String]
    let isActive: Bool
    let isDefault: Bool
    let sortOrder: Int?
    
    enum CodingKeys: String, CodingKey {
        case id
        case name
        case priceRub = "price_rub"
        case durationDays = "duration_days"
        case features
        case active
        case isDefault = "is_default"
        case sortOrder = "sort_order"
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        priceRub = try container.decode(Double.self, forKey: .priceRub)
        durationDays = try container.decode(Int.self, forKey: .durationDays)
        features = try container.decodeIfPresent([String].self, forKey: .features) ?? []
        isActive = try container.decodeIfPresent(Bool.self, forKey: .active) ?? true
        isDefault = try container.decodeIfPresent(Bool.self, forKey: .isDefault) ?? false
        sortOrder = try container.decodeIfPresent(Int.self, forKey: .sortOrder)
    }
    
    init(id: String,
         name: String,
         priceRub: Double,
         durationDays: Int,
         features: [String],
         isActive: Bool,
         isDefault: Bool,
         sortOrder: Int?) {
        self.id = id
        self.name = name
        self.priceRub = priceRub
        self.durationDays = durationDays
        self.features = features
        self.isActive = isActive
        self.isDefault = isDefault
        self.sortOrder = sortOrder
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(priceRub, forKey: .priceRub)
        try container.encode(durationDays, forKey: .durationDays)
        try container.encode(features, forKey: .features)
        try container.encode(isActive, forKey: .active)
        try container.encode(isDefault, forKey: .isDefault)
        try container.encodeIfPresent(sortOrder, forKey: .sortOrder)
    }
}

struct SetkaPlusPayment: Codable, Equatable {
    let paymentID: String
    let status: String
    let provider: String
    let createdAt: Int?
    let amount: Double?
    let currency: String?
    let requestID: String?
    let label: String?
    let planID: String?
    
    enum CodingKeys: String, CodingKey {
        case paymentID = "payment_id"
        case status
        case provider
        case createdAt = "created_at"
        case amount
        case currency
        case requestID = "request_id"
        case label
        case planID = "plan_id"
    }
}

struct SetkaPlusPaymentRequest: Codable, Equatable {
    let paymentID: String?
    let requestID: String?
    let provider: String?
    let status: String?
    let amount: Double?
    let currency: String?
    let label: String?
    let planID: String?
    let planName: String?
    let checkoutURL: String?
    let returnURL: String?
    
    enum CodingKeys: String, CodingKey {
        case paymentID = "payment_id"
        case requestID = "request_id"
        case provider
        case status
        case amount
        case currency
        case label
        case planID = "plan_id"
        case planName = "plan_name"
        case checkoutURL = "checkout_url"
        case returnURL = "return_url"
    }
}

struct SetkaPlusPaymentProcessResult: Codable, Equatable {
    let status: String?
    let paymentID: String?
    let requestID: String?
    let subscription: SetkaPlusSubscription?
    
    enum CodingKeys: String, CodingKey {
        case status
        case paymentID = "payment_id"
        case requestID = "request_id"
        case subscription
    }
}

struct SetkaPlusStickerItem: Codable, Equatable, Identifiable {
    let id: String
    let name: String
    let mxcURL: String
    let mimeType: String?
    let width: Int?
    let height: Int?
    let size: Int?

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case mxcURL = "mxc_url"
        case mimeType = "mime_type"
        case width
        case height
        case size
    }
}

struct SetkaPlusStickerPack: Codable, Equatable, Identifiable {
    let id: String
    let name: String
    let kind: String
    let stickers: [SetkaPlusStickerItem]
    let createdAt: Int?
    let updatedAt: Int?

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case kind
        case stickers
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

struct SetkaPlusStatusEmoji: Codable, Equatable {
    let emoji: String?
    let packID: String?
    let stickerID: String?
    let updatedAt: Int?

    enum CodingKeys: String, CodingKey {
        case emoji
        case packID = "pack_id"
        case stickerID = "sticker_id"
        case updatedAt = "updated_at"
        case statusEmoji = "status_emoji"
        case setkaPlusStatusEmoji = "setka_plus_status_emoji"
        case value
        case data
        case status
    }
    
    init(emoji: String?, packID: String?, stickerID: String?, updatedAt: Int?) {
        self.emoji = emoji
        self.packID = packID
        self.stickerID = stickerID
        self.updatedAt = updatedAt
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        if let status = Self.decode(from: container) {
            self = status
            return
        }
        
        for nestedKey in [CodingKeys.statusEmoji, .setkaPlusStatusEmoji, .value, .data, .status] {
            if let nestedContainer = try? container.nestedContainer(keyedBy: CodingKeys.self, forKey: nestedKey),
               let status = Self.decode(from: nestedContainer) {
                self = status
                return
            }
        }
        
        self = .init(emoji: nil, packID: nil, stickerID: nil, updatedAt: nil)
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(emoji, forKey: .emoji)
        try container.encodeIfPresent(packID, forKey: .packID)
        try container.encodeIfPresent(stickerID, forKey: .stickerID)
        try container.encodeIfPresent(updatedAt, forKey: .updatedAt)
    }
    
    private static func decode(from container: KeyedDecodingContainer<CodingKeys>) -> SetkaPlusStatusEmoji? {
        let emoji = try? container.decodeIfPresent(String.self, forKey: .emoji)
        let packID = try? container.decodeIfPresent(String.self, forKey: .packID)
        let stickerID = try? container.decodeIfPresent(String.self, forKey: .stickerID)
        let updatedAt = try? container.decodeIfPresent(Int.self, forKey: .updatedAt)
        
        if emoji != nil || packID != nil || stickerID != nil || updatedAt != nil {
            return .init(emoji: emoji.flatMap { $0 },
                         packID: packID.flatMap { $0 },
                         stickerID: stickerID.flatMap { $0 },
                         updatedAt: updatedAt.flatMap { $0 })
        }
        
        return nil
    }
}

struct SetkaPlusUserProfileDetails: Codable, Equatable {
    let bio: String?
    let backgroundURL: String?
    let lastSeenText: String?
    let shareURL: String?

    enum CodingKeys: String, CodingKey {
        case bio
        case backgroundURL = "background_url"
        case lastSeenText = "last_seen_text"
        case shareURL = "share_url"
    }
}

enum SlidingSyncConstants {
    static let maximumVisibleRangeSize = 30
}

enum CreateRoomAccessType: Equatable {
    case `public`
    case spaceMembers(spaceID: String)
    case askToJoinWithSpaceMembers(spaceID: String)
    case askToJoin
    case `private`
    
    var isVisibilityPrivate: Bool {
        switch self {
        case .private, .spaceMembers, .askToJoinWithSpaceMembers:
            true
        case .public, .askToJoin:
            false
        }
    }
}

/// This struct represents the configuration that we are using to register the application through Pusher to Sygnal
/// using the Matrix Rust SDK, more info here:
/// https://github.com/matrix-org/sygnal
struct PusherConfiguration {
    let identifiers: PusherIdentifiers
    let kind: PusherKind
    let appDisplayName: String
    let deviceDisplayName: String
    let profileTag: String?
    let lang: String
}

enum SessionVerificationState {
    case unknown
    case verified
    case unverified
}

/// The `Decodable` conformance is just for the purpose of migration
enum TimelineMediaVisibility: Decodable {
    case always
    case privateOnly
    case never
}

// sourcery: AutoMockable
protocol ClientProxyProtocol: AnyObject {
    var actionsPublisher: AnyPublisher<ClientProxyAction, Never> { get }
    
    var loadingStatePublisher: CurrentValuePublisher<ClientProxyLoadingState, Never> { get }
    
    var verificationStatePublisher: CurrentValuePublisher<SessionVerificationState, Never> { get }
    
    var homeserverReachabilityPublisher: CurrentValuePublisher<NetworkMonitorReachability, Never> { get }
    
    var userID: String { get }

    var deviceID: String? { get }

    var homeserver: String { get }
    
    var canDeactivateAccount: Bool { get }
    
    var userIDServerName: String? { get }
    
    var userDisplayNamePublisher: CurrentValuePublisher<String?, Never> { get }

    var userAvatarURLPublisher: CurrentValuePublisher<URL?, Never> { get }

    /// We delay fetching this until after the first sync. Nil until then
    var ignoredUsersPublisher: CurrentValuePublisher<[String]?, Never> { get }
    
    var timelineMediaVisibilityPublisher: CurrentValuePublisher<TimelineMediaVisibility, Never> { get }
    
    var hideInviteAvatarsPublisher: CurrentValuePublisher<Bool, Never> { get }
    
    var pusherNotificationClientIdentifier: String? { get }
    
    var mediaLoader: MediaLoaderProtocol { get }
    
    var roomSummaryProvider: RoomSummaryProviderProtocol { get }
    
    /// Used for listing rooms that shouldn't be affected by the main `roomSummaryProvider` filtering
    /// But can still be filtered by queries, since this may be shared across multiple views, remember to reset
    /// The filtering state when you are done with it
    var alternateRoomSummaryProvider: RoomSummaryProviderProtocol { get }
    
    /// Used for listing rooms, can't be filtered nor its state observed
    var staticRoomSummaryProvider: StaticRoomSummaryProviderProtocol { get }
    
    var roomsToAwait: Set<String> { get set }
    
    var notificationSettings: NotificationSettingsProxyProtocol { get }
    
    var secureBackupController: SecureBackupControllerProtocol { get }
    
    var sessionVerificationController: SessionVerificationControllerProxyProtocol? { get }
    
    var spaceService: SpaceServiceProxyProtocol { get }
    
    var isReportRoomSupported: Bool { get async }
    
    var isLiveKitRTCSupported: Bool { get async }
    
    var isLoginWithQRCodeSupported: Bool { get async }
    
    var maxMediaUploadSize: Result<UInt, ClientProxyError> { get async }
    
    func isOnlyDeviceLeft() async -> Result<Bool, ClientProxyError>
    
    func hasDevicesToVerifyAgainst() async -> Result<Bool, ClientProxyError>
    
    func startSync()

    func stopSync()
    
    func stopSync(completion: (() -> Void)?) // Hopefully this will become async once we get SE-0371.
    
    func expireSyncSessions() async
        
    func accountURL(action: AccountManagementAction) async -> URL?
    
    func directRoomForUserID(_ userID: String) -> Result<String?, ClientProxyError>
    
    func createDirectRoom(with userID: String, expectedRoomName: String?) async -> Result<String, ClientProxyError>
    
    func createRoom(name: String,
                    topic: String?,
                    accessType: CreateRoomAccessType,
                    isSpace: Bool,
                    userIDs: [String],
                    avatarURL: URL?,
                    aliasLocalPart: String?) async -> Result<String, ClientProxyError>
    
    func joinRoom(_ roomID: String, via: [String]) async -> Result<Void, ClientProxyError>
    
    func joinRoomAlias(_ roomAlias: String) async -> Result<Void, ClientProxyError>
    
    func knockRoom(_ roomID: String, via: [String], message: String?) async -> Result<Void, ClientProxyError>
    
    func knockRoomAlias(_ roomAlias: String, message: String?) async -> Result<Void, ClientProxyError>
    
    func canJoinRoom(with rules: [AllowRule]) -> Bool
    
    func uploadMedia(_ media: MediaInfo) async -> Result<String, ClientProxyError>
    
    func roomForIdentifier(_ identifier: String) async -> RoomProxyType?
    
    func roomPreviewForIdentifier(_ identifier: String, via: [String]) async -> Result<RoomPreviewProxyProtocol, ClientProxyError>
    
    func roomSummaryForIdentifier(_ identifier: String) -> RoomSummary?
    
    func roomSummaryForAlias(_ alias: String) -> RoomSummary?
    
    /// Will only work for rooms that are in our room list/local store
    func reportRoomForIdentifier(_ identifier: String, reason: String) async -> Result<Void, ClientProxyError>
    
    @discardableResult func loadUserDisplayName() async -> Result<Void, ClientProxyError>
    
    func setUserDisplayName(_ name: String) async -> Result<Void, ClientProxyError>

    @discardableResult func loadUserAvatarURL() async -> Result<Void, ClientProxyError>
    
    func setUserAvatar(media: MediaInfo) async -> Result<Void, ClientProxyError>
    
    func removeUserAvatar() async -> Result<Void, ClientProxyError>
    
    func linkNewDeviceService() -> LinkNewDeviceServiceProtocol
    
    func deactivateAccount(password: String?, eraseData: Bool) async -> Result<Void, ClientProxyError>
    
    func logout() async

    func setPusher(with configuration: PusherConfiguration) async throws
    
    func searchUsers(searchTerm: String, limit: UInt) async -> Result<SearchUsersResultsProxy, ClientProxyError>
    
    func profile(for userID: String) async -> Result<UserProfileProxy, ClientProxyError>
    
    // MARK: - Contacts
    
    func fetchContacts() async -> Result<[ManagedContact], ClientProxyError>
    func saveContact(_ contact: ManagedContact) async -> Result<Void, ClientProxyError>
    func deleteContact(roomID: String) async -> Result<Void, ClientProxyError>
    
    // MARK: - Room wallpaper
    
    func fetchRoomWallpaper(roomID: String) async -> Result<RoomWallpaperMetadata?, ClientProxyError>
    func saveRoomWallpaper(roomID: String, metadata: RoomWallpaperMetadata) async -> Result<Void, ClientProxyError>
    func deleteRoomWallpaper(roomID: String) async -> Result<Void, ClientProxyError>
    
    // MARK: - Setka Plus
    
    func fetchSetkaPlusSubscription() async -> Result<SetkaPlusSubscription, ClientProxyError>
    func fetchSetkaPlusPlans() async -> Result<[SetkaPlusPlan], ClientProxyError>
    func fetchSetkaPlusStickerPacks() async -> Result<[SetkaPlusStickerPack], ClientProxyError>
    func addSetkaPlusStickerPack(packID: String) async -> Result<Void, ClientProxyError>
    func fetchSetkaPlusPayments() async -> Result<[SetkaPlusPayment], ClientProxyError>
    func fetchSetkaPlusStatusEmoji(userID: String?) async -> Result<SetkaPlusStatusEmoji, ClientProxyError>
    func fetchSetkaPlusUserProfileDetails(userID: String) async -> Result<SetkaPlusUserProfileDetails, ClientProxyError>
    func updateSetkaPlusStatusEmoji(emoji: String?, packID: String?, stickerID: String?) async -> Result<SetkaPlusStatusEmoji, ClientProxyError>
    func createSetkaPlusYooMoneyPayment(amount: Double?, description: String?, planID: String?) async -> Result<SetkaPlusPaymentRequest, ClientProxyError>
    func processSetkaPlusYooMoneyPayment(requestID: String, moneySource: String, planID: String?) async -> Result<SetkaPlusPaymentProcessResult, ClientProxyError>
    
    func roomDirectorySearchProxy() -> RoomDirectorySearchProxyProtocol
    
    func resolveRoomAlias(_ alias: String) async -> Result<ResolvedRoomAlias, ClientProxyError>
    
    func isAliasAvailable(_ alias: String) async -> Result<Bool, ClientProxyError>
    
    @discardableResult func clearCaches() async -> Result<Void, ClientProxyError>
    
    @discardableResult func optimizeStores() async -> Result<Void, ClientProxyError>
    
    func storeSizes() async -> Result<StoreSizes, ClientProxyError>
    
    func fetchMediaPreviewConfiguration() async -> Result<MediaPreviewConfig?, ClientProxyError>

    // MARK: - Ignored users
    
    func ignoreUser(_ userID: String) async -> Result<Void, ClientProxyError>
    
    func unignoreUser(_ userID: String) async -> Result<Void, ClientProxyError>
    
    // MARK: - Recently visited rooms
    
    func trackRecentlyVisitedRoom(_ roomID: String) async -> Result<Void, ClientProxyError>
    
    func recentlyVisitedRooms(filter: (JoinedRoomProxyProtocol) -> Bool) async -> [JoinedRoomProxyProtocol]
    func recentConversationCounterparts() async -> [UserProfileProxy]
    
    // MARK: - Crypto
    
    func ed25519Base64() async -> String?
    func curve25519Base64() async -> String?
    
    func pinUserIdentity(_ userID: String) async -> Result<Void, ClientProxyError>
    func withdrawUserIdentityVerification(_ userID: String) async -> Result<Void, ClientProxyError>
    func resetIdentity() async -> Result<IdentityResetHandle?, ClientProxyError>
    
    func userIdentity(for userID: String, fallBackToServer: Bool) async -> Result<UserIdentityProxyProtocol?, ClientProxyError>
    
    // MARK: - Moderation & Safety
    
    func setTimelineMediaVisibility(_ value: TimelineMediaVisibility) async -> Result<Void, ClientProxyError>
    func setHideInviteAvatars(_ value: Bool) async -> Result<Void, ClientProxyError>
}

extension ClientProxyProtocol {
    func fetchSetkaPlusUserProfileDetails(userID: String) async -> Result<SetkaPlusUserProfileDetails, ClientProxyError> {
        .success(.init(bio: nil, backgroundURL: nil, lastSeenText: nil, shareURL: nil))
    }

    func addSetkaPlusStickerPack(packID: String) async -> Result<Void, ClientProxyError> {
        .failure(.invalidResponse)
    }
}
