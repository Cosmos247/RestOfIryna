//
//  EphemeralChatState.swift
//  RestOfIryna
//
//  Created by Dmytro Ihnatyuhin on 23.04.2026.
//
//  In-memory bookkeeping for transient bot messages whose ID we want to be
//  able to delete later — currently the Exploration mode picker (shown on
//  the first Explore tap, with inline [Reconnaissance] / [Expedition]
//  buttons). When the player taps a main-menu button instead of one of
//  those inline choices, we want the picker message to disappear so it
//  can't be tapped again out of context.
//
//  Intentionally NOT persisted. If the bot restarts, any stale picker in
//  chat history still has live buttons — tapping would start an
//  expedition normally (same as if the player had stayed on the picker).
//

import Foundation

public actor EphemeralChatState {
    public static let shared = EphemeralChatState()

    private var pendingPickers: [Int64: Int] = [:]

    public func setPicker(telegramId: Int64, messageId: Int) {
        pendingPickers[telegramId] = messageId
    }

    public func takePicker(telegramId: Int64) -> Int? {
        pendingPickers.removeValue(forKey: telegramId)
    }
}
