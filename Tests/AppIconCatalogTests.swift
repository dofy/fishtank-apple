import XCTest
@testable import FishtankCore

final class AppIconCatalogTests: XCTestCase {
    func testEverySpeciesHasExactlyOneIconAndValidArtwork() {
        XCTAssertEqual(AppIconCatalog.variants.count, FishCatalog.all.count)
        XCTAssertEqual(Set(AppIconCatalog.all.map(\.id)).count, FishCatalog.all.count + 1)
        XCTAssertEqual(Set(AppIconCatalog.all.map(\.speciesID)), Set(FishCatalog.all.map(\.id)))
        XCTAssertEqual(Set(AppIconCatalog.all.filter { $0.secondarySpeciesID == nil }.map(\.speciesID)).count, FishCatalog.all.count)
        XCTAssertEqual(AppIconCatalog.all.count, 33)
        XCTAssertEqual(AppIconCatalog.duet.secondarySpeciesID, "greyminnow")
        for design in AppIconCatalog.all {
            XCTAssertNotNil(FishCatalog.byID[design.speciesID])
            if let secondary = design.secondarySpeciesID { XCTAssertNotNil(FishCatalog.byID[secondary]) }
            XCTAssertNotNil(DecorCatalog.byID[design.decorationID])
            XCTAssertNotNil(DecorCatalog.byID[design.companionID])
            XCTAssertEqual(AppIconCatalog.design(design.id).id, design.id)
        }
    }
    func testExistingSelectionsKeepTheirOriginalSpecies() {
        let existing = ["coral":"copperband", "moon":"moonhorn", "sapphire":"sapphiredamsel", "treasure":"goldbutterfly", "neon":"neonstreak", "puffer":"creampuff", "seahorse":"coralseahorse", "crystal":"royalgoldtail", "jelly":"crystaljelly", "ray":"voidray", "turtle":"jadeturtle", "koi":"prismkoi"]
        for (id,species) in existing { XCTAssertEqual(AppIconCatalog.design(id).speciesID, species) }
    }
    func testUnpaginatedChoicesIncludeAllIconsInAscendingTierOrder() {
        let choices = AppIconCatalog.filtered(discovered: Set(FishCatalog.all.map(\.id)))
        XCTAssertEqual(choices.count, 33)
        XCTAssertEqual(Set(choices.map(\.id)), Set(AppIconCatalog.all.map(\.id)))
        let tiers = choices.map { FishCatalog.byID[$0.speciesID]!.tier }
        XCTAssertEqual(tiers, tiers.sorted())
        XCTAssertEqual(Set(choices.prefix(3).map(\.id)), ["classic", "greyminnow", "duet"])
    }
    func testTierFiltersMatchCatalogIncludingInitialFish() {
        for tier in 0...5 {
            XCTAssertEqual(Set(AppIconCatalog.filtered(tier: tier, discovered: Set(FishCatalog.all.map(\.id))).map(\.speciesID)), Set(FishCatalog.all.filter { $0.tier == tier }.map(\.id)))
        }
        XCTAssertTrue(AppIconCatalog.filtered(tier:99, discovered: Set(FishCatalog.all.map(\.id))).isEmpty)
    }
    func testIconsFollowPermanentSpeciesDiscoveryInsteadOfLevelOrInventory() {
        let initial = AquariumState.newGame(at: Date())
        XCTAssertEqual(AppIconCatalog.all.filter { AppIconCatalog.isUnlocked($0, discovered: initial.discovered) }.count, 3)
        XCTAssertFalse(AppIconCatalog.isUnlocked(AppIconCatalog.duet, discovered: []))
        let rare = AppIconCatalog.design("astraljelly")
        var progress = initial; progress.exp = 1_000_000
        XCTAssertEqual(progress.level, 10)
        XCTAssertFalse(AppIconCatalog.isUnlocked(rare, discovered: progress.discovered))
        progress.discovered.insert(rare.speciesID)
        XCTAssertFalse(progress.fish.contains { $0.speciesID == rare.speciesID })
        XCTAssertTrue(AppIconCatalog.isUnlocked(rare, discovered: progress.discovered))
        let complete = Set(FishCatalog.all.map(\.id))
        XCTAssertTrue(AppIconCatalog.all.allSatisfy { AppIconCatalog.isUnlocked($0, discovered: complete) })
    }
    func testBreedingUnlocksIconAndReleasingFishKeepsItAvailable() throws {
        let now = Date()
        var state = AquariumState.newGame(at: now)
        let before = state.discovered
        var random = FishRandom(seed: 42)
        let outcome = try state.breed(Array(state.fish.prefix(2).map(\.id)), at: now, random: &random)
        let icon = try XCTUnwrap(AppIconCatalog.all.first { $0.speciesID == outcome.child.speciesID })
        XCTAssertFalse(AppIconCatalog.isUnlocked(icon, discovered: before))
        XCTAssertTrue(AppIconCatalog.isUnlocked(icon, discovered: state.discovered))
        try state.release(outcome.child.id)
        XCTAssertFalse(state.fish.contains { $0.id == outcome.child.id })
        XCTAssertTrue(AppIconCatalog.isUnlocked(icon, discovered: state.discovered))
    }
    func testUndiscoveredIconsStayHiddenIncludingSecretsAndTierFilters() {
        let initial = AquariumState.newGame(at: Date())
        XCTAssertTrue(AppIconCatalog.filtered(discovered: []).isEmpty)
        XCTAssertEqual(Set(AppIconCatalog.filtered(discovered: initial.discovered).map(\.id)), ["classic", "greyminnow", "duet"])
        let ordinary = Set(FishCatalog.regular.map(\.id))
        XCTAssertEqual(AppIconCatalog.filtered(discovered: ordinary).count, 30)
        XCTAssertFalse(AppIconCatalog.filtered(tier: 5, discovered: ordinary).contains { FishCatalog.byID[$0.speciesID]!.hidden })
        var discovered = initial.discovered
        for species in FishCatalog.hidden {
            discovered.insert(species.id)
            let choices = AppIconCatalog.filtered(tier: 5, discovered: discovered)
            XCTAssertEqual(Set(choices.map(\.speciesID)), discovered.intersection(Set(FishCatalog.hidden.map(\.id))))
            XCTAssertEqual(AppIconCatalog.design(species.id).speciesID, species.id)
        }
        let onlyGoldfin: Set<String> = ["goldfin"]
        XCTAssertEqual(AppIconCatalog.filtered(discovered: onlyGoldfin).map(\.id), ["classic"])
    }
    func testReforgingUnlocksOnlyDiscoveredSecretIconPermanently() throws {
        let now = Date()
        var state = AquariumState.newGame(at: now)
        let materials = (0..<3).map { _ -> AquariumFish in
            var fish = AquariumFish.make(species: FishCatalog.byID["prismkoi"]!, at: now, adult: true)
            fish.uses = 0
            return fish
        }
        state.fish += materials
        state.reforgeMisses = 9
        var random = FishRandom(seed: 42)
        let result = try state.reforge(materials.map(\.id), at: now, random: &random)
        let choices = AppIconCatalog.filtered(discovered: state.discovered)
        XCTAssertTrue(choices.contains { $0.id == result.child.speciesID })
        XCTAssertEqual(choices.filter { FishCatalog.byID[$0.speciesID]!.hidden }.count, 1)
        try state.release(result.child.id)
        XCTAssertEqual(AppIconCatalog.filtered(discovered: state.discovered).map(\.id), choices.map(\.id))
    }
    func testUnknownSavedSelectionFallsBackToOriginalWithoutLoadingArbitraryPaths() {
        for id in [nil, "", "removed-design", "../../private-file"] {
            XCTAssertEqual(AppIconCatalog.design(id).id, AppIconCatalog.original.id)
        }
        XCTAssertEqual(AppIconCatalog.original.resourceName, "FishtankIcon")
    }
}
