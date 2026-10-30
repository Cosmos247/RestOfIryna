//
//  EventKeys.swift
//  RestOfIryna
//
//  Created by Dmytro Ihnatyuhin on 29.10.2026.
//
//  Every locale key a holiday prints, built from its ids (`events.json`). The
//  validator requires exactly this list in both locales and the bot renders
//  through the same functions, so a key cannot be required and never printed,
//  or printed and never required (auto-memory `feedback-rendered-keys-need-requirekey`).
//
//  The screen that renders each key is named beside it — a key the validator
//  requires is not a key anything renders (`CLAUDE.md`).
//

import Foundation

public struct EventKeys: Sendable {
    public let eventId: String

    public init(_ eventId: String) {
        self.eventId = eventId
    }

    private var stem: String { "event.\(eventId)" }

    // MARK: Notices — the watchman (`RestNotificationService`)

    /// A plain notice, or the finale's frame (`%{podium}`, `%{mine}`).
    public func notice(_ noticeId: String) -> String { "\(stem).notice.\(noticeId)" }
    /// The finale's line for a player who brought blood (`%{blood}`, `%{place}`).
    public var finaleMine: String { "\(stem).finale.mine" }
    /// The finale's line for a player who never went in.
    public var finaleNone: String { "\(stem).finale.none" }
    /// The 12:00 «new day» notice of a holiday day (`%{close}`, `%{deadline}`,
    /// `%{flask}`).
    public func rollover(_ rolloverId: String) -> String { "\(stem).rollover.\(rolloverId)" }
    /// The `%{flask}` of a holiday day's notice: the reader has taken the flask,
    /// or has not been to the palace for it yet (2026-10-30).
    public var rolloverFlaskTaken: String { "\(stem).flask.rollover.taken" }
    public var rolloverFlaskWaiting: String { "\(stem).flask.rollover.waiting" }

    // MARK: The palace — the reveal and the flask (`CapitalController`)

    /// The story, under the palace card while the manor is open, until the
    /// reader takes the flask (2026-10-30: the reveal is the palace's).
    public var palaceStory: String { "\(stem).palace.story" }
    /// The scribe's words as he hands the flask over (`%{deadline}`).
    public var palaceScribe: String { "\(stem).palace.scribe" }
    /// The button under the scribe's words.
    public var palaceTake: String { "\(stem).palace.take" }
    /// The banner once the flask is taken (`%{deadline}`).
    public var flaskTaken: String { "\(stem).flask.taken" }

    // MARK: The entrance — the walk at the entrance km (`ExplorationController`)

    public var entrance: String { "\(stem).entrance" }
    public var entranceButton: String { "\(stem).entrance.button" }
    /// Under the entrance in place of its button, for a walk without the flask.
    public var entranceNoFlask: String { "\(stem).entrance.no_flask" }
    /// An entrance button tapped after the close.
    public var entranceGone: String { "\(stem).entrance.gone" }
    /// An entrance button tapped away from the entrance km (an alert).
    public var entranceElsewhere: String { "\(stem).entrance.elsewhere" }
    public var confirm: String { "\(stem).confirm" }
    public var confirmBlood: String { "\(stem).confirm.blood" }
    /// What a death would take (`%{loss}`).
    public var confirmBag: String { "\(stem).confirm.bag" }
    public var confirmBagEmpty: String { "\(stem).confirm.bag_empty" }
    public var confirmEnter: String { "\(stem).confirm.enter" }
    public var confirmStay: String { "\(stem).confirm.stay" }

    // MARK: Inside — the manor screen and the fight (`ExplorationController`, `CombatController`)

