import XCTest
@testable import FishtankCore

final class DiscoveryOutcomeTests: XCTestCase {
    let now = Date(timeIntervalSince1970: 1_800_000_000)

    func testBreedingDiscoveryUsesHistoryBeforeAddingChild() throws {
        try checkDiscovery(merging: false)
    }

    func testMergeDiscoveryUsesHistoryBeforeAddingChild() throws {
        try checkDiscovery(merging: true)
    }

    private func checkDiscovery(merging: Bool) throws {
        var original = AquariumState.newGame(at: now)
        if merging {
            original.fish = (0..<10).map { _ in
                AquariumFish.make(species: FishCatalog.byID["copperband"]!, grade: 3, at: now, adult: true)
            }
            original.tankIDs = []
        }
        func produce(_ state: inout AquariumState) throws -> FishOutcome {
            var random = FishRandom(seed: 12345)
            if merging { return try state.merge(state.fish.map(\.id), at: now, random: &random) }
            return try state.breed(Array(state.fish.prefix(2).map(\.id)), at: now, random: &random)
        }
        var first = original
        let newSpecies = try produce(&first)
        XCTAssertTrue(newSpecies.novel)
        XCTAssertTrue(newSpecies.novelVariant)
        let species = newSpecies.child.speciesID
        let variant = "\(species):\(newSpecies.child.grade)"
        XCTAssertTrue(first.discoveredVariants.contains(variant))

        var knownSpecies = original
        knownSpecies.discovered.insert(species)
        let newAppearance = try produce(&knownSpecies)
        XCTAssertFalse(newAppearance.novel)
        XCTAssertTrue(newAppearance.novelVariant)

        var knownAppearance = original
        knownAppearance.discovered.insert(species)
        knownAppearance.discoveredVariants.insert(variant)
        let duplicate = try produce(&knownAppearance)
        XCTAssertFalse(duplicate.novel)
        XCTAssertFalse(duplicate.novelVariant)
    }
}
