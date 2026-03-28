//
// Copyright 2026 Element Creations Ltd.
// Copyright 2026 New Vector Ltd.
//
// SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial.
// Please see LICENSE files in the repository root for full details.
//

import Foundation
import SwiftUI
import UniformTypeIdentifiers
#if os(iOS)
import UIKit
#endif

@MainActor
final class AppThemeService: ObservableObject {
    static let shared = AppThemeService()
    
    @Published private(set) var currentTheme: SetkaThemeConfiguration = .default
    
    private weak var appSettings: AppSettings?
    private static let homeWallpaperCacheDirectory = "SetkaThemeCache"
    private static let homeWallpaperFilename = "home-wallpaper.jpg"
    
    private init() { }
    
    func configure(appSettings: AppSettings) {
        self.appSettings = appSettings
        currentTheme = appSettings.setkaThemeConfiguration
        appSettings.appAppearance = currentTheme.themeMode.appAppearance
    }
    
    func apply(theme: SetkaThemeConfiguration) {
        currentTheme = theme
        appSettings?.setkaThemeConfiguration = theme
        appSettings?.appAppearance = theme.themeMode.appAppearance
    }
    
    func resetToDefault() {
        apply(theme: .default)
    }
    
    var accentColor: Color {
        Color(hex: currentTheme.accentColorHex) ?? .compound.textActionPrimary
    }
    
    var shouldUseLiquidGlass: Bool {
        !currentTheme.disableLiquidGlassEffects
    }
    
    var shouldUseBlurEffects: Bool {
        currentTheme.enableBlurEffects
    }
    
    var uiScale: CGFloat {
        CGFloat(max(0.9, min(1.2, currentTheme.uiScale)))
    }
    
    var incomingBubbleColor: Color {
        Color(hex: currentTheme.incomingBubbleColorHex) ?? .compound._bgBubbleIncoming
    }
    
    var outgoingBubbleColor: Color {
        Color(hex: currentTheme.outgoingBubbleColorHex) ?? .compound._bgBubbleOutgoing
    }
    
    func resolvedIncomingBubbleColor(for colorScheme: ColorScheme) -> Color {
        resolveThemeColor(hex: currentTheme.incomingBubbleColorHex,
                          fallback: .compound._bgBubbleIncoming,
                          colorScheme: colorScheme,
                          darkFallbackHex: "#253341")
    }
    
    func resolvedOutgoingBubbleColor(for colorScheme: ColorScheme) -> Color {
        if normalizedHex(currentTheme.outgoingBubbleColorHex) == "D9FDD3" {
            return colorScheme == .dark ? Color(hex: "#2B5278") ?? .compound._bgBubbleOutgoing
                : Color(hex: "#DCEBFF") ?? .compound._bgBubbleOutgoing
        }
        
        return resolveThemeColor(hex: currentTheme.outgoingBubbleColorHex,
                                 fallback: .compound._bgBubbleOutgoing,
                                 colorScheme: colorScheme,
                                 darkFallbackHex: "#2B5278")
    }
    
    var outgoingBubbleGradient: LinearGradient? {
        guard let toColor = Color(hex: currentTheme.outgoingBubbleGradientToColorHex) else {
            return nil
        }
        
        return LinearGradient(colors: [outgoingBubbleColor, toColor],
                              startPoint: .topLeading,
                              endPoint: .bottomTrailing)
    }
    
    func resolvedOutgoingBubbleGradient(for colorScheme: ColorScheme) -> LinearGradient? {
        let toColorHex = currentTheme.outgoingBubbleGradientToColorHex
        guard !toColorHex.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return nil
        }
        
        let startColor = resolvedOutgoingBubbleColor(for: colorScheme)
        let normalizedToColor = normalizedHex(toColorHex)
        if normalizedToColor == "C8F5C0" || normalizedToColor == "D9FDD3" {
            let telegramLikeEnd = colorScheme == .dark ? Color(hex: "#365E8A") ?? startColor : Color(hex: "#CFE3FF") ?? startColor
            return LinearGradient(colors: [startColor, telegramLikeEnd],
                                  startPoint: .topLeading,
                                  endPoint: .bottomTrailing)
        }
        
        let endColor = resolveThemeColor(hex: toColorHex,
                                         fallback: startColor,
                                         colorScheme: colorScheme,
                                         darkFallbackHex: "#365E8A")
        
