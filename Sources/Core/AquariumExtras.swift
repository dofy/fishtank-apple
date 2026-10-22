import Foundation

struct PlacedDecoration: Codable, Equatable, Identifiable {
    var id: String
    var x: Double
    var flip = 1
    static let starter = [Self(id: "kelp", x: 0.14), Self(id: "rocks", x: 0.5), Self(id: "shell", x: 0.84)]
}

enum AquariumLighting: String, Codable, CaseIterable {
    case auto, day, night
    var title: String { switch self { case .auto: return L10n.text("自动"); case .day: return L10n.text("白昼"); case .night: return L10n.text("夜晚") } }
    func isNight(at date: Date) -> Bool {
        if self != .auto { return self == .night }
        let hour = Calendar.current.component(.hour, from: date)
        return hour < 7 || hour >= 19
    }
}

enum AquariumMusicTrack: String, CaseIterable {
    case lofi, tide, chiptune, japanese, taiwan, jazz

    var title: String {
        switch self {
        case .lofi: return L10n.text("珊瑚礁 Lo-Fi")
        case .tide: return L10n.text("深海潮汐")
        case .chiptune: return L10n.text("液晶八音盒")
        case .japanese: return L10n.text("日系庭院")
        case .taiwan: return L10n.text("台式怀旧")
        case .jazz: return L10n.text("月光 Jazz")
        }
    }
}

struct AquariumAudio: Codable, Equatable {
    var sfxEnabled = true
    var sfxVolume = 0.7
    var musicEnabled = true
    var musicVolume = 0.4
    var track = "lofi"
    var isValid: Bool {
        sfxVolume.isFinite && musicVolume.isFinite && (0...1).contains(sfxVolume)
            && (0...1).contains(musicVolume) && AquariumMusicTrack(rawValue: track) != nil
    }
}

struct AchievementProgress: Equatable {
    var id: String
    var current: Int
    var total: Int
    var unlocked: Bool
}

extension AquariumState {
    mutating func syncDecorations() {
        var seen = Set<String>()
        decorations = Array(decorations.filter {
            guard let item = DecorCatalog.byID[$0.id] else { return false }
            return level >= item.unlockLevel && seen.insert($0.id).inserted
        }.prefix(capacity)).map {
            PlacedDecoration(id: $0.id, x: max(0.06, min(0.94, $0.x.isFinite ? $0.x : 0.5)), flip: $0.flip == -1 ? -1 : 1)
        }
    }

    mutating func toggleDecoration(_ id: String) throws {
        guard let item = DecorCatalog.byID[id], level >= item.unlockLevel else { throw AquariumExtraError.decorLocked }
        syncDecorations()
        if decorations.contains(where: { $0.id == id }) { decorations.removeAll { $0.id == id }; return }
        guard decorations.count < capacity else { throw AquariumExtraError.decorFull }
        let samePlane = decorations.filter { DecorCatalog.byID[$0.id]?.top == item.top }
        let candidates = [0.5, 0.3, 0.7, 0.18, 0.82, 0.4, 0.6, 0.24, 0.76, 0.1, 0.9]
        let x = candidates.first { candidate in samePlane.allSatisfy { abs($0.x - candidate) > 0.08 } }
            ?? (0.2 + (Double(samePlane.count) * 0.15).truncatingRemainder(dividingBy: 0.6))
        decorations.append(PlacedDecoration(id: id, x: x))
    }

    mutating func moveDecoration(_ id: String, to x: Double) throws {
        guard x.isFinite, let index = decorations.firstIndex(where: { $0.id == id }) else { throw AquariumExtraError.invalidDecoration }
        var item = decorations.remove(at: index)
        item.x = min(0.94, max(0.06, x))
        decorations.append(item)
    }

    mutating func flipDecoration(_ id: String) throws {
        guard let index = decorations.firstIndex(where: { $0.id == id }) else { throw AquariumExtraError.invalidDecoration }
        decorations[index].flip *= -1
    }

    var achievementProgress: [AchievementProgress] {
        var species = discovered
        var variants = discoveredVariants
        for fish in fish { species.insert(fish.speciesID); variants.insert("\(fish.speciesID):\(fish.grade)") }
        for key in variants { if let id = key.split(separator: ":").first { species.insert(String(id)) } }
        let nonstarter = Set(FishCatalog.all.filter { $0.tier > 0 }.map(\.id))
        let validVariants = variants.filter { nonstarter.contains(String($0.split(separator: ":")[0])) }
        func family(_ form: String) -> Int { FishCatalog.all.filter { $0.form == form && species.contains($0.id) }.count }
        func tier(_ tier: Int) -> Int { FishCatalog.all.contains { $0.tier == tier && species.contains($0.id) } ? 1 : 0 }
        let count = species.intersection(nonstarter).count
        let values: [String: Int] = [
            "first-friend": min(1, count), "tier-one": FishCatalog.all.filter { $0.tier == 1 && species.contains($0.id) }.count,
            "jelly-family": family("jellyfish"), "grade-five": validVariants.contains { $0.hasSuffix(":5") } ? 1 : 0,
            "variant-collector": min(25, validVariants.count), "reef-explorer": species.count,
            "reef-rookie": min(5, count), "reef-naturalist": min(15, count), "rare-encounter": tier(3),
            "legend-encounter": tier(4), "mythic-encounter": tier(5), "eel-family": family("eel"),
            "color-palette": nonstarter.map { id in (1...5).filter { variants.contains("\(id):\($0)") }.count }.max() ?? 0,
            "variant-master": min(60, validVariants.count)
        ]
        return AchievementCatalog.all.map { item in
            let current = min(item.total, values[item.id] ?? 0)
            return AchievementProgress(id: item.id, current: current, total: item.total,
                                       unlocked: earnedAchievements.contains(item.id) || current >= item.total)
        }
    }

