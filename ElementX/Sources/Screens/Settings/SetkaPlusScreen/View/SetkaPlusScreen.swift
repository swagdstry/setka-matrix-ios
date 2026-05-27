//
// Copyright 2026 Element Creations Ltd.
// Copyright 2026 New Vector Ltd.
//
// SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial.
// Please see LICENSE files in the repository root for full details.
//

import Compound
import Foundation
import SwiftUI

struct SetkaPlusScreen: View {
    @Bindable var context: SetkaPlusScreenViewModelType.Context

    var body: some View {
        Form {
            subscriptionSection
            plansSection
            paymentsSection
        }
        .compoundList()
        .navigationTitle(SetkaPlusL10n.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { toolbar }
        .alert(item: $context.alertInfo)
    }

    private var toolbar: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            Button(SetkaPlusL10n.refresh) {
                context.send(viewAction: .refresh)
            }
            .disabled(context.viewState.isLoading || context.viewState.purchasingPlanID != nil)
        }
    }

    private var subscriptionSection: some View {
        Section {
            if let subscription = context.viewState.subscription {
                keyValueRow(label: SetkaPlusL10n.status,
                            value: statusTitle(for: subscription))

                keyValueRow(label: SetkaPlusL10n.plan,
                            value: normalizedSetkaNaming(subscription.planName ?? subscription.tier ?? "-"))

                keyValueRow(label: SetkaPlusL10n.expiresAt,
                            value: formattedDate(fromMilliseconds: subscription.expiresAt))
            } else if context.viewState.isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity)
            } else {
                keyValueRow(label: SetkaPlusL10n.status, value: "-")
            }
        } header: {
            Text(SetkaPlusL10n.sectionSubscription)
                .compoundListSectionHeader()
        }
    }

    private var plansSection: some View {
        Section {
            if context.viewState.plans.isEmpty {
                if context.viewState.isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                } else {
                    Text(SetkaPlusL10n.noPlans)
                        .font(.compound.bodySM)
                        .foregroundColor(.compound.textSecondary)
                }
            } else {
                ForEach(context.viewState.plans, id: \.id) { plan in
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 8) {
                            Text(normalizedSetkaNaming(plan.name))
                                .lineLimit(1)
                                .font(.compound.bodyLG)
                                .foregroundColor(.compound.textPrimary)

                            Spacer()

                            Text(priceString(for: plan.priceRub))
                                .font(.compound.bodyMDSemibold)
                                .foregroundColor(.compound.textPrimary)
                        }

                        Text("\(plan.durationDays) d")
                            .font(.compound.bodySM)
                            .foregroundColor(.compound.textSecondary)

                        if !plan.features.isEmpty {
                            Text(plan.features.joined(separator: " • "))
                                .font(.compound.bodySM)
                                .foregroundColor(.compound.textSecondary)
                        }

                        Button {
                            context.send(viewAction: .buyPlan(id: plan.id))
                        } label: {
                            Text(SetkaPlusL10n.buy)
                                .font(.compound.bodyMDSemibold)
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.compound(.secondary))
                        .disabled(context.viewState.purchasingPlanID != nil)
                    }
                    .padding(.vertical, 6)
                }
            }
        } header: {
            Text(SetkaPlusL10n.sectionPlans)
                .compoundListSectionHeader()
        }
    }

    private var paymentsSection: some View {
        Section {
            let payments = Array(context.viewState.payments.prefix(10))
            if payments.isEmpty {
                if context.viewState.isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                } else {
                    Text(SetkaPlusL10n.noPayments)
                        .font(.compound.bodySM)
                        .foregroundColor(.compound.textSecondary)
                }
            } else {
                ForEach(payments, id: \.paymentID) { payment in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(payment.status.capitalized)
                            .font(.compound.bodyMDSemibold)
                            .foregroundColor(.compound.textPrimary)
                        Text(payment.provider)
                            .font(.compound.bodySM)
                            .foregroundColor(.compound.textSecondary)
                        if let amount = payment.amount {
                            Text(priceString(for: amount))
                                .font(.compound.bodySM)
                                .foregroundColor(.compound.textSecondary)
                        }
                        Text(formattedDate(fromMilliseconds: payment.createdAt))
                            .font(.compound.bodySM)
                            .foregroundColor(.compound.textSecondary)
                    }
                    .padding(.vertical, 2)
                }
            }
        } header: {
            Text(SetkaPlusL10n.sectionPayments)
                .compoundListSectionHeader()
        }
    }

    private func keyValueRow(label: String, value: String) -> some View {
        HStack(spacing: 8) {
            Text(label)
                .font(.compound.bodyMD)
                .foregroundColor(.compound.textSecondary)
            Spacer()
            Text(value)
                .font(.compound.bodyMD)
                .foregroundColor(.compound.textPrimary)
                .multilineTextAlignment(.trailing)
        }
    }

    private func statusTitle(for subscription: SetkaPlusSubscription) -> String {
        let status = (subscription.status ?? "unknown").lowercased()
        switch status {
        case "active":
            return "Active"
        case "pending":
            return "Pending"
        case "expired":
            return "Expired"
        case "canceled":
            return "Canceled"
        case "inactive":
            return "Inactive"
        default:
            return status.capitalized
        }
    }

    private func formattedDate(fromMilliseconds timestamp: Int?) -> String {
        guard let timestamp, timestamp > 0 else { return "-" }
        let date = Date(timeIntervalSince1970: TimeInterval(timestamp) / 1000)
        return Self.dateFormatter.string(from: date)
    }

    private func priceString(for amount: Double) -> String {
        let rounded = String(format: "%.2f", amount)
        return "\(rounded) RUB"
    }

    private func normalizedSetkaNaming(_ value: String) -> String {
        value.replacingOccurrences(of: "Setka Plus", with: "Сетка Plus")
            .replacingOccurrences(of: "Setka", with: "Сетка")
    }

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }()
}

