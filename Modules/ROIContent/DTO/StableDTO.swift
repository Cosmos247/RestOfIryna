//
//  StableDTO.swift
//  RestOfIryna
//
//  Created by Dmytro Ihnatyuhin on 08.11.2026.
//
//  `stable.json` (schema v33, 2026-11-08, `content/spec/spec-wagon.md`) — what
//  the stable on Поділ hires out:
//  - the wagon («🫏 Віз»): a second store for anything the warehouse takes, that
//    rides with the player between the estate and the capital — and slows the
//    road while it does (the owner, the same day: three minutes, not two);
//  - the Rysak («🐴 Рисак», 2026-11-09, `content/spec/spec-horse.md`): a faster
//    horse for the same road, which never speeds the wagon up.
//
//  The lengths and their prices are the owner's: the longest is the cheapest
//  per minute, a rule the validator holds for both offers, so a `/reload` that
//  breaks it is refused rather than installed.
//

import Foundation

public struct StableFileDTO: Codable, Sendable, Equatable {
    public let horse: HorseDTO
    public let wagon: WagonDTO

    public init(horse: HorseDTO, wagon: WagonDTO) {
        self.horse = horse
        self.wagon = wagon
    }
}

public struct HorseDTO: Codable, Sendable, Equatable {
    /// A crossing between the estate and the capital on the Rysak, in game
    /// seconds — the wagon's whole minutes cannot say 1 min 30 s. Always
    /// shorter than the road's own crossing.
    public let travelSeconds: Int
    /// The rental lengths, shortest first.
    public let lengths: [WagonLengthDTO]

    public init(travelSeconds: Int, lengths: [WagonLengthDTO]) {
        self.travelSeconds = travelSeconds
        self.lengths = lengths
    }
}

public struct WagonDTO: Codable, Sendable, Equatable {
    /// Places, in units — the bag's own accounting.
    public let capacity: Int
    /// A crossing between the estate and the capital while the wagon rides along, in
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

/// One rental length at the stable, the wagon's and the Rysak's alike.
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
