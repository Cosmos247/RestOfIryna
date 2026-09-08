//
//  InviteToken.swift
//  RestOfIryna
//
//  Created by Dmytro Ihnatyuhin on 08.09.2026.
//
//  The invite token carried by a `/start` deep link during the closed test.
//
//  It is a timestamp and nothing else — but a timestamp the recipient can
//  neither read nor mint. `/link` issues one, the player taps the link, and
//  `TGDispatcher` decrypts it back to the instant it was created; a token
//  older than `validity` is refused. Nobody's identity is inside it, so one
//  link works for as many people as the admin forwards it to, for five
//  minutes, and then for nobody.
//
//  **Why encrypt AND authenticate.** Encryption alone hides the date and is
//  worth nothing on its own: the whole token is handed to the very people it
//  guards against, so the only real question is whether someone can WRITE a
//  fresh one. That is what the tag answers. The key is derived from the bot
//  token, which never leaves the server, so a forgery needs the bot's
//  credentials — at which point the invite gate is the least of the problems.
//
//  Layout: 2 bytes nonce · 4 bytes encrypted UNIX seconds · 4 bytes tag,
//  base32-encoded over an alphabet of LETTERS ONLY — exactly 16 characters,
//  well inside Telegram's 64-character limit for a start parameter, and
//  indistinguishable from noise.
//

import Crypto
import Foundation

enum InviteToken {

    /// How long a freshly minted token stays redeemable.
    static let validity: TimeInterval = 300  // 5 minutes

    /// A token whose timestamp is ahead of us by more than this is treated as
    /// broken rather than early. Only a clock disagreement between the box
    /// that minted it and the box reading it can produce one, and both are the
    /// same machine today — the tolerance is here so that stops being an
    /// assumption the day it stops being true.
    static let clockSkewTolerance: TimeInterval = 60

    /// 32 symbols, all of them letters, so the parameter reads as a word-shaped
    /// nonsense string rather than as encoded data. Telegram's start-parameter
    /// charset is `[A-Za-z0-9_-]`, so a letters-only subset is always safe.
    private static let alphabet = Array("abcdefghijklmnopqrstuvwxyzABCDEF")
    private static let reverse: [Character: UInt8] = {
        var map: [Character: UInt8] = [:]
        for (index, character) in alphabet.enumerated() { map[character] = UInt8(index) }
        return map
    }()

    /// 10 bytes → 80 bits → exactly 16 base32 characters, no padding.
    private static let payloadBytes = 10
    static let tokenLength = 16

    // Domain separators, so the two MACs of one nonce can never collide.
    private static let streamTag: UInt8 = 0x53  // 'S' — keystream
    private static let authTag: UInt8 = 0x54    // 'T' — authentication

    // MARK: - Verdict

    enum Verdict: Equatable {
        /// Token is well-formed, authentic and still inside the window.
        case valid(issuedAt: Date)
        /// Authentic, but minted longer ago than `validity`.
        case expired(age: TimeInterval)
        /// Malformed, or not minted by this bot.
        case invalid
    }

    // MARK: - Issue

    static func make(secret: String, at date: Date = Date()) -> String {
        let key = derivedKey(from: secret)
        let nonce: [UInt8] = [.random(in: 0...255), .random(in: 0...255)]

        let seconds = UInt32(max(0, date.timeIntervalSince1970))
        let plain = bigEndianBytes(seconds)
        let stream = keystream(nonce: nonce, key: key)
        let cipher = zip(plain, stream).map { $0 ^ $1 }
        let tag = authenticator(nonce: nonce, cipher: cipher, key: key)

        return encode(nonce + cipher + tag)
    }

    // MARK: - Redeem

