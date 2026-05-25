//
// Copyright 2026 Element Creations Ltd.
// Copyright 2026 New Vector Ltd.
//
// SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial.
// Please see LICENSE files in the repository root for full details.
//

import Compound
import PhotosUI
import SwiftUI
import UniformTypeIdentifiers

struct AppThemeScreen: View {
    @Environment(\.dismiss) private var dismiss
    private let appSettings: AppSettings
    @ObservedObject private var themeService = AppThemeService.shared
    
    @State private var draftTheme = SetkaThemeConfiguration.default
    @State private var isFileImporterPresented = false
    @State private var isFileExporterPresented = false
    @State private var isResetConfirmationPresented = false
    @State private var isHomeWallpaperPhotoPickerPresented = false
    @State private var exportDocument: SetkaThemesDocument?
    @State private var selectedHomeWallpaperPhotoItem: PhotosPickerItem?
    @State private var alertInfo: AlertInfo<String>?
    
    init(appSettings: AppSettings) {
        self.appSettings = appSettings
    }
    
    var body: some View {
        Form {
            themePreviewSection
            themeModeSection
            colorsSection
            layoutSection
            homeSection
            behaviorSection
            fileSection
        }
        .compoundList()
        .navigationTitle(SetkaThemeL10n.appThemeTitle)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { toolbar }
        .onAppear {
            draftTheme = appSettings.setkaThemeConfiguration
        }
        .fileImporter(isPresented: $isFileImporterPresented,
                      allowedContentTypes: [.setkaThemes, .json],
                      allowsMultipleSelection: false,
                      onCompletion: handleImportResult)
        .fileExporter(isPresented: $isFileExporterPresented,
                      document: exportDocument,
                      contentType: .setkaThemes,
                      defaultFilename: "setka-theme-\(Int(Date().timeIntervalSince1970 * 1000))",
                      onCompletion: handleExportResult)
        .alert(item: $alertInfo)
        .confirmationDialog(L10n.actionReset,
                            isPresented: $isResetConfirmationPresented,
                            titleVisibility: .visible) {
            Button(L10n.actionReset, role: .destructive) {
                draftTheme = .default
                applyTheme()
            }
            
            Button(L10n.actionCancel, role: .cancel) { }
        }
        .photosPicker(isPresented: $isHomeWallpaperPhotoPickerPresented,
                      selection: $selectedHomeWallpaperPhotoItem,
                      matching: .images,
                      preferredItemEncoding: .automatic,
                      photoLibrary: .shared())
        .onChange(of: selectedHomeWallpaperPhotoItem) { _, newItem in
            Task {
                guard let data = try? await newItem?.loadTransferable(type: Data.self) else {
                    return
                }
                
                await MainActor.run {
                    themeService.setHomeWallpaper(imageData: data)
                    draftTheme = themeService.currentTheme
                }
            }
        }
    }
    
    private var toolbar: some ToolbarContent {
        ToolbarItem(placement: .confirmationAction) {
            Button(L10n.actionSave) {
                saveThemeAndDismiss()
            }
        }
    }
    
    private var themeModeSection: some View {
        Section {
            ListRow(label: .plain(title: L10n.commonAppearance),
                    kind: .picker(selection: Binding(get: {
                        draftTheme.themeMode
                    }, set: { newMode in
                        draftTheme.themeMode = newMode
                    }), items: SetkaThemeMode.allCases.map { mode in
                        (title: mode.rawValue, tag: mode)
                    }))
        }
    }
    
    private var themePreviewSection: some View {
        Section {
            ListRow(kind: .custom {
                SetkaThemeChatPreviewCard(theme: draftTheme)
                    .padding(ListRowPadding.insets)
            })
        } header: {
            Text(SetkaThemeL10n.sectionThemePreview)
                .compoundListSectionHeader()
        }
    }
    
    private var colorsSection: some View {
        Section {
            colorPickerRow(title: SetkaThemeL10n.colorAccent, keyPath: \.accentColorHex)
            colorPickerRow(title: SetkaThemeL10n.colorTopBarBackground, keyPath: \.topBarBackgroundColorHex)
            colorPickerRow(title: SetkaThemeL10n.colorTopBarText, keyPath: \.topBarTextColorHex)
            colorPickerRow(title: SetkaThemeL10n.colorComposerBackground, keyPath: \.composerBackgroundColorHex)
            colorPickerRow(title: SetkaThemeL10n.colorServiceBubble, keyPath: \.serviceBubbleColorHex)
            colorPickerRow(title: SetkaThemeL10n.colorServiceText, keyPath: \.serviceTextColorHex)
            colorPickerRow(title: SetkaThemeL10n.colorIncomingBubble, keyPath: \.incomingBubbleColorHex)
            colorPickerRow(title: SetkaThemeL10n.colorOutgoingBubble, keyPath: \.outgoingBubbleColorHex)
            colorPickerRow(title: SetkaThemeL10n.colorOutgoingGradient, keyPath: \.outgoingBubbleGradientToColorHex)
            colorPickerRow(title: SetkaThemeL10n.colorHomeBackground, keyPath: \.homeBackgroundColorHex)
        } header: {
            Text(SetkaThemeL10n.sectionColors)
                .compoundListSectionHeader()
        }
    }
    
