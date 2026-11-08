//
//  StableDTO.swift
//  RestOfIryna
//
//  Created by Dmytro Ihnatyuhin on 08.11.2026.
//
//  `stable.json` (schema v33, 2026-11-08, `content/spec/spec-wagon.md`) — what
//  the stable on Поділ hires out. Its one offer is the wagon («🫏 Віз»): a
//  second store for anything the warehouse takes, that rides with the player
//  between the estate and the capital — and slows the road while it does
//  (the owner, the same day: three minutes, not two). The horse the owner first
//  asked for is parked (spec §7).
//
//  The lengths and their prices are the owner's (2026-11-08): the longest is
//  the cheapest per minute, a rule the validator holds, so a `/reload` that
//  breaks it is refused rather than installed.
//

import Foundation

public struct StableFileDTO: Codable, Sendable, Equatable {
    public let wagon: WagonDTO

    public init(wagon: WagonDTO) {
        self.wagon = wagon
    }
}

public struct WagonDTO: Codable, Sendable, Equatable {
    /// Places, in units — the bag's own accounting.
    public let capacity: Int
    /// A crossing between the estate and the capital while the hire runs, in
    /// game minutes — never shorter than the road's own `travelMinutes`.
    public let travelMinutes: Int
    /// The rental lengths, shortest first.
    public let lengths: [WagonLengthDTO]

    public init(capacity: Int, travelMinutes: Int, lengths: [WagonLengthDTO]) {
        self.capacity = capacity
        self.travelMinutes = travelMinutes
        self.lengths = lengths
    }
}

public struct WagonLengthDTO: Codable, Sendable, Equatable {
    /// Game minutes, authored at time scale 1 and divided by it where used.
    public let minutes: Int
    /// What this length costs, paid at the stable.
    public let silver: Int

    public init(minutes: Int, silver: Int) {
        self.minutes = minutes
        self.silver = silver
    }
}
