//
// Copyright 2025 Element Creations Ltd.
// Copyright 2022-2025 New Vector Ltd.
//
// SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial.
// Please see LICENSE files in the repository root for full details.
//

import Combine
import Compound
import SentrySwiftUI
import SwiftUI

struct HomeScreen: View {
    @Environment(\.colorScheme) private var colorScheme
    @ObservedObject var context: HomeScreenViewModel.Context
    @ObservedObject private var appThemeService = AppThemeService.shared
    
    @State private var scrollViewAdapter = ScrollViewAdapter()
    
    @Namespace private var navigationTransitionNamespace
    private enum NavigationTransitionSourceID {
        case spaceFilters
    }
    
    var body: some View {
        HomeScreenContent(context: context, scrollViewAdapter: scrollViewAdapter)
            .alert(item: $context.alertInfo)
            .alert(item: $context.leaveRoomAlertItem,
                   actions: leaveRoomAlertActions,
                   message: leaveRoomAlertMessage)
            .navigationTitle(title)
            .toolbar { toolbar }
            .background(homeBackground.ignoresSafeArea())
            .track(screen: .Home)
            .toolbarBloom(hasSearchBar: true)
            .sentryTrace("\(Self.self)")
            .sheet(item: $context.spaceFiltersViewModel) { vm in
                ChatsSpaceFiltersScreen(context: vm.context)
                    .navigationTransition(.zoom(sourceID: NavigationTransitionSourceID.spaceFilters,
                                                in: navigationTransitionNamespace))
            }
            // Setka Plus sheet скрыт для всех платформ
            // #if !os(macOS)
            // .sheet(isPresented: $context.setkaPlusStatusPickerPresented) {
            //     SetkaPlusStatusPickerSheet(isSetkaPlusActive: context.viewState.isSetkaPlusActive,
            //                                selectedEmoji: context.viewState.currentStatusEmojiGlyph,
            //                                selectedStickerID: context.viewState.currentStatusStickerID,
            //                                emojiPacks: context.viewState.setkaPlusEmojiPacks,
            //                                mediaProvider: context.mediaProvider,
            //                                onSelectEmoji: { emoji in
            //                                    context.send(viewAction: .setSetkaPlusStatusEmoji(emoji))
            //                                },
            //                                onSelectSticker: { packID, stickerID in
            //                                    context.send(viewAction: .setSetkaPlusStatusSticker(packID: packID, stickerID: stickerID))
            //                                },
            //                                onClear: {
            //                                    context.send(viewAction: .clearSetkaPlusStatusEmoji)
            //                                })
            // }
            // #endif
    }
    
    // MARK: - Private
    
    private var homeBackground: some View {
        GeometryReader { geometry in
            ZStack {
                switch appThemeService.currentTheme.homeBackgroundStyle {
                case .solid:
                    appThemeService.resolvedHomeBackgroundColor(for: colorScheme)
                case .gradient:
                    appThemeService.resolvedHomeGradient(for: colorScheme)
                case .image:
                    if let wallpaperURL = appThemeService.homeWallpaperURL {
                        AsyncImage(url: wallpaperURL) { phase in
                            switch phase {
                            case .success(let image):
                                image
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: geometry.size.width, height: geometry.size.height)
                                    .clipped()
                                    .blur(radius: appThemeService.wallpaperBlurRadius)
                            default:
                                appThemeService.resolvedHomeGradient(for: colorScheme)
                            }
                        }
                    } else {
                        appThemeService.resolvedHomeGradient(for: colorScheme)
                    }
                }
                
                Color.black
                    .opacity(appThemeService.resolvedHomeWallpaperDimOpacity(for: colorScheme))
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
        }
    }
    
    private var title: String {
        if let selectedSpace = context.viewState.selectedSpaceFilter {
            selectedSpace.room.name
        } else {
            L10n.screenRoomlistMainSpaceTitle
        }
    }
        
