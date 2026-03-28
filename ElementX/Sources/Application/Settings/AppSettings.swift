//
// Copyright 2025 Element Creations Ltd.
// Copyright 2022-2025 New Vector Ltd.
//
// SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial.
// Please see LICENSE files in the repository root for full details.
//

#if IS_MAIN_APP
import EmbeddedElementCall
#endif

import Foundation
import SwiftUI

/// Common settings between app and NSE
protocol CommonSettingsProtocol: AnyObject {
    var lastNotificationBootTime: TimeInterval? { get set }
    var notificationSoundName: RemotePreference<UNNotificationSoundName> { get }
    
    var logLevel: LogLevel { get }
    var traceLogPacks: Set<TraceLogPack> { get }
    var bugReportRageshakeURL: RemotePreference<RageshakeConfiguration> { get }
    
    var enableOnlySignedDeviceIsolationMode: Bool { get }
    var enableKeyShareOnInvite: Bool { get }
    var threadsEnabled: Bool { get }
    var hideQuietNotificationAlerts: Bool { get }
}

enum AppBuildType {
    case debug
    case nightly
    case release
}

enum SetkaThemeMode: String, Codable, CaseIterable, Hashable {
    case system = "System"
    case light = "Light"
    case dark = "Dark"
    
    var appAppearance: AppAppearance {
        switch self {
        case .system:
            .system
        case .light:
            .light
        case .dark:
            .dark
        }
    }
}

enum SetkaHomeBackgroundStyle: String, Codable, CaseIterable, Hashable {
    case solid
    case gradient
    case image
}

enum SetkaHomeChatListStyle: String, Codable, CaseIterable, Hashable {
    case plain
    case bubble
}

struct SetkaThemeConfiguration: Codable, Equatable {
    var version: Int
    var themeMode: SetkaThemeMode
    var accentColorHex: String
    var uiScale: Double
    var messageScale: Double
    var bubbleRadiusDp: Int
    var bubbleWidthPercent: Int
    var timelineOverlayOpacityPercent: Int
    var composerBackgroundOpacityPercent: Int
    var wallpaperBlurDp: Int
    var showEncryptionStatus: Bool
    var topBarBackgroundColorHex: String
    var topBarTextColorHex: String
    var composerBackgroundColorHex: String
    var serviceBubbleColorHex: String
    var serviceTextColorHex: String
    var incomingBubbleColorHex: String
    var incomingBubbleGradientToColorHex: String?
    var outgoingBubbleColorHex: String
    var outgoingBubbleGradientToColorHex: String
    var homeBackgroundColorHex: String
    var homeBackgroundStyle: SetkaHomeBackgroundStyle
    var homeGradientFromColorHex: String
    var homeGradientToColorHex: String
    var homeWallpaperImagePath: String?
    var homeChatListStyle: SetkaHomeChatListStyle
    var homeChatListOpacityPercent: Int
    var defaultRoomWallpaperStyle: String
    var enableChatAnimations: Bool
    var enableBlurEffects: Bool
    var initialTimelineItemCount: Int
    var disableLiquidGlassEffects: Bool
    
    static let `default` = SetkaThemeConfiguration(version: 7,
                                                   themeMode: .system,
                                                   accentColorHex: "#0A84FF",
                                                   uiScale: 1.0,
                                                   messageScale: 1.0,
                                                   bubbleRadiusDp: 10,
                                                   bubbleWidthPercent: 78,
                                                   timelineOverlayOpacityPercent: 20,
                                                   composerBackgroundOpacityPercent: 92,
                                                   wallpaperBlurDp: 12,
                                                   showEncryptionStatus: false,
                                                   topBarBackgroundColorHex: "#F6F7F8",
                                                   topBarTextColorHex: "#111111",
                                                   composerBackgroundColorHex: "#FFFFFF",
                                                   serviceBubbleColorHex: "#DCE5EA",
                                                   serviceTextColorHex: "#2A2A2A",
                                                   incomingBubbleColorHex: "#FFFFFF",
                                                   incomingBubbleGradientToColorHex: nil,
                                                   outgoingBubbleColorHex: "#DCEBFF",
                                                   outgoingBubbleGradientToColorHex: "#CFE3FF",
                                                   homeBackgroundColorHex: "#F2F5FA",
                                                   homeBackgroundStyle: .solid,
                                                   homeGradientFromColorHex: "#0F172A",
                                                   homeGradientToColorHex: "#111827",
                                                   homeWallpaperImagePath: nil,
                                                   homeChatListStyle: .plain,
                                                   homeChatListOpacityPercent: 84,
                                                   defaultRoomWallpaperStyle: "none",
                                                   enableChatAnimations: true,
                                                   enableBlurEffects: true,
                                                   initialTimelineItemCount: 20,
                                                   disableLiquidGlassEffects: false)
    
