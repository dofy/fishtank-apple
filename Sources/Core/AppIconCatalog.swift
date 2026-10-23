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
    static let original = AppIconDesign(id: "classic", nameKey: L10n.source("经典金鳍"), speciesID: "goldfin", decorationID: "kelp", companionID: "shell")
    private static let existing: [AppIconDesign] = [
        .init(id: "coral", nameKey: L10n.source("珊瑚蝶影"), speciesID: "copperband", decorationID: "coral", companionID: "shell"),
        .init(id: "moon", nameKey: L10n.source("月角青礁"), speciesID: "moonhorn", decorationID: "kelp", companionID: "rocks"),
        .init(id: "sapphire", nameKey: L10n.source("蓝宝石湾"), speciesID: "sapphiredamsel", decorationID: "coral", companionID: "shell"),
        .init(id: "treasure", nameKey: L10n.source("金蝶宝藏"), speciesID: "goldbutterfly", decorationID: "kelp", companionID: "chest"),
        .init(id: "neon", nameKey: L10n.source("霓虹海蕈"), speciesID: "neonstreak", decorationID: "mushroom", companionID: "rocks"),
        .init(id: "puffer", nameKey: L10n.source("奶油海星"), speciesID: "creampuff", decorationID: "kelp", companionID: "starfish"),
        .init(id: "seahorse", nameKey: L10n.source("绯色海马"), speciesID: "coralseahorse", decorationID: "coral", companionID: "starfish"),
        .init(id: "crystal", nameKey: L10n.source("紫晶金尾"), speciesID: "royalgoldtail", decorationID: "crystal", companionID: "shell"),
        .init(id: "jelly", nameKey: L10n.source("樱花水母"), speciesID: "crystaljelly", decorationID: "anemone", companionID: "shell"),
        .init(id: "ray", nameKey: L10n.source("深海鳐影"), speciesID: "voidray", decorationID: "arch", companionID: "crystal"),
        .init(id: "turtle", nameKey: L10n.source("翡翠沉木"), speciesID: "jadeturtle", decorationID: "kelp", companionID: "driftwood"),
        .init(id: "koi", nameKey: L10n.source("锦鲤城堡"), speciesID: "prismkoi", decorationID: "castle", companionID: "shell")
    ]
    static let duet = AppIconDesign(id: "duet", nameKey: L10n.source("金银同游"), speciesID: "goldfin", decorationID: "coral", companionID: "shell", secondarySpeciesID: "greyminnow")
    static let variants: [AppIconDesign] = existing + [
        .init(id: "greyminnow", nameKey: L10n.source("浅滩灰鲦"), speciesID: "greyminnow", decorationID: "kelp", companionID: "rocks"),
        .init(id: "neoncleaner", nameKey: L10n.source("蓝线珊瑚"), speciesID: "neoncleaner", decorationID: "coral", companionID: "rocks"),
        .init(id: "mossback", nameKey: L10n.source("苔岸精灵"), speciesID: "mossback", decorationID: "mushroom", companionID: "driftwood"),
        .init(id: "banggai", nameKey: L10n.source("月夜天竺"), speciesID: "banggai", decorationID: "crystal", companionID: "shell"),
        .init(id: "moonjelly", nameKey: L10n.source("海月微光"), speciesID: "moonjelly", decorationID: "anemone", companionID: "starfish"),
        .init(id: "blushingfire", nameKey: L10n.source("绯红海葵"), speciesID: "blushingfire", decorationID: "anemone", companionID: "shell"),
        .init(id: "bandedkrait", nameKey: L10n.source("环纹石隙"), speciesID: "bandedkrait", decorationID: "arch", companionID: "rocks"),
        .init(id: "ambereel", nameKey: L10n.source("琥珀宝藏"), speciesID: "ambereel", decorationID: "kelp", companionID: "chest"),
        .init(id: "skywing", nameKey: L10n.source("天翼浮礁"), speciesID: "skywing", decorationID: "coral", companionID: "starfish"),
        .init(id: "emberbarb", nameKey: L10n.source("余烬珊瑚"), speciesID: "emberbarb", decorationID: "coral", companionID: "driftwood"),
        .init(id: "volteel", nameKey: L10n.source("蓝弧紫晶"), speciesID: "volteel", decorationID: "crystal", companionID: "rocks"),
        .init(id: "goldenmoorish", nameKey: L10n.source("黄金神殿"), speciesID: "goldenmoorish", decorationID: "arch", companionID: "chest"),
        .init(id: "auroraeel", nameKey: L10n.source("极光晶湾"), speciesID: "auroraeel", decorationID: "crystal", companionID: "shell"),
        .init(id: "goldenseahorse", nameKey: L10n.source("金叶珊瑚"), speciesID: "goldenseahorse", decorationID: "coral", companionID: "chest"),
        .init(id: "leviathanfry", nameKey: L10n.source("海龙遗迹"), speciesID: "leviathanfry", decorationID: "castle", companionID: "crystal"),
        .init(id: "astraljelly", nameKey: L10n.source("星冕幽光"), speciesID: "astraljelly", decorationID: "mushroom", companionID: "crystal"),
        .init(id: "lanternangler", nameKey: L10n.source("幽灯石窟"), speciesID: "lanternangler", decorationID: "arch", companionID: "mushroom"),
        .init(id: "glassangel", nameKey: L10n.source("琉璃星湾"), speciesID: "glassangel", decorationID: "crystal", companionID: "starfish"),
        .init(id: "starnautilus", nameKey: L10n.source("星轮遗迹"), speciesID: "starnautilus", decorationID: "castle", companionID: "shell")
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
