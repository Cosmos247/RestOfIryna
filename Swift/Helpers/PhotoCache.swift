//
//  PhotoCache.swift
//  RestOfIryna
//
//  Created by Dmytro Ihnatyuhin on 17.05.2026.
//
//  Two-part fix for the "wall of duplicate photos in chat" problem:
//
//    1. `PhotoCache` (actor) — once Telegram returns a `file_id` for a
//       first-time photo upload, the bot caches it keyed by the local
//       asset path. Subsequent sendPhoto calls pass `.fileId(cached)`
//       so Telegram references the server-side copy instead of re-
//       uploading the same JPEG bytes. Cache is in-memory only and is
//       lost on bot restart — the first send per asset re-uploads, then
//       cache fills back up. file_id is a global Telegram reference, so
//       one cached entry works for every user.
//
//    2. `sendScenicPhoto(...)` — top-level helper that, before sending
//       a capital/estate/etc. "scenery" photo, deletes the user's
//       previous scenery photo (tracked in `EphemeralChatState.
//       lastSceneryPhotoId`). Result: only one scenery photo per user
//       lives in chat at any time, navigation replaces it rather than
//       stacking. Sub-screens (trader Buy/Sell list, tavern Menu) keep
//       editing the same photo message via `editMessageCaption` and
//       don't touch the slot.
//
//  This is the default photo path for any new feature. Use it whenever
//  the photo is a "this is where you are" UI element (welcome screens,
//  location backdrops). For one-shot narrative art that must stay in
//  chat history (registration King's Oath, future lore beats), call
//  `bot.sendPhoto` directly or write a `sendCachedPhoto` variant that
//  skips the scenery cleanup.
//

import Foundation
@preconcurrency import Lingo
import SwiftTelegramBot

public actor PhotoCache {
    public static let shared = PhotoCache()

    /// Local asset path → Telegram file_id. Lost on bot restart; the next
    /// first-send per asset re-uploads and re-caches.
    private var fileIds: [String: String] = [:]

    public func fileId(for assetPath: String) -> String? {
        return fileIds[assetPath]
    }

    public func set(assetPath: String, fileId: String) {
        fileIds[assetPath] = fileId
    }
}

/// Send a "scenery" photo with two optimisations:
///   1. Reuses Telegram's cached `file_id` after the first upload (no
///      repeat JPEG bytes on the wire).
///   2. Deletes the user's previous scenery photo so chat history doesn't
///      accumulate duplicates as the player navigates between
///      capital/estate locations.
///
/// Caption + parseMode + replyMarkup mirror `TGSendPhotoParams`. If the
/// asset is missing on disk and there's no cached id, falls back to a
/// plain `sendMessage` with the caption as text — still consumes the
/// scenery slot so the next call cleans it up the same way.
@discardableResult
public func sendScenicPhoto(
    assetPath: String,
    caption: String,
    parseMode: TGParseMode = .html,
    replyMarkup: TGReplyMarkup?,
    toUser user: User,
    bot: TGBot
) async throws -> Int {
    let chatId = TGChatId.chat(user.telegramId)

    // Drop any prior scenery photo so this user only ever sees one in
    // chat. Failure to delete (message already gone, no permission) is
    // benign — we just lose the cleanup for this round.
    if let prev = await EphemeralChatState.shared.takeLastSceneryPhoto(telegramId: user.telegramId) {
        _ = try? await bot.deleteMessage(params: TGDeleteMessageParams(chatId: chatId, messageId: prev))
    }

    let cachedId = await PhotoCache.shared.fileId(for: assetPath)
    let inputData: Data? = cachedId == nil ? (try? Data(contentsOf: URL(fileURLWithPath: assetPath))) : nil

    // Asset missing AND not cached → text-only fallback. Still occupies
    // the scenery slot so a future scenic-send cleans it up too.
    if cachedId == nil && inputData == nil {
        let sent = try await bot.sendMessage(params: TGSendMessageParams(
            chatId: chatId,
            text: caption,
            parseMode: parseMode,
            replyMarkup: replyMarkup
        ))
        await EphemeralChatState.shared.setLastSceneryPhoto(telegramId: user.telegramId, messageId: sent.messageId)
        return sent.messageId
    }

    let photoSource: TGFileInfo
    if let cachedId = cachedId {
        photoSource = .fileId(cachedId)
    } else {
        let filename = (assetPath as NSString).lastPathComponent
        photoSource = .file(TGInputFile(filename: filename, data: inputData!, mimeType: "image/jpeg"))
    }

    let sent = try await bot.sendPhoto(params: TGSendPhotoParams(
        chatId: chatId,
        photo: photoSource,
        caption: caption,
        parseMode: parseMode,
        replyMarkup: replyMarkup
    ))

    // Capture fileId only on first successful upload (when we sent .file).
    // Telegram returns multiple `TGPhotoSize` entries (different
    // resolutions); the largest fileSize preserves the original.
    if cachedId == nil, let largest = sent.photo?.max(by: { ($0.fileSize ?? 0) < ($1.fileSize ?? 0) }) {
        await PhotoCache.shared.set(assetPath: assetPath, fileId: largest.fileId)
    }

    await EphemeralChatState.shared.setLastSceneryPhoto(telegramId: user.telegramId, messageId: sent.messageId)
    return sent.messageId
}
