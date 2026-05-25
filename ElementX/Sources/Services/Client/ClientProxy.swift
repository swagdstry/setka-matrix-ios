//
// Copyright 2025 Element Creations Ltd.
// Copyright 2022-2025 New Vector Ltd.
//
// SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial.
// Please see LICENSE files in the repository root for full details.
//

@preconcurrency import Combine
import CryptoKit
import Foundation
import MatrixRustSDK
import OrderedCollections

// swiftlint:disable file_length
// swiftlint:disable:next type_body_length
class ClientProxy: ClientProxyProtocol {
    private let client: ClientProtocol
    private let networkMonitor: NetworkMonitorProtocol
    private let appSettings: AppSettings
    private let analyticsService: AnalyticsService
    
    let mediaLoader: MediaLoaderProtocol
    private let clientQueue: DispatchQueue
    
    private var roomListService: RoomListService
    // periphery: ignore - only for retain
    private var roomListStateUpdateTaskHandle: TaskHandle?
    // periphery: ignore - only for retain
    private var roomListStateLoadingStateUpdateTaskHandle: TaskHandle?

    private var syncService: SyncService
    // periphery: ignore - only for retain
    private var syncServiceStateUpdateTaskHandle: TaskHandle?
    
    // periphery:ignore - required for instance retention in the rust codebase
    private var ignoredUsersListenerTaskHandle: TaskHandle?
    
    // periphery:ignore - required for instance retention in the rust codebase
    private var verificationStateListenerTaskHandle: TaskHandle?
    
    // periphery:ignore - required for instance retention in the rust codebase
    private var sendQueueStatusListenerTaskHandle: TaskHandle?
    
    // periphery:ignore - required for instance retention in the rust codebase
    private var sendQueueUpdatesListenerTaskHandle: TaskHandle?
    
    // periphery:ignore - required for instance retention in the rust codebase
    private var mediaPreviewConfigListenerTaskHandle: TaskHandle?
    
    private var delegateHandle: TaskHandle?
    
    // These following summary providers both operate on the same allRooms() list but
    // can apply their own filtering and pagination
    private(set) var roomSummaryProvider: RoomSummaryProviderProtocol
    private(set) var alternateRoomSummaryProvider: RoomSummaryProviderProtocol
    
    private(set) var staticRoomSummaryProvider: StaticRoomSummaryProviderProtocol
    
    let notificationSettings: NotificationSettingsProxyProtocol

    let secureBackupController: SecureBackupControllerProtocol
    
    private(set) var sessionVerificationController: SessionVerificationControllerProxyProtocol?
    
    let spaceService: SpaceServiceProxyProtocol
    
    private static var roomCreationPowerLevelOverrides: PowerLevels {
        .init(usersDefault: nil,
              eventsDefault: nil,
              stateDefault: nil,
              ban: nil,
              kick: nil,
              redact: nil,
              invite: Int32(0),
              notifications: nil,
              users: [:],
              events: [
                  "m.call.member": Int32(0),
                  "org.matrix.msc3401.call.member": Int32(0)
              ])
    }
    
    private static var knockingRoomCreationPowerLevelOverrides: PowerLevels {
        .init(usersDefault: nil,
              eventsDefault: nil,
              stateDefault: nil,
              ban: nil,
              kick: nil,
              redact: nil,
              invite: Int32(50),
              notifications: nil,
              users: [:],
              events: [
                  "m.call.member": Int32(0),
                  "org.matrix.msc3401.call.member": Int32(0)
              ])
    }
    
    private static var standardSpaceCreationPowerLevelOverrides: PowerLevels {
        .init(usersDefault: nil,
              eventsDefault: Int32(100),
              stateDefault: nil,
              ban: nil,
              kick: nil,
              redact: nil,
              invite: Int32(50),
              notifications: nil,
              users: [:],
              events: [:])
    }
    
    private static var publicSpaceCreationPowerLevelOverrides: PowerLevels {
        .init(usersDefault: nil,
              eventsDefault: Int32(100),
              stateDefault: nil,
              ban: nil,
              kick: nil,
              redact: nil,
              invite: Int32(0),
              notifications: nil,
              users: [:],
              events: [:])
    }

    private var loadCachedAvatarURLTask: Task<Void, Never>?
    private let userAvatarURLSubject = CurrentValueSubject<URL?, Never>(nil)
    var userAvatarURLPublisher: CurrentValuePublisher<URL?, Never> {
        userAvatarURLSubject.asCurrentValuePublisher()
    }
    
    private let userDisplayNameSubject = CurrentValueSubject<String?, Never>(nil)
    var userDisplayNamePublisher: CurrentValuePublisher<String?, Never> {
        userDisplayNameSubject.asCurrentValuePublisher()
    }
    
    private let ignoredUsersSubject = CurrentValueSubject<[String]?, Never>(nil)
    var ignoredUsersPublisher: CurrentValuePublisher<[String]?, Never> {
        ignoredUsersSubject
            .asCurrentValuePublisher()
    }
    
    private var cancellables = Set<AnyCancellable>()
    
    /// Will be `true` whilst the app cleans up and forces a logout. Prevents the sync service from restarting
    /// before the client is released which ends up running in a loop. This is a workaround until the sync service
    /// can tell us *what* error occurred so we can handle restarts more gracefully.
    private var hasEncounteredAuthError = false
    
    deinit {
        stopSync { [delegateHandle] in
            // The delegate handle needs to be cancelled always after the sync stops
            delegateHandle?.cancel()
        }
    }
    
    private let actionsSubject = PassthroughSubject<ClientProxyAction, Never>()
    var actionsPublisher: AnyPublisher<ClientProxyAction, Never> {
        actionsSubject.eraseToAnyPublisher()
    }
    
    private let loadingStateSubject = CurrentValueSubject<ClientProxyLoadingState, Never>(.notLoading)
    var loadingStatePublisher: CurrentValuePublisher<ClientProxyLoadingState, Never> {
        loadingStateSubject.asCurrentValuePublisher()
    }
    
    private let verificationStateSubject = CurrentValueSubject<SessionVerificationState, Never>(.unknown)
    var verificationStatePublisher: CurrentValuePublisher<SessionVerificationState, Never> {
        verificationStateSubject.asCurrentValuePublisher()
    }
    
    private let homeserverReachabilitySubject = CurrentValueSubject<NetworkMonitorReachability, Never>(.reachable)
    var homeserverReachabilityPublisher: CurrentValuePublisher<NetworkMonitorReachability, Never> {
        homeserverReachabilitySubject.asCurrentValuePublisher()
    }
    
    private let timelineMediaVisibilitySubject = CurrentValueSubject<TimelineMediaVisibility, Never>(.always)
    var timelineMediaVisibilityPublisher: CurrentValuePublisher<TimelineMediaVisibility, Never> {
        timelineMediaVisibilitySubject.asCurrentValuePublisher()
    }
    
    private let hideInviteAvatarsSubject = CurrentValueSubject<Bool, Never>(false)
    var hideInviteAvatarsPublisher: CurrentValuePublisher<Bool, Never> {
        hideInviteAvatarsSubject.asCurrentValuePublisher()
    }
    
    var roomsToAwait: Set<String> = []
    
    private let sendQueueStatusSubject = CurrentValueSubject<Bool, Never>(false)
    
