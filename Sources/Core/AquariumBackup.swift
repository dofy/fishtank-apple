import Foundation
import CoreFoundation

/// Portable native backups and one-way import of the original web game's v1 JSON.
/// The complete original web snapshot is retained for legacy metadata compatibility.
enum AquariumBackup {
    static let maximumBytes = 10 * 1024 * 1024
    struct Envelope: Codable {
        var format = "fishtank-apple-backup"
        var version = 1
        var exportedAt: Date
        var state: AquariumState
    }
    static func export(_ state: AquariumState, at date: Date = Date()) throws -> Data {
        guard state.isValid else { throw AquariumError.invalidSave }
        let encoder = JSONEncoder(); encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(Envelope(exportedAt: date, state: state))
        guard data.count <= maximumBytes else { throw AquariumError.invalidSave }
        return data
    }
    static func parse(_ data: Data) throws -> AquariumState {
        guard data.count <= maximumBytes,
              let object = try JSONSerialization.jsonObject(with: data) as? [String: Any] else { throw AquariumError.invalidSave }
        if let format = object["format"] as? String {
            if format == "fishtank-apple-backup" {
                let envelope = try JSONDecoder().decode(Envelope.self, from: data)
                guard envelope.version == 1, envelope.state.isValid, envelope.exportedAt.timeIntervalSince1970.isFinite else { throw AquariumError.invalidSave }
                return envelope.state
            }
            guard format == "fishtank-backup", integer(object["version"]) == 1,
                  let exported = object["exportedAt"] as? String,
                  ISO8601DateFormatter.fractional.date(from: exported) != nil,
                  let state = object["state"] as? [String: Any] else { throw AquariumError.invalidSave }
            return try web(state)
        }
        if object["lastTick"] != nil { return try web(object) }
        return try AquariumSave.decode(data)
    }

