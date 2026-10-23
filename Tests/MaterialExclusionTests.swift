import XCTest
@testable import FishtankCore

final class MaterialExclusionTests: XCTestCase {
    let now = Date(timeIntervalSince1970: 1_800_000_000)

    private func fish(_ tier: Int, uses: Int = 0, locked: Bool = false, adult: Bool = true) -> AquariumFish {
        var item = AquariumFish.make(species: FishCatalog.pool(tier: tier)[0], at: now, adult: adult, uses: uses)
        item.locked = locked
        return item
    }

    func testNormalSummaryAccountsForEveryFishOnceAcrossFilterCombinations() {
        var state = AquariumState.newGame(at: now)
        state.fish = (0...5).flatMap { tier in
            [false, true].flatMap { locked in
                [0, 2].flatMap { uses in
                    [fish(tier, uses: uses, locked: locked), fish(tier, uses: uses, locked: locked, adult: false)]
                }
            }
        }
        state.tankIDs = state.fish.enumerated().filter { $0.offset % 3 == 0 }.map { $0.element.id }
        let snapshot = state.fish
        for zeroOnly in [false, true] {
            for excludeTank in [false, true] {
                for tiers: Set<Int> in [[], [1, 3], [1, 2, 3, 4]] {
                    state.mergePreferences = MergePreferences(zeroUsesOnly: zeroOnly, excludeInTank: excludeTank, tiers: tiers)
                    let expected = state.fish.filter {
                        (1...4).contains($0.tier) && !$0.locked && tiers.contains($0.tier)
                            && (!zeroOnly || $0.uses == 0) && (!excludeTank || !state.tankIDs.contains($0.id))
                    }
                    XCTAssertEqual(state.mergeCandidates.map(\.id), expected.map(\.id))
                    let summary = state.materialExclusions(reforge: false, at: now)
                    XCTAssertEqual(summary.reduce(0) { $0 + $1.count } + expected.count, state.fish.count)
                    XCTAssertEqual(summary.first { $0.id == .locked }?.count, snapshot.filter(\.locked).count)
                    XCTAssertTrue(summary.allSatisfy { $0.count > 0 })
                }
            }
        }
        XCTAssertEqual(state.fish, snapshot, "Reading exclusions must not change fish or protection")
    }

    func testReforgeSummarySeparatesRestrictionsAndUpdatesWhenFishMatures() {
        var state = AquariumState.newGame(at: now)
        state.fish = [fish(5, locked: true), fish(5, adult: false), fish(5, uses: 2), fish(5), fish(5), fish(2)]
        state.tankIDs = [state.fish[0].id, state.fish[3].id]
        let before = state
        let summary = Dictionary(uniqueKeysWithValues: state.materialExclusions(reforge: true, at: now).map { ($0.id, $0.count) })
        XCTAssertEqual(summary, [.locked: 1, .young: 1, .hasUses: 1, .displayed: 1, .notFiveStar: 1])
        XCTAssertEqual(state.reforgeCandidates(at: now).map(\.id), [state.fish[4].id])
        XCTAssertEqual(state, before)
        let later = now.addingTimeInterval(FishBalance.growth[5])
        XCTAssertFalse(state.materialExclusions(reforge: true, at: later).contains { $0.id == .young })
        XCTAssertEqual(state.reforgeCandidates(at: later).count, 2)
    }

    func testSummaryIncludesAdditionalVisibleFiltersAndOmitsZeroReasons() {
        var state = AquariumState.newGame(at: now)
        state.fish = [fish(1), fish(2), fish(2, locked: true), fish(5)]
        state.tankIDs = []
        let summary = Dictionary(uniqueKeysWithValues: state.materialExclusions(reforge: false, at: now, tierFilter: 2, search: "no matching fish").map { ($0.id, $0.count) })
        XCTAssertEqual(summary, [.locked: 1, .fiveStar: 1, .tierFilter: 1, .searchFilter: 1])
        state.fish = [fish(1), fish(4)]
        XCTAssertTrue(state.materialExclusions(reforge: false, at: now).isEmpty)
    }
}