    @ToolbarContentBuilder
    private var toolbar: some ToolbarContent {
        ToolbarItemGroup(placement: .navigationBarLeading) {
            settingsButton
                .buttonStyle(.borderless)
            
            // Setka Plus скрыт для всех платформ
            // if context.viewState.selectedSpaceFilter == nil, context.viewState.isSetkaPlusActive {
            //     #if !os(macOS)
            //     setkaPlusStatusButton
            //     #endif
            // }
        }
        
        ToolbarItem(placement: .primaryAction) {
            if #available(iOS 26, *) {
                newRoomButton
            } else {
                newRoomButton
                    .buttonStyle(.compound(.super, size: .toolbarIcon))
            }
        }
        
        if context.viewState.shouldShowSpaceFilters {
            if #available(iOS 26, *) {
                ToolbarSpacer(.fixed, placement: .primaryAction)
            }
               
            ToolbarItem(placement: .primaryAction) {
                SpaceFiltersButton(selected: context.viewState.selectedSpaceFilter != nil) {
                    context.send(viewAction: .spaceFilters)
                }
                .matchedTransitionSource(id: NavigationTransitionSourceID.spaceFilters,
                                         in: navigationTransitionNamespace)
            }
        }
    }
    
    var setkaPlusStatusButton: some View {
        Button {
            context.send(viewAction: .setkaPlusStatusTapped)
        } label: {
            Text(context.viewState.currentStatusEmojiGlyph ?? "✨")
                .font(.system(size: 19))
                .frame(width: 28, height: 28)
                .background(Color.compound.bgSubtlePrimary)
                .clipShape(.rect(cornerRadius: 7))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(SetkaPlusL10n.statusPickerTitle)
    }
    
    var settingsButton: some View {
        Button {
            context.send(viewAction: .showSettings)
        } label: {
            LoadableAvatarImage(url: context.viewState.userAvatarURL,
                                name: context.viewState.userDisplayName,
                                contentID: context.viewState.userID,
                                avatarSize: .user(on: .chats),
                                mediaProvider: context.mediaProvider)
                .accessibilityIdentifier(A11yIdentifiers.homeScreen.userAvatar)
                .clipShape(.circle)
                .overlayBadge(10, isBadged: context.viewState.requiresExtraAccountSetup)
                .accessibilityLabel(L10n.commonSettings)
        }
    }
    
    @ViewBuilder
    var newRoomButton: some View {
        switch context.viewState.roomListMode {
        case .empty, .rooms:
            Button {
                context.send(viewAction: .startChat)
            } label: {
                CompoundIcon(\.plus)
            }
            .accessibilityLabel(L10n.actionStartChat)
            .accessibilityIdentifier(A11yIdentifiers.homeScreen.startChat)
        default:
            EmptyView()
        }
    }
    
    @ViewBuilder
    func leaveRoomAlertActions(_ item: LeaveRoomAlertItem) -> some View {
        Button(item.cancelTitle, role: .cancel) { }
        Button(item.confirmationTitle, role: .destructive) {
            context.send(viewAction: .confirmLeaveRoom(roomIdentifier: item.roomID))
        }
    }
    
    func leaveRoomAlertMessage(_ item: LeaveRoomAlertItem) -> some View {
        Text(item.subtitle)
    }
}

private struct SpaceFiltersButton: View {
    var selected = false
    var action: () -> Void
    
    var body: some View {
        if #available(iOS 26, *) {
            if selected {
                content
                    .backportButtonStyleGlassProminent()
                    .tint(.compound.bgActionPrimaryRest)
            } else {
                content
            }
        } else {
            if selected {
                content
                    .buttonStyle(.compound(.primary, size: .toolbarIcon))
            } else {
                content
                    .buttonStyle(.compound(.tertiary, size: .toolbarIcon))
            }
        }
    }
    
    private var content: some View {
        Button {
            action()
        } label: {
            CompoundIcon(\.filter)
        }
        .accessibilityLabel(L10n.screenRoomlistYourSpaces)
        .accessibilityAddTraits(selected ? .isSelected : [])
        .accessibilityIdentifier(A11yIdentifiers.homeScreen.spaceFilters)
    }
}

// MARK: - Previews

struct HomeScreen_Previews: PreviewProvider, TestablePreview {
    static let loadingViewModel = viewModel(.skeletons)
    static let emptyViewModel = viewModel(.empty)
    static let loadedViewModel = viewModel(.rooms)
    
