//
// Copyright 2026 Element Creations Ltd.
// Copyright 2026 New Vector Ltd.
//
// SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial.
// Please see LICENSE files in the repository root for full details.
//

import Combine
import Foundation
import SwiftUI

struct SetkaPlusScreenCoordinatorParameters {
    let clientProxy: ClientProxyProtocol
    let userIndicatorController: UserIndicatorControllerProtocol
}

enum SetkaPlusScreenCoordinatorAction {
    case openCheckoutURL(URL)
}

final class SetkaPlusScreenCoordinator: CoordinatorProtocol {
    private let viewModel: SetkaPlusScreenViewModelProtocol

    private let actionsSubject = PassthroughSubject<SetkaPlusScreenCoordinatorAction, Never>()
    var actionsPublisher: AnyPublisher<SetkaPlusScreenCoordinatorAction, Never> {
        actionsSubject.eraseToAnyPublisher()
    }

    private var cancellables = Set<AnyCancellable>()

    init(parameters: SetkaPlusScreenCoordinatorParameters) {
        viewModel = SetkaPlusScreenViewModel(clientProxy: parameters.clientProxy,
                                             userIndicatorController: parameters.userIndicatorController)

        viewModel.actionsPublisher
            .sink { [weak self] action in
                switch action {
                case .openCheckoutURL(let url):
                    self?.actionsSubject.send(.openCheckoutURL(url))
                }
            }
            .store(in: &cancellables)
    }

    func start() {
        viewModel.fetchInitialContent()
    }

    func toPresentable() -> AnyView {
        AnyView(SetkaPlusScreen(context: viewModel.context))
    }
}
