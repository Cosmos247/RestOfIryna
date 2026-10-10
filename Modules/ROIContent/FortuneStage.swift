//
//  FortuneStage.swift
//  RestOfIryna
//
//  Created by Dmytro Ihnatyuhin on 10.10.2026.
//
//  Where a player stands between two FREE tarot cards (2026-10-10, the owner's
//  rules, five quizzes). Beside the free draw the fortune teller sells two
//  things, in one order only:
//
//      free ──«🕯 Відчарувати»──▶ dispelled ──«🔮 Друга карта»──▶ second
//
//  - The dispel ends the free card's running effect early. Nothing else: the
//    free card's time does not come sooner (`User.fortuneAvailableAt` keeps
//    reading the window stamped at the draw).
//  - The second card exists only as the replacement for a dispelled one — not
//    after a one-shot, whose effect already landed, and not after a card that
//    simply ran out.
//  - The second card is final: it cannot be dispelled, so there is never a
//    third. One second card per free card is the same as one a game day,
//    because a free card comes at most once a game day.
//
//  The next free draw puts the player back at `free`, whatever stage they left.
//
//  The answers live here, in pure Foundation, so the fortune screen, its
//  buttons and `FortuneService` ask one function each and the tests can reach
//  them — the reason `WeaponLadderRules` lives in this module too.
//

import Foundation

public enum FortuneStage: String, Sendable, CaseIterable {
    /// The card drawn last is the free one — running, run out, or a one-shot.
    case free
    /// The free card was dispelled; one second card may be drawn.
    case dispelled
    /// The second card is drawn. Nothing more until the next free card.
    case second

    /// Whether «🕯 Відчарувати» is on offer: only the FREE card, and only while
    /// its duration effect still runs. A one-shot has nothing left to take
    /// back — undoing the Tower would sell 25 silver for 30 — and the second
    /// card is final.
    public func mayDispel(cardHasDurationEffect: Bool, effectRunning: Bool) -> Bool {
        self == .free && cardHasDurationEffect && effectRunning
    }

    /// Whether «🔮 Друга карта» is on offer: only after a dispel, and only while
    /// the free card is still waiting. Once it is ready, the plain draw at the
    /// lower price is what the screen offers instead.
    public func mayDrawSecond(freeCardReady: Bool) -> Bool {
        self == .dispelled && !freeCardReady
    }
}
