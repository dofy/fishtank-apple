import Foundation

// Migrated from fishtank 5eb7520: species.ts, i18n.ts and balance.ts.
struct FishSpecies: Identifiable, Equatable {
    let id: String
    let nameKey: String
    var name: String { L10n.key(nameKey) }
    let tier: Int
    let form: String
    let silhouette: String
    let pattern: String
    let hue: Double
    let saturation: Double
    let lightness: Double
    let depth: Double
    let tail: Double
    let dorsal: Double
    let length: Double
    let electric: Bool
}

enum FishCatalog {
    static let all: [FishSpecies] = [
        FishSpecies(id: "goldfin", nameKey: L10n.source("金鳍初始鱼"), tier: 0, form: "fish", silhouette: "goldfish", pattern: "plain", hue: 28, saturation: 0.85, lightness: 0.56, depth: 0.54, tail: 0.36, dorsal: 0.35, length: 12, electric: false),
        FishSpecies(id: "greyminnow", nameKey: L10n.source("灰鲦鱼"), tier: 0, form: "fish", silhouette: "minnow", pattern: "plain", hue: 205, saturation: 0.14, lightness: 0.62, depth: 0.36, tail: 0.28, dorsal: 0.22, length: 11, electric: false),
        FishSpecies(id: "copperband", nameKey: L10n.source("铜带蝶鱼"), tier: 1, form: "fish", silhouette: "beak-butterfly", pattern: "stripes", hue: 24, saturation: 0.82, lightness: 0.58, depth: 0.82, tail: 0.26, dorsal: 0.65, length: 14, electric: false),
        FishSpecies(id: "moonhorn", nameKey: L10n.source("月角刺尾鱼"), tier: 1, form: "fish", silhouette: "unicorn-tang", pattern: "bands", hue: 162, saturation: 0.65, lightness: 0.48, depth: 0.66, tail: 0.36, dorsal: 0.5, length: 15, electric: false),
        FishSpecies(id: "neoncleaner", nameKey: L10n.source("霓虹清洁隆头鱼"), tier: 1, form: "fish", silhouette: "wrasse", pattern: "stripes", hue: 206, saturation: 0.82, lightness: 0.56, depth: 0.32, tail: 0.26, dorsal: 0.25, length: 14, electric: false),
        FishSpecies(id: "mossback", nameKey: L10n.source("苔背小精灵"), tier: 1, form: "fish", silhouette: "catfish", pattern: "spots", hue: 96, saturation: 0.48, lightness: 0.42, depth: 0.44, tail: 0.28, dorsal: 0.55, length: 13, electric: false),
        FishSpecies(id: "sapphiredamsel", nameKey: L10n.source("蓝宝石雀鲷"), tier: 1, form: "fish", silhouette: "damsel", pattern: "gradient", hue: 222, saturation: 0.86, lightness: 0.52, depth: 0.58, tail: 0.34, dorsal: 0.42, length: 13, electric: false),
        FishSpecies(id: "banggai", nameKey: L10n.source("邦盖天竺鲷"), tier: 1, form: "fish", silhouette: "banner-cardinal", pattern: "bands", hue: 248, saturation: 0.32, lightness: 0.62, depth: 0.84, tail: 0.46, dorsal: 0.85, length: 14, electric: false),
        FishSpecies(id: "moonjelly", nameKey: L10n.source("海月水母"), tier: 1, form: "jellyfish", silhouette: "saucer-jelly", pattern: "spots", hue: 192, saturation: 0.78, lightness: 0.68, depth: 0.76, tail: 0.4, dorsal: 0.2, length: 14, electric: false),
        FishSpecies(id: "goldbutterfly", nameKey: L10n.source("黄金蝶鱼"), tier: 2, form: "fish", silhouette: "crown-butterfly", pattern: "bands", hue: 46, saturation: 0.92, lightness: 0.6, depth: 0.88, tail: 0.28, dorsal: 0.62, length: 16, electric: false),
        FishSpecies(id: "neonstreak", nameKey: L10n.source("霓虹灯鱼"), tier: 2, form: "fish", silhouette: "tetra", pattern: "stripes", hue: 168, saturation: 0.88, lightness: 0.52, depth: 0.46, tail: 0.32, dorsal: 0.45, length: 13, electric: false),
        FishSpecies(id: "blushingfire", nameKey: L10n.source("绯红雷达鱼"), tier: 2, form: "fish", silhouette: "fire-goby", pattern: "gradient", hue: 352, saturation: 0.85, lightness: 0.58, depth: 0.48, tail: 0.34, dorsal: 0.92, length: 15, electric: false),
        FishSpecies(id: "creampuff", nameKey: L10n.source("奶油河豚"), tier: 2, form: "fish", silhouette: "spiky-puffer", pattern: "spots", hue: 38, saturation: 0.42, lightness: 0.74, depth: 0.92, tail: 0.22, dorsal: 0.25, length: 13, electric: false),
        FishSpecies(id: "coralseahorse", nameKey: L10n.source("珊瑚海马"), tier: 2, form: "seahorse", silhouette: "spiny-seahorse", pattern: "bands", hue: 340, saturation: 0.78, lightness: 0.62, depth: 0.92, tail: 0.3, dorsal: 0.5, length: 14, electric: false),
        FishSpecies(id: "bandedkrait", nameKey: L10n.source("环纹海蛇"), tier: 2, form: "seasnake", silhouette: "krait", pattern: "bands", hue: 190, saturation: 0.58, lightness: 0.58, depth: 0.36, tail: 0.2, dorsal: 0.1, length: 19, electric: false),
        FishSpecies(id: "ambereel", nameKey: L10n.source("琥珀电鳗"), tier: 2, form: "eel", silhouette: "amber-eel", pattern: "gradient", hue: 39, saturation: 0.8, lightness: 0.51, depth: 0.32, tail: 0.2, dorsal: 0.28, length: 19, electric: true),
        FishSpecies(id: "royalgoldtail", nameKey: L10n.source("皇家金尾鲷"), tier: 3, form: "fish", silhouette: "lyretail", pattern: "gradient", hue: 274, saturation: 0.72, lightness: 0.54, depth: 0.62, tail: 0.48, dorsal: 0.5, length: 17, electric: false),
        FishSpecies(id: "skywing", nameKey: L10n.source("天翼飞鱼"), tier: 3, form: "fish", silhouette: "glider-fish", pattern: "plain", hue: 202, saturation: 0.68, lightness: 0.64, depth: 0.68, tail: 0.4, dorsal: 0.88, length: 18, electric: false),
        FishSpecies(id: "emberbarb", nameKey: L10n.source("余烬虎皮鱼"), tier: 3, form: "fish", silhouette: "rhomboid-barb", pattern: "bands", hue: 14, saturation: 0.88, lightness: 0.52, depth: 0.64, tail: 0.36, dorsal: 0.48, length: 15, electric: false),
        FishSpecies(id: "volteel", nameKey: L10n.source("蓝弧电鳗"), tier: 3, form: "eel", silhouette: "electric-eel", pattern: "stripes", hue: 198, saturation: 0.92, lightness: 0.56, depth: 0.38, tail: 0.2, dorsal: 0.5, length: 21, electric: true),
        FishSpecies(id: "crystaljelly", nameKey: L10n.source("樱花水晶水母"), tier: 3, form: "jellyfish", silhouette: "ribbon-jelly", pattern: "gradient", hue: 326, saturation: 0.84, lightness: 0.66, depth: 0.9, tail: 0.5, dorsal: 0.3, length: 16, electric: false),
        FishSpecies(id: "goldenmoorish", nameKey: L10n.source("黄金神像鱼"), tier: 4, form: "fish", silhouette: "moorish-idol", pattern: "bands", hue: 48, saturation: 0.9, lightness: 0.6, depth: 0.92, tail: 0.34, dorsal: 1, length: 18, electric: false),
        FishSpecies(id: "voidray", nameKey: L10n.source("虚空魔鬼鳐"), tier: 4, form: "ray", silhouette: "manta", pattern: "spots", hue: 266, saturation: 0.62, lightness: 0.42, depth: 0.84, tail: 0.45, dorsal: 0.3, length: 20, electric: false),
        FishSpecies(id: "auroraeel", nameKey: L10n.source("极光彩带鳗"), tier: 4, form: "eel", silhouette: "ribbon-eel", pattern: "stripes", hue: 152, saturation: 0.82, lightness: 0.52, depth: 0.36, tail: 0.2, dorsal: 0.6, length: 22, electric: false),
        FishSpecies(id: "goldenseahorse", nameKey: L10n.source("黄金海马"), tier: 4, form: "seahorse", silhouette: "leafy-seahorse", pattern: "spots", hue: 45, saturation: 0.92, lightness: 0.6, depth: 0.95, tail: 0.35, dorsal: 0.65, length: 16, electric: false),
        FishSpecies(id: "jadeturtle", nameKey: L10n.source("翡翠海龟"), tier: 4, form: "turtle", silhouette: "sea-turtle", pattern: "spots", hue: 140, saturation: 0.65, lightness: 0.46, depth: 0.78, tail: 0.2, dorsal: 0.25, length: 19, electric: false),
        FishSpecies(id: "prismkoi", nameKey: L10n.source("棱镜锦鲤"), tier: 5, form: "fish", silhouette: "veil-koi", pattern: "gradient", hue: 316, saturation: 0.78, lightness: 0.62, depth: 0.62, tail: 0.52, dorsal: 0.48, length: 22, electric: false),
        FishSpecies(id: "leviathanfry", nameKey: L10n.source("利维坦海龙"), tier: 5, form: "seasnake", silhouette: "sea-dragon", pattern: "spots", hue: 186, saturation: 0.78, lightness: 0.46, depth: 0.48, tail: 0.3, dorsal: 0.8, length: 24, electric: false),
        FishSpecies(id: "astraljelly", nameKey: L10n.source("星冕帝王水母"), tier: 5, form: "jellyfish", silhouette: "crown-jelly", pattern: "spots", hue: 278, saturation: 0.86, lightness: 0.62, depth: 0.95, tail: 0.55, dorsal: 0.5, length: 19, electric: false),
    ]
    static let byID = Dictionary(uniqueKeysWithValues: all.map { ($0.id, $0) })
    static func pool(tier: Int) -> [FishSpecies] { all.filter { $0.tier == tier } }
}

