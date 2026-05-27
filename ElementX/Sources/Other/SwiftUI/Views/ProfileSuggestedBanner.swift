//
// Copyright 2025 Element Creations Ltd.
//
// SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial.
// Please see LICENSE files in the repository root for full details.
//

import SwiftUI

/// Free profile background preset (`linear:…` stored in `background_mxc`, aligned with Android).
struct ProfileSuggestedBanner: Identifiable, Equatable, Codable {
    let id: String
    let title: String
    let value: String

    var gradientColors: [Color] {
        Self.colors(from: value)
    }

    static let defaultPresets: [ProfileSuggestedBanner] = [
        .init(id: "blue", title: "Синий", value: "linear:#4A90E2,#7B61FF"),
        .init(id: "sunset", title: "Закат", value: "linear:#FF7A59,#FFA94D"),
        .init(id: "emerald", title: "Изумруд", value: "linear:#00B894,#55EFC4"),
        .init(id: "graphite", title: "Графит", value: "linear:#2D3436,#636E72")
    ]

    static func colors(from value: String) -> [Color] {
        let payload = value.replacingOccurrences(of: "linear:", with: "")
        let components = payload.split(separator: ",").map(String.init)
        guard components.count == 2 else {
            return [.blue, .purple]
        }
        return components.compactMap(Color.init(hex:))
    }

    private struct PresetsEnvelope: Decodable {
        let presets: [ProfileSuggestedBanner]?
        let backgrounds: [ProfileSuggestedBanner]?
    }

    static func decodeList(from data: Data) -> [ProfileSuggestedBanner]? {
        let decoder = JSONDecoder()
        if let list = try? decoder.decode([ProfileSuggestedBanner].self, from: data), !list.isEmpty {
            return list
        }
        if let envelope = try? decoder.decode(PresetsEnvelope.self, from: data) {
            let merged = envelope.presets ?? envelope.backgrounds
            if let merged, !merged.isEmpty {
                return merged
            }
        }
        if let single = try? decoder.decode(ProfileSuggestedBanner.self, from: data) {
            return [single]
        }
        return nil
    }
}
