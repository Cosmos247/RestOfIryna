//
//  Statistics.swift
//  RestOfIryna
//
//  Created by Dmytro Ihnatyuhin on 30.08.2026.
//
//  Percentiles, because the mean is the wrong number here.
//
//  Enemy crit barely moves the AVERAGE HP a fight costs and moves the tail
//  hard: the plan measured a level-1 mage against an elite at 77% mean HP loss
//  and p90 = 100%, which is a death. Balancing on the mean is precisely how
//  players die on a tail the table calls fine, so every acceptance band in the
//  report is stated on p90.
//

import Foundation

public struct Distribution: Sendable {
    public let count: Int
    public let mean: Double
    public let p50: Double
    public let p90: Double
    public let p99: Double
    public let min: Double
    public let max: Double

    /// Nearest-rank percentile on the sorted sample: the smallest value at or
    /// below which at least `p` of the sample falls. No interpolation — with
    /// thousands of runs the difference is noise, and an un-interpolated value
    /// is always one that actually occurred, which is what a tail claim should
    /// be.
    public init(_ values: [Double]) {
        guard !values.isEmpty else {
            count = 0; mean = 0; p50 = 0; p90 = 0; p99 = 0; min = 0; max = 0
            return
        }
        let sorted = values.sorted()
        func percentile(_ p: Double) -> Double {
            let rank = Int((p * Double(sorted.count)).rounded(.up))
            return sorted[Swift.max(0, Swift.min(sorted.count - 1, rank - 1))]
        }
        count = sorted.count
        mean = sorted.reduce(0, +) / Double(sorted.count)
        p50 = percentile(0.50)
        p90 = percentile(0.90)
        p99 = percentile(0.99)
        min = sorted[0]
        max = sorted[sorted.count - 1]
    }
}
