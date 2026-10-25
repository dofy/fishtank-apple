import Foundation

struct AppIconDesign: Identifiable {
    let id: String
    let nameKey: String
    var name: String { L10n.key(nameKey) }
    let speciesID: String
    let decorationID: String
    let companionID: String
    var secondarySpeciesID: String? = nil
    var resourceName: String { id == "classic" ? "FishtankIcon" : "FishtankIcon-\(id)" }
}

enum AppIconCatalog {
    static let preferenceKey = "appearance.appIcon"
    static let original = AppIconDesign(id: "classic", nameKey: L10n.source("Classic Goldfin"), speciesID: "goldfin", decorationID: "kelp", companionID: "shell")
    private static let existing: [AppIconDesign] = [
        .init(id: "coral", nameKey: L10n.source("Coral Butterfly"), speciesID: "copperband", decorationID: "coral", companionID: "shell"),
        .init(id: "moon", nameKey: L10n.source("Moonhorn Reef"), speciesID: "moonhorn", decorationID: "kelp", companionID: "rocks"),
        .init(id: "sapphire", nameKey: L10n.source("Sapphire Bay"), speciesID: "sapphiredamsel", decorationID: "coral", companionID: "shell"),
        .init(id: "treasure", nameKey: L10n.source("Golden Butterfly Treasure"), speciesID: "goldbutterfly", decorationID: "kelp", companionID: "chest"),
        .init(id: "neon", nameKey: L10n.source("Neon Sea Mushroom"), speciesID: "neonstreak", decorationID: "mushroom", companionID: "rocks"),
        .init(id: "puffer", nameKey: L10n.source("Cream Starfish"), speciesID: "creampuff", decorationID: "kelp", companionID: "starfish"),
        .init(id: "seahorse", nameKey: L10n.source("Crimson Seahorse"), speciesID: "coralseahorse", decorationID: "coral", companionID: "starfish"),
        .init(id: "crystal", nameKey: L10n.source("Amethyst Goldtail"), speciesID: "royalgoldtail", decorationID: "crystal", companionID: "shell"),
        .init(id: "jelly", nameKey: L10n.source("Cherry Blossom Jelly"), speciesID: "crystaljelly", decorationID: "anemone", companionID: "shell"),
        .init(id: "ray", nameKey: L10n.source("Deep-Sea Ray"), speciesID: "voidray", decorationID: "arch", companionID: "crystal"),
        .init(id: "turtle", nameKey: L10n.source("Emerald Driftwood"), speciesID: "jadeturtle", decorationID: "kelp", companionID: "driftwood"),
        .init(id: "koi", nameKey: L10n.source("Koi Castle"), speciesID: "prismkoi", decorationID: "castle", companionID: "shell")
    ]
    static let duet = AppIconDesign(id: "duet", nameKey: L10n.source("Gold and Silver Pair"), speciesID: "goldfin", decorationID: "coral", companionID: "shell", secondarySpeciesID: "greyminnow")
    static let variants: [AppIconDesign] = existing + [
        .init(id: "greyminnow", nameKey: L10n.source("Shallows Minnow"), speciesID: "greyminnow", decorationID: "kelp", companionID: "rocks"),
        .init(id: "neoncleaner", nameKey: L10n.source("Blue-Line Coral"), speciesID: "neoncleaner", decorationID: "coral", companionID: "rocks"),
        .init(id: "mossback", nameKey: L10n.source("Mossbank Sprite"), speciesID: "mossback", decorationID: "mushroom", companionID: "driftwood"),
        .init(id: "banggai", nameKey: L10n.source("Moonlit Cardinal"), speciesID: "banggai", decorationID: "crystal", companionID: "shell"),
        .init(id: "moonjelly", nameKey: L10n.source("Moon Jelly Glow"), speciesID: "moonjelly", decorationID: "anemone", companionID: "starfish"),
        .init(id: "blushingfire", nameKey: L10n.source("Crimson Anemone"), speciesID: "blushingfire", decorationID: "anemone", companionID: "shell"),
        .init(id: "bandedkrait", nameKey: L10n.source("Ringed Rock Crevice"), speciesID: "bandedkrait", decorationID: "arch", companionID: "rocks"),
        .init(id: "ambereel", nameKey: L10n.source("Amber Treasure"), speciesID: "ambereel", decorationID: "kelp", companionID: "chest"),
        .init(id: "skywing", nameKey: L10n.source("Skywing Reef"), speciesID: "skywing", decorationID: "coral", companionID: "starfish"),
        .init(id: "emberbarb", nameKey: L10n.source("Ember Coral"), speciesID: "emberbarb", decorationID: "coral", companionID: "driftwood"),
        .init(id: "volteel", nameKey: L10n.source("Blue Arc Amethyst"), speciesID: "volteel", decorationID: "crystal", companionID: "rocks"),
        .init(id: "goldenmoorish", nameKey: L10n.source("Golden Temple"), speciesID: "goldenmoorish", decorationID: "arch", companionID: "chest"),
        .init(id: "auroraeel", nameKey: L10n.source("Aurora Crystal Bay"), speciesID: "auroraeel", decorationID: "crystal", companionID: "shell"),
        .init(id: "goldenseahorse", nameKey: L10n.source("Golden-Leaf Coral"), speciesID: "goldenseahorse", decorationID: "coral", companionID: "chest"),
        .init(id: "leviathanfry", nameKey: L10n.source("Seadragon Ruins"), speciesID: "leviathanfry", decorationID: "castle", companionID: "crystal"),
        .init(id: "astraljelly", nameKey: L10n.source("Starcrown Glow"), speciesID: "astraljelly", decorationID: "mushroom", companionID: "crystal"),
        .init(id: "cuttlefish", nameKey: L10n.source("Cuttlefish Ink Reef"), speciesID: "cuttlefish", decorationID: "coral", companionID: "shell"),
        .init(id: "lanternangler", nameKey: L10n.source("Lantern Grotto"), speciesID: "lanternangler", decorationID: "arch", companionID: "mushroom"),
        .init(id: "glassangel", nameKey: L10n.source("Glass Starlit Bay"), speciesID: "glassangel", decorationID: "crystal", companionID: "starfish"),
        .init(id: "starnautilus", nameKey: L10n.source("Starwheel Ruins"), speciesID: "starnautilus", decorationID: "castle", companionID: "shell")
    ] + [duet]
    static let all: [AppIconDesign] = {
        let bySpecies = Dictionary(uniqueKeysWithValues: ([original] + variants.filter { $0.secondarySpeciesID == nil }).map { ($0.speciesID, $0) })
        return FishCatalog.all.compactMap { bySpecies[$0.id] } + [duet]
    }()
    static func label(_ design: AppIconDesign) -> String {
        design.secondarySpeciesID == nil ? (FishCatalog.byID[design.speciesID]?.name ?? design.name) : design.name
    }
    static func isUnlocked(_ design: AppIconDesign, discovered: Set<String>) -> Bool {
        guard let canonical = all.first(where: { $0.id == design.id }) else { return false }
        return discovered.contains(canonical.speciesID)
            && (canonical.secondarySpeciesID.map { discovered.contains($0) } ?? true)
    }
    static func filtered(tier: Int? = nil, discovered: Set<String>) -> [AppIconDesign] {
        all.filter { isUnlocked($0, discovered: discovered) && (tier == nil || FishCatalog.byID[$0.speciesID]?.tier == tier) }
            .sorted { (FishCatalog.byID[$0.speciesID]?.tier ?? 0) < (FishCatalog.byID[$1.speciesID]?.tier ?? 0) }
    }
    static func design(_ id: String?) -> AppIconDesign { all.first { $0.id == id } ?? original }
}
