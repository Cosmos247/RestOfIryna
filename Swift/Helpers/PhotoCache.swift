//
//  PhotoCache.swift
//  RestOfIryna
//
//  Created by Dmytro Ihnatyuhin on 17.05.2026.
//
//  `file_id` reuse for player-visible photos:
//
//    `PhotoCache` (actor) — once Telegram returns a `file_id` for a
//    first-time photo upload, the bot caches it keyed by the local asset
//    path. Subsequent sends pass `.fileId(cached)` so Telegram references
//    the server-side copy instead of re-uploading the same JPEG/PNG bytes.
//    A file_id is a global Telegram reference, so one cached entry works
//    for every user. Cache is in-memory only and is lost on bot restart —
//    the first send per asset re-uploads, then the cache fills back up.
//
//    `sendCachedPhoto(...)` — top-level helper that sends a photo through
//    that cache. It does NOT delete or replace any previous photo: every
//    location/lore photo stays in chat history (players asked to keep a
//    visible record of where they've been). Because each bubble references
//    the same server-side file_id, a long history of repeated backdrops
//    costs no extra storage — Telegram dedups by file_id.
//
//    This is the default photo path for ALL player-visible art — location
//    backdrops (capital/estate/tavern/trader/fortune), registration scenes,
//    future lore beats. Anything that wants in-chat cleanup (e.g. tavern
//    gambling rolls) deletes its own messages explicitly; the photo helper
//    never deletes.
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

    /// Local asset path → the `file_unique_id` of every size Telegram made of
    /// it. A `file_id` may differ from one message to the next; the unique id
    /// does not, so it is what answers "is this message already showing that
    /// picture?" — the question `editScreen(_:art:…)` asks before it swaps one.
    private var uniqueIds: [String: Set<String>] = [:]

    /// Note what a message that carries `assetPath` came back with.
    public func note(assetPath: String, photo: [TGPhotoSize]?) {
        guard let photo, !photo.isEmpty else { return }
        uniqueIds[assetPath, default: []].formUnion(photo.map(\.fileUniqueId))
        if fileIds[assetPath] == nil, let largest = photo.max(by: { ($0.fileSize ?? 0) < ($1.fileSize ?? 0) }) {
            fileIds[assetPath] = largest.fileId
        }
    }

    /// True only when the cache KNOWS the photo is this asset. After a restart
    /// it knows nothing, and the caller swaps a picture that may already be
    /// there — one wasted call, never a wrong picture.
    public func shows(assetPath: String, photo: [TGPhotoSize]?) -> Bool {
        guard let photo, let known = uniqueIds[assetPath] else { return false }
        return photo.contains { known.contains($0.fileUniqueId) }
    }
}

/// Send a player-visible photo, reusing Telegram's cached `file_id` after
/// the first upload (no repeat bytes on the wire for any later send of the
/// same asset). The message is left in chat — nothing is deleted, so the
/// player keeps a scrollable history of the locations they've visited.
///
/// Caption + parseMode + replyMarkup mirror `TGSendPhotoParams`. If the
/// asset is missing on disk and there's no cached id, falls back to a plain
/// `sendMessage` with the caption as text. Returns the sent message id.
@discardableResult
public func sendCachedPhoto(
    assetPath: String,
    caption: String,
    parseMode: TGParseMode = .html,
    replyMarkup: TGReplyMarkup?,
    toUser user: User,
    bot: TGBot
) async throws -> Int {
    let chatId = TGChatId.chat(user.telegramId)

    let cachedId = await PhotoCache.shared.fileId(for: assetPath)
    let inputData: Data? = cachedId == nil ? (try? Data(contentsOf: URL(fileURLWithPath: assetPath))) : nil

    // Asset missing AND not cached → text-only fallback.
    if cachedId == nil && inputData == nil {
        let sent = try await bot.sendMessage(params: TGSendMessageParams(
            chatId: chatId,
            text: caption,
            parseMode: parseMode,
            replyMarkup: replyMarkup
        ))
        return sent.messageId
    }

    let photoSource: TGFileInfo
    if let cachedId = cachedId {
        photoSource = .fileId(cachedId)
    } else {
        let filename = (assetPath as NSString).lastPathComponent
        // Auto-detect MIME from extension — tarot art ships as PNG, scenery
        // backdrops as JPG. Telegram is OK with either; passing the right
        // MIME lets the client pick a faster decode path.
        let ext = (filename as NSString).pathExtension.lowercased()
        let mime: String = (ext == "png") ? "image/png" : "image/jpeg"
        photoSource = .file(TGInputFile(filename: filename, data: inputData!, mimeType: mime))
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
    // resolutions); the largest fileSize preserves the original. The unique
    // ids are noted on every send, for `editScreen(_:art:…)`.
    await PhotoCache.shared.note(assetPath: assetPath, photo: sent.photo)

    return sent.messageId
}