    init(version: Int,
         themeMode: SetkaThemeMode,
         accentColorHex: String,
         uiScale: Double,
         messageScale: Double,
         bubbleRadiusDp: Int,
         bubbleWidthPercent: Int,
         timelineOverlayOpacityPercent: Int,
         composerBackgroundOpacityPercent: Int,
         wallpaperBlurDp: Int,
         showEncryptionStatus: Bool,
         topBarBackgroundColorHex: String,
         topBarTextColorHex: String,
         composerBackgroundColorHex: String,
         serviceBubbleColorHex: String,
         serviceTextColorHex: String,
         incomingBubbleColorHex: String,
         incomingBubbleGradientToColorHex: String?,
         outgoingBubbleColorHex: String,
         outgoingBubbleGradientToColorHex: String,
         homeBackgroundColorHex: String,
         homeBackgroundStyle: SetkaHomeBackgroundStyle,
         homeGradientFromColorHex: String,
         homeGradientToColorHex: String,
         homeWallpaperImagePath: String?,
         homeChatListStyle: SetkaHomeChatListStyle,
         homeChatListOpacityPercent: Int,
         defaultRoomWallpaperStyle: String,
         enableChatAnimations: Bool,
         enableBlurEffects: Bool,
         initialTimelineItemCount: Int,
         disableLiquidGlassEffects: Bool) {
        self.version = version
        self.themeMode = themeMode
        self.accentColorHex = accentColorHex
        self.uiScale = uiScale
        self.messageScale = messageScale
        self.bubbleRadiusDp = bubbleRadiusDp
        self.bubbleWidthPercent = bubbleWidthPercent
        self.timelineOverlayOpacityPercent = timelineOverlayOpacityPercent
        self.composerBackgroundOpacityPercent = composerBackgroundOpacityPercent
        self.wallpaperBlurDp = wallpaperBlurDp
        self.showEncryptionStatus = showEncryptionStatus
        self.topBarBackgroundColorHex = topBarBackgroundColorHex
        self.topBarTextColorHex = topBarTextColorHex
        self.composerBackgroundColorHex = composerBackgroundColorHex
        self.serviceBubbleColorHex = serviceBubbleColorHex
        self.serviceTextColorHex = serviceTextColorHex
        self.incomingBubbleColorHex = incomingBubbleColorHex
        self.incomingBubbleGradientToColorHex = incomingBubbleGradientToColorHex
        self.outgoingBubbleColorHex = outgoingBubbleColorHex
        self.outgoingBubbleGradientToColorHex = outgoingBubbleGradientToColorHex
        self.homeBackgroundColorHex = homeBackgroundColorHex
        self.homeBackgroundStyle = homeBackgroundStyle
        self.homeGradientFromColorHex = homeGradientFromColorHex
        self.homeGradientToColorHex = homeGradientToColorHex
        self.homeWallpaperImagePath = homeWallpaperImagePath
        self.homeChatListStyle = homeChatListStyle
        self.homeChatListOpacityPercent = homeChatListOpacityPercent
        self.defaultRoomWallpaperStyle = defaultRoomWallpaperStyle
        self.enableChatAnimations = enableChatAnimations
        self.enableBlurEffects = enableBlurEffects
        self.initialTimelineItemCount = initialTimelineItemCount
        self.disableLiquidGlassEffects = disableLiquidGlassEffects
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let defaults = SetkaThemeConfiguration.default
        
        version = try container.decodeIfPresent(Int.self, forKey: .version) ?? defaults.version
        themeMode = try container.decodeIfPresent(SetkaThemeMode.self, forKey: .themeMode) ?? defaults.themeMode
        accentColorHex = try container.decodeIfPresent(String.self, forKey: .accentColorHex) ?? defaults.accentColorHex
        uiScale = try container.decodeIfPresent(Double.self, forKey: .uiScale) ?? defaults.uiScale
        messageScale = try container.decodeIfPresent(Double.self, forKey: .messageScale) ?? defaults.messageScale
        bubbleRadiusDp = try container.decodeIfPresent(Int.self, forKey: .bubbleRadiusDp) ?? defaults.bubbleRadiusDp
        bubbleWidthPercent = try container.decodeIfPresent(Int.self, forKey: .bubbleWidthPercent) ?? defaults.bubbleWidthPercent
        timelineOverlayOpacityPercent = try container.decodeIfPresent(Int.self, forKey: .timelineOverlayOpacityPercent) ?? defaults.timelineOverlayOpacityPercent
        composerBackgroundOpacityPercent = try container.decodeIfPresent(Int.self, forKey: .composerBackgroundOpacityPercent) ?? defaults.composerBackgroundOpacityPercent
        wallpaperBlurDp = try container.decodeIfPresent(Int.self, forKey: .wallpaperBlurDp) ?? defaults.wallpaperBlurDp
        showEncryptionStatus = try container.decodeIfPresent(Bool.self, forKey: .showEncryptionStatus) ?? defaults.showEncryptionStatus
        topBarBackgroundColorHex = try container.decodeIfPresent(String.self, forKey: .topBarBackgroundColorHex) ?? defaults.topBarBackgroundColorHex
        topBarTextColorHex = try container.decodeIfPresent(String.self, forKey: .topBarTextColorHex) ?? defaults.topBarTextColorHex
        composerBackgroundColorHex = try container.decodeIfPresent(String.self, forKey: .composerBackgroundColorHex) ?? defaults.composerBackgroundColorHex
        serviceBubbleColorHex = try container.decodeIfPresent(String.self, forKey: .serviceBubbleColorHex) ?? defaults.serviceBubbleColorHex
        serviceTextColorHex = try container.decodeIfPresent(String.self, forKey: .serviceTextColorHex) ?? defaults.serviceTextColorHex
        incomingBubbleColorHex = try container.decodeIfPresent(String.self, forKey: .incomingBubbleColorHex) ?? defaults.incomingBubbleColorHex
        incomingBubbleGradientToColorHex = try container.decodeIfPresent(String.self, forKey: .incomingBubbleGradientToColorHex)
        outgoingBubbleColorHex = try container.decodeIfPresent(String.self, forKey: .outgoingBubbleColorHex) ?? defaults.outgoingBubbleColorHex
        outgoingBubbleGradientToColorHex = try container.decodeIfPresent(String.self, forKey: .outgoingBubbleGradientToColorHex) ?? defaults.outgoingBubbleGradientToColorHex
        homeBackgroundColorHex = try container.decodeIfPresent(String.self, forKey: .homeBackgroundColorHex) ?? defaults.homeBackgroundColorHex
        homeBackgroundStyle = try container.decodeIfPresent(SetkaHomeBackgroundStyle.self, forKey: .homeBackgroundStyle) ?? defaults.homeBackgroundStyle
        homeGradientFromColorHex = try container.decodeIfPresent(String.self, forKey: .homeGradientFromColorHex) ?? defaults.homeGradientFromColorHex
        homeGradientToColorHex = try container.decodeIfPresent(String.self, forKey: .homeGradientToColorHex) ?? defaults.homeGradientToColorHex
        homeWallpaperImagePath = try container.decodeIfPresent(String.self, forKey: .homeWallpaperImagePath)
        homeChatListStyle = try container.decodeIfPresent(SetkaHomeChatListStyle.self, forKey: .homeChatListStyle) ?? defaults.homeChatListStyle
        homeChatListOpacityPercent = try container.decodeIfPresent(Int.self, forKey: .homeChatListOpacityPercent) ?? defaults.homeChatListOpacityPercent
        defaultRoomWallpaperStyle = try container.decodeIfPresent(String.self, forKey: .defaultRoomWallpaperStyle) ?? defaults.defaultRoomWallpaperStyle
        enableChatAnimations = try container.decodeIfPresent(Bool.self, forKey: .enableChatAnimations) ?? defaults.enableChatAnimations
        enableBlurEffects = try container.decodeIfPresent(Bool.self, forKey: .enableBlurEffects) ?? defaults.enableBlurEffects
        initialTimelineItemCount = try container.decodeIfPresent(Int.self, forKey: .initialTimelineItemCount) ?? defaults.initialTimelineItemCount
        disableLiquidGlassEffects = try container.decodeIfPresent(Bool.self, forKey: .disableLiquidGlassEffects) ?? defaults.disableLiquidGlassEffects
    }
}

