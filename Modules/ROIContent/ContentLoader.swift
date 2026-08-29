//
//  ContentLoader.swift
//  RestOfIryna
//
//  Created by Dmytro Ihnatyuhin on 29.08.2026.
//
//  Reads `content/data/*.json` into a `ContentBundle`.
//
//  The only interesting part is error rendering. A raw `DecodingError` reads
//  like "The data couldn't be read because it isn't in the correct format",
//  which tells a balance designer nothing. Every throw here names the file, the
//  index inside the array, the record's `id` when it can be recovered, and what
//  was expected.
//
//  The loader never sorts. `EnemyCatalog.pickFor` selects with
//  `filter().randomElement()`, so array order decides which enemy a given RNG
//  draw returns; reordering would silently change every seeded simulation.
//

import Foundation

public enum ContentLoader {

    /// Files loaded in this order; the order also feeds the content hash.
    private static let manifestFile = "manifest.json"
    private static let itemsFile    = "items.json"
    private static let enemiesFile  = "enemies.json"
    private static let recipesFile  = "recipes.json"
    private static let weaponsFile  = "weapon_upgrades.json"

    public static func load(from root: URL) throws -> ContentBundle {
        var hashState = FNV1a()

        let manifestData = try read(manifestFile, in: root, into: &hashState)
        let manifest: ManifestDTO = try decode(manifestData, as: ManifestDTO.self, file: manifestFile)
        guard manifest.schemaVersion == ContentSchema.current else {
            throw ContentError.schemaMismatch(found: manifest.schemaVersion, expected: ContentSchema.current)
        }

        let itemsData = try read(itemsFile, in: root, into: &hashState)
        let itemFile: ItemFileDTO = try decode(itemsData, as: ItemFileDTO.self, file: itemsFile)

        let enemiesData = try read(enemiesFile, in: root, into: &hashState)
        let enemyFile: EnemyFileDTO = try decode(enemiesData, as: EnemyFileDTO.self, file: enemiesFile)

        let recipesData = try read(recipesFile, in: root, into: &hashState)
        let recipeFile: RecipeFileDTO = try decode(recipesData, as: RecipeFileDTO.self, file: recipesFile)

        let weaponsData = try read(weaponsFile, in: root, into: &hashState)
        let weaponFile: WeaponUpgradeFileDTO = try decode(weaponsData, as: WeaponUpgradeFileDTO.self, file: weaponsFile)

        return ContentBundle(
            manifest: manifest,
            items: itemFile.items,
            enemies: enemyFile.enemies,
            recipes: recipeFile.recipes,
            starterRecipeIds: recipeFile.starterRecipeIds,
            weaponLadders: weaponFile.ladders,
            weaponDurabilityByTier: weaponFile.durabilityByTier,
            contentHash: hashState.hexDigest
        )
    }

    /// Canonical encoder for everything the pipeline writes. `sortedKeys` makes
    /// the byte-for-byte round-trip check in the exporter deterministic.
    public static func makeEncoder() -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        return encoder
    }

    // MARK: - Internals

    private static func read(_ name: String, in root: URL, into hash: inout FNV1a) throws -> Data {
        let url = root.appendingPathComponent(name)
        guard let data = FileManager.default.contents(atPath: url.path) else {
            throw ContentError.missingFile(name)
        }
        hash.combine(data)
        return data
    }

    private static func decode<T: Decodable>(_ data: Data, as type: T.Type, file: String) throws -> T {
        do {
            return try JSONDecoder().decode(type, from: data)
        } catch let error as DecodingError {
            throw ContentError.decodeFailed(file: file, detail: render(error, data: data))
        } catch {
            throw ContentError.decodeFailed(file: file, detail: "\(error)")
        }
    }

    /// Turn a `DecodingError` into something a designer can act on.
    private static func render(_ error: DecodingError, data: Data) -> String {
        switch error {
        case .keyNotFound(let key, let ctx):
            return "\(path(ctx.codingPath)) — required field \"\(key.stringValue)\" is missing"
        case .typeMismatch(let expected, let ctx):
            return "\(path(ctx.codingPath)) — expected \(expected), found something else"
        case .valueNotFound(let expected, let ctx):
            return "\(path(ctx.codingPath)) — \(expected) is null but required"
        case .dataCorrupted(let ctx):
            return "\(path(ctx.codingPath)) — \(ctx.debugDescription)"
        @unknown default:
            return "\(error)"
        }
    }

    /// `items[17].gearStats.attack` rather than an array of opaque key objects.
    private static func path(_ codingPath: [any CodingKey]) -> String {
        guard !codingPath.isEmpty else { return "<root>" }
        var out = ""
        for key in codingPath {
            if let index = key.intValue {
                out += "[\(index)]"
            } else {
                out += out.isEmpty ? key.stringValue : ".\(key.stringValue)"
            }
        }
        return out
    }
}

// MARK: - FNV-1a

/// Same hash the quest system uses for derived daily assignment
/// (`QuestCatalog`), kept here so the content pipeline adds no dependency.
struct FNV1a {
    private var hash: UInt64 = 0xcbf29ce484222325
    private static let prime: UInt64 = 0x100000001b3

    mutating func combine(_ data: Data) {
        for byte in data {
            hash ^= UInt64(byte)
            hash = hash &* Self.prime
        }
    }

    var hexDigest: String {
        String(format: "%08x", UInt32(truncatingIfNeeded: hash))
    }
}
