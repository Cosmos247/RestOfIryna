//
//  PlaceOrdinal.swift
//  RestOfIryna
//
//  Created by Dmytro Ihnatyuhin on 29.10.2026.
//
//  A place on a board as a word's ending after its number: «7-ме місце»,
//  "7th place" — the holiday finale's line under the podium (2026-10-29).
//
//  The Ukrainian ending is the ordinal word's own, neuter because a place is
//  «місце»: перше, друге, третє, сьоме, восьме, сорокове — every other one,
//  and every -teen, ends -те. Written with the digits the way Ukrainian
//  writes it, so no number needs spelling out.
//

import Foundation

public enum PlaceOrdinal {
    public static func ukrainian(_ n: Int) -> String {
        let lastTwo = n % 100
        let suffix: String
        if (11...19).contains(lastTwo) {
            suffix = "те"
        } else {
            switch n % 10 {
            case 1: suffix = "ше"
            case 2: suffix = "ге"
            case 3: suffix = "тє"
            case 7, 8: suffix = "ме"
            case 0: suffix = lastTwo == 40 ? "ве" : "те"
            default: suffix = "те"
            }
        }
        return "\(n)-\(suffix)"
    }

    public static func english(_ n: Int) -> String {
        if (11...13).contains(n % 100) { return "\(n)th" }
        switch n % 10 {
        case 1: return "\(n)st"
        case 2: return "\(n)nd"
        case 3: return "\(n)rd"
        default: return "\(n)th"
        }
    }
}