/// Store Element specific app settings.
final class AppSettings {
    private enum UserDefaultsKeys: String {
        case lastVersionLaunched
        case seenInvites
        case hasSeenSpacesAnnouncement
        case hasSeenNewSoundBanner
        case appLockNumberOfPINAttempts
        case appLockNumberOfBiometricAttempts
        case timelineStyle
        
        case analyticsConsentState
        case hasRunNotificationPermissionsOnboarding
        case hasRunIdentityConfirmationOnboarding
        
        case frequentlyUsedSystemEmojis
        
        case enableNotifications
        case enableInAppNotifications
        case pusherProfileTag
        case lastNotificationBootTime
        case logLevel
        case traceLogPacks
        case viewSourceEnabled
        case optimizeMediaUploads
        case appAppearance
        case setkaThemeConfiguration
        case sharePresence
        
        case elementCallBaseURLOverride
        
        case voiceMessagePlaybackSpeed
        
        // Feature flags
        case publicSearchEnabled
        case fuzzyRoomListSearchEnabled
        case lowPriorityFilterEnabled
        case enableOnlySignedDeviceIsolationMode
        case enableKeyShareOnInvite
        case knockingEnabled
        case threadsEnabled
        case developerOptionsEnabled
        case linkPreviewsEnabled
        case focusEventOnNotificationTap
        case linkNewDeviceEnabled
        case liveLocationSharingEnabled
        
