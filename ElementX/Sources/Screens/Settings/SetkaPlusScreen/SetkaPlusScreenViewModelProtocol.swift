//
// Copyright 2026 Element Creations Ltd.
// Copyright 2026 New Vector Ltd.
//
// SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial.
// Please see LICENSE files in the repository root for full details.
//

import Combine

@MainActor
protocol SetkaPlusScreenViewModelProtocol {
    var actionsPublisher: AnyPublisher<SetkaPlusScreenViewModelAction, Never> { get }
    var context: SetkaPlusScreenViewModelType.Context { get }
    func fetchInitialContent()
}
