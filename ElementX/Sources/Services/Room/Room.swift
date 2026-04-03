//
// Copyright 2025 Element Creations Ltd.
// Copyright 2025 New Vector Ltd.
//
// SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial.
// Please see LICENSE files in the repository root for full details.
//

import MatrixRustSDK

extension RoomProtocol {
    var joinCallIntent: Intent {
        get async {
            let activeMembersCount = await (try? roomInfo().activeMembersCount) ?? UInt64.max
            let isOneToOne = activeMembersCount <= 2
            switch (hasActiveRoomCall(), isOneToOne) {
            case (true, true):
                return Intent.joinExistingDm
            case (true, false):
                return Intent.joinExisting
            case (false, true):
                return Intent.startCallDm
            case (false, false):
                return Intent.startCall
            }
        }
    }
}