        // Doug's tweaks 🔧
        case hideUnreadMessagesBadge
        case hideQuietNotificationAlerts
    }
    
    private static var suiteName: String = InfoPlistReader.main.appGroupIdentifier

    /// UserDefaults to be used on reads and writes.
    private static var store: UserDefaults! = UserDefaults(suiteName: suiteName)
    
    static var appBuildType: AppBuildType {
        #if DEBUG
        return .debug
        #else
        switch InfoPlistReader.main.baseBundleIdentifier {
        case "io.element.elementx.nightly":
            return .nightly
        default:
            return .release
        }
        #endif
    }
    
    static func resetAllSettings() {
        MXLog.warning("Resetting the AppSettings.")
        store.removePersistentDomain(forName: suiteName)
    }
    
    static func resetSessionSpecificSettings() {
        MXLog.warning("Resetting the user session specific AppSettings.")
        store.removeObject(forKey: UserDefaultsKeys.hasRunIdentityConfirmationOnboarding.rawValue)
    }
    
    static func configureWithSuiteName(_ name: String) {
        suiteName = name
        
        guard let userDefaults = UserDefaults(suiteName: name) else {
            fatalError("Fail to load shared UserDefaults")
        }
        
        store = userDefaults
    }
    
    // MARK: - Hooks
    
