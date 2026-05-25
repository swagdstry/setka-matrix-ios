//
// Copyright 2025 Element Creations Ltd.
// Copyright 2022-2025 New Vector Ltd.
//
// SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial.
// Please see LICENSE files in the repository root for full details.
//

import Foundation
import OrderedCollections
import SwiftUI
import UIKit

struct TextRoomTimelineView: View, TextBasedRoomTimelineViewProtocol {
    static let maxLinkPreviewsToRender = 2
    
    @Environment(\.timelineContext) private var context
    let timelineItem: TextRoomTimelineItem
    
    @State private var linkMetadata: OrderedDictionary<URL, LinkMetadataProviderItem>
    @State private var selectedSetkaPack: SetkaPackLinkCardView.PackData?
    @State private var inlineEmojiImages: [String: UIImage] = [:]
    @ScaledMetric(relativeTo: .body) private var inlineEmojiSize: CGFloat = 20.0
    
    init(timelineItem: TextRoomTimelineItem, linkMetadata: OrderedDictionary<URL, LinkMetadataProviderItem> = [:]) {
        self.timelineItem = timelineItem
        self.linkMetadata = linkMetadata
    }
    
    var body: some View {
        TimelineStyler(timelineItem: timelineItem) {
            VStack(alignment: .leading, spacing: 8) {
                if shouldRenderMessageText, let inlineComponents = inlineSetkaComponents, setkaPackLinks.isEmpty {
                    inlineSetkaText(from: inlineComponents)
                        .font(.compound.bodyLG)
                        .foregroundColor(.compound.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                        .task {
                            await loadInlineSetkaEmojiImages(for: inlineComponents)
                        }
                } else if shouldRenderMessageText, let attributedString = timelineItem.content.formattedBody, setkaPackLinks.isEmpty {
                    FormattedBodyText(attributedString: attributedString,
                                      additionalWhitespacesCount: timelineItem.additionalWhitespaces(),
                                      boostFontSize: timelineItem.shouldBoost)
                } else if shouldRenderMessageText {
                    FormattedBodyText(text: renderedMessageText,
                                      additionalWhitespacesCount: timelineItem.additionalWhitespaces(),
                                      boostFontSize: timelineItem.shouldBoost)
                }
                
                if context?.viewState.linkPreviewsEnabled ?? false, !linkMetadata.keys.isEmpty {
                    VStack(spacing: 8) {
                        ForEach(linkPreviewURLs, id: \.absoluteString) { url in
                            let metadata = linkMetadata[url]?.metadata ?? context?.viewState.linkMetadataProvider?.metadataItems[url]?.metadata
                            LinkPreviewView(url: url, metadata: metadata)
                        }
                    }
                    .padding(.bottom, 16)
                }

                if !setkaPackLinks.isEmpty {
                    VStack(spacing: 8) {
                        ForEach(setkaPackLinks, id: \.id) { pack in
                            SetkaPackLinkCardView(pack: pack,
                                                  mediaProvider: context?.mediaProvider) {
                                selectedSetkaPack = pack
                            }
                        }
                    }
                    .padding(.bottom, 16)
                }
            }
        }
        .task { await fetchLinkPreviews() }
        .sheet(item: $selectedSetkaPack) { pack in
            SetkaPackPreviewSheet(pack: pack,
                                  resolvedPack: context?.viewState.setkaPlusStickerPacks.first { $0.id == pack.packID },
                                  mediaProvider: context?.mediaProvider) { packID in
                context?.send(viewAction: .importSetkaPlusSharedPack(token: pack.shareToken, packID: packID))
            }
        }
    }
    
    private func fetchLinkPreviews() async {
        guard context?.viewState.linkPreviewsEnabled ?? false else {
            return
        }
        
        await withTaskGroup { taskGroup in
            for url in timelineItem.links.prefix(Self.maxLinkPreviewsToRender) {
                taskGroup.addTask {
                    if case let .success(metadata) = await context?.viewState.linkMetadataProvider?.fetchMetadataFor(url: url) {
                        await MainActor.run {
                            linkMetadata[url] = metadata
                        }
                    }
                }
            }
        }
    }

    private var setkaPackLinks: [SetkaPackLinkCardView.PackData] {
        let urlsFromTimeline = timelineItem.links
        let urlsFromMessageText = SetkaPackLinkParser.extractSetkaPackURLs(from: timelineItem.body)
        let urls = Array(Set(urlsFromTimeline + urlsFromMessageText))
        
        var uniquePacks: [SetkaPackLinkCardView.PackData] = []
        var seenPackIDs = Set<String>()
        for url in urls {
            guard let pack = SetkaPackLinkParser.parse(url: url),
                  seenPackIDs.insert(pack.packID).inserted else {
                continue
            }
            uniquePacks.append(pack)
        }
        
        return uniquePacks
    }

    private var linkPreviewURLs: [URL] {
        linkMetadata.keys.filter { url in
            SetkaPackLinkParser.parse(url: url) == nil
        }
    }

    private var renderedMessageText: String {
        let setkaPackURLs = SetkaPackLinkParser.extractSetkaPackURLs(from: timelineItem.body)
        guard !setkaPackURLs.isEmpty else {
            return timelineItem.body
        }

        var text = timelineItem.body
        for url in setkaPackURLs {
            text = text.replacingOccurrences(of: url.absoluteString, with: "")
        }

        return text
            .replacingOccurrences(of: "\n{3,}", with: "\n\n", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var shouldRenderMessageText: Bool {
        !renderedMessageText.isEmpty || !inlineSetkaRenderingText().isEmpty || !setkaPackLinks.isEmpty
    }
    
    private var inlineSetkaComponents: [InlineSetkaComponent]? {
        let htmlEmojiByToken = extractSetkaInlineEmojiFromHTML(timelineItem.content.formattedBodyHTMLString)
        let text = inlineSetkaRenderingText(htmlEmojiByToken: htmlEmojiByToken)
        guard text.contains("[img:") || text.contains(":") else {
            return nil
        }
        
        // Normalized token -> emoji map for quick lookup.
        var emojiByToken = htmlEmojiByToken
        let emojiPacks = (context?.viewState.setkaPlusStickerPacks ?? []).filter { $0.kind.lowercased() == "emoji" }
        for pack in emojiPacks {
            for sticker in pack.stickers {
                let emoji = InlineSetkaEmoji(id: sticker.id,
                                             name: sticker.name,
                                             mxcURL: sticker.mxcURL,
                                             mimeType: sticker.mimeType)
                emojiByToken[normalizedSetkaTokenName(sticker.name)] = emoji
                emojiByToken[sticker.id.lowercased()] = emoji
            }
        }
        
        guard !emojiByToken.isEmpty else {
            return nil
        }
        
        let pattern = #"\[img:\s*:([A-Za-z0-9_-]+):\]|:([A-Za-z0-9_-]+):"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else {
            return nil
        }
        
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        let matches = regex.matches(in: text, options: [], range: range)
        guard !matches.isEmpty else {
            return nil
        }
        
        var result: [InlineSetkaComponent] = []
        var currentLocation = range.location
        
        for match in matches {
            if match.range.location > currentLocation,
               let plainRange = Range(NSRange(location: currentLocation, length: match.range.location - currentLocation), in: text) {
                let chunk = String(text[plainRange])
                if !chunk.isEmpty {
                    result.append(.text(chunk))
                }
            }
            
            let imgTokenRange = match.range(at: 1)
            let plainTokenRange = match.range(at: 2)
            let tokenRange = imgTokenRange.location != NSNotFound ? imgTokenRange : plainTokenRange
            
            if let tokenSwiftRange = Range(tokenRange, in: text) {
                let token = String(text[tokenSwiftRange]).lowercased()
                if let emoji = emojiByToken[token] {
                    result.append(.emoji(emoji))
                } else if let fullRange = Range(match.range, in: text) {
                    // Keep original text if the token is unknown.
                    result.append(.text(String(text[fullRange])))
                }
            }
            
            currentLocation = match.range.location + match.range.length
        }
        
        if currentLocation < range.location + range.length,
           let tailRange = Range(NSRange(location: currentLocation, length: (range.location + range.length) - currentLocation), in: text) {
            let tail = String(text[tailRange])
            if !tail.isEmpty {
                result.append(.text(tail))
            }
        }
        
        // Only use custom inline rendering if we resolved at least one emoji.
        return result.contains { if case .emoji = $0 { return true } else { return false } } ? result : nil
    }
    
    private func inlineSetkaText(from components: [InlineSetkaComponent]) -> Text {
        let fragments = components.map { component -> Text in
            switch component {
            case .text(let text):
                return Text(text)
            case .emoji(let emoji):
                if let image = inlineEmojiImages[emoji.id] {
                    return Text(Image(uiImage: image).renderingMode(.original))
                } else {
                    // Keep a tiny placeholder to preserve text flow while the image is loading.
                    return Text(" ")
                }
            }
        }
        
        return fragments.reduce(Text(""), +)
    }
    
    private func loadInlineSetkaEmojiImages(for components: [InlineSetkaComponent]) async {
        let emojis = components.compactMap { component -> InlineSetkaEmoji? in
            if case .emoji(let emoji) = component {
                return emoji
            }
            return nil
        }
        
        for emoji in emojis where inlineEmojiImages[emoji.id] == nil {
            guard let sourceURL = URL(string: emoji.mxcURL),
                  let mediaSource = try? MediaSourceProxy(url: sourceURL, mimeType: emoji.mimeType),
                  case let .success(image) = await context?.mediaProvider?.loadImageFromSource(mediaSource, size: inlineEmojiImageSize) else {
                continue
            }
            
            inlineEmojiImages[emoji.id] = image.resizedForInlineEmoji(size: inlineEmojiImageSize)
        }
    }
    
    private var inlineEmojiImageSize: CGSize {
        .init(width: inlineEmojiSize, height: inlineEmojiSize)
    }
    
    private func inlineSetkaRenderingText(htmlEmojiByToken: [String: InlineSetkaEmoji]? = nil) -> String {
        let htmlEmojiByToken = htmlEmojiByToken ?? extractSetkaInlineEmojiFromHTML(timelineItem.content.formattedBodyHTMLString)
        if !htmlEmojiByToken.isEmpty,
           let htmlText = setkaInlineTextFromHTML(timelineItem.content.formattedBodyHTMLString) {
            return removingSetkaPackLinks(from: htmlText)
        }
        
        return renderedMessageText
    }
    
    private func removingSetkaPackLinks(from text: String) -> String {
        let setkaPackURLs = SetkaPackLinkParser.extractSetkaPackURLs(from: text)
        guard !setkaPackURLs.isEmpty else {
            return text
        }
        
        var cleanedText = text
        for url in setkaPackURLs {
            cleanedText = cleanedText.replacingOccurrences(of: url.absoluteString, with: "")
        }
        
        return cleanedText
            .replacingOccurrences(of: "\n{3,}", with: "\n\n", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    private func setkaInlineTextFromHTML(_ html: String?) -> String? {
        guard let html, html.range(of: "data-mx-emoticon", options: .caseInsensitive) != nil else {
            return nil
        }
        
        let tagPattern = #"<img[^>]*data-mx-emoticon[^>]*>"#
        guard let tagRegex = try? NSRegularExpression(pattern: tagPattern, options: [.caseInsensitive, .dotMatchesLineSeparators]) else {
            return nil
        }
        
        let normalizedHTML = html.replacingOccurrences(of: "\\/", with: "/")
        let htmlRange = NSRange(normalizedHTML.startIndex..<normalizedHTML.endIndex, in: normalizedHTML)
        let matches = tagRegex.matches(in: normalizedHTML, range: htmlRange)
        guard !matches.isEmpty else {
            return nil
        }
        
        var result = ""
        var currentLocation = htmlRange.location
        var emojiIndex = 1
        
        for match in matches {
            if match.range.location > currentLocation,
               let plainRange = Range(NSRange(location: currentLocation, length: match.range.location - currentLocation), in: normalizedHTML) {
                result += plainTextFromHTMLFragment(String(normalizedHTML[plainRange]))
            }
            
            if let tagRange = Range(match.range, in: normalizedHTML) {
                let attributes = attributes(fromHTMLTag: String(normalizedHTML[tagRange]))
                let rawToken = [attributes["alt"], attributes["title"], attributes["data-mx-emoticon"]]
                    .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
                    .first { !$0.isEmpty && $0 != "true" && $0 != "1" }
                
                result += normalizedSetkaTokenString(rawToken, fallbackIndex: emojiIndex)
                emojiIndex += 1
            }
            
            currentLocation = match.range.location + match.range.length
        }
        
        if currentLocation < htmlRange.location + htmlRange.length,
           let tailRange = Range(NSRange(location: currentLocation, length: (htmlRange.location + htmlRange.length) - currentLocation), in: normalizedHTML) {
            result += plainTextFromHTMLFragment(String(normalizedHTML[tailRange]))
        }
        
        let trimmedResult = result
            .replacingOccurrences(of: "\n{3,}", with: "\n\n", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmedResult.isEmpty ? nil : trimmedResult
    }
    
    private func plainTextFromHTMLFragment(_ fragment: String) -> String {
        fragment
            .replacingOccurrences(of: #"(?i)<br\s*/?>"#, with: "\n", options: .regularExpression)
            .replacingOccurrences(of: #"(?i)</p\s*>"#, with: "\n", options: .regularExpression)
            .replacingOccurrences(of: #"<[^>]+>"#, with: "", options: .regularExpression)
            .replacingOccurrences(of: "&nbsp;", with: " ")
            .replacingOccurrences(of: "&quot;", with: "\"")
            .replacingOccurrences(of: "&#39;", with: "'")
            .replacingOccurrences(of: "&lt;", with: "<")
            .replacingOccurrences(of: "&gt;", with: ">")
            .replacingOccurrences(of: "&amp;", with: "&")
    }
    
    private func normalizedSetkaTokenString(_ rawToken: String?, fallbackIndex: Int) -> String {
        guard let rawToken, !rawToken.isEmpty else {
            return ":emoji_\(fallbackIndex):"
        }
        
        return rawToken.hasPrefix(":") && rawToken.hasSuffix(":") ? rawToken : ":\(rawToken):"
    }
    
    private func extractSetkaInlineEmojiFromHTML(_ html: String?) -> [String: InlineSetkaEmoji] {
        guard let html, html.range(of: "data-mx-emoticon", options: .caseInsensitive) != nil else {
            return [:]
        }
        
        let tagPattern = #"<img[^>]*data-mx-emoticon[^>]*>"#
        guard let tagRegex = try? NSRegularExpression(pattern: tagPattern, options: [.caseInsensitive, .dotMatchesLineSeparators]) else {
            return [:]
        }
        
        let normalizedHTML = html.replacingOccurrences(of: "\\/", with: "/")
        let htmlRange = NSRange(normalizedHTML.startIndex..<normalizedHTML.endIndex, in: normalizedHTML)
        var result: [String: InlineSetkaEmoji] = [:]
        
        for tagMatch in tagRegex.matches(in: normalizedHTML, range: htmlRange) {
            guard let tagRange = Range(tagMatch.range, in: normalizedHTML) else {
                continue
            }
            
            let tag = String(normalizedHTML[tagRange])
            let attributes = attributes(fromHTMLTag: tag)
            
            let source = [attributes["data-mx-url"], attributes["data-mx-src"], attributes["src"]]
                .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: "\\s+", with: "", options: .regularExpression) }
                .first { !$0.isEmpty }
            
            guard let source else {
                continue
            }
            
            let rawToken = [attributes["alt"], attributes["title"], attributes["data-mx-emoticon"]]
                .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
                .first { !$0.isEmpty && $0 != "true" && $0 != "1" }
            let token = rawToken?.trimmingCharacters(in: CharacterSet(charactersIn: ":")).lowercased() ?? "emoji_\(result.count + 1)"
            let name = rawToken ?? ":\(token):"
            let emoji = InlineSetkaEmoji(id: "html:\(source):\(token)", name: name, mxcURL: source, mimeType: nil)
            result[token] = emoji
        }
        
        return result
    }
    
    private func attributes(fromHTMLTag tag: String) -> [String: String] {
        let attrPattern = #"([A-Za-z0-9:_-]+)\s*=\s*(?:"([^"]*)"|'([^']*)'|([^\s>]+))"#
        guard let attrRegex = try? NSRegularExpression(pattern: attrPattern, options: [.caseInsensitive]) else {
            return [:]
        }
        
        let tagRange = NSRange(tag.startIndex..<tag.endIndex, in: tag)
        var attributes: [String: String] = [:]
        for attrMatch in attrRegex.matches(in: tag, range: tagRange) {
            guard let keyRange = Range(attrMatch.range(at: 1), in: tag) else {
                continue
            }
            
            let valueRange = (2...4)
                .map { attrMatch.range(at: $0) }
                .first { $0.location != NSNotFound && $0.length > 0 }
            
            guard let valueRange, let valueSwiftRange = Range(valueRange, in: tag) else {
                continue
            }
            
            attributes[String(tag[keyRange]).lowercased()] = String(tag[valueSwiftRange])
        }
        
        return attributes
    }
    
    private func normalizedSetkaTokenName(_ name: String) -> String {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let spacesNormalized = trimmed.replacingOccurrences(of: " ", with: "_")
        let replaced = spacesNormalized.replacingOccurrences(of: "[^A-Za-z0-9_]+", with: "_", options: .regularExpression)
        let collapsed = replaced.replacingOccurrences(of: "_+", with: "_", options: .regularExpression)
        let normalized = collapsed.trimmingCharacters(in: CharacterSet(charactersIn: "_")).lowercased()
        return normalized.isEmpty ? "emoji" : normalized
    }
}

private enum InlineSetkaComponent: Identifiable {
    case text(String)
    case emoji(InlineSetkaEmoji)
    
    var id: String {
        switch self {
        case .text(let text):
            return "t:\(text.hashValue)"
        case .emoji(let emoji):
            return "e:\(emoji.id):\(emoji.mxcURL)"
        }
    }
}

private struct InlineSetkaEmoji: Identifiable, Hashable {
    let id: String
    let name: String
    let mxcURL: String
    let mimeType: String?
}

private extension UIImage {
    func resizedForInlineEmoji(size: CGSize) -> UIImage {
        guard size.width > 0, size.height > 0, self.size.width > 0, self.size.height > 0 else {
            return self
        }
        
        let scale = min(size.width / self.size.width, size.height / self.size.height)
        let scaledSize = CGSize(width: self.size.width * scale, height: self.size.height * scale)
        let origin = CGPoint(x: (size.width - scaledSize.width) / 2, y: (size.height - scaledSize.height) / 2)
        let format = UIGraphicsImageRendererFormat()
        format.scale = UIScreen.main.scale
        format.opaque = false
        
        return UIGraphicsImageRenderer(size: size, format: format).image { _ in
            draw(in: CGRect(origin: origin, size: scaledSize))
        }
    }
}

struct TextRoomTimelineView_Previews: PreviewProvider, TestablePreview {
    static let viewModel = TimelineViewModel.mock
    
    static var previews: some View {
        body.environmentObject(viewModel.context)
            .previewDisplayName("Bubble")
            .previewLayout(.sizeThatFits)
        body
            .environmentObject(viewModel.context)
            .environment(\.layoutDirection, .rightToLeft)
            .previewDisplayName("Bubble RTL")
            .previewLayout(.sizeThatFits)
    }
    
    static var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20.0) {
                TextRoomTimelineView(timelineItem: itemWith(text: "Short loin ground round tongue hamburger, fatback salami shoulder. Beef turkey sausage kielbasa strip steak. Alcatra capicola pig tail pancetta chislic.",
                                                            timestamp: .mock,
                                                            isOutgoing: false,
                                                            senderId: "Bob"))
                
                TextRoomTimelineView(timelineItem: itemWith(text: "Check out this cool website: https://www.apple.com and also https://github.com for some great projects!",
                                                            timestamp: .mock,
                                                            isOutgoing: true,
                                                            senderId: "Anne"))
                
                TextRoomTimelineView(timelineItem: itemWith(text: "Short loin ground round tongue hamburger, fatback salami shoulder. Beef turkey sausage kielbasa strip steak. Alcatra capicola pig tail pancetta chislic.",
                                                            timestamp: .mock,
                                                            isOutgoing: false,
                                                            senderId: "Bob"))
                
                TextRoomTimelineView(timelineItem: itemWith(text: "Some other text",
                                                            timestamp: .mock,
                                                            isOutgoing: true,
                                                            senderId: "Anne"))
                
                TextRoomTimelineView(timelineItem: itemWith(text: "טקסט אחר",
                                                            timestamp: .mock,
                                                            isOutgoing: true,
                                                            senderId: "Anne"))
                
                TextRoomTimelineView(timelineItem: itemWith(html: "<ol><li>First item</li><li>Second item</li><li>Third item</li></ol>",
                                                            timestamp: .mock,
                                                            isOutgoing: true,
                                                            senderId: "Anne"))
                
                TextRoomTimelineView(timelineItem: itemWith(html: "<ol><li>פריט ראשון</li><li>הפריט השני</li><li>פריט שלישי</li></ol>",
                                                            timestamp: .mock,
                                                            isOutgoing: true,
                                                            senderId: "Anne"))
                
                // HTML with links for testing
                TextRoomTimelineView(timelineItem: itemWith(html: "Check out <a href=\"https://www.apple.com\">Apple's website</a> and <a href=\"https://github.com\">GitHub</a>!",
                                                            timestamp: .mock,
                                                            isOutgoing: false,
                                                            senderId: "Bob"))
            }
        }
    }
    
    private static func itemWith(text: String, timestamp: Date, isOutgoing: Bool, senderId: String) -> TextRoomTimelineItem {
        TextRoomTimelineItem(id: .randomEvent,
                             timestamp: timestamp,
                             isOutgoing: isOutgoing,
                             isEditable: isOutgoing,
                             canBeRepliedTo: true,
                             sender: .init(id: senderId),
                             content: .init(body: text))
    }
    
    private static func itemWith(html: String, timestamp: Date, isOutgoing: Bool, senderId: String) -> TextRoomTimelineItem {
        let builder = AttributedStringBuilder(cacheKey: "preview", mentionBuilder: MentionBuilder())
        let attributedString = builder.fromHTML(html)
        
        return TextRoomTimelineItem(id: .randomEvent,
                                    timestamp: timestamp,
                                    isOutgoing: isOutgoing,
                                    isEditable: isOutgoing,
                                    canBeRepliedTo: true,
                                    sender: .init(id: senderId),
                                    content: .init(body: "", formattedBody: attributedString))
    }
}