    private static func integer(_ value: Any?) -> Int? {
        guard let number = value as? NSNumber, CFGetTypeID(number) != CFBooleanGetTypeID(),
              number.doubleValue.isFinite, number.doubleValue.rounded() == number.doubleValue,
              abs(number.doubleValue) <= 9_007_199_254_740_991 else { return nil }
        return number.intValue
    }
    private static func bool(_ value: Any?) -> Bool? {
        guard let number = value as? NSNumber, CFGetTypeID(number) == CFBooleanGetTypeID() else { return nil }
        return number.boolValue
    }
    private static func number(_ value: Any?) -> Double? {
        guard let value = value as? NSNumber, CFGetTypeID(value) != CFBooleanGetTypeID(), value.doubleValue.isFinite else { return nil }
        return value.doubleValue
    }
    private static func timestamp(_ value: Any?) throws -> Date {
        guard let ms = integer(value), ms >= 0 else { throw AquariumError.invalidSave }
        return Date(timeIntervalSince1970: Double(ms) / 1000)
    }
    private static func strings(_ value: Any?, limit: Int) throws -> [String] {
        guard let list = value as? [String], list.count <= limit,
              Set(list).count == list.count, list.allSatisfy({ !$0.isEmpty && $0.count <= 200 }) else { throw AquariumError.invalidSave }
        return list
    }
    private static func web(_ object: [String: Any]) throws -> AquariumState {
        guard integer(object["version"]) == 1,
              let list = object["fish"] as? [[String: Any]], list.count <= 20_000,
              let hearts = integer(object["hearts"]), (0...5).contains(hearts),
              let exp = integer(object["exp"]), (0...1_000_000_000).contains(exp),
              let level = integer(object["level"]), level == FishBalance.level(exp: exp),
              let theme = object["theme"] as? String, !theme.isEmpty, theme.count <= 200 else { throw AquariumError.invalidSave }
        let now = try timestamp(object["lastTick"])
        var state = AquariumState.newGame(at: now)
        state.fish = []; state.exp = exp; state.hearts = hearts; state.lastUpdated = now
        state.nextHeartAt = try timestamp(object["nextHeartAt"])
        state.reforgeMisses = try optionalInteger(object["reforgeMisses"], default: 0)
        var mapping: [String: UUID] = [:]
        for item in list {
            guard let uid = item["uid"] as? String, !uid.isEmpty, uid.count <= 200, mapping[uid] == nil,
                  let speciesID = item["speciesId"] as? String, let species = FishCatalog.byID[speciesID],
                  integer(item["tier"]) == species.tier,
                  let grade = integer(item["grade"]), (1...5).contains(grade), species.tier != 0 || grade == 1,
                  let uses = integer(item["uses"]), (0...999).contains(uses),
                  let banked = bool(item["expBanked"]) else { throw AquariumError.invalidSave }
            let maximum = try optionalInteger(item["maxUses"], default: max(uses, FishBalance.uses[species.tier]))
            guard maximum >= uses && maximum <= 999 else { throw AquariumError.invalidSave }
            let birth = try optionalInteger(item["birthExp"], default: 0)
            let locked = try optionalBool(item["locked"], default: false)
            if let nickname = item["nickname"], !(nickname is String) { throw AquariumError.invalidSave }
            if let favorite = item["favorite"], bool(favorite) == nil { throw AquariumError.invalidSave }
            var fish = AquariumFish(speciesID: speciesID, grade: grade, uses: species.tier == 0 ? 999 : uses,
                maxUses: species.tier == 0 ? 999 : maximum == 0 ? FishBalance.uses[species.tier] : maximum, bornAt: try timestamp(item["bornAt"]),
                maturesAt: item["maturesAt"] is NSNull ? nil : try timestamp(item["maturesAt"]),
                birthExp: birth, expBanked: banked, locked: locked)
            fish.id = UUID(); mapping[uid] = fish.id; state.fish.append(fish)
        }
        // Match the original loader's starter repair without replacing existing IDs or fish.
        let starterIDs = ["goldfin", "goldfin", "greyminnow"]
        while state.fish.filter({ $0.tier == 0 }).count < 3 {
            let count = state.fish.filter { $0.tier == 0 }.count
            state.fish.insert(.make(species: FishCatalog.byID[starterIDs[count]]!, at: now, adult: true), at: 0)
        }
        if let tank = object["tankUids"] {
            state.tankIDs = try strings(tank, limit: 20_000).map { uid in
                guard let id = mapping[uid] else { throw AquariumError.invalidSave }; return id
            }
        } else { state.tankIDs = Array(state.fish.prefix(3).map(\.id)) }
        state.discovered = Set(try strings(object["discovered"], limit: 10_000))
        state.discoveredVariants = Set(try object["discoveredVariants"].map { try strings($0, limit: 50_000) } ?? [])
        for fish in state.fish { state.discovered.insert(fish.speciesID); state.discoveredVariants.insert("\(fish.speciesID):\(fish.grade)") }
        if object["discoveredVariants"] == nil {
            for id in state.discovered where !state.discoveredVariants.contains(where: { $0.hasPrefix(id + ":") }) { state.discoveredVariants.insert(id + ":1") }
        }
        if let value = object["placedDecor"] {
            guard let items = value as? [[String: Any]] else { throw AquariumError.invalidSave }
            state.decorations = try items.map { item in
                guard let id = item["id"] as? String, let x = number(item["x"]) else { throw AquariumError.invalidSave }
                return PlacedDecoration(id: id, x: x, flip: try optionalInteger(item["flip"], default: 1))
            }
        }
        if let value = object["mergeFilter"] {
            state.mergePreferences = try JSONDecoder().decode(MergePreferences.self, from: JSONSerialization.data(withJSONObject: value))
        }
        if let value = object["railLights"] {
            state.railLights = try JSONDecoder().decode(AquariumRailLights.self, from: JSONSerialization.data(withJSONObject: value))
        }
        if let value = object["audio"] {
            guard let audio = value as? [String: Any], let sfx = bool(audio["sfxEnabled"]), let music = bool(audio["bgmEnabled"]),
                  let sfxVolume = number(audio["sfxVolume"]), let musicVolume = number(audio["bgmVolume"]),
                  let track = audio["bgmTrack"] as? String else { throw AquariumError.invalidSave }
            state.audio = AquariumAudio(sfxEnabled: sfx, sfxVolume: sfxVolume, musicEnabled: music, musicVolume: musicVolume, track: track)
        }
        if let mode = object["colorMode"] {
            guard let mode = mode as? String, ["auto", "light", "dark"].contains(mode) else { throw AquariumError.invalidSave }
            state.lighting = mode == "light" ? .day : mode == "dark" ? .night : .auto
        }
        if let locale = object["locale"] {
            guard let locale = locale as? String, ["zh", "en"].contains(locale) else { throw AquariumError.invalidSave }
        }
        if let value = object["milestones"] {
            guard let medals = value as? [String: Any] else { throw AquariumError.invalidSave }
            state.earnedAchievements = Set(try strings(medals["unlocked"], limit: AchievementCatalog.all.count))
            if let displayed = medals["displayed"] {
                state.displayedAchievements = try strings(displayed is String ? [displayed as! String] : displayed, limit: AchievementCatalog.all.count)
            }
        }
        state.webSourceSnapshot = try JSONSerialization.data(withJSONObject: object, options: [.sortedKeys])
        guard state.isValid else { throw AquariumError.invalidSave }
        state.syncAchievements()
        return state
    }
    private static func optionalInteger(_ value: Any?, default fallback: Int) throws -> Int {
        guard let value else { return fallback }
        guard let result = integer(value) else { throw AquariumError.invalidSave }; return result
    }
    private static func optionalBool(_ value: Any?, default fallback: Bool) throws -> Bool {
        guard let value else { return fallback }
        guard let result = bool(value) else { throw AquariumError.invalidSave }; return result
    }
}

private extension ISO8601DateFormatter {
    static var fractional: ISO8601DateFormatter {
        let formatter = ISO8601DateFormatter(); formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]; return formatter
    }
}