// MARK: - Previews

struct SetkaPlusScreen_Previews: PreviewProvider, TestablePreview {
    static var previews: some View {
        ElementNavigationStack {
            SetkaPlusScreen(context: loadedViewModel.context)
        }
        .previewDisplayName("Loaded")

        ElementNavigationStack {
            SetkaPlusScreen(context: loadingViewModel.context)
        }
        .previewDisplayName("Loading")
    }

    private static let loadedViewModel: SetkaPlusScreenViewModel = {
        let state = SetkaPlusScreenViewState(subscription: .init(tier: "setka_plus_month",
                                                                 status: "active",
                                                                 startedAt: 0,
                                                                 expiresAt: Int(Date().addingTimeInterval(30 * 24 * 60 * 60).timeIntervalSince1970 * 1000),
                                                                 updatedAt: 0,
                                                                 isActive: true,
                                                                 priceRub: 299,
                                                                 durationDays: 30,
                                                                 planName: "Setka Plus 30 days",
                                                                 lastPaymentID: "pay_1",
                                                                 paymentProvider: "yoomoney",
                                                                 amount: 299,
                                                                 currency: "RUB"),
                                             plans: [.init(id: "setka_plus_month",
                                                           name: "Setka Plus 30 days",
                                                           priceRub: 299,
                                                           durationDays: 30,
                                                           features: ["Custom stickers", "Priority media limits"],
                                                           isActive: true,
                                                           isDefault: true,
                                                           sortOrder: 10)],
                                             payments: [.init(paymentID: "pay_1",
                                                              status: "success",
                                                              provider: "yoomoney",
                                                              createdAt: Int(Date().timeIntervalSince1970 * 1000),
                                                              amount: 299,
                                                              currency: "RUB",
                                                              requestID: "req_1",
                                                              label: nil,
                                                              planID: "setka_plus_month")],
                                             isLoading: false,
                                             purchasingPlanID: nil,
                                             bindings: .init())

        return SetkaPlusScreenViewModel(clientProxy: ClientProxyMock(.init()),
                                        userIndicatorController: UserIndicatorControllerMock(),
                                        initialViewState: state)
    }()

    private static let loadingViewModel: SetkaPlusScreenViewModel = {
        var state = SetkaPlusScreenViewState()
        state.isLoading = true
        return SetkaPlusScreenViewModel(clientProxy: ClientProxyMock(.init()),
                                        userIndicatorController: UserIndicatorControllerMock(),
                                        initialViewState: state)
    }()
}
