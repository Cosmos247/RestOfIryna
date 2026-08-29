//
//  MarketCatalog.swift
//  RestOfIryna
//
//  Created by Dmytro Ihnatyuhin on 28.05.2026.
//
//  Façade over `content/data/market.json` (Phase 3B — was two Swift constants).
//  Tuning only: the capital Market's silver sink and its anti-spam limit.
//

import Foundation

public enum MarketCatalog {
    /// Flat silver charged when a lot is created. Non-refundable — this is the
    /// market's silver sink and the soft cap on spam listings.
    public static var listingFee: Int { Catalogs.current.market.listingFee }

    /// Maximum number of simultaneous active lots per seller. Keeps the
    /// item-grouped board readable and stops one player from escrowing their
    /// whole bag.
    public static var maxActiveLots: Int { Catalogs.current.market.maxActiveLots }
}
