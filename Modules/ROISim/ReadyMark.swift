//
//  ReadyMark.swift
//  RestOfIryna
//
//  Created by Dmytro Ihnatyuhin on 09.11.2026.
//
//  «✅» after a button's name (2026-11-09, a player's idea, the owner's shape):
//  every line on the card behind that button is already green. Nothing is
//  shown when something is short, and the room for the result is not a line on
//  any card, so a full bag does not take the mark away.
//
//  The mark goes after the name (the owner's word). Telegram cuts a long label
//  from its end, so the tincture list, the one list near that limit, leaves out
//  the flask to make room.
//

import Foundation

public enum ReadyMark {

    /// A button's name, with the mark after it when everything is in hand.
    public static func label(_ name: String, ready: Bool) -> String {
        ready ? "\(name) ✅" : name
    }

    /// Whether `held` covers every cost. A cost listed twice counts as the sum,
    /// because that is what the writers drain.
    public static func covers(_ costs: [(itemId: String, quantity: Int)], held: [String: Int]) -> Bool {
        var need: [String: Int] = [:]
        for cost in costs { need[cost.itemId, default: 0] += cost.quantity }
        return need.allSatisfy { held[$0.key, default: 0] >= $0.value }
    }
}
