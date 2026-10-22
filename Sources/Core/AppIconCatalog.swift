import Foundation

struct AppIconDesign: Identifiable {
    let id: String
    let name: String
    let speciesID: String
    let decorationID: String
    let companionID: String
    var secondarySpeciesID: String? = nil
    var resourceName: String { id == "classic" ? "FishtankIcon" : "FishtankIcon-\(id)" }
}

enum AppIconCatalog {
    static let preferenceKey = "appearance.appIcon"
    static let original = AppIconDesign(id: "classic", name: "经典金鳍", speciesID: "goldfin", decorationID: "kelp", companionID: "shell")
    private static let existing: [AppIconDesign] = [
        .init(id: "coral", name: "珊瑚蝶影", speciesID: "copperband", decorationID: "coral", companionID: "shell"),
        .init(id: "moon", name: "月角青礁", speciesID: "moonhorn", decorationID: "kelp", companionID: "rocks"),
        .init(id: "sapphire", name: "蓝宝石湾", speciesID: "sapphiredamsel", decorationID: "coral", companionID: "shell"),
        .init(id: "treasure", name: "金蝶宝藏", speciesID: "goldbutterfly", decorationID: "kelp", companionID: "chest"),
        .init(id: "neon", name: "霓虹海蕈", speciesID: "neonstreak", decorationID: "mushroom", companionID: "rocks"),
        .init(id: "puffer", name: "奶油海星", speciesID: "creampuff", decorationID: "kelp", companionID: "starfish"),
        .init(id: "seahorse", name: "绯色海马", speciesID: "coralseahorse", decorationID: "coral", companionID: "starfish"),
        .init(id: "crystal", name: "紫晶金尾", speciesID: "royalgoldtail", decorationID: "crystal", companionID: "shell"),
        .init(id: "jelly", name: "樱花水母", speciesID: "crystaljelly", decorationID: "anemone", companionID: "shell"),
        .init(id: "ray", name: "深海鳐影", speciesID: "voidray", decorationID: "arch", companionID: "crystal"),
        .init(id: "turtle", name: "翡翠沉木", speciesID: "jadeturtle", decorationID: "kelp", companionID: "driftwood"),
        .init(id: "koi", name: "锦鲤城堡", speciesID: "prismkoi", decorationID: "castle", companionID: "shell")
    ]
    static let duet = AppIconDesign(id: "duet", name: "金银同游", speciesID: "goldfin", decorationID: "coral", companionID: "shell", secondarySpeciesID: "greyminnow")
    static let variants: [AppIconDesign] = existing + [
        .init(id: "greyminnow", name: "浅滩灰鲦", speciesID: "greyminnow", decorationID: "kelp", companionID: "rocks"),
        .init(id: "neoncleaner", name: "蓝线珊瑚", speciesID: "neoncleaner", decorationID: "coral", companionID: "rocks"),
        .init(id: "mossback", name: "苔岸精灵", speciesID: "mossback", decorationID: "mushroom", companionID: "driftwood"),
        .init(id: "banggai", name: "月夜天竺", speciesID: "banggai", decorationID: "crystal", companionID: "shell"),
        .init(id: "moonjelly", name: "海月微光", speciesID: "moonjelly", decorationID: "anemone", companionID: "starfish"),
        .init(id: "blushingfire", name: "绯红海葵", speciesID: "blushingfire", decorationID: "anemone", companionID: "shell"),
        .init(id: "bandedkrait", name: "环纹石隙", speciesID: "bandedkrait", decorationID: "arch", companionID: "rocks"),
        .init(id: "ambereel", name: "琥珀宝藏", speciesID: "ambereel", decorationID: "kelp", companionID: "chest"),
        .init(id: "skywing", name: "天翼浮礁", speciesID: "skywing", decorationID: "coral", companionID: "starfish"),
        .init(id: "emberbarb", name: "余烬珊瑚", speciesID: "emberbarb", decorationID: "coral", companionID: "driftwood"),
        .init(id: "volteel", name: "蓝弧紫晶", speciesID: "volteel", decorationID: "crystal", companionID: "rocks"),
        .init(id: "goldenmoorish", name: "黄金神殿", speciesID: "goldenmoorish", decorationID: "arch", companionID: "chest"),
        .init(id: "auroraeel", name: "极光晶湾", speciesID: "auroraeel", decorationID: "crystal", companionID: "shell"),
        .init(id: "goldenseahorse", name: "金叶珊瑚", speciesID: "goldenseahorse", decorationID: "coral", companionID: "chest"),
        .init(id: "leviathanfry", name: "海龙遗迹", speciesID: "leviathanfry", decorationID: "castle", companionID: "crystal"),
        .init(id: "astraljelly", name: "星冕幽光", speciesID: "astraljelly", decorationID: "mushroom", companionID: "crystal")
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
        let starters = Set(FishCatalog.pool(tier: 0).map(\.id))
        let available = discovered.union(starters)
        return available.contains(canonical.speciesID)
            && (canonical.secondarySpeciesID.map { available.contains($0) } ?? true)
    }
    static func filtered(tier: Int? = nil) -> [AppIconDesign] {
        all.filter { tier == nil || FishCatalog.byID[$0.speciesID]?.tier == tier }
            .sorted { (FishCatalog.byID[$0.speciesID]?.tier ?? 0) < (FishCatalog.byID[$1.speciesID]?.tier ?? 0) }
    }
    static func design(_ id: String?) -> AppIconDesign { all.first { $0.id == id } ?? original }
}