        return LinearGradient(colors: [startColor, endColor],
                              startPoint: .topLeading,
                              endPoint: .bottomTrailing)
    }
    
    var bubbleCornerRadius: CGFloat {
        CGFloat(max(0, min(24, currentTheme.bubbleRadiusDp)))
    }
    
    var wallpaperBlurRadius: CGFloat {
        guard shouldUseBlurEffects else { return 0 }
        return CGFloat(max(0, min(40, currentTheme.wallpaperBlurDp)))
    }
    
    var timelineOverlayOpacity: Double {
        Double(max(0, min(100, currentTheme.timelineOverlayOpacityPercent))) / 100.0
    }
    
    func resolvedTimelineOverlayOpacity(for colorScheme: ColorScheme) -> Double {
        let base = timelineOverlayOpacity
        if colorScheme == .dark {
            return max(base, 0.48)
        }
        return base
    }
    
    var homeBackgroundColor: Color {
        Color(hex: currentTheme.homeBackgroundColorHex) ?? .compound.bgCanvasDefault
    }
    
    func resolvedHomeBackgroundColor(for colorScheme: ColorScheme) -> Color {
        if normalizedHex(currentTheme.homeBackgroundColorHex) == "ECE5DD" {
            return colorScheme == .dark ? Color(hex: "#0F172A") ?? .compound.bgCanvasDefault
                : Color(hex: "#F2F5FA") ?? .compound.bgCanvasDefault
        }
        
        return resolveThemeColor(hex: currentTheme.homeBackgroundColorHex,
                                 fallback: .compound.bgCanvasDefault,
                                 colorScheme: colorScheme,
                                 darkFallbackHex: "#0F172A")
    }
    
    var homeGradient: LinearGradient {
        LinearGradient(colors: [Color(hex: currentTheme.homeGradientFromColorHex) ?? homeBackgroundColor,
                                Color(hex: currentTheme.homeGradientToColorHex) ?? homeBackgroundColor],
                       startPoint: .topLeading,
                       endPoint: .bottomTrailing)
    }
    
    func resolvedHomeGradient(for colorScheme: ColorScheme) -> LinearGradient {
        let background = resolvedHomeBackgroundColor(for: colorScheme)
        let fromColor = resolveThemeColor(hex: currentTheme.homeGradientFromColorHex,
                                          fallback: background,
                                          colorScheme: colorScheme,
                                          darkFallbackHex: "#0B1320")
        let toColor = resolveThemeColor(hex: currentTheme.homeGradientToColorHex,
                                        fallback: background,
                                        colorScheme: colorScheme,
                                        darkFallbackHex: "#111827")
        
        return LinearGradient(colors: [fromColor, toColor],
                              startPoint: .topLeading,
                              endPoint: .bottomTrailing)
    }
    
    func resolvedHomeWallpaperDimOpacity(for colorScheme: ColorScheme) -> Double {
        colorScheme == .dark ? 0.42 : 0.0
    }
    
    func resolvedDefaultRoomWallpaperStyle(for colorScheme: ColorScheme) -> String {
        if colorScheme == .dark {
            return "dark"
        }
        
        if currentTheme.defaultRoomWallpaperStyle == "none" {
            return "light"
        }
        
        return currentTheme.defaultRoomWallpaperStyle
    }
    
    var homeWallpaperURL: URL? {
        guard let path = currentTheme.homeWallpaperImagePath,
              let url = URL(string: path),
              url.isFileURL else {
            return nil
        }
        
        return FileManager.default.fileExists(atPath: url.path(percentEncoded: false)) ? url : nil
    }
    
    var isHomeChatListBubbled: Bool {
        currentTheme.homeChatListStyle == .bubble
    }
    
    var homeChatListOpacity: Double {
        Double(max(20, min(100, currentTheme.homeChatListOpacityPercent))) / 100.0
    }
    
    var homeChatListBubbleColor: Color {
        Color(hex: currentTheme.topBarBackgroundColorHex) ?? .compound.bgSubtleSecondary
    }
    
    func resolvedHomeChatListBubbleColor(for colorScheme: ColorScheme) -> Color {
        resolveThemeColor(hex: currentTheme.topBarBackgroundColorHex,
                          fallback: .compound.bgSubtleSecondary,
                          colorScheme: colorScheme,
                          darkFallbackHex: "#1C2431")
    }
    
    func setHomeWallpaper(imageData: Data) {
        guard let image = UIImage(data: imageData),
              let normalizedData = image.jpegData(compressionQuality: 0.92),
              let localFileURL = homeWallpaperFileURL() else {
            return
        }
        
        do {
            try normalizedData.write(to: localFileURL, options: .atomic)
            var updatedTheme = currentTheme
            updatedTheme.homeWallpaperImagePath = localFileURL.absoluteString
            updatedTheme.homeBackgroundStyle = .image
            apply(theme: updatedTheme)
        } catch {
            MXLog.error("Failed saving home wallpaper: \(error)")
        }
    }
    
    func removeHomeWallpaper() {
        if let existingURL = homeWallpaperURL {
            try? FileManager.default.removeItem(at: existingURL)
        }
        
        var updatedTheme = currentTheme
        updatedTheme.homeWallpaperImagePath = nil
        if updatedTheme.homeBackgroundStyle == .image {
            updatedTheme.homeBackgroundStyle = .solid
        }
        apply(theme: updatedTheme)
    }
    
    private func homeWallpaperFileURL() -> URL? {
        do {
            let cachesDirectory = try FileManager.default.url(for: .cachesDirectory,
                                                              in: .userDomainMask,
                                                              appropriateFor: nil,
                                                              create: true)
            let themeDirectory = cachesDirectory.appendingPathComponent(Self.homeWallpaperCacheDirectory, isDirectory: true)
            try FileManager.default.createDirectory(at: themeDirectory, withIntermediateDirectories: true)
            return themeDirectory.appendingPathComponent(Self.homeWallpaperFilename)
        } catch {
            MXLog.error("Failed preparing home wallpaper directory: \(error)")
            return nil
        }
    }
    
    private func resolveThemeColor(hex: String, fallback: Color, colorScheme: ColorScheme, darkFallbackHex: String) -> Color {
        guard colorScheme == .dark else {
            return Color(hex: hex) ?? fallback
        }
        
        guard let parsed = ParsedHexColor(hex: hex) else {
            return Color(hex: darkFallbackHex) ?? fallback
        }
        
        if parsed.isBright {
            return Color(hex: darkFallbackHex) ?? fallback
        }
        
        return parsed.color
    }
    
    private func normalizedHex(_ hex: String) -> String {
        var normalized = hex.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        if normalized.hasPrefix("#") {
            normalized.removeFirst()
        }
        return normalized
    }
}

