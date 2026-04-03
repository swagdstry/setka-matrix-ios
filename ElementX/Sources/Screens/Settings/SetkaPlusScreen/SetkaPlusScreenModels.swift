//
// Copyright 2026 Element Creations Ltd.
// Copyright 2026 New Vector Ltd.
//
// SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial.
// Please see LICENSE files in the repository root for full details.
//

import Foundation

enum SetkaPlusScreenViewAction {
    case refresh
    case buyPlan(id: String)
}

enum SetkaPlusScreenViewModelAction {
    case openCheckoutURL(URL)
}

struct SetkaPlusScreenViewState: BindableState {
    var subscription: SetkaPlusSubscription?
    var plans: [SetkaPlusPlan] = []
    var payments: [SetkaPlusPayment] = []
    var isLoading = false
    var purchasingPlanID: String?
    var bindings = SetkaPlusScreenViewStateBindings()
}

struct SetkaPlusScreenViewStateBindings {
    var alertInfo: AlertInfo<SetkaPlusScreenErrorType>?
}

enum SetkaPlusScreenErrorType: Hashable {
    case generic
}