    // swiftlint:disable:next function_parameter_count
    func override(accountProviders: [String],
                  allowOtherAccountProviders: Bool,
                  hideBrandChrome: Bool,
                  pushGatewayBaseURL: URL,
                  oidcRedirectURL: URL,
                  websiteURL: URL,
                  logoURL: URL,
                  copyrightURL: URL,
                  acceptableUseURL: URL,
                  privacyURL: URL,
                  encryptionURL: URL,
                  deviceVerificationURL: URL,
                  chatBackupDetailsURL: URL,
                  identityPinningViolationDetailsURL: URL,
                  historySharingDetailsURL: URL,
                  elementWebHosts: [String],
                  accountProvisioningHost: String,
                  bugReportApplicationID: String,
                  analyticsTermsURL: URL?,
                  mapTilerConfiguration: MapTilerConfiguration) {
        self.accountProviders = accountProviders
        self.allowOtherAccountProviders = allowOtherAccountProviders
        self.hideBrandChrome = hideBrandChrome
        self.pushGatewayBaseURL = pushGatewayBaseURL
        self.oidcRedirectURL = oidcRedirectURL
        self.websiteURL = websiteURL
        self.logoURL = logoURL
        self.copyrightURL = copyrightURL
        self.acceptableUseURL = acceptableUseURL
        self.privacyURL = privacyURL
        self.encryptionURL = encryptionURL
        self.deviceVerificationURL = deviceVerificationURL
        self.chatBackupDetailsURL = chatBackupDetailsURL
        self.identityPinningViolationDetailsURL = identityPinningViolationDetailsURL
        self.historySharingDetailsURL = historySharingDetailsURL
        self.elementWebHosts = elementWebHosts
        self.accountProvisioningHost = accountProvisioningHost
        self.bugReportApplicationID = bugReportApplicationID
        self.analyticsTermsURL = analyticsTermsURL
        self.mapTilerConfiguration = mapTilerConfiguration
    }
    
    // MARK: - Application
    
    /// The last known version of the app that was launched on this device, which is
    /// used to detect when migrations should be run. When `nil` the app may have been
    /// deleted between runs so should clear data in the shared container and keychain.
    @UserPreference(key: UserDefaultsKeys.lastVersionLaunched, storageType: .userDefaults(store))
    var lastVersionLaunched: String?
        
    /// The Set of room identifiers of invites that the user already saw in the invites list.
    /// This Set is being used to implement badges for unread invites.
    @UserPreference(key: UserDefaultsKeys.seenInvites, defaultValue: [], storageType: .userDefaults(store))
    var seenInvites: Set<String>
    
    @UserPreference(key: UserDefaultsKeys.hasSeenSpacesAnnouncement, defaultValue: false, storageType: .userDefaults(store))
    var hasSeenSpacesAnnouncement
    
    /// Defaults to `true` for new users, and we use a migration to set it to `false` for existing users.
    @UserPreference(key: UserDefaultsKeys.hasSeenNewSoundBanner, defaultValue: true, storageType: .userDefaults(store))
    var hasSeenNewSoundBanner
    
    /// The initial set of account providers shown to the user in the authentication flow.
    ///
    /// Account provider is the friendly term for the server name. It should not contain an `https` prefix and should
    /// match the last part of the user ID. For example `example.com` and not `https://matrix.example.com`.
    private(set) var accountProviders = ["setka-matrix.ru"]
    /// Whether or not the user is allowed to manually enter their own account provider or must select from one of `defaultAccountProviders`.
    private(set) var allowOtherAccountProviders = false
    /// Whether the components surrounding the app brand/logo should be hidden or not
    private(set) var hideBrandChrome = false
    
    /// The task identifier used for background app refresh. Also used in main target's the Info.plist
    let backgroundAppRefreshTaskIdentifier = "io.element.elementx.background.refresh"

    /// A URL where users can go read more about the app.
    private(set) var websiteURL: URL = "https://element.io"
    /// A URL that contains the app's logo that may be used when showing content in a web view.
    private(set) var logoURL: URL = "https://element.io/mobile-icon.png"
    /// A URL that contains that app's copyright notice.
    private(set) var copyrightURL: URL = "https://element.io/copyright"
    /// A URL that contains the app's Terms of use.
    private(set) var acceptableUseURL: URL = "https://element.io/acceptable-use-policy-terms"
    /// A URL that contains the app's Privacy Policy.
    private(set) var privacyURL: URL = "https://element.io/privacy"
    /// A URL where users can go read more about encryption in general.
    private(set) var encryptionURL: URL = "https://element.io/help#encryption"
    /// A URL where users can go read more about device verification..
    private(set) var deviceVerificationURL: URL = "https://element.io/help#encryption-device-verification"
    /// A URL where users can go read more about the chat backup.
    private(set) var chatBackupDetailsURL: URL = "https://element.io/help#encryption5"
    /// A URL where users can go read more about identity pinning violations
    private(set) var identityPinningViolationDetailsURL: URL = "https://element.io/help#encryption18"
    /// A URL describing how history sharing works
    private(set) var historySharingDetailsURL: URL = "https://element.io/en/help#e2ee-history-sharing"