    private var layoutSection: some View {
        Section {
            sliderRow(title: SetkaThemeL10n.layoutUiScale,
                      value: Binding(get: { draftTheme.uiScale }, set: { draftTheme.uiScale = $0 }),
                      range: 0.9...1.2,
                      step: 0.01)
            
            sliderRow(title: SetkaThemeL10n.layoutMessageScale,
                      value: Binding(get: { draftTheme.messageScale }, set: { draftTheme.messageScale = $0 }),
                      range: 0.85...1.3,
                      step: 0.01)
            
            sliderRow(title: SetkaThemeL10n.layoutBubbleRadius,
                      value: Binding(get: { Double(draftTheme.bubbleRadiusDp) }, set: { draftTheme.bubbleRadiusDp = Int($0) }),
                      range: 0...24,
                      step: 1)
            
            sliderRow(title: SetkaThemeL10n.layoutBubbleWidth,
                      value: Binding(get: { Double(draftTheme.bubbleWidthPercent) }, set: { draftTheme.bubbleWidthPercent = Int($0) }),
                      range: 60...95,
                      step: 1)
            
            sliderRow(title: SetkaThemeL10n.layoutTimelineOverlayOpacity,
                      value: Binding(get: { Double(draftTheme.timelineOverlayOpacityPercent) }, set: { draftTheme.timelineOverlayOpacityPercent = Int($0) }),
                      range: 0...100,
                      step: 1)
            
            sliderRow(title: SetkaThemeL10n.layoutComposerOpacity,
                      value: Binding(get: { Double(draftTheme.composerBackgroundOpacityPercent) }, set: { draftTheme.composerBackgroundOpacityPercent = Int($0) }),
                      range: 0...100,
                      step: 1)
            
            sliderRow(title: SetkaThemeL10n.layoutWallpaperBlur,
                      value: Binding(get: { Double(draftTheme.wallpaperBlurDp) }, set: { draftTheme.wallpaperBlurDp = Int($0) }),
                      range: 0...24,
                      step: 1)
            
            ListRow(label: .plain(title: SetkaThemeL10n.layoutDefaultRoomWallpaper),
                    kind: .picker(selection: Binding(get: {
                        draftTheme.defaultRoomWallpaperStyle
                    }, set: { draftTheme.defaultRoomWallpaperStyle = $0 }),
                    items: [("System", "none"), (L10n.commonLight, "light"), (L10n.commonDark, "dark")]))
        } header: {
            Text(SetkaThemeL10n.sectionLayout)
                .compoundListSectionHeader()
        }
    }
    
    private var homeSection: some View {
        Section {
            ListRow(label: .plain(title: SetkaThemeL10n.homeBackgroundStyle),
                    kind: .picker(selection: Binding(get: {
                        draftTheme.homeBackgroundStyle
                    }, set: { draftTheme.homeBackgroundStyle = $0 }),
                    items: SetkaHomeBackgroundStyle.allCases.map { style in
                        (title: title(for: style), tag: style)
                    }))
            
            colorPickerRow(title: SetkaThemeL10n.homeGradientFrom, keyPath: \.homeGradientFromColorHex)
            colorPickerRow(title: SetkaThemeL10n.homeGradientTo, keyPath: \.homeGradientToColorHex)
            
            ListRow(label: .plain(title: SetkaThemeL10n.homeChatListStyle),
                    kind: .picker(selection: Binding(get: {
                        draftTheme.homeChatListStyle
                    }, set: { draftTheme.homeChatListStyle = $0 }),
                    items: SetkaHomeChatListStyle.allCases.map { style in
                        (title: title(for: style), tag: style)
                    }))
            
            sliderRow(title: SetkaThemeL10n.homeChatListOpacity,
                      value: Binding(get: { Double(draftTheme.homeChatListOpacityPercent) }, set: { draftTheme.homeChatListOpacityPercent = Int($0) }),
                      range: 20...100,
                      step: 1)
            
            ListRow(label: .default(title: SetkaThemeL10n.homeWallpaperPick, icon: \.image),
                    kind: .button {
                        isHomeWallpaperPhotoPickerPresented = true
                    })
            
            ListRow(label: .action(title: SetkaThemeL10n.homeWallpaperReset,
                                   icon: \.delete,
                                   role: .destructive),
                    kind: .button {
                        themeService.removeHomeWallpaper()
                        draftTheme = themeService.currentTheme
                    })
        } header: {
            Text(SetkaThemeL10n.homeSection)
                .compoundListSectionHeader()
        }
    }
    
