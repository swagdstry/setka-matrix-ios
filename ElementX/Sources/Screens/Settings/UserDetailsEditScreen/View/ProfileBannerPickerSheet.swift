//
// Copyright 2025 Element Creations Ltd.
//
// SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial.
// Please see LICENSE files in the repository root for full details.
//

import Compound
import SwiftUI

struct ProfileBannerPickerSheet: View {
    let isSetkaPlusActive: Bool
    let suggestedBanners: [ProfileSuggestedBanner]
    let onSelectCustomBanner: () -> Void
    let onSelectSuggestedBanner: (ProfileSuggestedBanner) -> Void
    let onDismiss: () -> Void

    var body: some View {
        ElementNavigationStack {
            Form {
                Section {
                    Button {
                        onSelectCustomBanner()
                    } label: {
                        HStack(spacing: 12) {
                            CompoundIcon(\.image, size: .medium, relativeTo: .compound.bodyLG)
                                .foregroundStyle(.compound.iconPrimary)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Свой баннер")
                                    .font(.compound.bodyLG)
                                    .foregroundStyle(.compound.textPrimary)
                                Text(isSetkaPlusActive ? "Фото или GIF из галереи" : "Только с подпиской Сетка Plus")
                                    .font(.compound.bodySM)
                                    .foregroundStyle(.compound.textSecondary)
                            }
                            Spacer()
                            if !isSetkaPlusActive {
                                CompoundIcon(\.lockSolid, size: .small, relativeTo: .compound.bodyLG)
                                    .foregroundStyle(.compound.iconTertiary)
                            }
                        }
                    }
                    .disabled(!isSetkaPlusActive)
                } header: {
                    Text("Свой баннер")
                        .compoundListSectionHeader()
                }

                Section {
                    LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
                        ForEach(suggestedBanners) { banner in
                            Button {
                                onSelectSuggestedBanner(banner)
                            } label: {
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .fill(LinearGradient(colors: banner.gradientColors,
                                                         startPoint: .topLeading,
                                                         endPoint: .bottomTrailing))
                                    .frame(height: 72)
                                    .overlay {
                                        Text(banner.title)
                                            .font(.compound.bodySMSemibold)
                                            .foregroundStyle(.white.opacity(0.95))
                                    }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.vertical, 4)
                } header: {
                    Text("Выбрать из предложенных")
                        .compoundListSectionHeader()
                } footer: {
                    Text("Бесплатные градиентные фоны доступны всем пользователям.")
                        .compoundListSectionFooter()
                }
            }
            .compoundList()
            .navigationTitle("Фон профиля")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.actionCancel) {
                        onDismiss()
                    }
                }
            }
        }
    }
}
