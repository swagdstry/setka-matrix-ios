//
// Copyright 2026 Element Creations Ltd.
// Copyright 2026 New Vector Ltd.
//
// SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial.
// Please see LICENSE files in the repository root for full details.
//

import Combine
import Foundation

typealias SetkaPlusScreenViewModelType = StateStoreViewModelV2<SetkaPlusScreenViewState, SetkaPlusScreenViewAction>

final class SetkaPlusScreenViewModel: SetkaPlusScreenViewModelType, SetkaPlusScreenViewModelProtocol {
    private let clientProxy: ClientProxyProtocol
    private let userIndicatorController: UserIndicatorControllerProtocol

    private let actionsSubject = PassthroughSubject<SetkaPlusScreenViewModelAction, Never>()
    var actionsPublisher: AnyPublisher<SetkaPlusScreenViewModelAction, Never> {
        actionsSubject.eraseToAnyPublisher()
    }

    init(clientProxy: ClientProxyProtocol,
         userIndicatorController: UserIndicatorControllerProtocol,
         initialViewState: SetkaPlusScreenViewState) {
        self.clientProxy = clientProxy
        self.userIndicatorController = userIndicatorController

        super.init(initialViewState: initialViewState)
    }
    
    convenience init(clientProxy: ClientProxyProtocol,
                     userIndicatorController: UserIndicatorControllerProtocol) {
        self.init(clientProxy: clientProxy,
                  userIndicatorController: userIndicatorController,
                  initialViewState: .init())
    }

    override func process(viewAction: SetkaPlusScreenViewAction) {
        switch viewAction {
        case .refresh:
            fetchInitialContent()
        case .buyPlan(let id):
            Task { await createPayment(for: id) }
        }
    }

    func fetchInitialContent() {
        Task { await reloadContent(showError: true) }
    }

    private func reloadContent(showError: Bool) async {
        state.isLoading = true

        async let subscriptionResult = clientProxy.fetchSetkaPlusSubscription()
        async let plansResult = clientProxy.fetchSetkaPlusPlans()
        async let paymentsResult = clientProxy.fetchSetkaPlusPayments()

        let (subscription, plans, payments) = await (subscriptionResult, plansResult, paymentsResult)

        var hasError = false

        switch subscription {
        case .success(let value):
            state.subscription = value
        case .failure(let error):
            hasError = true
            MXLog.error("Failed loading Setka Plus subscription with error: \(error)")
        }

        switch plans {
        case .success(let value):
            state.plans = value
        case .failure(let error):
            hasError = true
            MXLog.error("Failed loading Setka Plus plans with error: \(error)")
        }

        switch payments {
        case .success(let value):
            state.payments = value
        case .failure(let error):
            hasError = true
            MXLog.error("Failed loading Setka Plus payments with error: \(error)")
        }

        if hasError, showError {
            userIndicatorController.submitIndicator(.init(title: L10n.errorUnknown))
            state.bindings.alertInfo = .init(id: .generic)
        }

        state.isLoading = false
    }

    private func createPayment(for planID: String) async {
        guard state.purchasingPlanID == nil else { return }

        state.purchasingPlanID = planID
        defer { state.purchasingPlanID = nil }

        switch await clientProxy.createSetkaPlusYooMoneyPayment(amount: nil,
                                                                description: nil,
                                                                planID: planID) {
        case .success(let payment):
            guard let checkoutURL = payment.checkoutURL,
                  let url = URL(string: checkoutURL) else {
                state.bindings.alertInfo = .init(id: .generic,
                                                 title: L10n.commonError,
                                                 message: SetkaPlusL10n.cannotOpenCheckout)
                return
            }

            actionsSubject.send(.openCheckoutURL(url))
            userIndicatorController.submitIndicator(.init(title: SetkaPlusL10n.purchaseCreated))
            await reloadContent(showError: false)
        case .failure(let error):
            MXLog.error("Failed creating Setka Plus payment with error: \(error)")
            userIndicatorController.submitIndicator(.init(title: L10n.errorUnknown))
            state.bindings.alertInfo = .init(id: .generic)
        }
    }
}