    mutating func syncAchievements() {
        let earned = achievementProgress.filter(\.unlocked).map(\.id)
        earnedAchievements.formUnion(earned)
        displayedAchievements = displayedAchievements.filter { earnedAchievements.contains($0) }
    }

    mutating func setDisplayedAchievements(_ ids: [String]) throws {
        syncAchievements()
        guard Set(ids).count == ids.count, Set(ids).isSubset(of: earnedAchievements) else { throw AquariumExtraError.medalLocked }
        displayedAchievements = ids
    }

    var extrasAreValid: Bool {
        let ids = decorations.map(\.id)
        return audio.isValid && railLights.isValid && decorations.count <= capacity && Set(ids).count == ids.count
            && decorations.allSatisfy { DecorCatalog.byID[$0.id].map { $0.unlockLevel <= level } == true
                && $0.x.isFinite && (0.06...0.94).contains($0.x) && [-1, 1].contains($0.flip) }
            && earnedAchievements.isSubset(of: AchievementCatalog.ids)
            && Set(displayedAchievements).count == displayedAchievements.count
            && Set(displayedAchievements).isSubset(of: earnedAchievements)
    }

    // All previous native saves are additive migrations; occupied tank slots and fish stay intact.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let incoming = try c.decode(Int.self, forKey: .version)
        guard [2, 3].contains(incoming) else { throw AquariumError.invalidSave }
        self.init(version: 3, fish: try c.decode([AquariumFish].self, forKey: .fish),
                  tankIDs: try c.decode([UUID].self, forKey: .tankIDs), hearts: try c.decode(Int.self, forKey: .hearts),
                  nextHeartAt: try c.decode(Date.self, forKey: .nextHeartAt), lastUpdated: try c.decode(Date.self, forKey: .lastUpdated),
                  exp: try c.decode(Int.self, forKey: .exp), discovered: try c.decode(Set<String>.self, forKey: .discovered),
                  discoveredVariants: try c.decode(Set<String>.self, forKey: .discoveredVariants),
                  mergePreferences: try c.decode(MergePreferences.self, forKey: .mergePreferences),
                  random: try c.decode(FishRandom.self, forKey: .random),
                  decorations: try c.decodeIfPresent([PlacedDecoration].self, forKey: .decorations) ?? PlacedDecoration.starter,
                  earnedAchievements: try c.decodeIfPresent(Set<String>.self, forKey: .earnedAchievements) ?? [],
                  displayedAchievements: try c.decodeIfPresent([String].self, forKey: .displayedAchievements) ?? [],
                  audio: try c.decodeIfPresent(AquariumAudio.self, forKey: .audio) ?? AquariumAudio(),
                  lighting: try c.decodeIfPresent(AquariumLighting.self, forKey: .lighting) ?? .auto,
                  railLights: try c.decodeIfPresent(AquariumRailLights.self, forKey: .railLights) ?? AquariumRailLights(),
                  webSourceSnapshot: try c.decodeIfPresent(Data.self, forKey: .webSourceSnapshot))
    }
}

enum AquariumExtraError: String, LocalizedError {
    case decorLocked, decorFull, invalidDecoration, medalLocked
    var errorDescription: String? {
        switch self {
        case .decorLocked: return L10n.text("鱼缸升级后会解锁这件装饰。")
        case .decorFull: return L10n.text("装饰位已满，请先收回一件装饰。")
        case .invalidDecoration: return L10n.text("请先放入这件装饰。")
        case .medalLocked: return L10n.text("只能挂上已经获得的勋章。")
        }
    }
}

struct AquariumRailLights: Codable, Equatable {
    var animated = true
    var frequency = 0.5
    var isValid: Bool { frequency.isFinite && (0.2...2).contains(frequency) }
    func brightness(time: Double, index: Int, reducedMotion: Bool = false) -> Double {
        guard animated && !reducedMotion else { return 1 }
        let wave = (1 + cos(time * .pi * 2 * frequency - Double(index) * 0.7)) / 2
        return 0.25 + 0.75 * wave * wave
    }
}
