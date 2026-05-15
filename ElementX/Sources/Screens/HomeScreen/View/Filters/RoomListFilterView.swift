//
// Copyright 2025 Element Creations Ltd.
// Copyright 2024-2025 New Vector Ltd.
//
// SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial.
// Please see LICENSE files in the repository root for full details.
//

import SwiftUI

struct RoomListFilterView: View {
    let filter: RoomListFilter
    @Binding var isActive: Bool
    @ObservedObject private var appThemeService = AppThemeService.shared

    var body: some View {
        Toggle(isOn: $isActive) {
            Text(filter.localizedName)
        }
        .toggleStyle(FilterToggleStyle(isBubbleStyleEnabled: appThemeService.isHomeChatListBubbled))
    }
}

private struct FilterToggleStyle: ToggleStyle {
    let isBubbleStyleEnabled: Bool
    
    private func strokeColor(isOn: Bool) -> Color {
        if isBubbleStyleEnabled {
            return isOn ? .compound.bgActionPrimaryRest.opacity(0.92) : .compound.borderInteractiveSecondary.opacity(0.75)
        }
        return isOn ? .compound.bgActionPrimaryRest : .compound.borderInteractiveSecondary
    }
    
    private func backgroundColor(isOn: Bool) -> Color {
        if isBubbleStyleEnabled {
            return isOn ? .compound.bgActionPrimaryRest.opacity(0.44) : .white.opacity(0.08)
        }
        return isOn ? .compound.bgActionPrimaryRest : .compound.bgCanvasDefault
    }
    
    private func foregroundColor(isOn: Bool) -> Color {
        isOn ? .compound.textOnSolidPrimary : .compound.textPrimary
    }
    
    func makeBody(configuration: Configuration) -> some View {
        let shape = RoundedRectangle(cornerRadius: 20)
        configuration.label
            .font(.compound.bodyMD)
            .foregroundColor(foregroundColor(isOn: configuration.isOn))
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(shape.fill(backgroundColor(isOn: configuration.isOn)))
            .overlay {
                shape
                    .inset(by: 0.5)
                    .stroke(strokeColor(isOn: configuration.isOn))
            }
            .drawingGroup()
            // The button breaks the animation for some reason, so better to use the label directly with an onTapGesture
            .onTapGesture {
                configuration.isOn.toggle()
            }
    }
}

// MARK: - Previews

struct RoomListFilterView_Previews: PreviewProvider, TestablePreview {
    static var previews: some View {
        RoomListFilterView(filter: .people, isActive: .constant(false))
        RoomListFilterView(filter: .people, isActive: .constant(true))
    }
}
