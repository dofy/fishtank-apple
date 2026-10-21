import Foundation

enum AquariumSave {
    static func decode(_ data: Data) throws -> AquariumState {
        guard data.count <= 10 * 1024 * 1024 else { throw AquariumError.invalidSave }
        let decoder = JSONDecoder()
        let version = try decoder.decode(Header.self, from: data).version
        var state: AquariumState
        if version == 2 || version == 3 {
            state = try decoder.decode(AquariumState.self, from: data)
        } else if version == 1 {
            let old = try decoder.decode(Prototype.self, from: data)
            guard old.fish.count <= 100, (0...5).contains(old.hearts),
                  Set(old.fish.map(\.id)).count == old.fish.count else { throw AquariumError.invalidSave }
            state = .newGame(at: old.lastUpdated)
            state.fish = try old.fish.map { item in
                guard (0...2).contains(item.palette) else { throw AquariumError.invalidSave }
                var fish = AquariumFish.make(species: FishCatalog.byID[item.palette == 2 ? "greyminnow" : "goldfin"]!,
                                             at: old.lastUpdated, adult: true)
                fish.id = item.id
                fish.maturesAt = item.maturesAt
                return fish
            }
            state.tankIDs = Array(state.fish.prefix(3).map(\.id))
            state.hearts = old.hearts
            state.nextHeartAt = old.nextHeartAt
            state.discovered = Set(state.fish.map(\.speciesID))
            state.discoveredVariants = Set(state.fish.map { "\($0.speciesID):1" })
        } else { throw AquariumError.invalidSave }
        guard state.isValid else { throw AquariumError.invalidSave }
        state.syncAchievements()
        return state
    }

    private struct Header: Decodable { var version: Int }
    private struct Prototype: Decodable {
        struct Fish: Decodable { var id: UUID; var palette: Int; var maturesAt: Date? }
        var fish: [Fish]
        var hearts: Int
        var nextHeartAt: Date
        var lastUpdated: Date
    }
}