    private var behaviorSection: some View {
        Section {
            ListRow(label: .plain(title: SetkaThemeL10n.behaviorChatAnimations),
                    kind: .toggle(Binding(get: { draftTheme.enableChatAnimations }, set: { draftTheme.enableChatAnimations = $0 })))
            ListRow(label: .plain(title: SetkaThemeL10n.behaviorBlurEffects),
                    kind: .toggle(Binding(get: { draftTheme.enableBlurEffects }, set: { draftTheme.enableBlurEffects = $0 })))
            ListRow(label: .plain(title: SetkaThemeL10n.behaviorSeasonalEffects),
                    kind: .toggle(Binding(get: { draftTheme.enableSeasonalEffects }, set: { draftTheme.enableSeasonalEffects = $0 })))
            ListRow(label: .plain(title: SetkaThemeL10n.behaviorSeasonalEffectsReduceMotion),
                    kind: .toggle(Binding(get: { draftTheme.seasonalEffectsReduceMotion }, set: { draftTheme.seasonalEffectsReduceMotion = $0 })))
                .disabled(!draftTheme.enableSeasonalEffects)
            ListRow(label: .plain(title: SetkaThemeL10n.behaviorDisableLiquidGlass),
                    kind: .toggle(Binding(get: { draftTheme.disableLiquidGlassEffects }, set: { draftTheme.disableLiquidGlassEffects = $0 })))
            ListRow(label: .plain(title: SetkaThemeL10n.behaviorShowEncryptionStatus),
                    kind: .toggle(Binding(get: { draftTheme.showEncryptionStatus }, set: { draftTheme.showEncryptionStatus = $0 })))
            
            sliderRow(title: SetkaThemeL10n.behaviorInitialTimelineCount,
                      value: Binding(get: { Double(draftTheme.initialTimelineItemCount) }, set: { draftTheme.initialTimelineItemCount = Int($0) }),
                      range: 5...120,
                      step: 1)
        } header: {
            Text(SetkaThemeL10n.sectionBehavior)
                .compoundListSectionHeader()
        }
    }
    
    private var fileSection: some View {
        Section {
            ListRow(label: .default(title: SetkaThemeL10n.fileImport, icon: \.image),
                    kind: .button {
                        isFileImporterPresented = true
                    })
            
            ListRow(label: .default(title: SetkaThemeL10n.fileExport, icon: \.shareIos),
                    kind: .button {
                        exportDocument = SetkaThemesDocument(theme: draftTheme)
                        isFileExporterPresented = true
                    })
            
            ListRow(label: .action(title: L10n.actionReset, icon: \.delete, role: .destructive),
                    kind: .button {
                        isResetConfirmationPresented = true
                    })
        } header: {
            Text(SetkaThemeL10n.sectionFiles)
                .compoundListSectionHeader()
        } footer: {
            Text(SetkaThemeL10n.fileFooter)
                .compoundListSectionFooter()
        }
    }
    
