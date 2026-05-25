//
// Copyright 2025 Element Creations Ltd.
// Copyright 2024-2025 New Vector Ltd.
//
// SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial.
// Please see LICENSE files in the repository root for full details.
//

import Compound
import SentrySwiftUI
import SwiftUI

struct HomeScreenContent: View {
    @Environment(\.verticalSizeClass) private var verticalSizeClass
    
    @ObservedObject var context: HomeScreenViewModel.Context
    @ObservedObject private var mediaPlayerController = GlobalMediaPlayerController.shared
    @ObservedObject private var appThemeService = AppThemeService.shared
    @State private var isMiniPlayerCollapsed = false
    let scrollViewAdapter: ScrollViewAdapter
    
    var body: some View {
        roomList
            .sentryTrace("\(Self.self)")
    }
    
    private var roomList: some View {
        GeometryReader { geometry in
            ScrollView {
                switch context.viewState.roomListMode {
                case .skeletons:
                    LazyVStack(spacing: 0) {
                        ForEach(context.viewState.visibleRooms) { room in
                            HomeScreenRoomCell(room: room, isSelected: false, mediaProvider: context.mediaProvider, action: context.send)
                                .redacted(reason: .placeholder)
                                .shimmer() // Putting this directly on the LazyVStack creates an accordion animation on iOS 16.
                        }
                    }
                    .disabled(true)
                    .accessibilityRepresentation {
                        Text(L10n.commonLoading)
                    }
                case .empty:
                    HomeScreenEmptyStateLayout(minHeight: geometry.size.height) {
                        topSection
                        
                        HomeScreenEmptyStateView(context: context)
                            .layoutPriority(1)
                    }
                case .rooms:
                    LazyVStack(spacing: 0) {
                        Section {
                            if !context.viewState.shouldShowEmptyFilterState {
                                HomeScreenRoomList(context: context)
                            }
                        } header: {
                            topSection
                        }
                    }
                    .isSearching($context.isSearchFieldFocused)
                    .searchable(text: $context.searchQuery, placement: .navigationBarDrawer(displayMode: .always))
                    .compoundSearchField()
                    .disableAutocorrection(true)
                }
            }
            .safeAreaInset(edge: .top, spacing: 0) {
                if mediaPlayerController.shouldShowAudioOverlay || mediaPlayerController.activeVideoNote != nil {
                    InlineMiniMediaPlayerView(controller: mediaPlayerController,
                                              displayMode: isMiniPlayerCollapsed ? .compact : .expanded,
                                              onExpand: {
                                                  withAnimation(.spring(response: 0.32, dampingFraction: 0.86).disabledDuringTests()) {
                                                      isMiniPlayerCollapsed = false
                                                  }
                                              }
                    )
                                              .padding(.horizontal, 12)
                                              .padding(.top, 4)
                                              .padding(.bottom, 4)
                                              .transition(.asymmetric(insertion: .move(edge: .top).combined(with: .opacity),
                                                                      removal: .scale(scale: 0.94, anchor: .top).combined(with: .opacity)))
                }
            }
            .introspect(.scrollView, on: .supportedVersions) { scrollView in
                guard scrollView != scrollViewAdapter.scrollView else { return }
                scrollViewAdapter.scrollView = scrollView
            }
            .onReceive(scrollViewAdapter.didScroll) { _ in
                updateVisibleRange()
                updateMiniPlayerCollapse()
            }
            .onReceive(scrollViewAdapter.isScrolling) { _ in
                updateVisibleRange()
            }
            .onChange(of: context.searchQuery) {
                updateVisibleRange()
            }
            .onAppear {
                GlobalMediaPlayerController.shared.setHomeScreenVisible(true)
            }
            .onDisappear {
                GlobalMediaPlayerController.shared.setHomeScreenVisible(false)
            }
            .onChange(of: context.viewState.visibleRooms) {
                updateVisibleRange()
                
                // We have been seeing a lot of issues around the room list not updating properly after
                // rooms shifting around:
                // * Tapping on the room list doesn't always take you to the right room  - https://github.com/element-hq/element-x-ios/issues/2386
                // * Big blank gaps in the room list - https://github.com/element-hq/element-x-ios/issues/3026
                //
                // We initially thought it's caused by the filters header or the geometry reader but
                // the problem is still reproducible without those.
                //
                // As a last attempt we will manually force it to update by shifting the
                // inner scroll view by a point every time the room list is updated
                DispatchQueue.main.async {
                    guard !scrollViewAdapter.isScrolling.value, let scrollView = scrollViewAdapter.scrollView else {
                        return
                    }
                    
                    let oldOffset = scrollView.contentOffset
                    var newOffset = scrollView.contentOffset
                    newOffset.y += 1
                    
                    scrollView.setContentOffset(newOffset, animated: false)
                    scrollView.setContentOffset(oldOffset, animated: false)
                }
            }
            .background {
                Button("") {
                    context.send(viewAction: .globalSearch)
                }
                .keyboardShortcut(KeyEquivalent("k"), modifiers: [.command])
            }
            .overlay {
                if context.viewState.shouldShowEmptyFilterState {
                    RoomListFiltersEmptyStateView(state: context.filtersState)
                        .background(.compound.bgCanvasDefault)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
                        .scrollDismissesKeyboard(.immediately)
            .scrollDisabled(context.viewState.roomListMode == .skeletons)
            .scrollBounceBehavior(context.viewState.roomListMode == .empty ? .basedOnSize : .automatic)
            .animation(.elementDefault, value: context.viewState.roomListMode)
            .animation(.none, value: context.viewState.visibleRooms)
            .animation(.spring(response: 0.34, dampingFraction: 0.86).disabledDuringTests(),
                       value: mediaPlayerController.shouldShowAudioOverlay)
            .animation(.spring(response: 0.34, dampingFraction: 0.86).disabledDuringTests(),
                       value: mediaPlayerController.activeVideoNote != nil)
        }
    }
    
    @ViewBuilder
    private var topSection: some View {
        // An empty VStack causes glitches within the room list
        if context.viewState.shouldShowFilters || context.viewState.shouldShowBanner {
            VStack(spacing: 0) {
                if context.viewState.shouldShowFilters {
                    RoomListFiltersView(state: $context.filtersState)
                }
                
                if case let .show(state) = context.viewState.securityBannerMode {
                    HomeScreenRecoveryKeyConfirmationBanner(state: state, context: context)
                } else if context.viewState.shouldShowNewSoundBanner {
                    HomeScreenNewSoundBanner { context.send(viewAction: .dismissNewSoundBanner) }
                }
            }
            .background(appThemeService.isHomeChatListBubbled ? Color.clear : Color.compound.bgCanvasDefault)
        }
    }
    
    /// Often times the scroll view's content size isn't correct yet when this method is called e.g. when cancelling a search
    /// Dispatch it with a delay to allow the UI to update and the computations to be correct
    /// Once we move to iOS 17 we should remove all of this and use scroll anchors instead
    private func updateVisibleRange() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { delayedUpdateVisibleRange() }
    }
    
    private func updateMiniPlayerCollapse() {
        guard let scrollView = scrollViewAdapter.scrollView else { return }
        let shouldCollapse = scrollView.contentOffset.y + scrollView.contentInset.top > 6
        
        withAnimation(.spring(response: 0.28, dampingFraction: 0.88).disabledDuringTests()) {
            isMiniPlayerCollapsed = shouldCollapse
        }
    }
    
    private func delayedUpdateVisibleRange() {
        guard let scrollView = scrollViewAdapter.scrollView,
              scrollViewAdapter.isScrolling.value == false, // Ignore while scrolling
              context.searchQuery.isEmpty == true, // Ignore while filtering
              context.viewState.visibleRooms.count > 0 else {
            return
        }
        
        guard scrollView.contentSize.height > scrollView.bounds.height else {
            return
        }
        
        let adjustedContentSize = max(scrollView.contentSize.height - scrollView.contentInset.top - scrollView.contentInset.bottom, scrollView.bounds.height)
        let cellHeight = adjustedContentSize / Double(context.viewState.visibleRooms.count)
        
        let firstIndex = Int(max(0.0, scrollView.contentOffset.y + scrollView.contentInset.top) / cellHeight)
        let lastIndex = Int(max(0.0, scrollView.contentOffset.y + scrollView.bounds.height) / cellHeight)
        
        // This will be deduped and throttled on the view model layer
        context.send(viewAction: .updateVisibleItemRange(firstIndex..<lastIndex))
    }
}
