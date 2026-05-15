//
// Copyright 2025 Element Creations Ltd.
// Copyright 2024-2025 New Vector Ltd.
//
// SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial.
// Please see LICENSE files in the repository root for full details.
//

import SwiftUI

struct HomeScreenMacOS: View {
    @ObservedObject var context: HomeScreenViewModel.Context
    @State private var selectedTab: String = "Чаты"
    
    var body: some View {
        NavigationSplitView {
            // Sidebar with chats/filters
            VStack {
                HStack {
                    Text("Чаты")
                        .font(.headline)
                        .padding(.leading)
                    
                    Spacer()
                    
                    // Вкладки справа
                    HStack(spacing: 8) {
                        tabButton(title: "Чаты", tag: "Чаты")
                        tabButton(title: "Пространства", tag: "Пространства")
                        tabButton(title: "Контакты", tag: "Контакты")
                    }
                    .padding(.trailing)
                }
                .padding(.vertical, 8)
                
                Divider()
                
                // Room list
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(context.viewState.visibleRooms) { room in
                            HomeScreenRoomCell(room: room, isSelected: false, mediaProvider: context.mediaProvider, action: context.send)
                        }
                    }
                }
            }
            .frame(minWidth: 300, maxWidth: 400)
            .background(Color.compound.bgCanvasDefault)
            
            // Main content area
            VStack {
                if let selectedRoom = context.viewState.selectedRoomID {
                    Text("Выбранный чат: \(selectedRoom)")
                        .font(.title2)
                        .padding()
                } else {
                    VStack {
                        Image(systemName: "message.badge")
                            .font(.system(size: 48))
                            .foregroundColor(.compound.textSecondary)
                        
                        Text("Выберите чат для начала общения")
                            .font(.title3)
                            .foregroundColor(.compound.textSecondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.compound.bgCanvasDefault)
        }
        .navigationTitle("Сетка Matrix")
    }
    
    @ViewBuilder
    private func tabButton(title: String, tag: String) -> some View {
        Button(title) {
            selectedTab = tag
        }
        .foregroundColor(selectedTab == tag ? .compound.textActionPrimary : .compound.textSecondary)
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(selectedTab == tag ? Color.compound.bgActionPrimaryRest.opacity(0.1) : Color.clear)
        )
        .onHover { isHovered in
            // Можно добавить эффекты при наведении если нужно
        }
    }
}