    static func verify(_ token: String,
                       secret: String,
                       now: Date = Date(),
                       validFor: TimeInterval = validity) -> Verdict {
        guard token.count == tokenLength,
              let bytes = decode(token),
              bytes.count == payloadBytes
        else { return .invalid }

        let nonce = Array(bytes[0..<2])
        let cipher = Array(bytes[2..<6])
        let tag = Array(bytes[6..<10])
        let key = derivedKey(from: secret)

        // Authenticate BEFORE decrypting: a token that is not ours carries a
        // timestamp that means nothing, and comparing it to the clock first
        // would be reasoning about an attacker's number.
        guard constantTimeEquals(authenticator(nonce: nonce, cipher: cipher, key: key), tag) else {
            return .invalid
        }

        let stream = keystream(nonce: nonce, key: key)
        let plain = zip(cipher, stream).map { $0 ^ $1 }
        let issuedAt = Date(timeIntervalSince1970: TimeInterval(bigEndianUInt32(plain)))
        let age = now.timeIntervalSince(issuedAt)

        if age < -clockSkewTolerance { return .invalid }
        if age > validFor { return .expired(age: age) }
        return .valid(issuedAt: issuedAt)
    }

    // MARK: - Crypto helpers

    /// The bot token hashed down to a 256-bit key. Telegram's own login-widget
    /// verification derives its key the same way, and it means the invite
    /// system needs no secret of its own to be configured, forgotten, or
    /// committed.
    private static func derivedKey(from secret: String) -> SymmetricKey {
        SymmetricKey(data: SHA256.hash(data: Data(secret.utf8)))
    }

    private static func mac(_ message: [UInt8], key: SymmetricKey) -> [UInt8] {
        Array(HMAC<SHA256>.authenticationCode(for: Data(message), using: key))
    }

    private static func keystream(nonce: [UInt8], key: SymmetricKey) -> [UInt8] {
        Array(mac([streamTag] + nonce, key: key).prefix(4))
    }

    private static func authenticator(nonce: [UInt8], cipher: [UInt8], key: SymmetricKey) -> [UInt8] {
        Array(mac([authTag] + nonce + cipher, key: key).prefix(4))
    }

    /// Length-independent, early-exit-free comparison. The tag is only four
    /// bytes and the attacker is a friend with a phone, but a timing-safe
    /// compare costs one line and stops the question being asked.
    private static func constantTimeEquals(_ lhs: [UInt8], _ rhs: [UInt8]) -> Bool {
        guard lhs.count == rhs.count else { return false }
        var difference: UInt8 = 0
        for (a, b) in zip(lhs, rhs) { difference |= a ^ b }
        return difference == 0
    }

    // MARK: - Byte plumbing

    private static func bigEndianBytes(_ value: UInt32) -> [UInt8] {
        [UInt8((value >> 24) & 0xFF), UInt8((value >> 16) & 0xFF),
         UInt8((value >> 8) & 0xFF), UInt8(value & 0xFF)]
    }

    private static func bigEndianUInt32(_ bytes: [UInt8]) -> UInt32 {
        (UInt32(bytes[0]) << 24) | (UInt32(bytes[1]) << 16) | (UInt32(bytes[2]) << 8) | UInt32(bytes[3])
    }

    static func encode(_ bytes: [UInt8]) -> String {
        var out = ""
        var accumulator: UInt32 = 0
        var bits = 0
        for byte in bytes {
            accumulator = (accumulator << 8) | UInt32(byte)
            bits += 8
            while bits >= 5 {
                out.append(alphabet[Int((accumulator >> UInt32(bits - 5)) & 0x1F)])
                bits -= 5
            }
        }
        if bits > 0 {
            out.append(alphabet[Int((accumulator << UInt32(5 - bits)) & 0x1F)])
        }
        return out
    }

    static func decode(_ token: String) -> [UInt8]? {
        var out: [UInt8] = []
        var accumulator: UInt32 = 0
        var bits = 0
        for character in token {
            guard let value = reverse[character] else { return nil }
            accumulator = (accumulator << 5) | UInt32(value)
            bits += 5
            if bits >= 8 {
                out.append(UInt8((accumulator >> UInt32(bits - 8)) & 0xFF))
                bits -= 8
            }
        }
        return out
    }
}