    static var previews: some View {
        ElementNavigationStack {
            HomeScreen(context: loadingViewModel.context)
        }
        .snapshotPreferences(expect: loadedViewModel.context.$viewState.map { state in
            state.roomListMode == .skeletons
        })
        .previewDisplayName("Loading")
        
        ElementNavigationStack {
            HomeScreen(context: emptyViewModel.context)
        }
        .snapshotPreferences(expect: emptyViewModel.context.$viewState.map { state in
            state.roomListMode == .empty
        })
        .previewDisplayName("Empty")
        
        ElementNavigationStack {
            HomeScreen(context: loadedViewModel.context)
        }
        .snapshotPreferences(expect: loadedViewModel.context.$viewState.map { state in
            state.roomListMode == .rooms
        })
        .previewDisplayName("Loaded")
    }
    
    static func viewModel(_ mode: HomeScreenRoomListMode) -> HomeScreenViewModel {
        let userID = "@alice:example.com"
        
        let roomSummaryProviderState: RoomSummaryProviderMockConfigurationState = switch mode {
        case .skeletons:
            .loading
        case .empty:
            .loaded([])
        case .rooms:
            .loaded(.mockRooms)
        }
        
        let clientProxy = ClientProxyMock(.init(userID: userID,
                                                roomSummaryProvider: RoomSummaryProviderMock(.init(state: roomSummaryProviderState))))
        
        let userSession = UserSessionMock(.init(clientProxy: clientProxy))
        
        return HomeScreenViewModel(userSession: userSession,
                                   selectedRoomPublisher: CurrentValueSubject<String?, Never>(nil).asCurrentValuePublisher(),
                                   appSettings: ServiceLocator.shared.settings,
                                   analyticsService: ServiceLocator.shared.analytics,
                                   notificationManager: NotificationManagerMock(),
                                   userIndicatorController: ServiceLocator.shared.userIndicatorController)
    }
}

enum SeasonalAmbientKind {
    case avatar
    case button
    case searchBar
    case filter
}

private enum SeasonalAmbientSeason {
    case winter
    case spring
    case summer
    case autumn
    
    static func current(date: Date = Date(), calendar: Calendar = .current) -> SeasonalAmbientSeason {
        let month = calendar.component(.month, from: date)
        switch month {
        case 12, 1, 2:
            return .winter
        case 3, 4, 5:
            return .spring
        case 6, 7, 8:
            return .summer
        default:
            return .autumn
        }
    }
}

private struct SeasonalAmbientModifier: ViewModifier {
    let kind: SeasonalAmbientKind
    @ObservedObject private var appThemeService = AppThemeService.shared
    @Environment(\.accessibilityReduceMotion) private var accessibilityReduceMotion
    
    func body(content: Content) -> some View {
        content
            .overlay {
                if appThemeService.seasonalEffectsEnabled {
                    SeasonalAmbientOverlay(season: .current(),
                                           kind: kind,
                                           reduceMotion: accessibilityReduceMotion || appThemeService.shouldReduceSeasonalMotion)
                }
            }
    }
}

private struct SeasonalAmbientOverlay: View {
    let season: SeasonalAmbientSeason
    let kind: SeasonalAmbientKind
    let reduceMotion: Bool
    
    @State private var animate = false
    
