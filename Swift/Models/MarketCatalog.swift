//
//  MarketCatalog.swift
//  RestOfIryna
//
//  Created by Dmytro Ihnatyuhin on 28.05.2026.
//
//  Phase 6.5 — pure tuning constants for the capital Market. Kept tiny and
//  separate (like `TavernCatalog`) so balancing the silver sink and the
//  anti-spam limit is a one-line edit.
//

import Foundation

public enum MarketCatalog {
    /// Flat silver charged when a lot is created. Non-refundable — this is the
    /// market's silver sink and the soft cap on spam listings. Tunable.
    public static let listingFee = 5

    /// Maximum number of simultaneous active lots per seller. Keeps the
    /// item-grouped board readable and stops one player from escrowing their
    /// whole bag. Tunable.
    public static let maxActiveLots = 5
}
