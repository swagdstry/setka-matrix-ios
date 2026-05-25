//
// Copyright 2025 Element Creations Ltd.
// Copyright 2024-2025 New Vector Ltd.
//
// SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial.
// Please see LICENSE files in the repository root for full details.
//

@testable import ElementX
import MatrixRustSDK
import Testing

@MainActor
struct TimelineItemFactoryTests {
    @Test
    func callInvite() throws {
        let ownUserID = "@alice:matrix.org"
        let senderUserID = "@bob:matrix.org"

        let factory = RoomTimelineItemFactory(userID: ownUserID,
                                              attributedStringBuilder: AttributedStringBuilder(mentionBuilder: MentionBuilder()),
                                              stateEventStringBuilder: RoomStateEventStringBuilder(userID: ownUserID))
        
        let eventTimelineItem = EventTimelineItem.mockCallInvite(sender: senderUserID)
        
        let eventTimelineItemProxy = EventTimelineItemProxy(item: eventTimelineItem, uniqueID: .init("0"))
                
        let item = try #require(factory.buildTimelineItem(for: eventTimelineItemProxy, isDM: false) as? CallInviteRoomTimelineItem,
                                "Incorrect item type")
        
        #expect(item.isReactable == false)
        #expect(item.canBeRepliedTo == false)
        #expect(item.isEditable == false)
        #expect(item.sender == TimelineItemSender(id: senderUserID))
        #expect(item.properties.isEdited == false)
        #expect(item.properties.reactions == [])
        #expect(item.properties.deliveryStatus == nil)
    }
    
    @Test
    func textMessageWithCustomEmojiHTMLUsesAltFallbackWhenBodyIsBlank() throws {
        let ownUserID = "@alice:matrix.org"
        let html = "<img data-mx-emoticon src=\"mxc://example.org/abc\" alt=\":element_logo:\" title=\"element_logo\" width=\"50\" height=\"50\" />"
        let messageType = MessageType.text(content: .init(body: "", formatted: .init(format: .html, body: html)))
        let content = TimelineItemContent.msgLike(content: .init(kind: .message(content: .init(msgType: messageType,
                                                                                               body: "",
                                                                                               isEdited: false,
                                                                                               mentions: nil)),
                                                                 reactions: [],
                                                                 inReplyTo: nil,
                                                                 threadRoot: nil,
                                                                 threadSummary: nil))
        
        let factory = RoomTimelineItemFactory(userID: ownUserID,
                                              attributedStringBuilder: AttributedStringBuilder(mentionBuilder: MentionBuilder()),
                                              stateEventStringBuilder: RoomStateEventStringBuilder(userID: ownUserID))
        let eventTimelineItem = EventTimelineItem(configuration: .init(content: content))
        let eventTimelineItemProxy = EventTimelineItemProxy(item: eventTimelineItem, uniqueID: .init("0"))
        
        let item = try #require(factory.buildTimelineItem(for: eventTimelineItemProxy, isDM: false) as? TextRoomTimelineItem,
                                "Incorrect item type")
        
        #expect(item.content.body == ":element_logo:")
        #expect(item.content.formattedBodyHTMLString == html)
    }
}
