//
// Copyright 2026 Element Creations Ltd.
// Copyright 2026 New Vector Ltd.
//
// SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial.
// Please see LICENSE files in the repository root for full details.
//

import Foundation

enum SetkaPlusL10n {
    static var title: String {
        tr("screen_setka_plus_title")
    }

    static var refresh: String {
        tr("screen_setka_plus_refresh")
    }

    static var sectionSubscription: String {
        tr("screen_setka_plus_section_subscription")
    }

    static var sectionPlans: String {
        tr("screen_setka_plus_section_plans")
    }

    static var sectionPayments: String {
        tr("screen_setka_plus_section_payments")
    }

    static var status: String {
        tr("screen_setka_plus_status")
    }

    static var plan: String {
        tr("screen_setka_plus_plan")
    }

    static var expiresAt: String {
        tr("screen_setka_plus_expires_at")
    }

    static var buy: String {
        tr("screen_setka_plus_buy")
    }

    static var noPlans: String {
        tr("screen_setka_plus_no_plans")
    }

    static var noPayments: String {
        tr("screen_setka_plus_no_payments")
    }

    static var cannotOpenCheckout: String {
        tr("screen_setka_plus_checkout_unavailable")
    }

    static var purchaseCreated: String {
        tr("screen_setka_plus_purchase_created")
    }

    static var statusPickerTitle: String {
        tr("screen_setka_plus_status_picker_title")
    }

    static var statusPickerQuickEmoji: String {
        tr("screen_setka_plus_status_picker_quick_emoji")
    }

    static var statusPickerCustomEmoji: String {
        tr("screen_setka_plus_status_picker_custom_emoji")
    }

    static var statusPickerClear: String {
        tr("screen_setka_plus_status_picker_clear")
    }

    static var subscriptionRequiredForStatus: String {
        tr("screen_setka_plus_status_subscription_required")
    }

    private static func tr(_ key: String) -> String {
        NSLocalizedString(key, tableName: "SetkaPlus", bundle: .main, value: fallbackValue(for: key), comment: "")
    }

    private static func fallbackValue(for key: String) -> String {
        switch key {
        case "screen_setka_plus_title":
            return "Сетка Plus"
        case "screen_setka_plus_refresh":
            return "Refresh"
        case "screen_setka_plus_section_subscription":
            return "Subscription"
        case "screen_setka_plus_section_plans":
            return "Plans"
        case "screen_setka_plus_section_payments":
            return "Payments"
        case "screen_setka_plus_status":
            return "Status"
        case "screen_setka_plus_plan":
            return "Plan"
        case "screen_setka_plus_expires_at":
            return "Expires"
        case "screen_setka_plus_buy":
            return "Buy"
        case "screen_setka_plus_no_plans":
            return "No plans available"
        case "screen_setka_plus_no_payments":
            return "No payments yet"
        case "screen_setka_plus_checkout_unavailable":
            return "Payment link is unavailable. Please try again."
        case "screen_setka_plus_purchase_created":
            return "Payment created. Continue in YooMoney."
        case "screen_setka_plus_status_picker_title":
            return "Status emoji"
        case "screen_setka_plus_status_picker_quick_emoji":
            return "Quick emoji"
        case "screen_setka_plus_status_picker_custom_emoji":
            return "Custom emoji packs"
        case "screen_setka_plus_status_picker_clear":
            return "Clear status"
        case "screen_setka_plus_status_subscription_required":
            return "Status emoji are available with Сетка Plus subscription."
        default:
            return key
        }
    }
}