    /// Any domains that Element web may be hosted on - used for handling links.
    private(set) var elementWebHosts = ["app.element.io", "staging.element.io", "develop.element.io"]
    /// The domain that account provisioning links will be hosted on - used for handling the links.
    private(set) var accountProvisioningHost = "mobile.element.io"
    /// The App Store URL for Element Pro, shown to the user when a homeserver requires that app.
    /// **Note:** This property isn't overridable as it in unexpected for forks to come across the error (or to even have a "Pro" app).
    let elementProAppStoreURL: URL = "https://apps.apple.com/app/element-pro-for-work/id6502951615"
    
    @UserPreference(key: UserDefaultsKeys.appAppearance, defaultValue: .system, storageType: .userDefaults(store))
    var appAppearance: AppAppearance
    
    @UserPreference(key: UserDefaultsKeys.setkaThemeConfiguration, defaultValue: .default, storageType: .userDefaults(store))
    var setkaThemeConfiguration: SetkaThemeConfiguration
    
    // MARK: - Security
    
    /// The app must be locked with a PIN code as part of the authentication flow.
    let appLockIsMandatory = false
    /// The amount of time the app can remain in the background for without requesting the PIN/TouchID/FaceID.
    let appLockGracePeriod: TimeInterval = 0
    /// Any codes that the user isn't allowed to use for their PIN.
    let appLockPINCodeBlockList = ["0000", "1234"]
    /// The number of attempts the user has made to unlock the app with a PIN code (resets when unlocked).
    @UserPreference(key: UserDefaultsKeys.appLockNumberOfPINAttempts, defaultValue: 0, storageType: .userDefaults(store))
    var appLockNumberOfPINAttempts: Int
    
    // MARK: - Authentication
    
    /// Any pre-defined static client registrations for OIDC issuers.
    let oidcStaticRegistrations: [URL: String] = ["https://id.thirdroom.io/realms/thirdroom": "elementx"]
    /// The redirect URL used for OIDC.
    /// This auth server currently accepts only Element's app scheme for native clients.
    private(set) var oidcRedirectURL: URL = "io.element.elementx:/oidc/login"
    
    private(set) lazy var oidcConfiguration = OIDCConfiguration(clientName: InfoPlistReader.main.bundleDisplayName,
                                                                redirectURI: oidcRedirectURL,
                                                                clientURI: websiteURL,
                                                                logoURI: logoURL,
                                                                tosURI: acceptableUseURL,
                                                                policyURI: privacyURL,
                                                                staticRegistrations: oidcStaticRegistrations.mapKeys { $0.absoluteString })
    
    /// Whether or not the Create Account button is shown on the start screen.
    ///
    /// **Note:** Setting this to false doesn't prevent someone from creating an account when the selected homeserver's MAS allows registration.
    let showCreateAccountButton = true
    
    // MARK: - Notifications
    
    var pusherAppID: String {
        #if DEBUG
        InfoPlistReader.main.baseBundleIdentifier + ".ios.dev"
        #else
        InfoPlistReader.main.baseBundleIdentifier + ".ios.prod"
        #endif
    }
    
    private(set) var pushGatewayBaseURL: URL = "https://matrix.org"
    var pushGatewayNotifyEndpoint: URL {
        pushGatewayBaseURL.appending(path: "_matrix/push/v1/notify")
    }
    
    @UserPreference(key: UserDefaultsKeys.enableNotifications, defaultValue: true, storageType: .userDefaults(store))
    var enableNotifications

    @UserPreference(key: UserDefaultsKeys.enableInAppNotifications, defaultValue: true, storageType: .userDefaults(store))
    var enableInAppNotifications
    
    @UserPreference(key: UserDefaultsKeys.hideQuietNotificationAlerts, defaultValue: false, storageType: .userDefaults(store))
    var hideQuietNotificationAlerts

    /// Tag describing which set of device specific rules a pusher executes.
    @UserPreference(key: UserDefaultsKeys.pusherProfileTag, storageType: .userDefaults(store))
    var pusherProfileTag: String?
    
