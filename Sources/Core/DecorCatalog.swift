import Foundation

struct AquariumDecor: Identifiable, Equatable {
    let id: String
    let nameKey: String
    var name: String { L10n.key(nameKey) }
    let unlockLevel: Int
    let top: Bool
    let hue: Double
    let width: Double
    let height: Double

    /// Shared display geometry: scene, thumbnail and raster sampling must agree.
    var displayWidth: Double { (id == "fairylights" ? 64 : max(18, width * 0.48)) * (id == "chest" ? 2 : 1) }
    var displayHeight: Double { (id == "fairylights" ? 32 : max(12, height * 0.4)) * (id == "chest" ? 2 : 1) }
    var displayAspectRatio: Double { displayWidth / displayHeight }
}

enum DecorCatalog {
    static let all: [AquariumDecor] = [
        .init(id: "kelp", nameKey: L10n.source("Emerald Seagrass"), unlockLevel: 1, top: false, hue: 142, width: 58, height: 146),
        .init(id: "rocks", nameKey: L10n.source("Reef Cluster"), unlockLevel: 1, top: false, hue: 205, width: 72, height: 34),
        .init(id: "shell", nameKey: L10n.source("Pearl Scallop"), unlockLevel: 1, top: false, hue: 330, width: 50, height: 32),
        .init(id: "fairylights", nameKey: L10n.source("Rainbow String Lights"), unlockLevel: 1, top: true, hue: 46, width: 138, height: 38),
        .init(id: "coral", nameKey: L10n.source("Staghorn Coral"), unlockLevel: 2, top: false, hue: 12, width: 76, height: 118),
        .init(id: "mushroom", nameKey: L10n.source("Glowcap Anemone"), unlockLevel: 2, top: false, hue: 174, width: 64, height: 78),
        .init(id: "starfish", nameKey: L10n.source("Starfish Rock"), unlockLevel: 3, top: false, hue: 26, width: 58, height: 38),
        .init(id: "starlamps", nameKey: L10n.source("Starlight Chandelier"), unlockLevel: 3, top: true, hue: 50, width: 108, height: 92),
        .init(id: "driftwood", nameKey: L10n.source("Driftwood Arch"), unlockLevel: 4, top: false, hue: 28, width: 102, height: 68),
        .init(id: "anemone", nameKey: L10n.source("Glow Anemone"), unlockLevel: 5, top: false, hue: 286, width: 64, height: 82),
        .init(id: "lanterns", nameKey: L10n.source("Festival Lantern"), unlockLevel: 5, top: true, hue: 14, width: 118, height: 58),
        .init(id: "arch", nameKey: L10n.source("Undersea Stone Arch"), unlockLevel: 6, top: false, hue: 198, width: 98, height: 126),
        .init(id: "crystal", nameKey: L10n.source("Amethyst Grotto"), unlockLevel: 6, top: false, hue: 272, width: 70, height: 104),
        .init(id: "chest", nameKey: L10n.source("Sunken Treasure Chest"), unlockLevel: 7, top: false, hue: 40, width: 62, height: 44),
        .init(id: "jellylamps", nameKey: L10n.source("Neon Jellyfish Lamp"), unlockLevel: 7, top: true, hue: 308, width: 114, height: 84),
        .init(id: "anchor", nameKey: L10n.source("Ancient Anchor"), unlockLevel: 8, top: false, hue: 210, width: 72, height: 132),
        .init(id: "castle", nameKey: L10n.source("Undersea Castle"), unlockLevel: 9, top: false, hue: 38, width: 106, height: 156),
        .init(id: "statue", nameKey: L10n.source("Deep-Sea Idol"), unlockLevel: 10, top: false, hue: 175, width: 74, height: 142),
    ]
    static let byID = Dictionary(uniqueKeysWithValues: all.map { ($0.id, $0) })
}

struct Achievement: Identifiable {
    let id: String
    let titleKey: String
    var title: String { L10n.key(titleKey) }
    let noteKey: String
    var note: String { L10n.key(noteKey) }
    let total: Int
}

enum AchievementCatalog {
    static let all: [Achievement] = [
        .init(id: "first-friend", titleKey: L10n.source("First Encounter"), noteKey: L10n.source("Discover your first non-starter fish"), total: 1),
        .init(id: "tier-one", titleKey: L10n.source("Reef Neighbors"), noteKey: L10n.source("Collect every 1★ species"), total: 7),
        .init(id: "jelly-family", titleKey: L10n.source("Jellyfish Drifter"), noteKey: L10n.source("Discover all three jellyfish"), total: 3),
        .init(id: "grade-five", titleKey: L10n.source("A Touch of Iridescence"), noteKey: L10n.source("First grade-5 fish discovered"), total: 1),
        .init(id: "variant-collector", titleKey: L10n.source("Iridescent Collector"), noteKey: L10n.source("Discover 25 non-starter grade variants"), total: 25),
        .init(id: "reef-explorer", titleKey: L10n.source("Ocean Friends"), noteKey: L10n.source("Discover every regular sea creature"), total: FishCatalog.regular.count),
        .init(id: "reef-rookie", titleKey: L10n.source("First Reef"), noteKey: L10n.source("Discover 5 non-starter species"), total: 5),
        .init(id: "reef-naturalist", titleKey: L10n.source("Ocean Naturalist"), noteKey: L10n.source("Discover 15 non-starter species"), total: 15),
        .init(id: "rare-encounter", titleKey: L10n.source("Deep Blue Visitor"), noteKey: L10n.source("Discover your first 3★ rare fish"), total: 1),
        .init(id: "legend-encounter", titleKey: L10n.source("Legendary Glow"), noteKey: L10n.source("Discover your first 4★ legendary fish"), total: 1),
        .init(id: "mythic-encounter", titleKey: L10n.source("Mythic Echo"), noteKey: L10n.source("Discover your first 5★ mythical fish"), total: 1),
        .init(id: "eel-family", titleKey: L10n.source("Eel-Dance Current"), noteKey: L10n.source("Discover all three eels"), total: 3),
        .init(id: "color-palette", titleKey: L10n.source("Rainbow Shoal"), noteKey: L10n.source("Collect all five grades of any non-starter fish"), total: 5),
        .init(id: "variant-master", titleKey: L10n.source("Iridescent Treasury"), noteKey: L10n.source("Discover 60 non-starter grade variants"), total: 60),
        .init(id: "secret-encounter", titleKey: L10n.source("Secret Encounter"), noteKey: L10n.source("Reforge your first secret creature"), total: 1),
        .init(id: "secret-trio", titleKey: L10n.source("Secret Trio"), noteKey: L10n.source("Discover all three secret species"), total: 3),
    ]
    static let ids = Set(all.map(\.id))
}
