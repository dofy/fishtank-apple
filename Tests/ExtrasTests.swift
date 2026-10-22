import XCTest
@testable import FishtankCore

final class ExtrasTests: XCTestCase {
    let now = Date(timeIntervalSince1970: 1_800_000_000)
    private struct Fixtures: Decodable {
        struct Scenario: Decodable {
            struct Progress: Decodable { var id: String; var current: Int; var total: Int; var unlocked: Bool }
            var variants: [String]; var progress: [Progress]; var unlocked: [String]
        }
        var achievements: [Scenario]
        var placements: [PlacedDecoration]
        var moved: [PlacedDecoration]
        var moveId: String
    }
    private func fixtures() throws -> Fixtures {
        let url = Bundle.module.url(forResource: "extras-parity", withExtension: "json", subdirectory: "Fixtures")!
        return try JSONDecoder().decode(Fixtures.self, from: Data(contentsOf: url))
    }
    func testSevenAchievementHistoriesMatchWeb() throws {
        let scenarios = try fixtures().achievements
        XCTAssertEqual(scenarios.count, 7)
        for sample in scenarios {
            var state = AquariumState.newGame(at: now)
            state.fish = []; state.tankIDs = []; state.discovered = []; state.discoveredVariants = Set(sample.variants)
            state.syncAchievements()
            XCTAssertEqual(state.earnedAchievements, Set(sample.unlocked))
            for (actual, expected) in zip(state.achievementProgress, sample.progress) {
                XCTAssertEqual(actual.id, expected.id)
                XCTAssertEqual(actual.current, expected.current, expected.id)
                XCTAssertEqual(actual.total, expected.total, expected.id)
                XCTAssertEqual(actual.unlocked, expected.unlocked, expected.id)
            }
        }
    }
    func testDecorationPlacementOrderAndBoundsMatchWeb() throws {
        var state = AquariumState.newGame(at: now)
        state.exp = 57_760
        for item in DecorCatalog.all { try? state.toggleDecoration(item.id) }
        let expected = try fixtures()
        XCTAssertEqual(state.decorations, expected.placements)
        try state.moveDecoration(expected.moveId, to: -2)
        try state.flipDecoration(expected.moveId)
        XCTAssertEqual(state.decorations, expected.moved)
        try state.moveDecoration(expected.moveId, to: 8)
        XCTAssertEqual(state.decorations.last?.x, 0.94)
        let previous = state
        XCTAssertThrowsError(try state.moveDecoration(expected.moveId, to: .nan))
        XCTAssertEqual(state, previous)
    }
    func testLockedAndFullDecorationSlotsDoNotChangeState() throws {
        var state = AquariumState.newGame(at: now)
        let original = state
        XCTAssertThrowsError(try state.toggleDecoration("castle"))
        XCTAssertEqual(state, original)
        XCTAssertThrowsError(try state.toggleDecoration("fairylights"))
        XCTAssertEqual(state, original)
        try state.toggleDecoration("rocks")
        try state.toggleDecoration("fairylights")
        XCTAssertEqual(state.decorations.count, 3)
        XCTAssertEqual(state.decorations.last?.x, 0.5)
        XCTAssertTrue(state.isValid)
    }
    func testMedalsPermanentIndependentAndMultiple() throws {
        var state = AquariumState.newGame(at: now)
        state.discoveredVariants = ["copperband:5", "moonjelly:1", "crystaljelly:1", "astraljelly:1"]
        state.syncAchievements()
        let earned = state.earnedAchievements
        XCTAssertTrue(earned.contains("first-friend"))
        XCTAssertTrue(earned.contains("grade-five"))
        XCTAssertTrue(earned.contains("jelly-family"))
        let initialDecor = state.decorations
        try state.setDisplayedAchievements(Array(earned).sorted())
        XCTAssertEqual(state.decorations, initialDecor)
        XCTAssertGreaterThan(state.displayedAchievements.count, 1)
        state.discovered = []; state.discoveredVariants = []; state.fish = []; state.tankIDs = []
        state.syncAchievements()
        XCTAssertEqual(state.earnedAchievements, earned)
        XCTAssertEqual(Set(state.displayedAchievements), earned)
        let before = state
        XCTAssertThrowsError(try state.setDisplayedAchievements(["reef-explorer"]))
        XCTAssertEqual(state, before)
        XCTAssertThrowsError(try state.setDisplayedAchievements(["first-friend", "first-friend"]))
        XCTAssertEqual(state, before)
    }
    func testSchemaTwoMigrationRetainsProgressAndBackfillsAchievements() throws {
        var state = AquariumState.newGame(at: now)
        state.discoveredVariants.insert("copperband:5")
        var object = try JSONSerialization.jsonObject(with: JSONEncoder().encode(state)) as! [String: Any]
        object["version"] = 2
        for key in ["decorations", "earnedAchievements", "displayedAchievements", "audio", "lighting"] { object.removeValue(forKey: key) }
        let migrated = try AquariumSave.decode(JSONSerialization.data(withJSONObject: object))
        XCTAssertEqual(migrated.version, 3)
        XCTAssertEqual(migrated.fish, state.fish)
        XCTAssertEqual(migrated.tankIDs, state.tankIDs)
        XCTAssertEqual(migrated.random, state.random)
        XCTAssertEqual(migrated.decorations, PlacedDecoration.starter)
        XCTAssertTrue(migrated.earnedAchievements.contains("grade-five"))
        XCTAssertTrue(migrated.displayedAchievements.isEmpty)
    }
    func testDecorAudioAndMedalsRoundTripAndInvalidInputRejected() throws {
        var state = AquariumState.newGame(at: now)
        state.discoveredVariants.insert("copperband:5"); state.syncAchievements()
        try state.setDisplayedAchievements(["first-friend", "grade-five"])
        try state.moveDecoration("kelp", to: 0.72)
        try state.flipDecoration("kelp")
        state.audio.musicVolume = 0.2; state.audio.track = "chiptune"; state.lighting = .night
        XCTAssertEqual(try AquariumSave.decode(JSONEncoder().encode(state)), state)
        state.audio.sfxVolume = .infinity
        XCTAssertFalse(state.isValid)
        state.audio.sfxVolume = 0.7
        state.decorations[0].x = -1
        XCTAssertFalse(state.isValid)
    }

    func testMusicStylesPreserveSaveAndIndependentAudioPreferences() throws {
        XCTAssertEqual(AquariumMusicTrack.allCases.map(\.rawValue),
                       ["lofi", "tide", "chiptune", "japanese", "taiwan", "jazz"])
        for track in AquariumMusicTrack.allCases {
            var state = AquariumState.newGame(at: now)
            let fish = state.fish, random = state.random
            state.audio.track = track.rawValue
            state.audio.musicEnabled = false
            state.audio.musicVolume = 0.17
            state.audio.sfxEnabled = false
            let restored = try AquariumSave.decode(JSONEncoder().encode(state))
            XCTAssertEqual(restored.audio, state.audio)
            XCTAssertEqual(restored.fish, fish)
            XCTAssertEqual(restored.random, random)
            XCTAssertFalse(track.title.isEmpty)
        }
        var invalid = AquariumState.newGame(at: now)
        invalid.audio.track = "unknown-track"
        XCTAssertThrowsError(try AquariumSave.decode(JSONEncoder().encode(invalid)))
    }
}