    /// The device's last boot time as recorded by the NSE.
    @UserPreference(key: UserDefaultsKeys.lastNotificationBootTime, storageType: .userDefaults(store))
    var lastNotificationBootTime: TimeInterval?
    
    /// The name of sound played when delivering noisy notifications.
    var notificationSoundName: RemotePreference<UNNotificationSoundName> = .init(.init("message.caf"))
    
    // MARK: - Logging
        
    @UserPreference(key: UserDefaultsKeys.logLevel, defaultValue: LogLevel.info, storageType: .userDefaults(store))
    var logLevel
    
    @UserPreference(key: UserDefaultsKeys.traceLogPacks, defaultValue: [], storageType: .userDefaults(store))
    var traceLogPacks: Set<TraceLogPack>
    
    // MARK: - Bug report
    
    let bugReportRageshakeURL: RemotePreference<RageshakeConfiguration> = .init(Secrets.rageshakeURL.map { .url(URL(string: $0)!) } ?? .disabled) // swiftlint:disable:this force_unwrapping
    let bugReportSentryURL: URL? = Secrets.sentryDSN.map { URL(string: $0)! } // swiftlint:disable:this force_unwrapping
    let bugReportSentryRustURL: URL? = Secrets.sentryRustDSN.map { URL(string: $0)! } // swiftlint:disable:this force_unwrapping
    /// The name allocated by the bug report server
    private(set) var bugReportApplicationID = "element-x-ios"
    
    // MARK: - Analytics
    
    /// The configuration to use for analytics. Set to `nil` to disable analytics.
    let analyticsConfiguration: AnalyticsConfiguration? = AppSettings.makeAnalyticsConfiguration()
    /// The URL to open with more information about analytics terms. When this is `nil` the "Learn more" link will be hidden.
    private(set) var analyticsTermsURL: URL? = "https://element.io/cookie-policy"
    /// Whether or not there the app is able ask for user consent to enable analytics or sentry reporting.
    var canPromptForAnalytics: Bool {
        analyticsConfiguration != nil || bugReportSentryURL != nil
    }
    
    private static func makeAnalyticsConfiguration() -> AnalyticsConfiguration? {
        guard let host = Secrets.postHogHost, let apiKey = Secrets.postHogAPIKey else { return nil }
        return AnalyticsConfiguration(host: host, apiKey: apiKey)
    }
    
    /// Whether the user has opted in to send analytics.
    @UserPreference(key: UserDefaultsKeys.analyticsConsentState, defaultValue: AnalyticsConsentState.unknown, storageType: .userDefaults(store))
    var analyticsConsentState
    
    @UserPreference(key: UserDefaultsKeys.hasRunNotificationPermissionsOnboarding, defaultValue: false, storageType: .userDefaults(store))
    var hasRunNotificationPermissionsOnboarding
    
    @UserPreference(key: UserDefaultsKeys.hasRunIdentityConfirmationOnboarding, defaultValue: false, storageType: .userDefaults(store))
    var hasRunIdentityConfirmationOnboarding
    
    @UserPreference(key: UserDefaultsKeys.frequentlyUsedSystemEmojis, defaultValue: [FrequentlyUsedEmoji](), storageType: .userDefaults(store))
    var frequentlyUsedSystemEmojis
    
    // MARK: - Home Screen
    
    @UserPreference(key: UserDefaultsKeys.hideUnreadMessagesBadge, defaultValue: false, storageType: .userDefaults(store))
    var hideUnreadMessagesBadge
    
    // MARK: - Room Screen
    
    @UserPreference(key: UserDefaultsKeys.viewSourceEnabled, defaultValue: appBuildType == .debug, storageType: .userDefaults(store))
    var viewSourceEnabled
    
    @UserPreference(key: UserDefaultsKeys.optimizeMediaUploads, defaultValue: true, storageType: .userDefaults(store))
    var optimizeMediaUploads

    @UserPreference(key: UserDefaultsKeys.voiceMessagePlaybackSpeed, defaultValue: AudioPlaybackSpeed.default, storageType: .userDefaults(store))
    var voiceMessagePlaybackSpeed: AudioPlaybackSpeed

    /// Whether or not to show a warning on the media caption composer so the user knows
    /// that captions might not be visible to users who are using other Matrix clients.
    let shouldShowMediaCaptionWarning = true