    private func sliderRow(title: String, value: Binding<Double>, range: ClosedRange<Double>, step: Double) -> some View {
        ListRow(kind: .custom {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    Text(title)
                        .font(.compound.bodySM)
                        .foregroundStyle(.compound.textPrimary)
                    Spacer()
                    Text(formatValue(value.wrappedValue, step: step))
                        .font(.compound.bodyXS)
                        .foregroundStyle(.compound.textSecondary)
                        .monospacedDigit()
                }
                
                Slider(value: value, in: range, step: step)
                    .tint(.compound.textActionPrimary)
            }
            .padding(ListRowPadding.insets)
        })
    }
    
    private func colorPickerRow(title: String, keyPath: WritableKeyPath<SetkaThemeConfiguration, String>) -> some View {
        ListRow(kind: .custom {
            HStack(spacing: 8) {
                ColorPicker(title, selection: Binding(get: {
                    Color(hex: draftTheme[keyPath: keyPath]) ?? .compound.textPrimary
                }, set: { newColor in
                    if let hex = newColor.toHex() {
                        draftTheme[keyPath: keyPath] = hex
                    }
                }), supportsOpacity: false)
                
                Text(draftTheme[keyPath: keyPath])
                    .font(.compound.bodyXS)
                    .foregroundStyle(.compound.textSecondary)
                    .monospaced()
            }
            .padding(ListRowPadding.insets)
        })
    }
    
    private func applyTheme() {
        appSettings.setkaThemeConfiguration = draftTheme
        themeService.apply(theme: draftTheme)
        appSettings.appAppearance = draftTheme.themeMode.appAppearance
    }
    
    private func saveThemeAndDismiss() {
        applyTheme()
        dismiss()
    }
    
    private func handleImportResult(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }
            do {
                let data = try Data(contentsOf: url)
                let decoded = try JSONDecoder().decode(SetkaThemeConfiguration.self, from: data)
                draftTheme = decoded
                applyTheme()
            } catch {
                alertInfo = AlertInfo(id: UUID().uuidString, title: SetkaThemeL10n.importFailedTitle, message: error.localizedDescription)
            }
        case .failure(let error):
            alertInfo = AlertInfo(id: UUID().uuidString, title: SetkaThemeL10n.importFailedTitle, message: error.localizedDescription)
        }
    }
    
    private func handleExportResult(_ result: Result<URL, Error>) {
        if case let .failure(error) = result {
            alertInfo = AlertInfo(id: UUID().uuidString, title: SetkaThemeL10n.exportFailedTitle, message: error.localizedDescription)
        }
    }
    
    private func formatValue(_ value: Double, step: Double) -> String {
        if step >= 1 {
            return String(Int(value))
        }
        return String(format: "%.2f", value)
    }
    
    private func title(for style: SetkaHomeBackgroundStyle) -> String {
        switch style {
        case .solid:
            return SetkaThemeL10n.homeBackgroundStyleSolid
        case .gradient:
            return SetkaThemeL10n.homeBackgroundStyleGradient
        case .image:
            return SetkaThemeL10n.homeBackgroundStyleImage
        }
    }
    
    private func title(for style: SetkaHomeChatListStyle) -> String {
        switch style {
        case .plain:
            return SetkaThemeL10n.homeChatListStylePlain
        case .bubble:
            return SetkaThemeL10n.homeChatListStyleBubble
        }
    }
}

