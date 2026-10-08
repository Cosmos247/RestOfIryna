//
//  PollWatchdog.swift
//  RestOfIryna
//
//  Created by Dmytro Ihnatyuhin on 08.10.2026.
//
//  Ends the process when the Telegram long-poll stops coming back, so pm2
//  starts it again.
//
//  On 2026-10-08 the bot froze twice in thirteen minutes. The process stayed
//  up and pm2 reported it `online`; every thread sat idle in epoll or a
//  condition wait; the process held no socket to Telegram at all; and the
//  SDK's polling loop never asked for another update while the queue grew.
//  Something it awaited never resumed — an HTTP/2 stream cancelled under it is
//  the best guess, since the first freeze came on the heels of a
//  `StreamClosed` — and a suspended task leaves no stack to read. Nothing in
//  the process noticed, and pm2 only restarts a process that exits.
//
//  So every `getUpdates` that COMPLETES — answered or thrown — stamps a clock
//  (`HummingbirdTGClient.post`), and a plain thread checks it. A thread, not a
//  Swift task: the watchdog must not depend on the executor it is guarding. A
//  loop that is alive but failing (Telegram down, DNS gone) keeps stamping and
//  is left alone, because a restart would not fix it; only a loop that has
//  stopped coming back at all is ended.
//
//  Plain constants in real seconds, like `InviteToken.validity`: an operations
//  limit, not a balance knob. A debugger paused on the Mac for longer than
//  `staleAfter` trips it too, on resume — that is the price of a guard that
//  needs no cooperation from the code it watches.
//

import Foundation
import Logging

enum PollWatchdog {

    /// Silence after which the poll counts as dead. The SDK long-polls with a
    /// 10 s hold and the client's read timeout is 60 s (`configure`), so a
    /// living loop completes a call at least every ~70 s even when every
    /// request fails.
    static let staleAfter: TimeInterval = 120
    static let checkEvery: TimeInterval = 15

    private nonisolated(unsafe) static var lastPoll = Date()
    private static let lock = NSLock()

    /// A `getUpdates` call just finished, one way or the other.
    static func recordPoll() {
        lock.lock()
        lastPoll = Date()
        lock.unlock()
    }

    private static var secondsSinceLastPoll: TimeInterval {
        lock.lock()
        defer { lock.unlock() }
        return Date().timeIntervalSince(lastPoll)
    }

    /// Call once, after `bot.start()`. The clock starts now, so the first poll
    /// has the whole window to arrive.
    static func start(logger: Logger) {
        recordPoll()
        Thread.detachNewThread {
            while true {
                Thread.sleep(forTimeInterval: checkEvery)
                let silent = secondsSinceLastPoll
                guard silent > staleAfter else { continue }
                logger.critical("""
                    [WATCHDOG] no getUpdates has completed for \(Int(silent))s — \
                    the poll loop is stuck; exiting so pm2 restarts the bot
                    """)
                // `fflush(nil)`, never `fflush(stdout)` — see `entrypoint.swift`.
                fflush(nil)
                exit(1)
            }
        }
    }
}
