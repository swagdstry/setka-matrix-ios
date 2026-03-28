//
// Copyright 2026 Element Creations Ltd.
// Copyright 2026 New Vector Ltd.
//
// SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial.
// Please see LICENSE files in the repository root for full details.
//

import Foundation

enum SetkaThemeL10n {
    static var appThemeTitle: String {
        tr("screen_app_theme_title")
    }
    
    static var sectionThemePreview: String {
        tr("screen_app_theme_section_preview")
    }

    static var sectionColors: String {
        tr("screen_app_theme_section_colors")
    }

    static var sectionLayout: String {
        tr("screen_app_theme_section_layout")
    }

    static var sectionBehavior: String {
        tr("screen_app_theme_section_behavior")
    }

    static var sectionFiles: String {
        tr("screen_app_theme_section_files")
    }
    
    static var colorAccent: String {
        tr("screen_app_theme_color_accent")
    }

    static var colorTopBarBackground: String {
        tr("screen_app_theme_color_top_bar_background")
    }

    static var colorTopBarText: String {
        tr("screen_app_theme_color_top_bar_text")
    }

    static var colorComposerBackground: String {
        tr("screen_app_theme_color_composer_background")
    }

    static var colorServiceBubble: String {
        tr("screen_app_theme_color_service_bubble")
    }

    static var colorServiceText: String {
        tr("screen_app_theme_color_service_text")
    }

    static var colorIncomingBubble: String {
        tr("screen_app_theme_color_incoming_bubble")
    }

    static var colorOutgoingBubble: String {
        tr("screen_app_theme_color_outgoing_bubble")
    }

    static var colorOutgoingGradient: String {
        tr("screen_app_theme_color_outgoing_gradient")
    }

    static var colorHomeBackground: String {
        tr("screen_app_theme_color_home_background")
    }
    
    static var layoutUiScale: String {
        tr("screen_app_theme_layout_ui_scale")
    }

    static var layoutMessageScale: String {
        tr("screen_app_theme_layout_message_scale")
    }

    static var layoutBubbleRadius: String {
        tr("screen_app_theme_layout_bubble_radius")
    }

    static var layoutBubbleWidth: String {
        tr("screen_app_theme_layout_bubble_width_percent")
    }

    static var layoutTimelineOverlayOpacity: String {
        tr("screen_app_theme_layout_timeline_overlay_opacity_percent")
    }

    static var layoutComposerOpacity: String {
        tr("screen_app_theme_layout_composer_opacity_percent")
    }

    static var layoutWallpaperBlur: String {
        tr("screen_app_theme_layout_wallpaper_blur")
    }
    
    static var layoutDefaultRoomWallpaper: String {
        tr("screen_app_theme_layout_default_room_wallpaper")
    }
    
    static var homeSection: String {
        tr("screen_app_theme_section_home")
    }
    
    static var homeBackgroundStyle: String {
        tr("screen_app_theme_home_background_style")
    }
    
    static var homeBackgroundStyleSolid: String {
        tr("screen_app_theme_home_background_style_solid")
    }
    
    static var homeBackgroundStyleGradient: String {
        tr("screen_app_theme_home_background_style_gradient")
    }
    
    static var homeBackgroundStyleImage: String {
        tr("screen_app_theme_home_background_style_image")
    }
    
    static var homeGradientFrom: String {
        tr("screen_app_theme_home_gradient_from")
    }
    
    static var homeGradientTo: String {
        tr("screen_app_theme_home_gradient_to")
    }
    
    static var homeWallpaperPick: String {
        tr("screen_app_theme_home_wallpaper_pick")
    }
    
    static var homeWallpaperReset: String {
        tr("screen_app_theme_home_wallpaper_reset")
    }
    
    static var homeChatListStyle: String {
        tr("screen_app_theme_home_chat_list_style")
    }
    
    static var homeChatListStylePlain: String {
        tr("screen_app_theme_home_chat_list_style_plain")
    }
    
    static var homeChatListStyleBubble: String {
        tr("screen_app_theme_home_chat_list_style_bubble")
    }
    
    static var homeChatListOpacity: String {
        tr("screen_app_theme_home_chat_list_opacity")
    }
    
    static var behaviorChatAnimations: String {
        tr("screen_app_theme_behavior_chat_animations")
    }

    static var behaviorBlurEffects: String {
        tr("screen_app_theme_behavior_blur_effects")
    }

    static var behaviorDisableLiquidGlass: String {
        tr("screen_app_theme_behavior_disable_liquid_glass")
    }

    static var behaviorShowEncryptionStatus: String {
        tr("screen_app_theme_behavior_show_encryption_status")
    }

    static var behaviorInitialTimelineCount: String {
        tr("screen_app_theme_behavior_initial_timeline_count")
    }
    
    static var fileImport: String {
        tr("screen_app_theme_file_import")
    }

    static var fileExport: String {
        tr("screen_app_theme_file_export")
    }

    static var fileFooter: String {
        tr("screen_app_theme_file_footer")
    }
    
    static var importFailedTitle: String {
        tr("screen_app_theme_import_failed_title")
    }

    static var exportFailedTitle: String {
        tr("screen_app_theme_export_failed_title")
    }
    
    private static func tr(_ key: String) -> String {
        NSLocalizedString(key, tableName: "SetkaTheme", bundle: .main, value: fallbackValue(for: key), comment: "")
    }
    
    private static func fallbackValue(for key: String) -> String {
        let trimmed = key.replacingOccurrences(of: "screen_app_theme_", with: "")
        let words = trimmed.split(separator: "_").map(String.init)
        
        let mapped = words.map { word in
            switch word {
            case "ui":
                return "UI"
            case "ios":
                return "iOS"
            case "dp":
                return "dp"
            default:
                return word
            }
        }
        
        let sentence = mapped.joined(separator: " ")
        guard let first = sentence.first else {
            return key
        }
        
        return String(first).uppercased() + sentence.dropFirst()
    }
}