private struct SetkaThemeChatPreviewCard: View {
    let theme: SetkaThemeConfiguration
    
    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 12) {
                outgoingBubble(text: "Доброе утро! 👋", time: "21:18")
                
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 8) {
                        Rectangle()
                            .fill(accentColor)
                            .frame(width: 3)
                            .clipShape(Capsule())
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("evxrst")
                                .font(.system(size: 13, weight: .semibold, design: .rounded))
                                .foregroundStyle(accentColor)
                            Text("Доброе утро! 👋")
                                .font(messageFont)
                                .foregroundStyle(serviceTextColor)
                        }
                        Spacer(minLength: 0)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                    .background(serviceBubbleColor)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    
                    HStack(alignment: .lastTextBaseline, spacing: 8) {
                        Text("Знаешь, который час?")
                            .font(messageFont)
                            .foregroundStyle(incomingTextColor)
                        Text("21:20")
                            .font(.system(size: 12, weight: .medium, design: .rounded))
                            .foregroundStyle(secondaryTextColor)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(12)
                .background(incomingBubbleColor)
                .clipShape(RoundedRectangle(cornerRadius: bubbleCornerRadius, style: .continuous))
                .frame(maxWidth: bubbleMaxWidth, alignment: .leading)
                .frame(maxWidth: .infinity, alignment: .leading)
                
                outgoingBubble(text: "В Токио утро 😎", time: "21:22")
            }
            .padding(16)
            .background(chatBackground)
            
            Rectangle()
                .fill(topBarDivider)
                .frame(height: 1)
            
            HStack(spacing: 10) {
                Circle()
                    .fill(accentColor)
                    .frame(width: 10, height: 10)
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(composerBackgroundColor)
                    .frame(height: 34)
                    .overlay(alignment: .trailing) {
                        Circle()
                            .fill(accentColor.opacity(0.85))
                            .frame(width: 26, height: 26)
                            .padding(.trailing, 4)
                    }
            }
            .padding(12)
            .background(topBarColor.opacity(0.45))
        }
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(Color.white.opacity(0.08))
        }
    }
    
    private func outgoingBubble(text: String, time: String) -> some View {
        HStack(alignment: .lastTextBaseline, spacing: 8) {
            Text(text)
                .font(messageFont)
                .foregroundStyle(outgoingTextColor)
            Text(time)
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundStyle(secondaryTextColor)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(outgoingBubbleBackground)
        .clipShape(RoundedRectangle(cornerRadius: bubbleCornerRadius, style: .continuous))
        .frame(maxWidth: bubbleMaxWidth, alignment: .trailing)
        .frame(maxWidth: .infinity, alignment: .trailing)
    }
    
    @ViewBuilder
    private var chatBackground: some View {
        switch theme.homeBackgroundStyle {
        case .solid:
            homeBackgroundColor
        case .gradient:
            LinearGradient(colors: [homeGradientFromColor, homeGradientToColor],
                           startPoint: .topLeading,
                           endPoint: .bottomTrailing)
        case .image:
            ZStack {
                LinearGradient(colors: [homeGradientFromColor, homeGradientToColor],
                               startPoint: .topLeading,
                               endPoint: .bottomTrailing)
                Color.black.opacity(0.12)
            }
        }
    }
    
    private var messageFont: Font {
        let scale = CGFloat(max(0.85, min(1.3, theme.messageScale)))
        return .system(size: 16 * scale, weight: .regular, design: .rounded)
    }
    
    private var bubbleCornerRadius: CGFloat {
        CGFloat(max(8, min(24, theme.bubbleRadiusDp)))
    }
    
    private var bubbleMaxWidth: CGFloat {
        CGFloat(max(180, min(360, theme.bubbleWidthPercent * 4)))
    }
    
    private var accentColor: Color {
        Color(hex: theme.accentColorHex) ?? .compound.textActionPrimary
    }
    
    private var homeBackgroundColor: Color {
        Color(hex: theme.homeBackgroundColorHex) ?? .compound.bgCanvasDefault
    }
    
    private var homeGradientFromColor: Color {
        Color(hex: theme.homeGradientFromColorHex) ?? homeBackgroundColor
    }
    
    private var homeGradientToColor: Color {
        Color(hex: theme.homeGradientToColorHex) ?? homeBackgroundColor
    }
    
    private var incomingBubbleColor: Color {
        Color(hex: theme.incomingBubbleColorHex) ?? .compound._bgBubbleIncoming
    }
    
    private var serviceBubbleColor: Color {
        Color(hex: theme.serviceBubbleColorHex) ?? .compound.bgSubtleSecondary
    }
    
    private var serviceTextColor: Color {
        Color(hex: theme.serviceTextColorHex) ?? .compound.textSecondary
    }
    
    private var outgoingBubbleBackground: some ShapeStyle {
        let start = Color(hex: theme.outgoingBubbleColorHex) ?? .compound._bgBubbleOutgoing
        let end = Color(hex: theme.outgoingBubbleGradientToColorHex) ?? start
        return LinearGradient(colors: [start, end], startPoint: .topLeading, endPoint: .bottomTrailing)
    }
    
    private var outgoingTextColor: Color {
        Color(hex: theme.topBarTextColorHex) ?? .white
    }
    
    private var incomingTextColor: Color {
        Color(hex: theme.topBarTextColorHex) ?? .compound.textPrimary
    }
    
    private var secondaryTextColor: Color {
        (Color(hex: theme.topBarTextColorHex) ?? .compound.textSecondary).opacity(0.78)
    }
    
    private var topBarColor: Color {
        Color(hex: theme.topBarBackgroundColorHex) ?? .compound.bgSubtlePrimary
    }
    
    private var topBarDivider: Color {
        (Color(hex: theme.topBarTextColorHex) ?? .compound.borderDisabled).opacity(0.18)
    }
    
    private var composerBackgroundColor: Color {
        let baseColor = Color(hex: theme.composerBackgroundColorHex) ?? .compound.bgCanvasDefault
        let alpha = Double(max(0, min(100, theme.composerBackgroundOpacityPercent))) / 100.0
        return baseColor.opacity(alpha)
    }
}

private struct SetkaThemesDocument: FileDocument {
    static var readableContentTypes: [UTType] {
        [.setkaThemes, .json]
    }
    
    var theme: SetkaThemeConfiguration
    
    init(theme: SetkaThemeConfiguration) {
        self.theme = theme
    }
    
    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents else {
            throw CocoaError(.fileReadCorruptFile)
        }
        
        theme = try JSONDecoder().decode(SetkaThemeConfiguration.self, from: data)
    }
    
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        let data = try JSONEncoder().encode(theme)
        return FileWrapper(regularFileWithContents: data)
    }
}

// MARK: - Previews

struct AppThemeScreen_Previews: PreviewProvider, TestablePreview {
    static var previews: some View {
        ElementNavigationStack {
            AppThemeScreen(appSettings: ServiceLocator.shared.settings)
        }
    }
}
