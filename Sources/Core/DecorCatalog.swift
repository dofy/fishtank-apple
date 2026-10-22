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
}

enum DecorCatalog {
    static let all: [AquariumDecor] = [
        .init(id: "kelp", nameKey: L10n.source("翠绿海草"), unlockLevel: 1, top: false, hue: 142, width: 58, height: 146),
        .init(id: "rocks", nameKey: L10n.source("礁石群"), unlockLevel: 1, top: false, hue: 205, width: 72, height: 34),
        .init(id: "shell", nameKey: L10n.source("珍珠扇贝"), unlockLevel: 1, top: false, hue: 330, width: 50, height: 32),
        .init(id: "fairylights", nameKey: L10n.source("七彩串灯"), unlockLevel: 1, top: true, hue: 46, width: 138, height: 38),
        .init(id: "coral", nameKey: L10n.source("鹿角珊瑚"), unlockLevel: 2, top: false, hue: 12, width: 76, height: 118),
        .init(id: "mushroom", nameKey: L10n.source("夜光海蕈"), unlockLevel: 2, top: false, hue: 174, width: 64, height: 78),
        .init(id: "starfish", nameKey: L10n.source("海星礁石"), unlockLevel: 3, top: false, hue: 26, width: 58, height: 38),
        .init(id: "starlamps", nameKey: L10n.source("星芒吊灯"), unlockLevel: 3, top: true, hue: 50, width: 108, height: 92),
        .init(id: "driftwood", nameKey: L10n.source("沉木拱枝"), unlockLevel: 4, top: false, hue: 28, width: 102, height: 68),
        .init(id: "anemone", nameKey: L10n.source("荧光海葵"), unlockLevel: 5, top: false, hue: 286, width: 64, height: 82),
        .init(id: "lanterns", nameKey: L10n.source("祭典灯笼"), unlockLevel: 5, top: true, hue: 14, width: 118, height: 58),
        .init(id: "arch", nameKey: L10n.source("海底石拱门"), unlockLevel: 6, top: false, hue: 198, width: 98, height: 126),
        .init(id: "crystal", nameKey: L10n.source("紫晶簇洞"), unlockLevel: 6, top: false, hue: 272, width: 70, height: 104),
        .init(id: "chest", nameKey: L10n.source("沉船宝箱"), unlockLevel: 7, top: false, hue: 40, width: 62, height: 44),
        .init(id: "jellylamps", nameKey: L10n.source("霓虹水母灯"), unlockLevel: 7, top: true, hue: 308, width: 114, height: 84),
        .init(id: "anchor", nameKey: L10n.source("古老船锚"), unlockLevel: 8, top: false, hue: 210, width: 72, height: 132),
        .init(id: "castle", nameKey: L10n.source("海底城堡"), unlockLevel: 9, top: false, hue: 38, width: 106, height: 156),
        .init(id: "statue", nameKey: L10n.source("深海神像"), unlockLevel: 10, top: false, hue: 175, width: 74, height: 142),
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
        .init(id: "first-friend", titleKey: L10n.source("初次相遇"), noteKey: L10n.source("发现第一种非初始鱼"), total: 1),
        .init(id: "tier-one", titleKey: L10n.source("珊瑚礁邻居"), noteKey: L10n.source("收齐全部 1★ 鱼种"), total: 7),
        .init(id: "jelly-family", titleKey: L10n.source("水母漫游"), noteKey: L10n.source("发现全部三种水母"), total: 3),
        .init(id: "grade-five", titleKey: L10n.source("一抹幻彩"), noteKey: L10n.source("首次发现品阶 5 的小鱼"), total: 1),
        .init(id: "variant-collector", titleKey: L10n.source("幻彩收藏家"), noteKey: L10n.source("发现 25 种非初始品阶外观"), total: 25),
        .init(id: "reef-explorer", titleKey: L10n.source("海洋朋友"), noteKey: L10n.source("发现全部 29 种海洋生物"), total: 29),
        .init(id: "reef-rookie", titleKey: L10n.source("礁石初探"), noteKey: L10n.source("发现 5 种非初始鱼"), total: 5),
        .init(id: "reef-naturalist", titleKey: L10n.source("海洋博物家"), noteKey: L10n.source("发现 15 种非初始鱼"), total: 15),
        .init(id: "rare-encounter", titleKey: L10n.source("深蓝来客"), noteKey: L10n.source("发现第一种 3★ 稀有鱼"), total: 1),
        .init(id: "legend-encounter", titleKey: L10n.source("传说之光"), noteKey: L10n.source("发现第一种 4★ 传说鱼"), total: 1),
        .init(id: "mythic-encounter", titleKey: L10n.source("神话回响"), noteKey: L10n.source("发现第一种 5★ 神话鱼"), total: 1),
        .init(id: "eel-family", titleKey: L10n.source("鳗舞海流"), noteKey: L10n.source("发现全部三种鳗鱼"), total: 3),
        .init(id: "color-palette", titleKey: L10n.source("五彩同游"), noteKey: L10n.source("集齐任一非初始鱼的五种品阶"), total: 5),
        .init(id: "variant-master", titleKey: L10n.source("幻彩宝库"), noteKey: L10n.source("发现 60 种非初始品阶外观"), total: 60),
    ]
    static let ids = Set(all.map(\.id))
}