    /// The manor's name over its gate, before the first step (depth 0).
    public var manorGate: String { "\(stem).manor.gate" }
    /// `%{depth}`.
    public var manorTitle: String { "\(stem).manor.title" }
    public func room(_ roomId: String) -> String { "\(stem).room.\(roomId)" }
    /// `%{run}`, `%{total}`.
    public var manorBlood: String { "\(stem).manor.blood" }
    /// «🔙 Крок назад» and a Flee typed into the fight.
    public var noWayBack: String { "\(stem).manor.no_way_back" }
    /// Whoever is inside at the close.
    public var closed: String { "\(stem).manor.closed" }
    public func creatureName(_ creatureId: String) -> String { "\(stem).creature.\(creatureId).name" }
    /// `%{enemy}`.
    public func encounter(_ creatureId: String, room roomId: String) -> String {
        "\(stem).creature.\(creatureId).encounter.\(roomId)"
    }
    /// `%{enemy}`, `%{blood}`.
    public func kill(_ creatureId: String) -> String { "\(stem).creature.\(creatureId).kill" }
    /// A find's description on the step that turns it up (2026-10-30); the
    /// receipt under it is the meal's (`vigor.restored`, `hp.restored`).
    public func findText(_ findId: String) -> String { "\(stem).find.\(findId)" }
    /// `%{cause}`, `%{blood}`, `%{loss}`.
    public var death: String { "\(stem).death" }
    /// `%{run}`, `%{total}`.
    public var deathBlood: String { "\(stem).death.blood" }
    public var deathLoss: String { "\(stem).death.loss" }
    public var deathLossNone: String { "\(stem).death.loss_none" }

    // MARK: The capital while the King is ill (`CapitalController`)

    public var palace: String { "\(stem).capital.palace" }
    /// Replaces the welcome's last sentence.
    public var welcomeTail: String { "\(stem).capital.welcome_tail" }
    public var tavern: String { "\(stem).capital.tavern" }
    public var fortune: String { "\(stem).capital.fortune" }

    /// Every key the event prints, with the path in `events.json` that asks
    /// for it. The validator requires all of them in both locales.
    public static func required(for event: EventDTO, at index: Int) -> [(key: String, path: String)] {
        let keys = EventKeys(event.id)
        let base = "events[\(index)]"
        var out: [(String, String)] = []
        for (i, notice) in event.notices.enumerated() {
            out.append((keys.notice(notice.id), "\(base).notices[\(i)]"))
            if notice.kind == EventNoticeKind.finale.rawValue {
                out.append((keys.finaleMine, "\(base).notices[\(i)]"))
                out.append((keys.finaleNone, "\(base).notices[\(i)]"))
            }
        }
        for (i, rollover) in event.rollovers.enumerated() {
            out.append((keys.rollover(rollover.id), "\(base).rollovers[\(i)]"))
        }
        // Every holiday day's notice is given its `%{flask}`, whichever day's
        // text asks for it.
        if !event.rollovers.isEmpty {
            out.append((keys.rolloverFlaskTaken, "\(base).rollovers"))
            out.append((keys.rolloverFlaskWaiting, "\(base).rollovers"))
        }
        for key in [keys.entrance, keys.entranceButton, keys.entranceNoFlask, keys.entranceGone, keys.entranceElsewhere,
                    keys.confirm, keys.confirmBlood, keys.confirmBag, keys.confirmBagEmpty,
                    keys.confirmEnter, keys.confirmStay, keys.manorGate, keys.manorTitle, keys.manorBlood, keys.noWayBack,
                    keys.closed, keys.death, keys.deathBlood, keys.deathLoss, keys.deathLossNone,
                    keys.palace, keys.welcomeTail, keys.tavern, keys.fortune,
                    keys.palaceStory, keys.palaceScribe, keys.palaceTake, keys.flaskTaken] {
            out.append((key, base))
        }
        for (i, room) in event.rooms.enumerated() {
            out.append((keys.room(room.id), "\(base).rooms[\(i)]"))
        }
        for (i, find) in event.findList.enumerated() {
            out.append((keys.findText(find.id), "\(base).finds[\(i)]"))
        }
        for (i, creature) in event.creatures.enumerated() {
            let path = "\(base).creatures[\(i)]"
            out.append((keys.creatureName(creature.id), path))
            out.append((keys.kill(creature.id), path))
            for room in event.rooms {
                out.append((keys.encounter(creature.id, room: room.id), path))
            }
        }
        return out
    }
}