    init(client: ClientProtocol,
         networkMonitor: NetworkMonitorProtocol,
         appSettings: AppSettings,
         analyticsService: AnalyticsService) async throws {
        self.client = client
        self.networkMonitor = networkMonitor
        self.appSettings = appSettings
        self.analyticsService = analyticsService
        
        clientQueue = .init(label: "ClientProxyQueue", attributes: .concurrent)
        
        mediaLoader = MediaLoader(client: client)
        
        notificationSettings = await NotificationSettingsProxy(notificationSettings: client.getNotificationSettings())
        
        secureBackupController = SecureBackupController(encryption: client.encryption())
        
        spaceService = await SpaceServiceProxy(spaceService: client.spaceService())
        
        let configuredAppService = try await ClientProxyServices(client: client,
                                                                 actionsSubject: actionsSubject,
                                                                 notificationSettings: notificationSettings,
                                                                 appSettings: appSettings)
        
        syncService = configuredAppService.syncService
        roomListService = configuredAppService.roomListService
        roomSummaryProvider = configuredAppService.roomSummaryProvider
        alternateRoomSummaryProvider = configuredAppService.alternateRoomSummaryProvider
        staticRoomSummaryProvider = configuredAppService.staticRoomSummaryProvider
        
        syncServiceStateUpdateTaskHandle = createSyncServiceStateObserver(syncService)
        roomListStateUpdateTaskHandle = createRoomListServiceObserver(roomListService)
        roomListStateLoadingStateUpdateTaskHandle = createRoomListLoadingStateUpdateObserver(roomListService)
                
        delegateHandle = try client.setDelegate(delegate: ClientDelegateWrapper { [weak self] isSoftLogout in
            self?.hasEncounteredAuthError = true
            self?.actionsSubject.send(.receivedAuthError(isSoftLogout: isSoftLogout))
        } backgroundTaskErrorCallback: { error in
            switch error {
            case .panic(let message, let backtrace):
                MXLog.error("Received background task panic: \(message ?? "Missing message")\nBacktrace:\n\(backtrace ?? "Missing backtrace")")
                
                if AppSettings.appBuildType == .debug || AppSettings.appBuildType == .nightly {
                    fatalError(message ?? "")
                }
            case .error(let error):
                MXLog.error("Received background task error: \(error)")
            case .earlyTermination:
                MXLog.error("Received background task early termination")
            }
        })
        
        try await client.setUtdDelegate(utdDelegate: ClientDecryptionErrorDelegate(actionsSubject: actionsSubject))
        
        networkMonitor.reachabilityPublisher
            .removeDuplicates()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] reachability in
                if reachability == .reachable {
                    self?.startSync()
                }
            }
            .store(in: &cancellables)

        loadUserAvatarURLFromCache()
        
        ignoredUsersListenerTaskHandle = client.subscribeToIgnoredUsers(listener: SDKListener { [weak self] ignoredUsers in
            self?.ignoredUsersSubject.send(ignoredUsers)
        })
        
        await updateVerificationState(client.encryption().verificationState())
        
        verificationStateListenerTaskHandle = client.encryption().verificationStateListener(listener: SDKListener { [weak self] verificationState in
            Task { await self?.updateVerificationState(verificationState) }
        })
        
        sendQueueStatusListenerTaskHandle = client.subscribeToSendQueueStatus(listener: SDKListener { [weak self] roomID, error in
            MXLog.error("Send queue failed in room: \(roomID) with error: \(error)")
            self?.sendQueueStatusSubject.send(false)
        })
        
        sendQueueUpdatesListenerTaskHandle = try? await client.subscribeToSendQueueUpdates(listener: SDKListener { _, update in
            switch update {
            case .newLocalEvent(let transactionID):
                analyticsService.signpost.startTransaction(.sendMessage(uuid: transactionID))
            case .sentEvent(let transactionID, _):
                analyticsService.signpost.finishTransaction(.sendMessage(uuid: transactionID))
            default:
                break
            }
        })
        
        sendQueueStatusSubject
            .combineLatest(homeserverReachabilityPublisher)
            .debounce(for: 1.0, scheduler: DispatchQueue.main)
            .sink { enabled, reachability in
                MXLog.info("Send queue status changed to enabled: \(enabled), homeserver reachability: \(reachability)")
                
                if enabled == false, reachability == .reachable {
                    MXLog.info("Enabling all send queues")
                    Task {
                        await client.enableAllSendQueues(enable: true)
                    }
                }
            }
            .store(in: &cancellables)
        
        Task {
            do {
                try await client.setMediaRetentionPolicy(policy: .init(maxCacheSize: nil,
                                                                       maxFileSize: nil,
                                                                       // 30 days in seconds
                                                                       lastAccessExpiry: 30 * 24 * 60 * 60,
                                                                       // 1 day in seconds
                                                                       cleanupFrequency: 24 * 60 * 60))
            } catch {
                MXLog.error("Failed setting media retention policy with error: \(error)")
            }
        }
        
        Task {
            mediaPreviewConfigListenerTaskHandle = await createMediaPreviewConfigObserver()
        }
    }
    
    var userID: String {
        do {
            return try client.userId()
        } catch {
            MXLog.error("Failed retrieving room info with error: \(error)")
            return "Unknown user identifier"
        }
    }

    var deviceID: String? {
        do {
            return try client.deviceId()
        } catch {
            MXLog.error("Failed retrieving deviceID with error: \(error)")
            return nil
        }
    }

    var homeserver: String {
        client.homeserver()
    }
    
    var canDeactivateAccount: Bool {
        client.canDeactivateAccount()
    }
    
    var userIDServerName: String? {
        do {
            return try client.userIdServerName()
        } catch {
            MXLog.error("Failed retrieving userID server name with error: \(error)")
            return nil
        }
    }
    
    var isReportRoomSupported: Bool {
        get async {
            do {
                return try await client.isReportRoomApiSupported()
            } catch {
                MXLog.error("Failed checking report room support with error: \(error)")
                return false
            }
        }
    }
    
    var isLiveKitRTCSupported: Bool {
        get async {
            do {
                return try await client.isLivekitRtcSupported()
            } catch {
                MXLog.error("Failed checking LiveKit RTC support with error: \(error)")
                return false
            }
        }
    }
    
    var isLoginWithQRCodeSupported: Bool {
        get async {
            do {
                return try await client.isLoginWithQrCodeSupported()
            } catch {
                MXLog.error("Failed checking QR code support with error: \(error)")
                return false
            }
        }
    }
    
    var maxMediaUploadSize: Result<UInt, ClientProxyError> {
        get async {
            do {
                return try await .success(UInt(client.getMaxMediaUploadSize()))
            } catch {
                MXLog.error("Failed checking the max media upload size with error: \(error)")
                return .failure(.sdkError(error))
            }
        }
    }

    private(set) lazy var pusherNotificationClientIdentifier: String? = {
        // NOTE: The result is stored as part of the restoration token. Any changes
        // here would require a migration to correctly match incoming notifications.
        guard let data = userID.data(using: .utf8) else { return nil }
        let digest = SHA256.hash(data: data)
        return digest.compactMap { String(format: "%02x", $0) }.joined()
    }()
    
    func isOnlyDeviceLeft() async -> Result<Bool, ClientProxyError> {
        do {
            let result = try await client.encryption().isLastDevice()
            return .success(result)
        } catch {
            MXLog.error("Failed checking isLastDevice with error: \(error)")
            return .failure(.sdkError(error))
        }
    }

    func hasDevicesToVerifyAgainst() async -> Result<Bool, ClientProxyError> {
        do {
            let result = try await client.encryption().hasDevicesToVerifyAgainst()
            return .success(result)
        } catch {
            MXLog.error("Failed checking hasDevicesToVerifyAgainst with error: \(error)")
            return .failure(.sdkError(error))
        }
    }

    func startSync() {
        guard !hasEncounteredAuthError else {
            MXLog.warning("Ignoring request, this client has an unknown token.")
            return
        }
        
        guard networkMonitor.reachabilityPublisher.value == .reachable else {
            MXLog.warning("Ignoring request, network unreachable.")
            return
        }
        
        MXLog.info("Starting sync")
        
        Task {
            await syncService.start()
            
            // If we are using OIDC we want to cache the account management URL in volatile memory on the SDK side.
            // To avoid the cache being invalidated while the app is backgrounded, we cache at every sync start.
            await cacheAccountURL()
        }
    }
    
    /// A stored task for restarting the sync after a failure. This is stored so that we can cancel
    /// it when `stopSync` is called (e.g. when signing out) to prevent an otherwise infinite
    /// loop that was triggered by trying to sync a signed out session.
    @CancellableTask private var restartTask: Task<Void, Never>?
    
    func restartSync() {
        guard restartTask == nil else { return }
        
        restartTask = Task { [weak self] in
            do {
                // Until the SDK can tell us the failure, we add a small
                // delay to avoid generating multi-gigabyte log files.
                try await Task.sleep(for: .milliseconds(250))
                self?.startSync()
            } catch {
                MXLog.error("Restart cancelled.")
            }
            self?.restartTask = nil
        }
    }
    
    func stopSync() {
        stopSync(completion: nil)
    }
    
    func stopSync(completion: (() -> Void)?) {
        MXLog.info("Stopping sync")
        
        if restartTask != nil {
            MXLog.warning("Removing the sync service restart task.")
            restartTask = nil
        }
        
        // Capture the sync service strongly as this method is called on deinit and so the
        // existence of self when the Task executes is questionable and would sometimes crash.
        // Note: This isn't strictly necessary now given the unwrap above, but leaving the code as
        // documentation. SE-0371 will allow us to fix this by using an async deinit.
        Task { [syncService] in
            defer {
                completion?()
            }
            
            await syncService.stop()
            MXLog.info("Sync stopped")
        }
    }
    
    func expireSyncSessions() async {
        await syncService.expireSessions()
    }
    
    func accountURL(action: AccountManagementAction) async -> URL? {
        try? await client.accountUrl(action: action).flatMap(URL.init(string:))
    }
    
    func directRoomForUserID(_ userID: String) -> Result<String?, ClientProxyError> {
        do {
            let roomID = try client.getDmRoom(userId: userID)?.id()
            return .success(roomID)
        } catch {
            MXLog.error("Failed retrieving direct room for userID: \(userID) with error: \(error)")
            return .failure(.sdkError(error))
        }
    }
    
    func createDirectRoom(with userID: String, expectedRoomName: String?) async -> Result<String, ClientProxyError> {
        do {
            let parameters = CreateRoomParameters(name: nil,
                                                  topic: nil,
                                                  isEncrypted: true,
                                                  isDirect: true,
                                                  visibility: .private,
                                                  preset: .trustedPrivateChat,
                                                  invite: [userID],
                                                  avatar: nil,
                                                  powerLevelContentOverride: Self.roomCreationPowerLevelOverrides,
                                                  historyVisibilityOverride: .invited)
            let roomID = try await client.createRoom(request: parameters)
            
            await waitForRoomToSync(roomID: roomID)
            
            return .success(roomID)
        } catch {
            MXLog.error("Failed creating direct room for userID: \(userID) with error: \(error)")
            return .failure(.sdkError(error))
        }
    }
    
    func createRoom(name: String,
                    topic: String?,
                    accessType: CreateRoomAccessType,
                    isSpace: Bool,
                    userIDs: [String],
                    avatarURL: URL?,
                    aliasLocalPart: String?) async -> Result<String, ClientProxyError> {
        do {
            let powerLevelContentOverride = if isSpace {
                if accessType == .public {
                    Self.publicSpaceCreationPowerLevelOverrides
                } else {
                    Self.standardSpaceCreationPowerLevelOverrides
                }
            } else {
                if accessType.isAskToJoin {
                    Self.knockingRoomCreationPowerLevelOverrides
                } else {
                    Self.roomCreationPowerLevelOverrides
                }
            }
            
            let parameters = CreateRoomParameters(name: name,
                                                  topic: topic,
                                                  isEncrypted: accessType.isEncrypted,
                                                  isDirect: false,
                                                  visibility: accessType.visibility,
                                                  preset: accessType.preset,
                                                  invite: userIDs,
                                                  avatar: avatarURL?.absoluteString,
                                                  powerLevelContentOverride: powerLevelContentOverride,
                                                  joinRuleOverride: accessType.joinRuleOverride?.rustValue,
                                                  historyVisibilityOverride: accessType.historyVisibilityOverride,
                                                  // This is an FFI naming mistake, what is required is the `aliasLocalPart` not the whole alias
                                                  canonicalAlias: aliasLocalPart,
                                                  isSpace: isSpace)
            let roomID = try await client.createRoom(request: parameters)
            
            await waitForRoomToSync(roomID: roomID)
            
            return .success(roomID)
        } catch {
            MXLog.error("Failed creating room with error: \(error)")
            return .failure(.sdkError(error))
        }
    }
    
    func joinRoom(_ roomID: String, via: [String]) async -> Result<Void, ClientProxyError> {
        do {
            let _ = try await client.joinRoomByIdOrAlias(roomIdOrAlias: roomID, serverNames: via)
                        
            await waitForRoomToSync(roomID: roomID, timeout: .seconds(30))
            
            return .success(())
        } catch ClientError.MatrixApi(.unknown, _, _, _) {
            MXLog.error("Failed joining roomID: \(roomID) invalid invite")
            return .failure(.invalidInvite)
        } catch ClientError.MatrixApi(.forbidden, _, _, _) {
            MXLog.error("Failed joining roomID: \(roomID) forbidden")
            return .failure(.forbiddenAccess)
        } catch {
            MXLog.error("Failed joining roomID: \(roomID) with error: \(error)")
            return .failure(.sdkError(error))
        }
    }
    
    func joinRoomAlias(_ roomAlias: String) async -> Result<Void, ClientProxyError> {
        do {
            let room = try await client.joinRoomByIdOrAlias(roomIdOrAlias: roomAlias, serverNames: [])
            
            await waitForRoomToSync(roomID: room.id(), timeout: .seconds(30))
            
            return .success(())
        } catch ClientError.MatrixApi(.unknown, _, _, _) {
            MXLog.error("Failed joining roomAlias: \(roomAlias) invalid invite")
            return .failure(.invalidInvite)
        } catch ClientError.MatrixApi(.forbidden, _, _, _) {
            MXLog.error("Failed joining roomAlias: \(roomAlias) forbidden")
            return .failure(.forbiddenAccess)
        } catch {
            MXLog.error("Failed joining roomAlias: \(roomAlias) with error: \(error)")
            return .failure(.sdkError(error))
        }
    }
    
    func knockRoom(_ roomID: String, via: [String], message: String?) async -> Result<Void, ClientProxyError> {
        do {
            let _ = try await client.knock(roomIdOrAlias: roomID, reason: message, serverNames: via)
            await waitForRoomToSync(roomID: roomID, timeout: .seconds(30))
            return .success(())
        } catch {
            MXLog.error("Failed knocking roomID: \(roomID) with error: \(error)")
            return .failure(.sdkError(error))
        }
    }
    
    func knockRoomAlias(_ roomAlias: String, message: String?) async -> Result<Void, ClientProxyError> {
        do {
            let room = try await client.knock(roomIdOrAlias: roomAlias, reason: message, serverNames: [])
            await waitForRoomToSync(roomID: room.id(), timeout: .seconds(30))
            return .success(())
        } catch {
            MXLog.error("Failed knocking roomAlias: \(roomAlias) with error: \(error)")
            return .failure(.sdkError(error))
        }
    }
    
    func canJoinRoom(with rules: [AllowRule]) -> Bool {
        for rule in rules {
            if case let .roomMembership(roomID) = rule,
               let room = try? client.getRoom(roomId: roomID),
               room.membership() == .joined {
                return true
            }
        }
        return false
    }
    
    func uploadMedia(_ media: MediaInfo) async -> Result<String, ClientProxyError> {
        guard let mimeType = media.mimeType else {
            MXLog.error("Failed uploading media, invalid mime type: \(media)")
            return .failure(ClientProxyError.invalidMedia)
        }
        
        do {
            let data = try Data(contentsOf: media.url)
            let matrixUrl = try await client.uploadMedia(mimeType: mimeType, data: data, progressWatcher: nil)
            return .success(matrixUrl)
        } catch let ClientError.MatrixApi(errorKind, _, _, _) {
            MXLog.error("Failed uploading media with error kind: \(errorKind)")
            return .failure(ClientProxyError.failedUploadingMedia(errorKind))
        } catch {
            MXLog.error("Failed uploading media with error: \(error)")
            return .failure(ClientProxyError.sdkError(error))
        }
    }
        
    func roomForIdentifier(_ identifier: String) async -> RoomProxyType? {
        let shouldAwait = roomsToAwait.remove(identifier) != nil
        
        // Try fetching the room from the cold cache (if available) first
        if let room = await buildRoomForIdentifier(identifier) {
            return room
        }
        
        if !staticRoomSummaryProvider.statePublisher.value.isLoaded {
            _ = await staticRoomSummaryProvider.statePublisher.values.first { $0.isLoaded }
        }
        
        if shouldAwait {
            await waitForRoomToSync(roomID: identifier)
        }
        
        return await buildRoomForIdentifier(identifier)
    }
    
    func roomPreviewForIdentifier(_ identifier: String, via: [String]) async -> Result<RoomPreviewProxyProtocol, ClientProxyError> {
        do {
            let roomPreview = try await client.getRoomPreviewFromRoomId(roomId: identifier, viaServers: via)
            return .success(RoomPreviewProxy(roomPreview: roomPreview))
        } catch ClientError.MatrixApi(.forbidden, _, _, _) {
            MXLog.error("Failed retrieving preview for room: \(identifier) is private")
            return .failure(.roomPreviewIsPrivate)
        } catch {
            MXLog.error("Failed retrieving preview for room: \(identifier) with error: \(error)")
            return .failure(.sdkError(error))
        }
    }
    
    func roomSummaryForIdentifier(_ identifier: String) -> RoomSummary? {
        staticRoomSummaryProvider.roomListPublisher.value.first { $0.id == identifier }
    }
    
    func roomSummaryForAlias(_ alias: String) -> RoomSummary? {
        staticRoomSummaryProvider.roomListPublisher.value.first { $0.canonicalAlias == alias || $0.alternativeAliases.contains(alias) }
    }
    
    func reportRoomForIdentifier(_ identifier: String, reason: String) async -> Result<Void, ClientProxyError> {
        do {
            guard let room = try client.getRoom(roomId: identifier) else {
                MXLog.error("Failed reporting room with identifier: \(identifier), room not in local store")
                return .failure(.roomNotInLocalStore)
            }
            try await room.reportRoom(reason: reason)
            return .success(())
        } catch {
            MXLog.error("Failed reporting room with identifier: \(identifier), with error: \(error)")
            return .failure(.sdkError(error))
        }
    }

    func loadUserDisplayName() async -> Result<Void, ClientProxyError> {
        do {
            let displayName = try await client.displayName()
            userDisplayNameSubject.send(displayName)
            return .success(())
        } catch {
            MXLog.error("Failed loading user display name with error: \(error)")
            return .failure(.sdkError(error))
        }
    }
    
    func setUserDisplayName(_ name: String) async -> Result<Void, ClientProxyError> {
        do {
            try await client.setDisplayName(name: name)
            Task {
                await self.loadUserDisplayName()
            }
            return .success(())
        } catch {
            MXLog.error("Failed setting user display name with error: \(error)")
            return .failure(.sdkError(error))
        }
    }

    func loadUserAvatarURL() async -> Result<Void, ClientProxyError> {
        do {
            let urlString = try await client.avatarUrl()
            loadCachedAvatarURLTask?.cancel()
            userAvatarURLSubject.send(urlString.flatMap(URL.init))
            return .success(())
        } catch {
            MXLog.error("Failed loading user avatar URL with error: \(error)")
            return .failure(.sdkError(error))
        }
    }
    
    func setUserAvatar(media: MediaInfo) async -> Result<Void, ClientProxyError> {
        guard case let .image(imageURL, _, _) = media, let mimeType = media.mimeType else {
            MXLog.error("Failed uploading, invalid media: \(media)")
            return .failure(.invalidMedia)
        }
            
        do {
            let data = try Data(contentsOf: imageURL)
            try await client.uploadAvatar(mimeType: mimeType, data: data)
            Task {
                await self.loadUserAvatarURL()
            }
            return .success(())
        } catch {
            MXLog.error("Failed setting user avatar with error: \(error)")
            return .failure(.sdkError(error))
        }
    }
    
    func removeUserAvatar() async -> Result<Void, ClientProxyError> {
        do {
            try await client.removeAvatar()
            Task {
                await self.loadUserAvatarURL()
            }
            return .success(())
        } catch {
            MXLog.error("Failed removing user avatar with error: \(error)")
            return .failure(.sdkError(error))
        }
    }
    
    func linkNewDeviceService() -> LinkNewDeviceServiceProtocol {
        LinkNewDeviceService(handler: client.newGrantLoginWithQrCodeHandler())
    }
    
    func deactivateAccount(password: String?, eraseData: Bool) async -> Result<Void, ClientProxyError> {
        do {
            try await client.deactivateAccount(authData: password.map { .password(passwordDetails: .init(identifier: userID, password: $0)) },
                                               eraseData: eraseData)
            return .success(())
        } catch {
            return .failure(.sdkError(error))
        }
    }
    
    func logout() async {
        do {
            try await client.logout()
        } catch {
            MXLog.error("Failed logging out with error: \(error)")
        }
    }
    
    func setPusher(with configuration: PusherConfiguration) async throws {
        try await client.setPusher(identifiers: configuration.identifiers,
                                   kind: configuration.kind,
                                   appDisplayName: configuration.appDisplayName,
                                   deviceDisplayName: configuration.deviceDisplayName,
                                   profileTag: configuration.profileTag,
                                   lang: configuration.lang)
    }
    
    func searchUsers(searchTerm: String, limit: UInt) async -> Result<SearchUsersResultsProxy, ClientProxyError> {
        do {
            return try await .success(.init(sdkResults: client.searchUsers(searchTerm: searchTerm, limit: UInt64(limit))))
        } catch {
            MXLog.error("Failed searching users with error: \(error)")
            return .failure(.sdkError(error))
        }
    }
    
    func profile(for userID: String) async -> Result<UserProfileProxy, ClientProxyError> {
        do {
            return try await .success(.init(sdkUserProfile: client.getProfile(userId: userID)))
        } catch {
            MXLog.error("Failed retrieving profile for userID: \(userID) with error: \(error)")
            return .failure(.sdkError(error))
        }
    }
    
    func fetchContacts() async -> Result<[ManagedContact], ClientProxyError> {
        do {
            let data = try await performContactsRequest(method: "GET",
                                                        path: "/user/\(encodedUserID())/contact_list")
            let response = try JSONDecoder().decode(ContactsResponse.self, from: data)
            let contacts = response.rooms.map { roomID, metadata in
                ManagedContact(roomID: roomID,
                               alias: metadata.displayName ?? roomSummaryForIdentifier(roomID)?.name ?? metadata.userID ?? roomID,
                               userID: metadata.userID,
                               email: metadata.email,
                               phone: metadata.phone)
            }
            
            return .success(contacts)
        } catch {
            MXLog.error("Failed fetching contacts with error: \(error)")
            return .failure(.sdkError(error))
        }
    }
    
    func saveContact(_ contact: ManagedContact) async -> Result<Void, ClientProxyError> {
        do {
            let payload = ContactMetadataPayload(displayName: contact.alias,
                                                 userID: contact.userID,
                                                 email: contact.syncEmailToServer ? contact.email : nil,
                                                 phone: contact.syncPhoneToServer ? contact.phone : nil)
            let body = try JSONEncoder().encode(payload)
            _ = try await performContactsRequest(method: "PUT",
                                                 path: "/user/\(encodedUserID())/contact_list/rooms/\(encodedPathSegment(contact.roomID))",
                                                 body: body)
            return .success(())
        } catch {
            MXLog.error("Failed saving contact with error: \(error)")
            return .failure(.sdkError(error))
        }
    }
    
    func deleteContact(roomID: String) async -> Result<Void, ClientProxyError> {
        do {
            _ = try await performContactsRequest(method: "DELETE",
                                                 path: "/user/\(encodedUserID())/contact_list/rooms/\(encodedPathSegment(roomID))")
            return .success(())
        } catch {
            MXLog.error("Failed deleting contact with error: \(error)")
            return .failure(.sdkError(error))
        }
    }
    
    func fetchRoomWallpaper(roomID: String) async -> Result<RoomWallpaperMetadata?, ClientProxyError> {
        do {
            let encodedRoomID = encodedPathSegment(roomID)
            let (data, response) = try await performUserMetadataRequest(method: "GET",
                                                                        path: "/user/\(encodedUserID())/room_wallpaper/rooms/\(encodedRoomID)")
            if response.statusCode == 404 {
                return .success(nil)
            }
            
            guard 200..<300 ~= response.statusCode else {
                return .failure(.invalidResponse)
            }
            
            let metadata = try JSONDecoder().decode(RoomWallpaperMetadataPayload.self, from: data)
            return .success(metadata.model)
        } catch let error as ClientProxyError {
            MXLog.error("Failed fetching room wallpaper with error: \(error)")
            return .failure(error)
        } catch {
            MXLog.error("Failed fetching room wallpaper with error: \(error)")
            return .failure(.sdkError(error))
        }
    }
    
    func saveRoomWallpaper(roomID: String, metadata: RoomWallpaperMetadata) async -> Result<Void, ClientProxyError> {
        do {
            let encodedRoomID = encodedPathSegment(roomID)
            let payload = RoomWallpaperMetadataPayload(model: metadata)
            let body = try JSONEncoder().encode(payload)
            let (_, response) = try await performUserMetadataRequest(method: "PUT",
                                                                     path: "/user/\(encodedUserID())/room_wallpaper/rooms/\(encodedRoomID)",
                                                                     body: body)
            guard 200..<300 ~= response.statusCode else {
                return .failure(.invalidResponse)
            }
            
            return .success(())
        } catch let error as ClientProxyError {
            MXLog.error("Failed saving room wallpaper with error: \(error)")
            return .failure(error)
        } catch {
            MXLog.error("Failed saving room wallpaper with error: \(error)")
            return .failure(.sdkError(error))
        }
    }
    
    func deleteRoomWallpaper(roomID: String) async -> Result<Void, ClientProxyError> {
        do {
            let encodedRoomID = encodedPathSegment(roomID)
            let (_, response) = try await performUserMetadataRequest(method: "DELETE",
                                                                     path: "/user/\(encodedUserID())/room_wallpaper/rooms/\(encodedRoomID)")
            guard 200..<300 ~= response.statusCode || response.statusCode == 404 else {
                return .failure(.invalidResponse)
            }
            
            return .success(())
        } catch let error as ClientProxyError {
            MXLog.error("Failed deleting room wallpaper with error: \(error)")
            return .failure(error)
        } catch {
            MXLog.error("Failed deleting room wallpaper with error: \(error)")
            return .failure(.sdkError(error))
        }
    }
    
    func fetchSetkaPlusSubscription() async -> Result<SetkaPlusSubscription, ClientProxyError> {
        do {
            let data = try await performSetkaPlusRequest(method: "GET",
                                                         path: "/user/\(encodedUserID())/setka_plus/subscription")
            let subscription = try JSONDecoder().decode(SetkaPlusSubscription.self, from: data)
            return .success(subscription)
        } catch {
            MXLog.error("Failed fetching Setka Plus subscription with error: \(error)")
            return .failure(.sdkError(error))
        }
    }
    
    func fetchSetkaPlusPlans() async -> Result<[SetkaPlusPlan], ClientProxyError> {
        do {
            let data = try await performSetkaPlusRequest(method: "GET",
                                                         path: "/user/\(encodedUserID())/setka_plus/plans")
            let response = try JSONDecoder().decode(SetkaPlusPlansResponse.self, from: data)
            return .success(response.plans)
        } catch {
            MXLog.error("Failed fetching Setka Plus plans with error: \(error)")
            return .failure(.sdkError(error))
        }
    }

    func fetchSetkaPlusStickerPacks() async -> Result<[SetkaPlusStickerPack], ClientProxyError> {
        do {
            let data = try await performSetkaPlusRequest(method: "GET",
                                                         path: "/user/\(encodedUserID())/setka_plus/sticker_packs")
            let response = try JSONDecoder().decode(SetkaPlusStickerPacksResponse.self, from: data)
            return .success(response.packs)
        } catch {
            MXLog.error("Failed fetching Setka Plus sticker packs with error: \(error)")
            return .failure(.sdkError(error))
        }
    }

    func createSetkaPlusStickerPack(name: String, kind: String) async -> Result<SetkaPlusStickerPack, ClientProxyError> {
        let normalizedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedKind = kind.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedName.isEmpty, !normalizedKind.isEmpty else {
            return .failure(.invalidResponse)
        }

        do {
            let payload = SetkaPlusStickerPackSavePayload(name: normalizedName,
                                                          kind: normalizedKind,
                                                          stickers: [])
            let body = try JSONEncoder().encode(payload)
            let data = try await performSetkaPlusRequest(method: "POST",
                                                         path: "/user/\(encodedUserID())/setka_plus/sticker_packs",
                                                         body: body)
            let pack = try decodeSetkaPlusStickerPackResponse(data)
            return .success(pack)
        } catch {
            MXLog.error("Failed creating Setka Plus sticker pack with error: \(error)")
            return .failure(.sdkError(error))
        }
    }

    func saveSetkaPlusStickerPack(_ pack: SetkaPlusStickerPack) async -> Result<SetkaPlusStickerPack, ClientProxyError> {
        let normalizedPackID = pack.id.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedName = pack.name.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedKind = pack.kind.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedPackID.isEmpty, !normalizedName.isEmpty, !normalizedKind.isEmpty else {
            return .failure(.invalidResponse)
        }

        do {
            let payload = SetkaPlusStickerPackSavePayload(name: normalizedName,
                                                          kind: normalizedKind,
                                                          stickers: pack.stickers)
            let body = try JSONEncoder().encode(payload)
            let data = try await performSetkaPlusRequest(method: "PUT",
                                                         path: "/user/\(encodedUserID())/setka_plus/sticker_packs/\(encodedPathSegment(normalizedPackID))",
                                                         body: body)
            let updatedPack = try decodeSetkaPlusStickerPackResponse(data, fallback: pack)
            return .success(updatedPack)
        } catch {
            MXLog.error("Failed saving Setka Plus sticker pack with error: \(error)")
            return .failure(.sdkError(error))
        }
    }

    func deleteSetkaPlusStickerPack(packID: String) async -> Result<Void, ClientProxyError> {
        let normalizedPackID = packID.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedPackID.isEmpty else {
            return .failure(.invalidResponse)
        }

        do {
            let (_, response) = try await performUserMetadataRequest(method: "DELETE",
                                                                     path: "/user/\(encodedUserID())/setka_plus/sticker_packs/\(encodedPathSegment(normalizedPackID))")
            guard 200..<300 ~= response.statusCode || response.statusCode == 404 else {
                return .failure(.invalidResponse)
            }
            return .success(())
        } catch let error as ClientProxyError {
            MXLog.error("Failed deleting Setka Plus sticker pack with ClientProxyError: \(error)")
            return .failure(error)
        } catch {
            MXLog.error("Failed deleting Setka Plus sticker pack with error: \(error)")
            return .failure(.sdkError(error))
        }
    }

    func addSetkaPlusStickerPack(packID: String) async -> Result<Void, ClientProxyError> {
        let normalizedPackID = packID.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedPackID.isEmpty else {
            return .failure(.invalidResponse)
        }

        if case let .success(existingPacks) = await fetchSetkaPlusStickerPacks(),
           existingPacks.contains(where: { $0.id == normalizedPackID }) {
            MXLog.info("Setka Plus sticker pack is already on account: \(normalizedPackID)")
            return .success(())
        }

        let body = try? JSONEncoder().encode(SetkaPlusAddStickerPackPayload(packID: normalizedPackID))
        struct CandidateRequest {
            let method: String
            let path: String
            let body: Data?
        }
        
        let candidateRequests: [CandidateRequest] = [
            .init(method: "POST", path: "/user/\(encodedUserID())/setka_plus/sticker_packs", body: body),
            .init(method: "PUT", path: "/user/\(encodedUserID())/setka_plus/sticker_packs/\(encodedPathSegment(normalizedPackID))", body: nil),
            .init(method: "POST", path: "/setka_plus/sticker_packs/\(encodedPathSegment(normalizedPackID))/add", body: nil),
            .init(method: "POST", path: "/setka_plus/sticker_packs/add", body: body)
        ]

        for request in candidateRequests {
            do {
                let (data, response) = try await performUserMetadataRequest(method: request.method, path: request.path, body: request.body)
                if 200..<300 ~= response.statusCode || response.statusCode == 409 || response.statusCode == 422 {
                    // 409/422 commonly mean "already added" or "already associated" for idempotent add operations.
                    return .success(())
                }
                if isStickerPackAlreadyAddedResponse(statusCode: response.statusCode, body: data) {
                    MXLog.info("Setka Plus sticker pack add treated as success (already added) for status \(response.statusCode)")
                    return .success(())
                }
                MXLog.warning("Failed adding Setka Plus sticker pack using \(request.method) \(request.path): status \(response.statusCode)")
            } catch {
                MXLog.warning("Failed adding Setka Plus sticker pack using \(request.method) \(request.path): \(error)")
            }
        }

        // Final consistency check: some backends can return non-2xx while still persisting the pack.
        if case let .success(existingPacks) = await fetchSetkaPlusStickerPacks(),
           existingPacks.contains(where: { $0.id == normalizedPackID }) {
            MXLog.info("Setka Plus sticker pack detected on account after add attempts: \(normalizedPackID)")
            return .success(())
        }

        return .failure(.invalidResponse)
    }

    func createSetkaPlusStickerPackShareLink(packID: String) async -> Result<String, ClientProxyError> {
        let normalizedPackID = packID.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedPackID.isEmpty else {
            return .failure(.invalidResponse)
        }

        do {
            let data = try await performSetkaPlusRequest(method: "POST",
                                                         path: "/user/\(encodedUserID())/setka_plus/sticker_packs/\(encodedPathSegment(normalizedPackID))/share",
                                                         body: Data("{}".utf8))
            let link = try decodeSetkaPlusShareLinkResponse(data)
            return .success(link)
        } catch {
            MXLog.error("Failed creating Setka Plus sticker pack share link with error: \(error)")
            return .failure(.sdkError(error))
        }
    }

    func resolveSetkaPlusSharedStickerPack(token: String) async -> Result<SetkaPlusStickerPack, ClientProxyError> {
        let normalizedToken = token.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedToken.isEmpty else {
            return .failure(.invalidResponse)
        }

        do {
            let data = try await performSetkaPlusRequest(method: "GET",
                                                         path: "/user/\(encodedUserID())/setka_plus/shared_packs/\(encodedPathSegment(normalizedToken))")
            let pack = try decodeSetkaPlusSharedStickerPackResponse(data)
            return .success(pack)
        } catch {
            MXLog.error("Failed resolving Setka Plus shared sticker pack with error: \(error)")
            return .failure(.sdkError(error))
        }
    }

    func importSetkaPlusSharedStickerPack(token: String) async -> Result<SetkaPlusStickerPack, ClientProxyError> {
        let normalizedToken = token.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedToken.isEmpty else {
            return .failure(.invalidResponse)
        }

        do {
            let data = try await performSetkaPlusRequest(method: "POST",
                                                         path: "/user/\(encodedUserID())/setka_plus/shared_packs/\(encodedPathSegment(normalizedToken))/import",
                                                         body: Data("{}".utf8))
            let pack = try decodeSetkaPlusStickerPackResponse(data)
            return .success(pack)
        } catch {
            MXLog.error("Failed importing Setka Plus shared sticker pack with error: \(error)")
            return .failure(.sdkError(error))
        }
    }
    
    func fetchSetkaPlusPayments() async -> Result<[SetkaPlusPayment], ClientProxyError> {
        do {
            let data = try await performSetkaPlusRequest(method: "GET",
                                                         path: "/user/\(encodedUserID())/setka_plus/payments")
            let response = try JSONDecoder().decode(SetkaPlusPaymentsResponse.self, from: data)
            return .success(response.payments)
        } catch {
            MXLog.error("Failed fetching Setka Plus payments with error: \(error)")
            return .failure(.sdkError(error))
        }
    }

    func fetchSetkaPlusStatusEmoji(userID: String?) async -> Result<SetkaPlusStatusEmoji, ClientProxyError> {
        do {
            let targetUserID = userID?.trimmingCharacters(in: .whitespacesAndNewlines)
            let isFetchingOtherUser = targetUserID != nil && targetUserID != self.userID
            let path: String
            if let targetUserID, !targetUserID.isEmpty, targetUserID != self.userID {
                path = "/setka_plus/users/\(encodedPathSegment(targetUserID))/status_emoji"
                MXLog.info("Fetching Setka Plus status for user: \(targetUserID)")
            } else {
                path = "/user/\(encodedUserID())/setka_plus/status_emoji"
                MXLog.info("Fetching own Setka Plus status")
            }

            let (data, response) = try await performUserMetadataRequest(method: "GET", path: path)
            MXLog.info("Setka Plus status fetch response: \(response.statusCode)")
            
            if response.statusCode == 404 {
                if isFetchingOtherUser {
                    MXLog.info("Setka Plus status not found (404) for other user - returning empty status")
                    return .success(.init(emoji: nil, packID: nil, stickerID: nil, updatedAt: nil))
                }
                MXLog.info("Setka Plus status not found (404) - returning empty status")
                return .success(.init(emoji: nil, packID: nil, stickerID: nil, updatedAt: nil))
            }
            
            guard 200..<300 ~= response.statusCode else {
                MXLog.error("Setka Plus status fetch failed with status code: \(response.statusCode)")
                throw ClientProxyError.invalidResponse
            }
            
            var statusEmoji = try decodeSetkaPlusStatusEmojiResponse(data)
            if isFetchingOtherUser,
               statusEmoji.emoji?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty != false,
               statusEmoji.stickerID?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty != false {
                // User has Setka Plus metadata endpoint available but no custom status yet.
                statusEmoji = .init(emoji: nil,
                                    packID: statusEmoji.packID,
                                    stickerID: "setka_plus_subscription",
                                    updatedAt: statusEmoji.updatedAt)
            }
            MXLog.info("Setka Plus status fetch successful: \(statusEmoji.emoji ?? "nil")")
            return .success(statusEmoji)
        } catch let error as ClientProxyError {
            MXLog.error("Failed fetching Setka Plus status emoji with ClientProxyError: \(error)")
            return .failure(error)
        } catch {
            MXLog.error("Failed fetching Setka Plus status emoji with error: \(error)")
            return .failure(.sdkError(error))
        }
    }

    func fetchSetkaPlusUserProfileDetails(userID: String) async -> Result<SetkaPlusUserProfileDetails, ClientProxyError> {
        let encodedTargetUserID = encodedPathSegment(userID)
        let candidates = [
            "/user/\(encodedTargetUserID)/setka_profile",
            "/profile/\(encodedTargetUserID)/setka_profile",
            "/setka_plus/users/\(encodedTargetUserID)/profile"
        ]

        for path in candidates {
            do {
                let (data, response) = try await performUserMetadataRequest(method: "GET", path: path)

                if response.statusCode == 404 {
                    continue
                }

                guard 200..<300 ~= response.statusCode else {
                    MXLog.warning("Setka Plus user profile fetch failed for \(path) with status code: \(response.statusCode)")
                    continue
                }

                let details = try JSONDecoder().decode(SetkaPlusUserProfileDetails.self, from: data)
                return .success(details)
            } catch {
                MXLog.warning("Failed fetching Setka Plus user profile details from \(path) with error: \(error)")
            }
        }

        return .success(.init(bio: nil, backgroundURL: nil, lastSeenText: nil, shareURL: nil))
    }
    
    func updateSetkaPlusUserProfileDetails(_ details: SetkaPlusUserProfileUpdate) async -> Result<Void, ClientProxyError> {
        let payload = try? JSONEncoder().encode(details)
        let candidates: [(String, String)] = [
            ("PUT", "/user/\(encodedUserID())/setka_profile"),
            ("PATCH", "/user/\(encodedUserID())/setka_profile"),
            ("POST", "/user/\(encodedUserID())/setka_profile"),
            ("PATCH", "/user/\(encodedUserID())/setka_plus/profile"),
            ("PUT", "/user/\(encodedUserID())/setka_plus/profile"),
            ("POST", "/user/\(encodedUserID())/setka_plus/profile")
        ]
        
        for (method, path) in candidates {
            do {
                _ = try await performSetkaPlusRequest(method: method, path: path, body: payload)
                return .success(())
            } catch let error as ClientProxyError {
                MXLog.warning("Failed updating Setka Plus user profile using \(method) \(path): \(error)")
            } catch {
                MXLog.warning("Failed updating Setka Plus user profile using \(method) \(path): \(error)")
            }
        }
        
        return .failure(.invalidResponse)
    }

    func updateSetkaPlusStatusEmoji(emoji: String?, packID: String?, stickerID: String?) async -> Result<SetkaPlusStatusEmoji, ClientProxyError> {
        do {
            MXLog.info("Updating Setka Plus status emoji via API: emoji=\(emoji ?? "nil"), packID=\(packID ?? "nil"), stickerID=\(stickerID ?? "nil")")
            
            let payload = SetkaPlusStatusEmojiPayload(emoji: emoji,
                                                      packID: packID,
                                                      stickerID: stickerID)
            let body = try JSONEncoder().encode(payload)
            let (data, response) = try await performUserMetadataRequest(method: "PUT",
                                                                        path: "/user/\(encodedUserID())/setka_plus/status_emoji",
                                                                        body: body)
            
            MXLog.info("Setka Plus status update response: \(response.statusCode)")
            
            guard 200..<300 ~= response.statusCode else {
                MXLog.error("Setka Plus status update failed with status code: \(response.statusCode)")
                throw ClientProxyError.invalidResponse
            }
            
            let fallbackStatus = SetkaPlusStatusEmoji(emoji: emoji, packID: packID, stickerID: stickerID, updatedAt: nil)
            let statusEmoji = try decodeSetkaPlusStatusEmojiResponse(data, fallback: fallbackStatus)
            MXLog.info("Setka Plus status update successful: \(statusEmoji.emoji ?? "nil")")
            return .success(statusEmoji)
        } catch let error as ClientProxyError {
            MXLog.error("Failed updating Setka Plus status emoji with ClientProxyError: \(error)")
            return .failure(error)
        } catch {
            MXLog.error("Failed updating Setka Plus status emoji with error: \(error)")
            return .failure(.sdkError(error))
        }
    }
    
    func createSetkaPlusYooMoneyPayment(amount: Double?, description: String?, planID: String?) async -> Result<SetkaPlusPaymentRequest, ClientProxyError> {
        do {
            let payload = SetkaPlusCreateYooMoneyPaymentPayload(amount: amount,
                                                                description: description,
                                                                planID: planID)
            let body = try JSONEncoder().encode(payload)
            let data = try await performSetkaPlusRequest(method: "POST",
                                                         path: "/user/\(encodedUserID())/setka_plus/payments/yoomoney/create",
                                                         body: body)
            let response = try JSONDecoder().decode(SetkaPlusPaymentRequest.self, from: data)
            return .success(response)
        } catch {
            MXLog.error("Failed creating Setka Plus YooMoney payment with error: \(error)")
            return .failure(.sdkError(error))
        }
    }
    
    func processSetkaPlusYooMoneyPayment(requestID: String, moneySource: String, planID: String?) async -> Result<SetkaPlusPaymentProcessResult, ClientProxyError> {
        do {
            let payload = SetkaPlusProcessYooMoneyPaymentPayload(requestID: requestID,
                                                                 moneySource: moneySource,
                                                                 planID: planID)
            let body = try JSONEncoder().encode(payload)
            let data = try await performSetkaPlusRequest(method: "POST",
                                                         path: "/user/\(encodedUserID())/setka_plus/payments/yoomoney/process",
                                                         body: body)
            let response = try JSONDecoder().decode(SetkaPlusPaymentProcessResult.self, from: data)
            return .success(response)
        } catch {
            MXLog.error("Failed processing Setka Plus YooMoney payment with error: \(error)")
            return .failure(.sdkError(error))
        }
    }
    
    func roomDirectorySearchProxy() -> RoomDirectorySearchProxyProtocol {
        RoomDirectorySearchProxy(roomDirectorySearch: client.roomDirectorySearch(), appSettings: appSettings)
    }
    
    func resolveRoomAlias(_ alias: String) async -> Result<ResolvedRoomAlias, ClientProxyError> {
        do {
            guard let resolvedAlias = try await client.resolveRoomAlias(roomAlias: alias) else {
                MXLog.error("Failed resolving room alias, is nil")
                return .failure(.failedResolvingRoomAlias)
            }
            
            // Resolving aliases is done through the directory/room API which returns too many / all known
            // vias, which in turn results in invalid join requests. Trim them to something manageable
            // https://github.com/element-hq/synapse/issues/17298
            let limitedAlias = ResolvedRoomAlias(roomId: resolvedAlias.roomId, servers: Array(resolvedAlias.servers.prefix(50)))
            
            return .success(limitedAlias)
        } catch {
            MXLog.error("Failed resolving room alias: \(alias) with error: \(error)")
            return .failure(.sdkError(error))
        }
    }
    
    func isAliasAvailable(_ alias: String) async -> Result<Bool, ClientProxyError> {
        do {
            let result = try await client.isRoomAliasAvailable(alias: alias)
            return .success(result)
        } catch {
            MXLog.error("Failed checking if alias: \(alias) is available with error: \(error)")
            return .failure(.sdkError(error))
        }
    }
    
    func clearCaches() async -> Result<Void, ClientProxyError> {
        do {
            return try await .success(client.clearCaches(syncService: syncService))
        } catch {
            MXLog.error("Failed clearing client caches with error: \(error)")
            return .failure(.sdkError(error))
        }
    }
    
    func optimizeStores() async -> Result<Void, ClientProxyError> {
        do {
            return try await .success(client.optimizeStores())
        } catch {
            MXLog.error("Failed optimizing client stores with error: \(error)")
            return .failure(.sdkError(error))
        }
    }
    
    func storeSizes() async -> Result<StoreSizes, ClientProxyError> {
        do {
            return try await .success(client.getStoreSizes())
        } catch {
            MXLog.error("Failed optimizing client stores with error: \(error)")
            return .failure(.sdkError(error))
        }
    }
    
    func fetchMediaPreviewConfiguration() async -> Result<MediaPreviewConfig?, ClientProxyError> {
        do {
            let config = try await client.fetchMediaPreviewConfig()
            return .success(config)
        } catch {
            MXLog.error("Failed fetching media preview config with error: \(error)")
            return .failure(.sdkError(error))
        }
    }
        
    // MARK: Ignored users
    
    func ignoreUser(_ userID: String) async -> Result<Void, ClientProxyError> {
        do {
            try await client.ignoreUser(userId: userID)
            return .success(())
        } catch {
            MXLog.error("Failed ignoring user with error: \(error)")
            return .failure(.sdkError(error))
        }
    }
    
    func unignoreUser(_ userID: String) async -> Result<Void, ClientProxyError> {
        do {
            try await client.unignoreUser(userId: userID)
            return .success(())
        } catch {
            MXLog.error("Failed unignoring user with error: \(error)")
            return .failure(.sdkError(error))
        }
    }
    
    // MARK: Recently visited rooms
    
    func trackRecentlyVisitedRoom(_ roomID: String) async -> Result<Void, ClientProxyError> {
        do {
            try await client.trackRecentlyVisitedRoom(room: roomID)
            return .success(())
        } catch {
            MXLog.error("Failed tracking recently visited room: \(roomID) with error: \(error)")
            return .failure(.sdkError(error))
        }
    }
    
    func recentlyVisitedRooms(filter: (JoinedRoomProxyProtocol) -> Bool) async -> [JoinedRoomProxyProtocol] {
        let maxResultsToReturn = 5
        
        guard case let .success(roomIdentifiers) = await recentlyVisitedRoomIDs() else {
            return []
        }
        
        var rooms: [JoinedRoomProxyProtocol] = []
        
        for roomID in roomIdentifiers {
            guard case let .joined(roomProxy) = await roomForIdentifier(roomID),
                  filter(roomProxy) else {
                continue
            }
            
            rooms.append(roomProxy)
            
            if rooms.count >= maxResultsToReturn {
                return rooms
            }
        }
        
        return rooms
    }
    
    func recentConversationCounterparts() async -> [UserProfileProxy] {
        let maxResultsToReturn = 5
        
        guard case let .success(roomIdentifiers) = await recentlyVisitedRoomIDs() else {
            return []
        }
        
        var users: OrderedSet<UserProfileProxy> = []
        
        for roomID in roomIdentifiers {
            guard case let .joined(roomProxy) = await roomForIdentifier(roomID),
                  roomProxy.infoPublisher.value.isDirect,
                  let members = await roomProxy.members() else {
                continue
            }
            
            for member in members where member.isActive && member.userID != userID {
                users.append(.init(userID: member.userID, displayName: member.displayName, avatarURL: member.avatarURL))
                
                // Return early to avoid unnecessary work
                if users.count >= maxResultsToReturn {
                    return users.elements
                }
            }
        }
        
        return users.elements
    }
    
    private func recentlyVisitedRoomIDs() async -> Result<[String], ClientProxyError> {
        do {
            let result = try await client.getRecentlyVisitedRooms()
            return .success(result)
        } catch {
            MXLog.error("Failed retrieving recently visited rooms with error: \(error)")
            return .failure(.sdkError(error))
        }
    }
    
    // MARK: Moderation & Safety
    
    func setTimelineMediaVisibility(_ value: TimelineMediaVisibility) async -> Result<Void, ClientProxyError> {
        do {
            try await client.setMediaPreviewDisplayPolicy(policy: value.rustValue)
            return .success(())
        } catch {
            MXLog.error("Failed to set timeline media visibility: \(error)")
            return .failure(.sdkError(error))
        }
    }
    
    func setHideInviteAvatars(_ value: Bool) async -> Result<Void, ClientProxyError> {
        do {
            try await client.setInviteAvatarsDisplayPolicy(policy: value ? .off : .on)
            return .success(())
        } catch {
            MXLog.error("Failed to set hide invite avatars: \(error)")
            return .failure(.sdkError(error))
        }
    }
    
    // MARK: - Private
    
    private func cacheAccountURL() async {
        // Calling this function for the first time will cache the account URL in volatile memory for 24 hrs on the SDK.
        _ = try? await client.accountUrl(action: nil)
    }
    
    private func updateVerificationState(_ verificationState: VerificationState) async {
        let verificationState: SessionVerificationState = switch verificationState {
        case .unknown:
            .unknown
        case .unverified:
            .unverified
        case .verified:
            .verified
        }
        
        // The session verification controller requires the user's identity which
        // isn't available before a keys query response. Use the verification
        // state updates as an aproximation for when that happens.
        await buildSessionVerificationControllerProxyIfPossible(verificationState: verificationState)
        
        // Only update the session verification state after creating a session
        // verification proxy to avoid race conditions
        verificationStateSubject.send(verificationState)
    }
    
    private func buildSessionVerificationControllerProxyIfPossible(verificationState: SessionVerificationState) async {
        guard sessionVerificationController == nil, verificationState != .unknown else {
            return
        }
        
        do {
            let sessionVerificationController = try await client.getSessionVerificationController()
            self.sessionVerificationController = SessionVerificationControllerProxy(sessionVerificationController: sessionVerificationController)
        } catch {
            MXLog.error("Failed retrieving session verification controller proxy with error: \(error)")
        }
    }

    private func loadUserAvatarURLFromCache() {
        loadCachedAvatarURLTask = Task {
            do {
                let urlString = try await self.client.cachedAvatarUrl()
                guard !Task.isCancelled else { return }
                self.userAvatarURLSubject.value = urlString.flatMap(URL.init)
            } catch {
                MXLog.error("Failed to look for the avatar url in the cache: \(error)")
            }
        }
    }
    
    private func createSyncServiceStateObserver(_ syncService: SyncService) -> TaskHandle {
        syncService.state(listener: SDKListener { [weak self] state in
            guard let self else { return }
            
            MXLog.info("Received sync service update: \(state)")
            
            switch state {
            case .running, .terminated, .idle:
                homeserverReachabilitySubject.send(.reachable)
            case .offline:
                homeserverReachabilitySubject.send(.unreachable)
            case .error:
                restartSync()
            }
        })
    }
    
    private func createMediaPreviewConfigObserver() async -> TaskHandle? {
        do {
            return try await client.subscribeToMediaPreviewConfig(listener: SDKListener { [weak self] config in
                guard let self else { return }
                
                if let config {
                    timelineMediaVisibilitySubject.send(config.mediaPreviewVisibility)
                    hideInviteAvatarsSubject.send(config.hideInviteAvatars)
                } else {
                    // return default values
                    timelineMediaVisibilitySubject.send(.always)
                    hideInviteAvatarsSubject.send(false)
                }
            })
        } catch {
            MXLog.error("Failed creating media preview config observer: \(error)")
            return nil
        }
    }

    private func createRoomListServiceObserver(_ roomListService: RoomListService) -> TaskHandle {
        roomListService.state(listener: SDKListener { [weak self] state in
            guard let self else { return }
            
            MXLog.info("Received room list update: \(state)")
            
            guard state != .error,
                  state != .terminated else {
                // The sync service is responsible of handling error and termination
                return
            }
            
            // Hide the sync spinner as soon as we get any update back
            actionsSubject.send(.receivedSyncUpdate)
            
            if ignoredUsersSubject.value == nil {
                updateIgnoredUsers()
            }
        })
    }
    
    private func createRoomListLoadingStateUpdateObserver(_ roomListService: RoomListService) -> TaskHandle {
        roomListService.syncIndicator(delayBeforeShowingInMs: 1000, delayBeforeHidingInMs: 0, listener: SDKListener { [weak self] state in
            guard let self else { return }
            
            switch state {
            case .show:
                loadingStateSubject.send(.loading)
            case .hide:
                loadingStateSubject.send(.notLoading)
            }
        })
    }
    
    private func buildRoomForIdentifier(_ roomID: String) async -> RoomProxyType? {
        do {
            guard let room = try client.getRoom(roomId: roomID) else {
                return nil
            }
            
            switch room.membership() {
            case .invited:
                return try await .invited(InvitedRoomProxy(room: room))
            case .knocked:
                guard appSettings.knockingEnabled else {
                    return nil
                }
                
                return try await .knocked(KnockedRoomProxy(room: room))
            case .joined:
                let roomProxy = try await JoinedRoomProxy(roomListService: roomListService,
                                                          room: room,
                                                          appSettings: appSettings,
                                                          analyticsService: analyticsService)
                
                return .joined(roomProxy)
            case .left:
                return .left
            case .banned:
                return try await .banned(BannedRoomProxy(room: room))
            }
        } catch {
            MXLog.error("Failed retrieving room: \(roomID), with error: \(error)")
            return nil
        }
    }
    
    private func waitForRoomToSync(roomID: String, timeout: Duration = .seconds(10)) async {
        MXLog.info("Wait for \(roomID)")
        let runner = ExpiringTaskRunner { [weak self] in
            guard let self else { return }
            
            do {
                _ = try await client.awaitRoomRemoteEcho(roomId: roomID)
                MXLog.info("Wait for \(roomID) got remote echo.")
            } catch {
                MXLog.info("Failed waiting for remote echo in \(roomID): \(error)")
            }
        }
        
        do {
            try await runner.run(timeout: timeout)
        } catch {
            MXLog.info("Wait for \(roomID) failed: \(error)")
        }
    }

    private func updateIgnoredUsers() {
        Task {
            do {
                let ignoredUsers = try await client.ignoredUsers()
                ignoredUsersSubject.send(ignoredUsers)
            } catch {
                MXLog.error("Failed fetching ignored users with error: \(error)")
            }
        }
    }
    
    // MARK: - Crypto
    
    func ed25519Base64() async -> String? {
        await client.encryption().ed25519Key()
    }
    
    func curve25519Base64() async -> String? {
        await client.encryption().curve25519Key()
    }
    
    func pinUserIdentity(_ userID: String) async -> Result<Void, ClientProxyError> {
        MXLog.info("Pinning current identity for user: \(userID)")
        
        do {
            guard let userIdentity = try await client.encryption().userIdentity(userId: userID, fallbackToServer: true) else {
                MXLog.error("Failed retrieving identity for user: \(userID)")
                return .failure(.failedRetrievingUserIdentity)
            }
            
            return try await .success(userIdentity.pin())
        } catch {
            MXLog.error("Failed pinning current identity for user: \(error)")
            return .failure(.sdkError(error))
        }
    }
    
    func withdrawUserIdentityVerification(_ userID: String) async -> Result<Void, ClientProxyError> {
        MXLog.info("Withdrawing current identity verification for user: \(userID)")
        
        do {
            guard let userIdentity = try await client.encryption().userIdentity(userId: userID, fallbackToServer: true) else {
                MXLog.error("Failed retrieving identity for user: \(userID)")
                return .failure(.failedRetrievingUserIdentity)
            }
            
            return try await .success(userIdentity.withdrawVerification())
        } catch {
            MXLog.error("Failed withdrawing current identity verification for user: \(error)")
            return .failure(.sdkError(error))
        }
    }
    
    func resetIdentity() async -> Result<IdentityResetHandle?, ClientProxyError> {
        do {
            return try await .success(client.encryption().resetIdentity())
        } catch {
            return .failure(.sdkError(error))
        }
    }
    
    func userIdentity(for userID: String, fallBackToServer: Bool) async -> Result<UserIdentityProxyProtocol?, ClientProxyError> {
        do {
            return try await .success(client.encryption().userIdentity(userId: userID, fallbackToServer: fallBackToServer).map(UserIdentityProxy.init))
        } catch {
            MXLog.error("Failed retrieving user identity: \(error)")
            return .failure(.sdkError(error))
        }
    }

    private func encodedUserID() -> String {
        encodedPathSegment(userID)
    }
    
    private func encodedPathSegment(_ value: String) -> String {
        let allowedCharacters = CharacterSet(charactersIn: "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~")
        return value.addingPercentEncoding(withAllowedCharacters: allowedCharacters) ?? value
    }
    
    private func performContactsRequest(method: String,
                                        path: String,
                                        body: Data? = nil) async throws -> Data {
        let (data, response) = try await performUserMetadataRequest(method: method, path: path, body: body)
        guard 200..<300 ~= response.statusCode else {
            throw ClientProxyError.invalidResponse
        }
        
        return data
    }
    
    private func performSetkaPlusRequest(method: String,
                                         path: String,
                                         body: Data? = nil) async throws -> Data {
        let (data, response) = try await performUserMetadataRequest(method: method, path: path, body: body)
        guard 200..<300 ~= response.statusCode else {
            throw ClientProxyError.invalidResponse
        }
        
        return data
    }
    
    private func performUserMetadataRequest(method: String,
                                            path: String,
                                            body: Data? = nil) async throws -> (Data, HTTPURLResponse) {
        let session = try client.session()
        let baseURLString = homeserver.hasSuffix("/") ? String(homeserver.dropLast()) : homeserver
        guard let url = URL(string: "\(baseURLString)/_matrix/client/v3\(path)") else {
            throw ClientProxyError.invalidServerName
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("Bearer \(session.accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        
        if let body {
            request.httpBody = body
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }
        
        let (data, response) = try await URLSession.shared.dataWithRetry(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw ClientProxyError.invalidResponse
        }
        
        return (data, httpResponse)
    }
    
    private func decodeSetkaPlusStatusEmojiResponse(_ data: Data,
                                                    fallback: SetkaPlusStatusEmoji = .init(emoji: nil, packID: nil, stickerID: nil, updatedAt: nil)) throws -> SetkaPlusStatusEmoji {
        guard !data.isEmpty else {
            return fallback
        }
        
        let decoded = try JSONDecoder().decode(SetkaPlusStatusEmoji.self, from: data)
        let hasPayload = [decoded.emoji, decoded.packID, decoded.stickerID].contains { value in
            guard let value else { return false }
            return !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        } || decoded.updatedAt != nil
        
        return hasPayload ? decoded : fallback
    }

    private func decodeSetkaPlusStickerPackResponse(_ data: Data,
                                                    fallback: SetkaPlusStickerPack? = nil) throws -> SetkaPlusStickerPack {
        if let direct = try? JSONDecoder().decode(SetkaPlusStickerPack.self, from: data) {
            return direct
        }

        if let wrapped = try? JSONDecoder().decode(SetkaPlusStickerPackWrappedResponse.self, from: data),
           let pack = wrapped.pack ?? wrapped.data ?? wrapped.value {
            return pack
        }

        if let fallback {
            return fallback
        }

        throw ClientProxyError.invalidResponse
    }

    private func decodeSetkaPlusSharedStickerPackResponse(_ data: Data) throws -> SetkaPlusStickerPack {
        if let wrapped = try? JSONDecoder().decode(SetkaPlusSharedStickerPackResponse.self, from: data),
           let pack = wrapped.pack ?? wrapped.data ?? wrapped.value {
            return pack
        }

        return try decodeSetkaPlusStickerPackResponse(data)
    }

    private func decodeSetkaPlusShareLinkResponse(_ data: Data) throws -> String {
        if let direct = try? JSONDecoder().decode(SetkaPlusShareLinkResponse.self, from: data),
           let url = [direct.url, direct.shareURL, direct.link]
           .compactMap({ $0?.trimmingCharacters(in: .whitespacesAndNewlines) })
           .first(where: { !$0.isEmpty }) {
            return url
        }

        if let text = String(data: data, encoding: .utf8)?
            .trimmingCharacters(in: .whitespacesAndNewlines),
            !text.isEmpty,
            text.hasPrefix("http") {
            return text
        }

        throw ClientProxyError.invalidResponse
    }

    private func isStickerPackAlreadyAddedResponse(statusCode: Int, body: Data) -> Bool {
        guard statusCode == 400 || statusCode == 403 || statusCode == 404 else {
            return false
        }

        guard !body.isEmpty,
              let text = String(data: body, encoding: .utf8)?.lowercased() else {
            return false
        }

        let markers = [
            "already",
            "exists",
            "duplicate",
            "added",
            "already_added",
            "already exists"
        ]
        return markers.contains { text.contains($0) }
    }
}

private struct ContactsResponse: Decodable {
    let rooms: [String: ContactMetadataPayload]
}

private struct SetkaPlusPlansResponse: Decodable {
    let plans: [SetkaPlusPlan]
}

private struct SetkaPlusPaymentsResponse: Decodable {
    let payments: [SetkaPlusPayment]
}

private struct SetkaPlusStickerPacksResponse: Decodable {
    let packs: [SetkaPlusStickerPack]
}

private struct SetkaPlusStickerPackWrappedResponse: Decodable {
    let pack: SetkaPlusStickerPack?
    let data: SetkaPlusStickerPack?
    let value: SetkaPlusStickerPack?
}

private struct SetkaPlusSharedStickerPackResponse: Decodable {
    let pack: SetkaPlusStickerPack?
    let data: SetkaPlusStickerPack?
    let value: SetkaPlusStickerPack?
}

private struct SetkaPlusShareLinkResponse: Decodable {
    let url: String?
    let shareURL: String?
    let link: String?

    enum CodingKeys: String, CodingKey {
        case url
        case shareURL = "share_url"
        case link
    }
}

private struct SetkaPlusStickerPackSavePayload: Codable {
    let name: String
    let kind: String
    let stickers: [SetkaPlusStickerItem]
}

private struct SetkaPlusCreateYooMoneyPaymentPayload: Codable {
    let amount: Double?
    let description: String?
    let planID: String?
    
    enum CodingKeys: String, CodingKey {
        case amount
        case description
        case planID = "plan_id"
    }
}

private struct SetkaPlusProcessYooMoneyPaymentPayload: Codable {
    let requestID: String
    let moneySource: String
    let planID: String?
    
    enum CodingKeys: String, CodingKey {
        case requestID = "request_id"
        case moneySource = "money_source"
        case planID = "plan_id"
    }
}

private struct SetkaPlusStatusEmojiPayload: Codable {
    let emoji: String?
    let packID: String?
    let stickerID: String?

    enum CodingKeys: String, CodingKey {
        case emoji
        case packID = "pack_id"
        case stickerID = "sticker_id"
    }
}

private struct SetkaPlusAddStickerPackPayload: Codable {
    let packID: String

    enum CodingKeys: String, CodingKey {
        case packID = "pack_id"
    }
}

private struct ContactMetadataPayload: Codable {
    let displayName: String?
    let userID: String?
    let email: String?
    let phone: String?
    
    enum CodingKeys: String, CodingKey {
        case displayName = "display_name"
        case userID = "user_id"
        case email
        case phone
    }
}

private struct RoomWallpaperMetadataPayload: Codable {
    private struct DecodedFields {
        let type: String?
        let theme: String?
        let image: String?
        let data: String?
        let contentType: String?
    }
    
    let type: String?
    let theme: String?
    let image: String?
    let data: String?
    let contentType: String?
    
    enum CodingKeys: String, CodingKey {
        case type
        case theme
        case image
        case url
        case path
        case imageURL = "image_url"
        case data
        case contentType = "content_type"
        case wallpaper
        case roomWallpaper = "room_wallpaper"
        case value
    }
    
    init(type: String?, theme: String?, image: String?, data: String?, contentType: String?) {
        self.type = type
        self.theme = theme
        self.image = image
        self.data = data
        self.contentType = contentType
    }
    
    init(model: RoomWallpaperMetadata) {
        self.init(type: model.type,
                  theme: model.theme,
                  image: model.image,
                  data: model.data,
                  contentType: model.contentType)
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        if let decoded = Self.decodeFields(from: container) {
            type = decoded.type
            theme = decoded.theme
            image = decoded.image
            data = decoded.data
            contentType = decoded.contentType
            return
        }
        
        for nestedKey in [CodingKeys.wallpaper, .roomWallpaper, .value] {
            if let nestedContainer = try? container.nestedContainer(keyedBy: CodingKeys.self, forKey: nestedKey),
               let decoded = Self.decodeFields(from: nestedContainer) {
                type = decoded.type
                theme = decoded.theme
                image = decoded.image
                data = decoded.data
                contentType = decoded.contentType
                return
            }
        }
        
        type = nil
        theme = nil
        image = nil
        data = nil
        contentType = nil
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(type, forKey: .type)
        try container.encodeIfPresent(theme, forKey: .theme)
        try container.encodeIfPresent(image, forKey: .image)
        try container.encodeIfPresent(data, forKey: .data)
        try container.encodeIfPresent(contentType, forKey: .contentType)
    }
    
    var model: RoomWallpaperMetadata {
        .init(type: type,
              theme: theme,
              image: image,
              data: data,
              contentType: contentType)
    }
    
    private static func decodeFields(from container: KeyedDecodingContainer<CodingKeys>) -> DecodedFields? {
        let type = try? container.decodeIfPresent(String.self, forKey: .type)
        let theme = try? container.decodeIfPresent(String.self, forKey: .theme)
        
        let imageFromImageKey = try? container.decodeIfPresent(String.self, forKey: .image)
        let imageFromURLKey = try? container.decodeIfPresent(String.self, forKey: .url)
        let imageFromPathKey = try? container.decodeIfPresent(String.self, forKey: .path)
        let imageFromImageURLKey = try? container.decodeIfPresent(String.self, forKey: .imageURL)
        let image = imageFromImageKey ?? imageFromURLKey ?? imageFromPathKey ?? imageFromImageURLKey
        
        let data = try? container.decodeIfPresent(String.self, forKey: .data)
        let contentType = try? container.decodeIfPresent(String.self, forKey: .contentType)
        
        guard type != nil || theme != nil || image != nil || data != nil || contentType != nil else {
            return nil
        }
        
        return .init(type: type,
                     theme: theme,
                     image: image,
                     data: data,
                     contentType: contentType)
    }
}

private final class ClientDelegateWrapper: ClientDelegate {
    private let authErrorCallback: @Sendable (Bool) -> Void
    private let backgroundTaskErrorCallback: @Sendable (MatrixRustSDK.BackgroundTaskFailureReason) -> Void
    
    init(authErrorCallback: @escaping @Sendable (Bool) -> Void,
         backgroundTaskErrorCallback: @escaping @Sendable (MatrixRustSDK.BackgroundTaskFailureReason) -> Void) {
        self.authErrorCallback = authErrorCallback
        self.backgroundTaskErrorCallback = backgroundTaskErrorCallback
    }
    
    // MARK: - ClientDelegate

    func didReceiveAuthError(isSoftLogout: Bool) {
        MXLog.error("Received authentication error, softlogout=\(isSoftLogout)")
        authErrorCallback(isSoftLogout)
    }
    
    func didRefreshTokens() {
        MXLog.info("Delegating session updates to the ClientSessionDelegate.")
    }
    
    func onBackgroundTaskErrorReport(taskName: String, error: MatrixRustSDK.BackgroundTaskFailureReason) {
        backgroundTaskErrorCallback(error)
    }
}

private final class ClientDecryptionErrorDelegate: UnableToDecryptDelegate {
    private let actionsSubject: PassthroughSubject<ClientProxyAction, Never>
    
    init(actionsSubject: PassthroughSubject<ClientProxyAction, Never>) {
        self.actionsSubject = actionsSubject
    }
    
    func onUtd(info: UnableToDecryptInfo) {
        actionsSubject.send(.receivedDecryptionError(info))
    }
}

private struct ClientProxyServices {
    let syncService: SyncService
    let roomListService: RoomListService
    let roomSummaryProvider: RoomSummaryProviderProtocol
    let alternateRoomSummaryProvider: RoomSummaryProviderProtocol
    let staticRoomSummaryProvider: StaticRoomSummaryProviderProtocol
    
    init(client: ClientProtocol,
         actionsSubject: PassthroughSubject<ClientProxyAction, Never>,
         notificationSettings: NotificationSettingsProxyProtocol,
         appSettings: AppSettings) async throws {
        let syncService = try await client
            .syncService()
            .withOfflineMode()
            .withSharePos(enable: true)
            .finish()
        
        let roomListService = syncService.roomListService()
        
        let roomMessageEventStringBuilder = RoomMessageEventStringBuilder(attributedStringBuilder: AttributedStringBuilder(cacheKey: "roomList",
                                                                                                                           mentionBuilder: PlainMentionBuilder()), destination: .roomList)
        let eventStringBuilder = try RoomEventStringBuilder(stateEventStringBuilder: RoomStateEventStringBuilder(userID: client.userId(), shouldDisambiguateDisplayNames: false),
                                                            messageEventStringBuilder: roomMessageEventStringBuilder,
                                                            shouldDisambiguateDisplayNames: false,
                                                            shouldPrefixSenderName: true)
        
        roomSummaryProvider = RoomSummaryProvider(roomListService: roomListService,
                                                  eventStringBuilder: eventStringBuilder,
                                                  name: "AllRooms",
                                                  shouldUpdateVisibleRange: true,
                                                  notificationSettings: notificationSettings,
                                                  appSettings: appSettings)
        try await roomSummaryProvider.setRoomList(roomListService.allRooms())
        
        alternateRoomSummaryProvider = RoomSummaryProvider(roomListService: roomListService,
                                                           eventStringBuilder: eventStringBuilder,
                                                           name: "AlternateAllRooms",
                                                           notificationSettings: notificationSettings,
                                                           appSettings: appSettings)
        try await alternateRoomSummaryProvider.setRoomList(roomListService.allRooms())
        
        staticRoomSummaryProvider = RoomSummaryProvider(roomListService: roomListService,
                                                        eventStringBuilder: eventStringBuilder,
                                                        name: "StaticAllRooms",
                                                        roomListPageSize: .max,
                                                        notificationSettings: notificationSettings,
                                                        appSettings: appSettings)
        try await staticRoomSummaryProvider.setRoomList(roomListService.allRooms())
        
        self.syncService = syncService
        self.roomListService = roomListService
    }
}

private extension MediaPreviewConfig {
    var mediaPreviewVisibility: TimelineMediaVisibility {
        switch mediaPreviews {
        case .on:
            .always
        case .private:
            .privateOnly
        case .off:
            .never
        case .none:
            .always
        }
    }
    
    var hideInviteAvatars: Bool {
        switch inviteAvatars {
        case .off:
            true
        case .on:
            false
        case .none:
            true
        }
    }
}

private extension TimelineMediaVisibility {
    var rustValue: MediaPreviews {
        switch self {
        case .always:
            .on
        case .never:
            .off
        case .privateOnly:
            .private
        }
    }
}

private extension CreateRoomAccessType {
    var isEncrypted: Bool {
        switch self {
        case .public:
            false
        default:
            true
        }
    }
    
    var visibility: RoomVisibility {
        isVisibilityPrivate ? .private : .public
    }
    
    var preset: RoomPreset {
        isVisibilityPrivate ? .privateChat : .publicChat
    }
    
    var historyVisibilityOverride: RoomHistoryVisibility? {
        isVisibilityPrivate ? .invited : nil
    }
    
    var joinRuleOverride: JoinRule? {
        switch self {
        case .askToJoin:
            .knock
        case .spaceMembers(let spaceID):
            .restricted(rules: [.roomMembership(roomID: spaceID)])
        case .askToJoinWithSpaceMembers(let spaceID):
            .knockRestricted(rules: [.roomMembership(roomID: spaceID)])
        case .private, .public:
            nil
        }
    }
    
    var isAskToJoin: Bool {
        switch self {
        case .askToJoin, .askToJoinWithSpaceMembers:
            true
        default:
            false
        }
    }
}
