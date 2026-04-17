//
//  ContentType.swift
//  RestOfIryna
//
//  Created by Maxim Lanskoy on 13.06.2025.
//  Maintained by Dmytro Ihnatyuhin from 17.04.2026.
//

import Foundation

public enum ContentType {
	case command(Command)
    case commands([Command])
	case from
	case forwardFrom
	case forwardFromChat
	case forwardDate
	case replyToMessage
	case editDate
	case text
	case entities
	case audio
	case document
	case photo
	case sticker
	case video
	case voice
	case caption
	case contact
	case location
	case venue
	case newChatMembers
	case leftChatMember
	case newChatTitle
	case newChatPhoto
	case deleteChatPhoto
	case groupChatCreated
	case supergroupChatCreated
	case channelChatCreated
	case migrateToChatId
	case migrateFromChatId
	case pinnedMessage
    case callback_query(data: String?)
    
    case editedFrom
    case editedForwardFrom
    case editedForwardFromChat
    case editedForwardDate
    case editedReplyToMessage
    case editedEditDate
    case editedText
    case editedEntities
    case editedAudio
    case editedDocument
    case editedPhoto
    case editedSticker
    case editedVideo
    case editedVoice
    case editedCaption
    case editedContact
    case editedLocation
    case editedVenue
}
