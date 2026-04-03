//
// Copyright 2026 Element Creations Ltd.
// Copyright 2026 New Vector Ltd.
//
// SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial.
// Please see LICENSE files in the repository root for full details.
//

import Foundation

enum SetkaPlusStatusDisplay {
    static func glyph(for status: SetkaPlusStatusEmoji?) -> String? {
        guard let status else { return nil }
        if let emoji = normalized(status.emoji) {
            return emoji
        }
        if normalized(status.stickerID) != nil {
            // Sticker rendering requires media pipeline integration.
            // Keep a consistent fallback glyph for now.
            return "✨"
        }
        return nil
    }

    static func decoratedName(_ name: String, status: SetkaPlusStatusEmoji?) -> String {
        guard let glyph = glyph(for: status) else { return name }
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedName.hasSuffix(glyph) {
            return trimmedName
        }
        return "\(trimmedName) \(glyph)"
    }

    static func decoratedNameIfNeeded(_ name: String, status: SetkaPlusStatusEmoji?) -> String {
        decoratedName(name, status: status)
    }

    private static func normalized(_ value: String?) -> String? {
        guard let value else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