extension UTType {
    static var setkaThemes: UTType {
        UTType(filenameExtension: "setkathemes") ?? .json
    }
}

extension Color {
    init?(hex: String) {
        var normalized = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if normalized.hasPrefix("#") {
            normalized.removeFirst()
        }
        
        guard normalized.count == 6 || normalized.count == 8,
              let int = UInt64(normalized, radix: 16) else {
            return nil
        }
        
        let r, g, b, a: UInt64
        if normalized.count == 8 {
            r = (int >> 24) & 0xFF
            g = (int >> 16) & 0xFF
            b = (int >> 8) & 0xFF
            a = int & 0xFF
        } else {
            r = (int >> 16) & 0xFF
            g = (int >> 8) & 0xFF
            b = int & 0xFF
            a = 0xFF
        }
        
        self = Color(.sRGB,
                     red: Double(r) / 255.0,
                     green: Double(g) / 255.0,
                     blue: Double(b) / 255.0,
                     opacity: Double(a) / 255.0)
    }
    
    func toHex(includeAlpha: Bool = false) -> String? {
        #if os(iOS)
        let uiColor = UIColor(self)
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0
        
        guard uiColor.getRed(&red, green: &green, blue: &blue, alpha: &alpha) else {
            return nil
        }
        
        if includeAlpha {
            return String(format: "#%02X%02X%02X%02X",
                          Int(red * 255),
                          Int(green * 255),
                          Int(blue * 255),
                          Int(alpha * 255))
        }
        
        return String(format: "#%02X%02X%02X",
                      Int(red * 255),
                      Int(green * 255),
                      Int(blue * 255))
        #else
        return nil
        #endif
    }
}

private struct ParsedHexColor {
    let color: Color
    let red: Double
    let green: Double
    let blue: Double
    
    var isBright: Bool {
        // Relative luminance approximation for UI brightness checks.
        (0.2126 * red + 0.7152 * green + 0.0722 * blue) > 0.65
    }
    
    init?(hex: String) {
        var normalized = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if normalized.hasPrefix("#") {
            normalized.removeFirst()
        }
        
        guard normalized.count == 6 || normalized.count == 8,
              let int = UInt64(normalized, radix: 16) else {
            return nil
        }
        
        let r, g, b: UInt64
        if normalized.count == 8 {
            r = (int >> 24) & 0xFF
            g = (int >> 16) & 0xFF
            b = (int >> 8) & 0xFF
        } else {
            r = (int >> 16) & 0xFF
            g = (int >> 8) & 0xFF
            b = int & 0xFF
        }
        
        red = Double(r) / 255.0
        green = Double(g) / 255.0
        blue = Double(b) / 255.0
        color = Color(.sRGB, red: red, green: green, blue: blue)
    }
}