    // MARK: - Element Call
    
    #if IS_MAIN_APP
    // swiftlint:disable:next force_unwrapping
    let elementCallBaseURL: URL = EmbeddedElementCall.appURL!
    #endif
    
    // These are publicly availble on https://call.element.io so we don't neeed to treat them as secrets
    let elementCallPosthogAPIHost = "https://posthog-element-call.element.io"
    let elementCallPosthogAPIKey = "phc_rXGHx9vDmyEvyRxPziYtdVIv0ahEv8A9uLWFcCi1WcU"
    let elementCallPosthogSentryDSN = "https://3bd2f95ba5554d4497da7153b552ffb5@sentry.tools.element.io/41"
    
    @UserPreference(key: UserDefaultsKeys.elementCallBaseURLOverride, defaultValue: nil, storageType: .userDefaults(store))
    var elementCallBaseURLOverride: URL?
    
    // MARK: - Users
    
    /// Whether to hide the display name and avatar of ignored users as these may contain objectionable content.
    let hideIgnoredUserProfiles = true
    
    // MARK: - Maps
    
    /// maptiler base url
    private(set) var mapTilerConfiguration = MapTilerConfiguration(baseURL: "https://api.maptiler.com/maps",
                                                                   apiKey: Secrets.mapLibreAPIKey,
                                                                   lightStyleID: "9bc819c8-e627-474a-a348-ec144fe3d810",
                                                                   darkStyleID: "dea61faf-292b-4774-9660-58fcef89a7f3")
    
    // MARK: - Presence
    
    @UserPreference(key: UserDefaultsKeys.sharePresence, defaultValue: true, storageType: .userDefaults(store))
    var sharePresence
    
    // MARK: - Feature Flags
    
    /// Others
    @UserPreference(key: UserDefaultsKeys.publicSearchEnabled, defaultValue: false, storageType: .userDefaults(store))
    var publicSearchEnabled
    
    @UserPreference(key: UserDefaultsKeys.fuzzyRoomListSearchEnabled, defaultValue: false, storageType: .userDefaults(store))
    var fuzzyRoomListSearchEnabled
    
    @UserPreference(key: UserDefaultsKeys.lowPriorityFilterEnabled, defaultValue: false, storageType: .userDefaults(store))
    var lowPriorityFilterEnabled
    
    /// Configuration to enable only signed device isolation mode for  crypto. In this mode only devices signed by their owner will be considered in e2ee rooms.
    @UserPreference(key: UserDefaultsKeys.enableOnlySignedDeviceIsolationMode, defaultValue: false, storageType: .userDefaults(store))
    var enableOnlySignedDeviceIsolationMode
    
    /// Configuration to enable encrypted history sharing on invite, and accepting keys from inviters.
    @UserPreference(key: UserDefaultsKeys.enableKeyShareOnInvite, defaultValue: false, storageType: .userDefaults(store))
    var enableKeyShareOnInvite
    
    @UserPreference(key: UserDefaultsKeys.knockingEnabled, defaultValue: false, storageType: .userDefaults(store))
    var knockingEnabled
    
    @UserPreference(key: UserDefaultsKeys.threadsEnabled, defaultValue: false, storageType: .userDefaults(store))
    var threadsEnabled
    
    @UserPreference(key: UserDefaultsKeys.focusEventOnNotificationTap, defaultValue: false, storageType: .userDefaults(store))
    var focusEventOnNotificationTap
        
    @UserPreference(key: UserDefaultsKeys.linkPreviewsEnabled, defaultValue: false, storageType: .userDefaults(store))
    var linkPreviewsEnabled
    
    @UserPreference(key: UserDefaultsKeys.linkNewDeviceEnabled, defaultValue: false, storageType: .userDefaults(store))
    var linkNewDeviceEnabled
    
    @UserPreference(key: UserDefaultsKeys.liveLocationSharingEnabled, defaultValue: false, storageType: .userDefaults(store))
    var liveLocationSharingEnabled
    
    @UserPreference(key: UserDefaultsKeys.developerOptionsEnabled, defaultValue: appBuildType == .debug, storageType: .userDefaults(store))
    var developerOptionsEnabled
}

extension AppSettings: CommonSettingsProtocol { }