    var body: some View {
        GeometryReader { geometry in
            let size = geometry.size
            let cornerRadius = cornerRadius(for: kind)
            let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            
            ZStack {
                switch season {
                case .winter:
                    winterOverlay(shape: shape, size: size)
                case .spring:
                    springOverlay(shape: shape, size: size)
                case .summer:
                    summerOverlay(shape: shape, size: size)
                case .autumn:
                    autumnOverlay(shape: shape, size: size)
                }
            }
            .frame(width: size.width, height: size.height)
        }
        .allowsHitTesting(false)
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.easeInOut(duration: 1.8).repeatForever(autoreverses: true).disabledDuringTests()) {
                animate = true
            }
        }
    }
    
    private func winterOverlay(shape: RoundedRectangle, size: CGSize) -> some View {
        ZStack {
            shape
                .stroke(.white.opacity(0.35), lineWidth: 1)
            
            shape
                .fill(.white.opacity(0.13))
                .frame(height: max(4, size.height * 0.22))
                .frame(maxHeight: .infinity, alignment: .bottom)
                .mask(shape)
            
            HStack(spacing: max(4, size.width * 0.08)) {
                ForEach(0..<4, id: \.self) { index in
                    RoundedRectangle(cornerRadius: 2, style: .continuous)
                        .fill(.white.opacity(0.45))
                        .frame(width: 2, height: max(4, size.height * (0.08 + (Double(index % 2) * 0.06))))
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
            .padding(.bottom, -3)
        }
    }
    
    private func springOverlay(shape: RoundedRectangle, size: CGSize) -> some View {
        ZStack {
            shape
                .stroke(Color(hex: "#8FA8C7")?.opacity(0.5) ?? .blue.opacity(0.4), lineWidth: 1)
            
            HStack(spacing: max(8, size.width * 0.22)) {
                ForEach(0..<3, id: \.self) { index in
                    Circle()
                        .fill(Color(hex: "#7FC8F8")?.opacity(0.55) ?? .cyan.opacity(0.5))
                        .frame(width: 4, height: 4)
                        .offset(y: reduceMotion ? 0 : (animate ? 8 + CGFloat(index) * 2 : -2))
                        .opacity(reduceMotion ? 0.55 : (animate ? 0.2 : 0.75))
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .padding(.top, 2)
        }
    }
    
    private func summerOverlay(shape: RoundedRectangle, size: CGSize) -> some View {
        ZStack {
            shape
                .stroke(Color(hex: "#F8D34D")?.opacity(0.9) ?? .yellow.opacity(0.8), lineWidth: 1.2)
                .shadow(color: Color(hex: "#FFD166")?.opacity(animate ? 0.45 : 0.25) ?? .yellow.opacity(animate ? 0.45 : 0.25),
                        radius: animate ? 7 : 4)
            
            ForEach(0..<3, id: \.self) { index in
                Capsule(style: .continuous)
                    .fill(Color(hex: "#FFD166")?.opacity(0.34) ?? .yellow.opacity(0.3))
                    .frame(width: max(8, size.width * 0.11), height: 2)
                    .rotationEffect(.degrees(Double(index - 1) * 22))
                    .offset(y: -max(4, size.height * 0.5))
                    .opacity(reduceMotion ? 0.45 : (animate ? 0.65 : 0.35))
            }
        }
    }
    
    private func autumnOverlay(shape: RoundedRectangle, size: CGSize) -> some View {
        let leafColor = Color(hex: "#C97C2E") ?? .orange
        
        return ZStack {
            shape
                .stroke(leafColor.opacity(0.55), lineWidth: 1)
            
            HStack(spacing: max(8, size.width * 0.19)) {
                ForEach(0..<3, id: \.self) { index in
                    Image(systemName: "leaf.fill")
                        .font(.system(size: max(7, size.height * 0.28)))
                        .foregroundStyle(leafColor.opacity(0.65))
                        .rotationEffect(.degrees(reduceMotion ? Double(index * 12) : (animate ? Double(index * 18) + 16 : Double(index * 18) - 16)))
                        .offset(y: reduceMotion ? 0 : (animate ? 7 : -7))
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .padding(.top, 2)
        }
    }
    
    private func cornerRadius(for kind: SeasonalAmbientKind) -> CGFloat {
        switch kind {
        case .avatar:
            return 14
        case .button:
            return 16
        case .searchBar:
            return 18
        case .filter:
            return 20
        }
    }
}

extension View {
    func seasonalAmbient(_ kind: SeasonalAmbientKind) -> some View {
        modifier(SeasonalAmbientModifier(kind: kind))
    }
}

struct HomeSearchSeasonalOverlay: View {
    @ObservedObject private var appThemeService = AppThemeService.shared
    
    var body: some View {
        RoundedRectangle(cornerRadius: 16, style: .continuous)
            .fill(Color.clear)
            .frame(height: 52)
            .seasonalAmbient(.searchBar)
            .opacity(appThemeService.seasonalEffectsEnabled ? 1 : 0)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }
}
