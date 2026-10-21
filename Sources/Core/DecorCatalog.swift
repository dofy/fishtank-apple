import Foundation

struct AquariumDecor: Identifiable, Equatable {
    let id: String
    let name: String
    let unlockLevel: Int
    let top: Bool
    let hue: Double
    let width: Double
    let height: Double
}

enum DecorCatalog {
    static let all: [AquariumDecor] = [
        .init(id: "kelp", name: "翠绿海草", unlockLevel: 1, top: false, hue: 142, width: 58, height: 146),
        .init(id: "rocks", name: "礁石群", unlockLevel: 1, top: false, hue: 205, width: 72, height: 34),
        .init(id: "shell", name: "珍珠扇贝", unlockLevel: 1, top: false, hue: 330, width: 50, height: 32),
        .init(id: "fairylights", name: "七彩串灯", unlockLevel: 1, top: true, hue: 46, width: 138, height: 38),
        .init(id: "coral", name: "鹿角珊瑚", unlockLevel: 2, top: false, hue: 12, width: 76, height: 118),
        .init(id: "mushroom", name: "夜光海蕈", unlockLevel: 2, top: false, hue: 174, width: 64, height: 78),
        .init(id: "starfish", name: "海星礁石", unlockLevel: 3, top: false, hue: 26, width: 58, height: 38),
        .init(id: "starlamps", name: "星芒吊灯", unlockLevel: 3, top: true, hue: 50, width: 108, height: 92),
        .init(id: "driftwood", name: "沉木拱枝", unlockLevel: 4, top: false, hue: 28, width: 102, height: 68),
        .init(id: "anemone", name: "荧光海葵", unlockLevel: 5, top: false, hue: 286, width: 64, height: 82),
        .init(id: "lanterns", name: "祭典灯笼", unlockLevel: 5, top: true, hue: 14, width: 118, height: 58),
        .init(id: "arch", name: "海底石拱门", unlockLevel: 6, top: false, hue: 198, width: 98, height: 126),
        .init(id: "crystal", name: "紫晶簇洞", unlockLevel: 6, top: false, hue: 272, width: 70, height: 104),
        .init(id: "chest", name: "沉船宝箱", unlockLevel: 7, top: false, hue: 40, width: 62, height: 44),
        .init(id: "jellylamps", name: "霓虹水母灯", unlockLevel: 7, top: true, hue: 308, width: 114, height: 84),
        .init(id: "anchor", name: "古老船锚", unlockLevel: 8, top: false, hue: 210, width: 72, height: 132),
        .init(id: "castle", name: "海底城堡", unlockLevel: 9, top: false, hue: 38, width: 106, height: 156),
        .init(id: "statue", name: "深海神像", unlockLevel: 10, top: false, hue: 175, width: 74, height: 142),
    ]
    static let byID = Dictionary(uniqueKeysWithValues: all.map { ($0.id, $0) })
}

struct Achievement: Identifiable {
    let id: String
    let title: String
    let note: String
    let total: Int
}

enum AchievementCatalog {
    static let all: [Achievement] = [
        .init(id: "first-friend", title: "初次相遇", note: "发现第一种非初始鱼", total: 1),
        .init(id: "tier-one", title: "珊瑚礁邻居", note: "收齐全部 1★ 鱼种", total: 7),
        .init(id: "jelly-family", title: "水母漫游", note: "发现全部三种水母", total: 3),
        .init(id: "grade-five", title: "一抹幻彩", note: "首次发现品阶 5 的小鱼", total: 1),
        .init(id: "variant-collector", title: "幻彩收藏家", note: "发现 25 种非初始品阶外观", total: 25),
        .init(id: "reef-explorer", title: "海洋朋友", note: "发现全部 29 种海洋生物", total: 29),
        .init(id: "reef-rookie", title: "礁石初探", note: "发现 5 种非初始鱼", total: 5),
        .init(id: "reef-naturalist", title: "海洋博物家", note: "发现 15 种非初始鱼", total: 15),
        .init(id: "rare-encounter", title: "深蓝来客", note: "发现第一种 3★ 稀有鱼", total: 1),
        .init(id: "legend-encounter", title: "传说之光", note: "发现第一种 4★ 传说鱼", total: 1),
        .init(id: "mythic-encounter", title: "神话回响", note: "发现第一种 5★ 神话鱼", total: 1),
        .init(id: "eel-family", title: "鳗舞海流", note: "发现全部三种鳗鱼", total: 3),
        .init(id: "color-palette", title: "五彩同游", note: "集齐任一非初始鱼的五种品阶", total: 5),
        .init(id: "variant-master", title: "幻彩宝库", note: "发现 60 种非初始品阶外观", total: 60),
    ]
    static let ids = Set(all.map(\.id))
}