enum FishBalance {
    static let heartInterval: TimeInterval = 420
    static let parentCooldown: TimeInterval = 180
    static let growth: [TimeInterval] = [180, 300, 420, 600, 900, 1200]
    static let experience = [5, 10, 40, 160, 640, 2560]
    static let uses = [999, 5, 4, 3, 2, 2]
    static let levelThresholds = [0, 10, 60, 260, 760, 1760, 4760, 12760, 27760, 57760]
    static let matrix: [String: [Double]] = [
        "0+0": [100, 0, 0, 0, 0],
        "0+1": [90, 10, 0, 0, 0],
        "0+2": [76, 20, 4, 0, 0],
        "0+3": [48.9, 41.6, 9.5, 0, 0],
        "0+4": [37.7, 44.3, 15, 3, 0],
        "0+5": [0, 50.5, 43, 6.5, 0],
        "1+1": [76, 20, 4, 0, 0],
        "1+2": [48.9, 41.6, 9.5, 0, 0],
        "2+2": [37.7, 44.3, 15, 3, 0],
        "1+3": [37.7, 44.3, 15, 3, 0],
        "2+3": [0, 50.5, 43, 6.5, 0],
        "1+4": [0, 50.5, 43, 6.5, 0],
        "3+3": [0, 40.5, 47.5, 10, 2],
        "2+4": [0, 40.5, 47.5, 10, 2],
        "1+5": [0, 40.5, 47.5, 10, 2],
        "3+4": [0, 0, 52.1, 44.4, 3.5],
        "2+5": [0, 0, 52.1, 44.4, 3.5],
        "4+4": [0, 0, 43.7, 51.3, 5],
        "3+5": [0, 0, 43.7, 51.3, 5],
        "4+5": [0, 0, 0, 70, 30],
        "5+5": [0, 0, 0, 45, 55],
    ]
    static func level(exp: Int) -> Int { levelThresholds.filter { exp >= $0 }.count }
    static func totalExperience(tier: Int, grade: Int) -> Int {
        Int((Double(experience[tier]) * (1 + 0.25 * Double(grade - 1))).rounded())
    }
    static func gradeWeights(average: Double) -> [Double] {
        let bias = 0.35 * (average - 1)
        return [56.0, 26, 12, 5, 1].enumerated().map { max(0.01, $0.element * (1 + bias * Double($0.offset))) }
    }
}
