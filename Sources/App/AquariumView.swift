import SwiftUI
import SpriteKit
#if os(macOS)
import AppKit
#endif

private enum AquariumTab: String, CaseIterable, Identifiable {
    case tank = "鱼群", breed = "繁育", merge = "合成", decor = "装饰", book = "收藏", settings = "设置"
    var id: Self { self }
}

struct AquariumView: View {
    @ObservedObject private var localization = AppLocalization.shared
    @ObservedObject var store: AquariumStore
    var openAgentSettings: (() -> Void)? = nil
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reducedMotion
    @State private var scene = AquariumScene()
    @State private var isVisible = false
    #if os(iOS)
    @State private var immersive = false
    @State private var confirmObservationExit = false
    @State private var observationFeedback = ""
    #endif
    @State private var tab = AquariumTab.tank
    @State private var selected: [UUID] = []
    @State private var fishSort = FishSort.tier
    @State private var sortDescending = true
    @State private var page = 0
    @State private var tierFilter = -1
    @State private var search = ""
    @State private var releaseTarget: AquariumFish?
    @State private var confirmMerge = false
    @State private var showingMedals = false
    private let pageSize = 30
    private let gold = PixelTheme.gold
    private let columns = [GridItem(.adaptive(minimum: PixelTheme.metric(180, 232)), spacing: 12, alignment: .top)]
    private var hasModal: Bool { store.outcome != nil || releaseTarget != nil || confirmMerge }

    private var scenePaused: Bool {
        #if os(macOS)
        // AppKit hosts this view outside a SwiftUI Window scene.
        return !isVisible
        #else
        return !isVisible || scenePhase != .active
        #endif
    }

    private var managementContent: some View {
        GeometryReader { geometry in
        VStack(spacing: 0) {
            #if os(macOS)
            chrome
            #endif
            sharedInformation
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    pageContent(landscape: geometry.size.width > geometry.size.height,
                                width: max(1, geometry.size.width - 40))
                }
                .padding(.horizontal, 20).padding(.vertical, PixelTheme.metric(12, 20))
                .frame(maxWidth: managementWidth, alignment: .leading)
                .frame(maxWidth: .infinity)
            }
            .accessibilityIdentifier("aquarium.content")
            .id(tab)
            .onChange(of: tab) { _ in
                selected = []; page = 0; search = ""; tierFilter = -1
            }
            if tab == .breed { breedActionBar }
            if tab == .merge { mergeActionBar }
            navigationBar
        }
        .background(PixelTheme.panel)
        #if os(macOS)
        .modifier(PixelWindowFrame())
        #else
        .background(PixelTheme.panel.ignoresSafeArea())
        #endif
        }
    }

    private var managementWidth: CGFloat {
        #if os(macOS)
        return 1080
        #else
        return .infinity
        #endif
    }

    @ViewBuilder private func pageContent(landscape: Bool, width: CGFloat) -> some View {
        switch tab {
        case .tank:
            #if os(iOS)
            ipadTankContent(landscape: landscape, width: width)
            #else
            tankContent
            #endif
        case .breed: breedContent
        case .merge: mergeContent
        case .decor: decorContent
        case .book: collectionContent
        case .settings: settingsContent
        }
    }

    var body: some View {
        Group {
            #if os(iOS)
            if immersive { observationContent } else { managementContent }
            #else
            managementContent
            #endif
        }
        .font(PixelTheme.font())
        .lineSpacing(PixelTheme.metric(0, 4))
        .foregroundStyle(PixelTheme.text)
        .preferredColorScheme(.dark)
        .buttonStyle(PixelButtonStyle())
        .toggleStyle(PixelToggleStyle())
        .environment(\.pixelClick, { store.sound.play("click") })
        .tint(PixelTheme.green)
        .onAppear {
            isVisible = true
            store.refresh()
            scene.populate(with: store.state.tankFish)
            scene.syncExtras(from: store.state, at: store.now)
            scene.effect = { store.sound.play($0) }
            scene.reducedMotion = reducedMotion
            scene.decorationMoved = { id, x in store.moveDecoration(id, to: x) }
            store.sound.setSuspended(false)
        }
        .onDisappear { isVisible = false; store.save() }
        #if os(macOS)
        .onReceive(NotificationCenter.default.publisher(for: NSWindow.willCloseNotification)) { notification in
            if (notification.object as? NSWindow)?.title == L10n.text("Fishtank · 养成手册") { isVisible = false; store.save() }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSWindow.didBecomeKeyNotification)) { notification in
            if (notification.object as? NSWindow)?.title == L10n.text("Fishtank · 养成手册") { isVisible = true }
        }
        #endif
        .onReceive(NotificationCenter.default.publisher(for: .aquariumLanguageDidChange)) { _ in
            scene.refreshLocalizedFont()
        }
        .onReceive(store.$state) { state in
            scene.populate(with: state.tankFish)
            scene.syncExtras(from: state, at: store.now)
        }
        .onChange(of: reducedMotion) { scene.reducedMotion = $0 }
        .onChange(of: scenePhase) { phase in
            store.refresh()
            if phase != .active { store.save(); store.rescheduleReminders() }
            #if os(iOS)
            store.sound.setSuspended(phase != .active)
            #endif
        }
        .disabled(hasModal)
        .accessibilityHidden(hasModal)
        .overlay {
            if hasModal {
                ZStack {
                    Color.black.opacity(0.6).contentShape(Rectangle()).onTapGesture {}
                    if let outcome = store.outcome {
                        outcomeView(outcome).frame(maxWidth: 440).padding(16)
                    } else {
                        VStack(alignment: .leading, spacing: 20) {
                            Text(confirmMerge ? L10n.text("确认合成？") : L10n.text("确认放生？")).font(PixelTheme.font(24)).foregroundStyle(gold)
                            Text(confirmMerge ? L10n.text("会永久消耗所选的 10 条鱼，产出继承最高品阶。") : L10n.text("放生后无法找回，图鉴记录会保留。"))
                                .fixedSize(horizontal: false, vertical: true)
                            ViewThatFits(in: .horizontal) {
                                HStack(spacing: PixelTheme.metric(8, 6)) {
                                    confirmationCancelButton.fixedSize()
                                    Spacer(minLength: 0)
                                    confirmationSubmitButton.fixedSize()
                                }
                                VStack(alignment: .trailing, spacing: 12) {
                                    confirmationSubmitButton.fixedSize()
                                    confirmationCancelButton.fixedSize()
                                }.frame(maxWidth: .infinity, alignment: .trailing)
                            }
                        }.padding(24).frame(maxWidth: 420).pixelPanel(PixelTheme.panel).padding(16)
                    }
                }.font(PixelTheme.font()).foregroundStyle(PixelTheme.text)
                    .buttonStyle(PixelButtonStyle()).accessibilityAddTraits(.isModal)
            }
        }
    }

    private var confirmationCancelButton: some View {
        Button(L10n.text("取消")) { releaseTarget = nil; confirmMerge = false }
            .buttonStyle(PixelButtonStyle(compact: PixelTheme.isPad))
            .keyboardShortcut(.cancelAction)
    }

    private var confirmationSubmitButton: some View {
        Button(confirmMerge ? L10n.text("消耗材料并合成") : L10n.text("确认放生")) {
            if confirmMerge {
                if store.merge(selected) { selected = [] }
                confirmMerge = false
            } else if let fish = releaseTarget {
                store.release(fish.id); releaseTarget = nil
            }
        }.buttonStyle(PixelButtonStyle(primary: true, compact: PixelTheme.isPad))
    }

    #if os(iOS)
    private var observationContent: some View {
        ZStack {
            NativeAquariumView(scene: scene, paused: scenePaused || confirmObservationExit, fillsViewport: true,
                interactionEnabled: !confirmObservationExit, onSingleTap: { point in
                    store.sound.interact()
                    observationFeedback = scene.tapWater(at: point) ? L10n.text("已与鱼儿互动") : L10n.text("已投喂一颗鱼食")
                }, onDoubleTap: { confirmObservationExit = true })
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .accessibilityLabel(L10n.text("沉浸鱼缸，单击投喂或与鱼互动，双击退出预览"))
                .accessibilityIdentifier("aquarium.observation")
                .accessibilityValue(observationFeedback)
                .accessibilityAddTraits(.isButton)
                .accessibilityAction(named: L10n.text("投喂")) { store.sound.interact(); scene.feed(reducedMotion: reducedMotion) }
                .accessibilityAction(named: L10n.text("退出预览")) { confirmObservationExit = true }
                .accessibilityHidden(confirmObservationExit)
                .allowsHitTesting(!confirmObservationExit)
                .disabled(confirmObservationExit)
            if confirmObservationExit { observationExitDialog }
        }
        .ignoresSafeArea()
        .statusBarHidden()
        .persistentSystemOverlays(.hidden)
    }

    private var observationExitDialog: some View {
        ZStack {
            Color.black.opacity(0.6).contentShape(Rectangle()).onTapGesture {}
            VStack(alignment: .leading, spacing: 20) {
                Text(L10n.text("退出全屏预览？")).font(PixelTheme.font(24)).foregroundStyle(gold)
                Text(L10n.text("返回养成界面，鱼缸进度会保留。"))
                    .fixedSize(horizontal: false, vertical: true)
                HStack(spacing: 16) {
                    Button(L10n.text("继续观赏")) { confirmObservationExit = false }
                        .keyboardShortcut(.cancelAction)
                    Spacer(minLength: 0)
                    Button(L10n.text("退出预览")) { confirmObservationExit = false; immersive = false }
                        .buttonStyle(PixelButtonStyle(primary: true))
                        .keyboardShortcut(.defaultAction)
                }
            }.padding(24).frame(maxWidth: 420).pixelPanel(PixelTheme.panel).padding(20)
        }.accessibilityAddTraits(.isModal)
    }

    private func beginObservation() {
        store.sound.interact()
        confirmObservationExit = false
        observationFeedback = ""
        immersive = true
    }

    private var observationEntry: some View {
        Button(action: beginObservation) {
            HStack(spacing: 8) { PixelIcon("eye", color: PixelTheme.ink); Text(L10n.text("全屏预览")) }
        }.buttonStyle(PixelButtonStyle(primary: true))
            .accessibilityLabel(L10n.text("沉浸观赏鱼缸"))
    }

    @ViewBuilder private func ipadTankContent(landscape: Bool, width: CGFloat) -> some View {
        if landscape && width >= 860 {
            HStack(alignment: .top, spacing: 24) {
                VStack(alignment: .leading, spacing: 16) {
                    PixelAquariumPreview(scene: scene, store: store, paused: scenePaused)
                    ipadTankActions
                }.frame(width: min(360, width * 0.3))
                tankInventory.frame(maxWidth: .infinity)
            }
        } else {
            VStack(alignment: .leading, spacing: 20) {
                if width >= 600 {
                    HStack(alignment: .center, spacing: 24) {
                        PixelAquariumPreview(scene: scene, store: store, paused: scenePaused)
                            .frame(width: min(480, width * 0.58))
                        ipadTankActions.frame(maxWidth: .infinity, alignment: .leading)
                    }
                } else {
                    PixelAquariumPreview(scene: scene, store: store, paused: scenePaused)
                    ipadTankActions
                }
                tankInventory
            }
        }
    }

    private var ipadTankActions: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(L10n.text("我的鱼缸")).font(PixelTheme.font(24)).foregroundStyle(gold)
            Text(L10n.text("装饰 \(store.state.decorations.count)/\(store.state.capacity) · 勋章 \(store.state.displayedAchievements.count) 枚"))
                .foregroundStyle(PixelTheme.muted)
            observationEntry
            Button(L10n.text("布置鱼缸")) { tab = .decor }
            Text(L10n.text("预览中单击投喂或与鱼互动，双击确认退出。"))
                .font(PixelTheme.captionFont()).foregroundStyle(PixelTheme.muted).lineSpacing(6).fixedSize(horizontal: false, vertical: true)
        }
    }
    #endif

    private var sharedInformation: some View {
        VStack(alignment: .leading, spacing: PixelTheme.metric(6, 10)) {
            #if os(macOS)
            compactHeading
            #else
            heading
            #endif
            Text(store.message)
                .font(PixelTheme.captionFont()).foregroundStyle(gold).lineLimit(PixelTheme.isPad ? 2 : 1).lineSpacing(PixelTheme.metric(0, 4))
                .frame(maxWidth: .infinity, alignment: .leading)
                .frame(height: PixelTheme.metric(20, 44), alignment: .topLeading)
                #if os(macOS)
                .help(store.message)
                #endif
                .accessibilityAddTraits(.updatesFrequently)
            if let title = store.achievementToast {
                HStack {
                    PixelIcon("medal", color: gold)
                    Text(L10n.text("获得勋章：") + title)
                    Spacer()
                    Button(L10n.text("收好")) { store.achievementToast = nil }
                }.padding(12).pixelPanel(PixelTheme.panel, selected: true)
            }
        }.padding(.horizontal, 20).padding(.top, PixelTheme.metric(8, 12)).padding(.bottom, PixelTheme.metric(4, 0))
            .frame(maxWidth: managementWidth, alignment: .leading).frame(maxWidth: .infinity)
            #if os(macOS)
            .overlay(alignment: .bottom) {
                Rectangle().fill(PixelTheme.highlight.opacity(0.55)).frame(height: 1)
                    .allowsHitTesting(false).accessibilityHidden(true)
            }
            #endif
            .accessibilityElement(children: .contain).accessibilityIdentifier("aquarium.status")
    }

    #if os(macOS)
    private var compactHeading: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 12) {
                HStack(spacing: 8) {
                    PixelIcon("fish", color: gold)
                    Text(L10n.text("像素海洋")).font(PixelTheme.font(18)).foregroundStyle(gold)
                        .accessibilityIdentifier("aquarium.heading")
                    Text("Lv.\(store.state.level)").foregroundStyle(PixelTheme.muted)
                }.fixedSize(horizontal: true, vertical: false)
                Spacer(minLength: 16)
                compactExperience
            }
            HStack(spacing: 16) { heartSummary; collectionSummary; tankSummary; Spacer(minLength: 0) }
        }
    }

    private var compactExperience: some View {
        Group {
            if let next = store.state.nextLevelExp {
                HStack(spacing: 8) {
                    PixelMeter(value: Double(store.state.exp - FishBalance.levelThresholds[store.state.level - 1]),
                               total: Double(next - FishBalance.levelThresholds[store.state.level - 1])).frame(width: 120)
                    Text("\(store.state.exp) / \(next)").font(PixelTheme.captionFont()).foregroundStyle(PixelTheme.muted)
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(L10n.text("累计经验 \(store.state.exp) / \(next) · 下一级增加一个展示位"))
                .help(L10n.text("累计经验 \(store.state.exp) / \(next) · 下一级增加一个展示位"))
            } else {
                Text(L10n.text("鱼缸已满级 · 累计经验 \(store.state.exp)"))
                    .font(PixelTheme.captionFont()).foregroundStyle(PixelTheme.muted)
            }
        }.fixedSize(horizontal: true, vertical: false)
    }
    #endif

    private var heading: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                HStack(spacing: 10) { PixelIcon("fish", color: gold); Text(L10n.text("像素海洋")).accessibilityIdentifier("aquarium.heading").font(PixelTheme.font(24)).foregroundStyle(gold) }
                Spacer()
                Text("Lv.\(store.state.level)").font(PixelTheme.font(24))
            }
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 18) { heartSummary; collectionSummary; tankSummary }
                VStack(alignment: .leading, spacing: 6) { heartSummary; collectionSummary; tankSummary }
            }
            if let next = store.state.nextLevelExp {
                PixelMeter(value: Double(store.state.exp - FishBalance.levelThresholds[store.state.level - 1]),
                             total: Double(next - FishBalance.levelThresholds[store.state.level - 1]))
                Text(L10n.text("累计经验 \(store.state.exp) / \(next) · 下一级增加一个展示位"))
                    .font(PixelTheme.captionFont()).foregroundStyle(PixelTheme.muted)
            } else { Text(L10n.text("鱼缸已满级 · 累计经验 \(store.state.exp)")).font(PixelTheme.captionFont()).foregroundStyle(PixelTheme.muted) }
        }
    }

    private var heartSummary: some View {
        HStack(spacing: 6) {
            HStack(spacing: 2) {
                ForEach(0..<5, id: \.self) { index in
                    PixelIcon(index < store.state.hearts ? "heart" : "heartEmpty", color: index < store.state.hearts ? PixelTheme.pink : PixelTheme.muted)
                }
            }
            Text(store.state.hearts < 5 ? L10n.text("\(countdown(store.state.nextHeartAt)) 后恢复") : L10n.text("已回满"))
                .font(PixelTheme.captionFont()).foregroundStyle(PixelTheme.pink)
        }.accessibilityElement(children: .ignore)
            .accessibilityLabel(L10n.text("繁育爱心剩余 \(store.state.hearts) 颗，共 5 颗"))
            .accessibilityIdentifier("aquarium.hearts")
    }
    private var collectionSummary: some View { Text(L10n.text("鱼种 \(store.state.discovered.count)/29")).font(PixelTheme.captionFont()) }
    private var tankSummary: some View { Text(L10n.text("展示 \(store.state.tankIDs.count)/\(store.state.capacity) · 背包 \(store.state.fish.count)")).font(PixelTheme.captionFont()).foregroundStyle(PixelTheme.muted) }

    private var tankContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            GeometryReader { geometry in
                HStack(spacing: 24) {
                    PixelAquariumPreview(scene: scene, store: store, paused: scenePaused)
                        .frame(width: min(192, geometry.size.width), height: min(192, geometry.size.width) * 9 / 16)
                        #if os(macOS)
                        .help(L10n.text("工作间隙，\n看看这一小缸海。"))
                        #endif
                    if geometry.size.width > 650 {
                        VStack(alignment: .leading, spacing: 16) {
                            Text(L10n.text("装饰 \(store.state.decorations.count)/\(store.state.capacity) · 勋章 \(store.state.displayedAchievements.count) 枚"))
                                .foregroundStyle(PixelTheme.muted)
                            Button(L10n.text("布置鱼缸")) { tab = .decor }
                        }
                        Spacer(minLength: 0)
                    }
                }
            }.frame(height: 108)
            tankInventory
        }
    }

    private var tankInventory: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text(L10n.text("我的鱼群")).font(PixelTheme.font(PixelTheme.metric(18, 24)))
                Spacer()
                Button { scene.feed(reducedMotion: reducedMotion); store.sound.play("feed"); store.message = L10n.text("撒下鱼食，看小鱼慢慢追过来。") } label: {
                    HStack(spacing: 6) { PixelIcon("food"); Text(L10n.text("投喂")) }
                }
                    .buttonStyle(PixelButtonStyle())
            }
            filters
            fishSorting
            fishGrid(visibleFish)
        }
    }

    private enum FishSort: String, CaseIterable {
        case tier = "星级", grade = "品阶", uses = "繁育次数", displayed = "展示", acquired = "获得时间"
    }

    private var fishSortDirection: some View {
        Button(sortDescending ? L10n.text("降序") : L10n.text("升序")) { sortDescending.toggle(); page = 0 }
            .accessibilityIdentifier("fish.sort.direction")
    }
    private var stackedFishSorting: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(L10n.text("鱼群排序")).foregroundStyle(gold)
                Spacer()
                fishSortDirection
            }
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 8) { fishSortButtons }
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: L10n.language == .english ? 2 : 3), spacing: 8) { fishSortButtons }
            }
        }
    }
    private var fishSorting: some View {
        #if os(macOS)
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 12) {
                Text(L10n.text("鱼群排序")).foregroundStyle(gold).fixedSize()
                HStack(spacing: 8) { fishSortButtons }.fixedSize(horizontal: true, vertical: false)
                Spacer(minLength: 0)
                fishSortDirection.fixedSize()
            }
            stackedFishSorting
        }
        #else
        stackedFishSorting
        #endif
    }

    private var fishSortButtons: some View {
        ForEach(FishSort.allCases, id: \.self) { order in
            Button(L10n.key(order.rawValue)) { fishSort = order; page = 0 }
                .buttonStyle(PixelButtonStyle(primary: fishSort == order))
                .accessibilityIdentifier("fish.sort." + String(describing: order))
                .accessibilityValue(fishSort == order ? L10n.text("已选中") : L10n.text("未选中"))
        }
    }

    private func sortValue(_ fish: AquariumFish) -> Double {
        switch fishSort {
        case .tier: return Double(fish.tier)
        case .grade: return Double(fish.grade)
        case .uses: return fish.tier == 0 ? .infinity : Double(fish.uses)
        case .displayed: return store.state.tankIDs.contains(fish.id) ? 1 : 0
        case .acquired: return fish.bornAt.timeIntervalSince1970
        }
    }

    private var breedContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(L10n.text("两条亲代，一次新的相遇。")).font(PixelTheme.font(PixelTheme.metric(18, 24)))
            Text(L10n.text("每次消耗 1 颗爱心。初始鱼繁育后冷却 3 分钟；其他鱼消耗繁育次数。锁定不影响繁育。"))
                .font(PixelTheme.font()).lineSpacing(4).foregroundStyle(PixelTheme.muted)
            VStack(alignment: .leading, spacing: 12) {
                if PixelTheme.isPad { Text(L10n.text("亲代筛选")).foregroundStyle(gold) }
                filters
            }.frame(maxWidth: .infinity, alignment: .leading).padding(14).pixelPanel()
            ViewThatFits(in: .horizontal) {
                HStack { breedParentHeading; Spacer(minLength: 12); breedSelectionTools }
                VStack(alignment: .leading, spacing: 8) { breedParentHeading; breedSelectionTools }
            }
            recommendationReadout.font(PixelTheme.captionFont()).padding(12).pixelPanel()
            fishGrid(visibleFish)
        }
    }

    private var breedParentHeading: some View {
        HStack(spacing: 8) {
            Text(L10n.text("选择亲代")).foregroundStyle(gold)
            Text(L10n.text("可繁育 \(visibleFish.filter { $0.canBreed(at: store.now) }.count) 条")).foregroundStyle(PixelTheme.muted)
        }.fixedSize(horizontal: true, vertical: false)
    }

    private var breedSelectionTools: some View {
        HStack(spacing: 8) {
            Button(L10n.text("推荐配对")) { selected = store.state.recommendedPair(at: store.now) }
                .disabled(store.state.breedRecommendation(at: store.now).parentIDs.count < 2)
            Button(L10n.text("清空")) { selected = [] }.disabled(selected.isEmpty)
        }.buttonStyle(PixelButtonStyle()).fixedSize(horizontal: true, vertical: false)
    }

    private var recommendationReadout: some View {
        let r = store.state.breedRecommendation(at: store.now)
        return VStack(alignment: .leading, spacing: 4) {
            Text(Set(selected) == Set(r.parentIDs) && !selected.isEmpty ? L10n.text("推荐组合（已选）") : L10n.text("推荐组合（未选用）"))
            switch r.reason {
            case .newSpecies: Text(L10n.text("优先补新鱼种"))
            case .newVariant:
                Text(L10n.text("优先补品阶外观"))
                if r.missingSpeciesCount > 0 { Text(L10n.text("现有可用亲代暂时无法获得缺失鱼种。")) }
            case .complete: Text(L10n.text("普通图鉴已收齐，推荐高星亲代。"))
            case .unreachable: Text(L10n.text("现有可用亲代无法补齐缺失图鉴，请等待成年或解除锁定。"))
            case .unavailable: Text(L10n.text("需要两条未锁定的成年亲代。"))
            }
            if r.reason == .newSpecies || r.reason == .newVariant {
                Text(L10n.text("新鱼种 \(recommendationPercent(r.newSpeciesProbability)) · 新外观 \(recommendationPercent(r.newVariantProbability))"))
                Text(L10n.text("概率仅对应推荐组合的单次繁育，不保证获得。"))
            }
        }.foregroundStyle(PixelTheme.muted).fixedSize(horizontal: false, vertical: true)
            .accessibilityIdentifier("breed.recommendation")
    }
    private func recommendationPercent(_ value: Double) -> String {
        if value > 0 && value < 0.001 { return L10n.text("低于 0.1%") }
        return (value * 100).formatted(.number.precision(.fractionLength(1))) + "%"
    }

    private var breedReadout: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(L10n.text("已选择 \(selected.count)/2 条亲代")).foregroundStyle(PixelTheme.text)
            if selected.count == 2,
               let a = store.state.fish.first(where: { $0.id == selected[0] }),
               let b = store.state.fish.first(where: { $0.id == selected[1] }),
               let odds = FishBalance.matrix["\(min(a.tier, b.tier))+\(max(a.tier, b.tier))"] {
                Text(L10n.text("后代概率：") + odds.enumerated().filter { $0.element > 0 }.map {
                    "\($0.offset + 1)★ \($0.element.formatted(.number.precision(.fractionLength(0...1))))%"
                }.joined(separator: "  ")).foregroundStyle(gold)
                    .accessibilityIdentifier("breed.odds")
            } else {
                Text(PixelTheme.isPad ? L10n.text("点击鱼卡或推荐配对，选满 2 条后繁育。") : L10n.text("请选择两条不同的亲代鱼。"))
                    .foregroundStyle(PixelTheme.muted)
            }
        }.font(PixelTheme.captionFont()).lineSpacing(4).fixedSize(horizontal: false, vertical: true)
    }

    private var breedConfirmButton: some View {
        Button {
            if store.breed(selected) { selected = [] }
        } label: {
            HStack(spacing: 8) { PixelIcon("heart", color: PixelTheme.ink); Text(L10n.text("开始繁育 · 1 爱心")) }
        }.buttonStyle(PixelButtonStyle(primary: true))
            .disabled(selected.count != 2 || store.state.hearts == 0 || !selected.allSatisfy { id in
                store.state.fish.first { $0.id == id }?.canBreed(at: store.now) == true
            }).fixedSize(horizontal: true, vertical: false)
    }

    private var breedActionBar: some View {
        selectionActionBar(readout: breedReadout, action: breedConfirmButton)
    }

    private var mergeContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(L10n.text("十条小鱼，汇成新的星光。")).font(PixelTheme.font(PixelTheme.metric(18, 24)))
            Text(L10n.text("消耗 10 条 1–4 星鱼，继承最高品阶；同星材料必定升一星。混星时，每条材料为自己的星级 +1 投一票。初始鱼、5 星鱼和锁定鱼不可选。"))
                .font(PixelTheme.font()).lineSpacing(4).foregroundStyle(PixelTheme.muted)
            VStack(alignment: .leading, spacing: 12) {
                Text(L10n.text("材料筛选")).foregroundStyle(gold)
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 12) { mergeFilterToggles; Spacer(minLength: 0) }
                    VStack(alignment: .leading, spacing: 8) { mergeFilterToggles }
                }
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 12) { Text(L10n.text("材料星级")).foregroundStyle(PixelTheme.muted); mergeTierButtons; Spacer(minLength: 0) }
                    VStack(alignment: .leading, spacing: 8) { Text(L10n.text("材料星级")).foregroundStyle(PixelTheme.muted); mergeTierButtons }
                }
            }.frame(maxWidth: .infinity, alignment: .leading).padding(14).pixelPanel()
            ViewThatFits(in: .horizontal) {
                HStack {
                    mergeMaterialHeading
                    Spacer(minLength: 12)
                    mergeSelectionTools
                }
                VStack(alignment: .leading, spacing: 8) { mergeMaterialHeading; mergeSelectionTools }
            }
            fishGrid(visibleFish)
        }
    }

    private var mergeFilterToggles: some View {
        Group {
            Toggle(L10n.text("只选繁育次数耗尽的鱼"), isOn: mergeBinding(\.zeroUsesOnly)).fixedSize(horizontal: true, vertical: false)
            Toggle(L10n.text("排除正在鱼缸展示的鱼"), isOn: mergeBinding(\.excludeInTank)).fixedSize(horizontal: true, vertical: false)
        }
    }

    private var mergeTierButtons: some View {
        HStack(spacing: 8) {
            ForEach(1...4, id: \.self) { tier in
                Button("\(tier)★") {
                    var preferences = store.state.mergePreferences
                    if preferences.tiers.contains(tier) { preferences.tiers.remove(tier) } else { preferences.tiers.insert(tier) }
                    store.setMergePreferences(preferences); selected = []; page = 0
                }.buttonStyle(PixelButtonStyle(primary: store.state.mergePreferences.tiers.contains(tier), compact: true, fixedWidth: PixelTheme.filterButtonWidth))
                    .accessibilityValue(store.state.mergePreferences.tiers.contains(tier) ? L10n.text("已选中") : L10n.text("未选中"))
            }
        }.fixedSize(horizontal: true, vertical: false)
    }

    private var mergeMaterialHeading: some View {
        HStack(spacing: 8) {
            Text(L10n.text("选择材料")).foregroundStyle(gold)
            Text(L10n.text("可选 \(visibleFish.count) 条")).foregroundStyle(PixelTheme.muted)
        }.fixedSize(horizontal: true, vertical: false)
    }

    private var mergeSelectionTools: some View {
        HStack(spacing: 8) {
            Button(L10n.text("自动选材")) { selected = store.state.autoMergeSelection() }
                .help(L10n.text("优先同星材料；选择 1 条最高品阶与 9 条低消耗材料。"))
            Button(L10n.text("清空")) { selected = [] }.disabled(selected.isEmpty)
        }.buttonStyle(PixelButtonStyle()).fixedSize(horizontal: true, vertical: false)
    }

    private var mergeReadout: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(L10n.text("已选择 \(selected.count)/10 条材料")).foregroundStyle(PixelTheme.text)
            if selected.isEmpty {
                Text(PixelTheme.isPad ? L10n.text("点击鱼卡或自动选材，凑齐 10 条后合成。") : L10n.text("合成需要 10 条不同的鱼。"))
                    .foregroundStyle(PixelTheme.muted)
            } else {
                let picked = store.state.fish.filter { selected.contains($0.id) }
                let odds = Dictionary(grouping: picked, by: { $0.tier + 1 })
                Text(L10n.text("产出概率：") + odds.keys.sorted().map { "\($0)★ \(odds[$0]!.count * 100 / max(1, picked.count))%" }.joined(separator: "  ")
                     + L10n.text(" · 继承品阶 \(picked.map(\.grade).max() ?? 1)"))
                    .foregroundStyle(gold)
            }
        }.font(PixelTheme.captionFont()).lineSpacing(4).fixedSize(horizontal: false, vertical: true)
    }

    private var mergeConfirmButton: some View {
        Button { confirmMerge = true } label: {
            HStack(spacing: 8) { PixelIcon("merge", color: PixelTheme.ink); Text(L10n.text("合成新鱼 · 消耗 10 条")) }
        }.buttonStyle(PixelButtonStyle(primary: true)).disabled(selected.count != 10)
            .fixedSize(horizontal: true, vertical: false)
    }

    private var mergeActionBar: some View {
        selectionActionBar(readout: mergeReadout, action: mergeConfirmButton)
    }

    private func selectionActionBar<Readout: View, Action: View>(readout: Readout, action: Action) -> some View {
        Group {
            #if os(macOS)
            HStack(spacing: 16) {
                readout.frame(maxWidth: .infinity, alignment: .leading)
                action
            }.padding(.horizontal, 12).padding(.vertical, 8)
            #else
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 16) { readout.frame(minWidth: 180, alignment: .leading); Spacer(minLength: 16); action }
                VStack(alignment: .leading, spacing: 10) { readout; HStack { Spacer(minLength: 0); action } }
            }.padding(12)
            #endif
        }.frame(maxWidth: .infinity, alignment: .leading)
            .background(PixelTheme.panel)
            .overlay(alignment: .top) { Rectangle().fill(PixelTheme.highlight.opacity(0.25)).frame(height: 1) }
    }

    private func mergeBinding(_ key: WritableKeyPath<MergePreferences, Bool>) -> Binding<Bool> {
        Binding(get: { store.state.mergePreferences[keyPath: key] }, set: { value in
            var preferences = store.state.mergePreferences
            preferences[keyPath: key] = value
            store.setMergePreferences(preferences); selected = []; page = 0
        })
    }

    private var fishSearch: some View {
        TextField(L10n.text("搜索鱼种"), text: $search).textFieldStyle(.plain)
            .padding(12).background(PixelTheme.ink).pixelPanel(PixelTheme.ink)
            .onChange(of: search) { _ in page = 0 }
    }
    private var stackedFilters: some View {
        VStack(alignment: .leading, spacing: 10) {
            fishSearch
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 6) { tierButtons }
                LazyVGrid(columns: [GridItem(.adaptive(minimum: PixelTheme.filterButtonWidth), spacing: 6)], alignment: .leading, spacing: 6) { tierButtons }
            }
        }
    }
    private var filters: some View {
        #if os(macOS)
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 12) {
                fishSearch.frame(minWidth: 160)
                HStack(spacing: 6) { tierButtons }.fixedSize(horizontal: true, vertical: false)
            }
            stackedFilters
        }
        #else
        stackedFilters
        #endif
    }
    private var tierButtons: some View {
        ForEach(-1...5, id: \.self) { tier in
            Button(tier == -1 ? L10n.text("全部") : tier == 0 ? L10n.text("初始") : "\(tier)★") { tierFilter = tier; page = 0 }
                .buttonStyle(PixelButtonStyle(primary: tierFilter == tier, compact: true, fixedWidth: PixelTheme.filterButtonWidth))
        }
    }

    private var visibleFish: [AquariumFish] {
        let list = tab == .merge ? store.state.mergeCandidates : store.state.fish
        return list.filter { (tierFilter < 0 || $0.tier == tierFilter) && (search.isEmpty || $0.name.localizedCaseInsensitiveContains(search)) }
            .sorted {
                if tab == .tank && sortValue($0) != sortValue($1) {
                    return sortDescending ? sortValue($0) > sortValue($1) : sortValue($0) < sortValue($1)
                }
                if tab == .breed && $0.canBreed(at: store.now) != $1.canBreed(at: store.now) { return $0.canBreed(at: store.now) }
                if $0.tier != $1.tier { return $0.tier > $1.tier }
                if $0.grade != $1.grade { return $0.grade > $1.grade }
                return $0.bornAt < $1.bornAt
            }
    }

    @ViewBuilder
    private func fishGrid(_ fish: [AquariumFish]) -> some View {
        let pageCount = max(1, (fish.count + pageSize - 1) / pageSize)
        let currentPage = min(page, pageCount - 1)
        if fish.isEmpty {
            Text(tab == .merge ? L10n.text("没有符合筛选条件的材料鱼。可关闭“只选繁育次数耗尽”或调整星级。") : L10n.text("没有符合条件的鱼。"))
                .foregroundStyle(PixelTheme.muted).padding(.vertical, 30)
        } else {
            LazyVGrid(columns: columns, spacing: 12) {
                ForEach(Array(fish.dropFirst(currentPage * pageSize).prefix(pageSize))) { item in fishCard(item) }
            }
        }
        if pageCount > 1 {
            HStack {
                Button(L10n.text("上一页")) { page = currentPage - 1 }.disabled(currentPage == 0)
                Spacer()
                Text(L10n.text("\(currentPage + 1) / \(pageCount) · \(fish.count) 条"))
                Spacer()
                Button(L10n.text("下一页")) { page = currentPage + 1 }.disabled(currentPage == pageCount - 1)
            }.buttonStyle(PixelButtonStyle())
        }
    }

    private func fishCard(_ fish: AquariumFish) -> some View {
        let isSelected = selected.contains(fish.id)
        let inTank = store.state.tankIDs.contains(fish.id)
        return ZStack(alignment: .bottomTrailing) {
            Button {
                if tab == .tank { store.toggleTank(fish.id) }
                else {
                    if isSelected { selected.removeAll { $0 == fish.id } }
                    else if selected.count < (tab == .breed ? 2 : 10) { selected.append(fish.id) }
                    store.sound.play("click")
                }
            } label: {
                VStack(alignment: .leading, spacing: PixelTheme.metric(8, 10)) {
                    portrait(fish.species, grade: fish.grade).padding(6).frame(height: 68).frame(maxWidth: .infinity)
                        .background(PixelSpecimenWell())
                    Text(fish.name).font(PixelTheme.font()).lineLimit(PixelTheme.isPad ? 1 : 2)
                        .frame(maxWidth: .infinity, alignment: .leading).frame(height: PixelTheme.metric(L10n.language == .english ? 38 : 32, 24), alignment: .topLeading)
                    Text(L10n.text("\(fish.tier == 0 ? L10n.text("初始鱼") : String(repeating: "★", count: fish.tier)) · 品阶 \(fish.grade)"))
                        .font(PixelTheme.captionFont()).foregroundStyle(gold)
                    breedingHearts(fish)
                    Text(status(fish)).font(PixelTheme.captionFont()).foregroundStyle(fish.canBreed(at: store.now) ? PixelTheme.green : PixelTheme.muted)
                        .lineLimit(1)
                    Spacer(minLength: tab == .tank ? PixelTheme.metric(40, 52) : 0)
                }.padding(PixelTheme.metric(14, 16)).frame(maxWidth: .infinity, alignment: .leading)
                    .frame(height: tab == .tank ? PixelTheme.metric(280, 300) : PixelTheme.metric(220, 248), alignment: .topLeading)
                    .pixelCard(displayed: tab == .tank && inTank, selected: isSelected)
                    .overlay(alignment: .topLeading) { if isSelected { PixelIcon("check", color: gold).padding(8) } }
                    .contentShape(Rectangle())
            }.buttonStyle(.plain).disabled(tab == .breed && !fish.canBreed(at: store.now))
                .accessibilityIdentifier("fish.card." + fish.id.uuidString)
                .accessibilityLabel(L10n.text("\(tab == .tank ? (inTank ? L10n.text("收回") : L10n.text("放入")) : (isSelected ? L10n.text("取消选择") : L10n.text("选择")))\(fish.name)，\(fish.tier) 星，品阶 \(fish.grade)"))
                .accessibilityValue(tab == .tank ? (inTank ? L10n.text("展示中") : L10n.text("未展示")) : (isSelected ? L10n.text("已选择") : L10n.text("未选择")))
            if tab == .tank {
                HStack(spacing: 8) {
                    Spacer(minLength: 0)
                    Button { store.setLocked(fish.id, !fish.locked) } label: { PixelIcon(fish.locked ? "lock" : "unlock") }
                        .accessibilityLabel(fish.locked ? L10n.text("解锁\(fish.name)") : L10n.text("锁定\(fish.name)"))
                    if fish.tier > 0 {
                        Button(L10n.text("放生"), role: .destructive) { releaseTarget = fish }.disabled(fish.locked)
                    }
                }.buttonStyle(PixelButtonStyle(compact: true)).padding(14)
            }
        }.overlay(alignment: .topTrailing) { if inTank { displayedBadge.padding(8).allowsHitTesting(false) } }
    }

    private var displayedBadge: some View {
        HStack(spacing: 4) {
            PixelIcon("eye", color: PixelTheme.ink)
            Text(L10n.text("展示中")).font(PixelTheme.captionFont()).foregroundStyle(PixelTheme.ink)
        }.padding(.horizontal, 6).padding(.vertical, 2)
            .background(PixelOutline().fill(PixelTheme.green))
            .overlay(PixelOutline().stroke(PixelTheme.ink, lineWidth: 1))
            .accessibilityElement(children: .combine)
            .accessibilityIdentifier("fish.displayed")
    }

    private func breedingHearts(_ fish: AquariumFish) -> some View {
        HStack(spacing: 6) {
            Text(L10n.text("繁育")).foregroundStyle(PixelTheme.muted)
            HStack(spacing: 2) {
                if fish.tier == 0 {
                    PixelIcon("heart", color: PixelTheme.pink)
                    PixelIcon("infinity", color: PixelTheme.pink)
                } else {
                    ForEach(0..<min(fish.maxUses, 6), id: \.self) { index in
                        PixelIcon(index < fish.uses ? "heart" : "heartEmpty", color: index < fish.uses ? PixelTheme.pink : PixelTheme.muted)
                    }
                    if fish.maxUses > 6 { Text("…").foregroundStyle(PixelTheme.muted) }
                }
            }
        }.font(PixelTheme.captionFont()).frame(height: PixelTheme.metric(16, 24))
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(fish.tier == 0 ? L10n.text("繁育次数无限") : L10n.text("剩余繁育 \(fish.uses) 次，共 \(fish.maxUses) 次"))
            .help(fish.tier == 0 ? L10n.text("繁育次数无限") : L10n.text("实心爱心为剩余次数，空心爱心为已用次数。"))
    }

    private var bookContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(L10n.text("海洋图鉴")).font(PixelTheme.font(24))
            Text(L10n.text("已发现 \(store.state.discovered.count)/29 种 · 品阶外观 \(store.state.discoveredVariants.count)/\(FishCatalog.all.reduce(0) { $0 + ($1.tier == 0 ? 1 : 5) })。放生和合成不会抹去收集记录。"))
                .font(PixelTheme.font()).foregroundStyle(PixelTheme.muted)
            LazyVGrid(columns: columns, spacing: 12) {
                ForEach(FishCatalog.all) { species in
                    let found = store.state.discovered.contains(species.id)
                    let displayedCount = store.state.tankFish.filter { $0.speciesID == species.id }.count
                    VStack(alignment: .leading, spacing: 10) {
                        portrait(species, grade: 1).frame(height: 68).frame(maxWidth: .infinity)
                            .opacity(found ? 1 : 0.18).accessibilityHidden(!found)
                        Text(found ? species.name : L10n.text("未发现的\(species.tier)星鱼")).font(PixelTheme.font())
                        Text(species.tier == 0 ? L10n.text("初始鱼") : String(repeating: "★", count: species.tier))
                            .font(PixelTheme.font()).foregroundStyle(gold)
                        HStack(spacing: 5) {
                            ForEach(1...(species.tier == 0 ? 1 : 5), id: \.self) { grade in
                                let owned = store.state.discoveredVariants.contains("\(species.id):\(grade)")
                                VStack(spacing: 3) {
                                    portrait(species, grade: grade).frame(height: 20).opacity(owned ? 1 : 0.12)
                                    Text("\(grade)").font(PixelTheme.font())
                                }.accessibilityLabel(L10n.text("品阶 \(grade)，\(owned ? L10n.text("已收集") : L10n.text("未收集"))"))
                            }
                        }
                        HStack(spacing: 4) {
                            Text(L10n.text("现有 \(store.state.fish.filter { $0.speciesID == species.id }.count) 条")).foregroundStyle(PixelTheme.muted)
                            Spacer(minLength: 0)
                            if displayedCount > 0 { Text(L10n.text("展示 \(displayedCount) 条")).foregroundStyle(PixelTheme.green) }
                        }.font(PixelTheme.font())
                    }.padding(14).frame(maxWidth: .infinity, alignment: .leading)
                        .background(PixelOutline().fill(Color(hex: 0x304C5B)))
                        .overlay { PixelOutline().stroke(Color(hex: 0x56727F), lineWidth: 1).allowsHitTesting(false) }
                        .accessibilityElement(children: .contain)
                        .accessibilityIdentifier("catalog.entry." + species.id)
                }
            }
        }
    }

    private func outcomeView(_ result: FishOutcome) -> some View {
        VStack(spacing: 20) {
            Text(result.novel ? L10n.text("发现新的海洋伙伴") : L10n.text("新的小鱼诞生了")).font(PixelTheme.font(24)).foregroundStyle(gold)
            portrait(result.child.species, grade: result.child.grade).frame(width: 192, height: 144)
            VStack(spacing: 10) {
                if result.novel || result.novelVariant {
                    PixelDiscoveryBadge(newSpecies: result.novel)
                }
                Text(result.child.name).font(PixelTheme.font(24))
            }
            Text(L10n.text("\(result.child.tier)★ · 品阶 \(result.child.grade)"))
            breedingHearts(result.child)
            Text(L10n.text("成长时间 \(Int(FishBalance.growth[result.child.tier] / 60)) 分钟\(result.expGained > 0 ? L10n.text(" · 出生经验 +\(result.expGained)") : "")"))
                .font(PixelTheme.font()).foregroundStyle(PixelTheme.muted)
            Button(L10n.text("收下小鱼")) { store.outcome = nil }.buttonStyle(PixelButtonStyle(primary: true))
                .keyboardShortcut(.defaultAction)
        }.padding(32).frame(minWidth: 280)
            .font(PixelTheme.font()).foregroundStyle(PixelTheme.text)
            .background(PixelTheme.panel).pixelPanel()
            .onAppear { store.sound.play("reveal", tier: result.child.tier) }
            .preferredColorScheme(.dark)
    }

    private func portrait(_ species: FishSpecies, grade: Int) -> some View {
        Image(decorative: PixelArt.image(species: species, grade: grade), scale: 1)
            .interpolation(.none).resizable().scaledToFit()
    }
    private func status(_ fish: AquariumFish) -> String {
        if let date = fish.maturesAt, date > store.now {
            return L10n.text("\(fish.expBanked ? L10n.text("冷却") : L10n.text("成长"))中 · \(countdown(date))")
        }
        return fish.canBreed(at: store.now) ? L10n.text("已成年 · 可繁育") : L10n.text("已成年 · 次数耗尽")
    }
    private func countdown(_ date: Date) -> String {
        let seconds = max(0, Int(ceil(date.timeIntervalSince(store.now))))
        return String(format: "%02d:%02d", seconds / 60, seconds % 60)
    }
}

private extension AquariumView {
    var chrome: some View {
        #if os(macOS)
        PixelWindowChrome(title: L10n.text("Fishtank / 口袋海洋"), closeLabel: L10n.text("关闭养成手册"), bottomSpacing: 0) { NSApp.keyWindow?.close() }
        #else
        EmptyView()
        #endif
    }

    var navigationBar: some View {
        #if os(macOS)
        HStack(spacing: 6) {
            ForEach(AquariumTab.allCases) { item in
                Button { tab = item; store.sound.interact() } label: {
                    HStack(spacing: 8) {
                        PixelIcon(icon(for: item), color: tab == item ? PixelTheme.green : PixelTheme.muted)
                            .frame(width: 16, height: 16)
                        Text(L10n.key(item.rawValue))
                    }
                }.buttonStyle(PixelTabStyle(selected: tab == item, edge: .bottom))
                    .keyboardShortcut(KeyEquivalent(Character(String((AquariumTab.allCases.firstIndex(of: item) ?? 0) + 1))), modifiers: .command)
                    .accessibilityLabel(L10n.key(item.rawValue))
                    .accessibilityAddTraits(tab == item ? .isSelected : [])
            }
        }
        .padding(.horizontal, 12).padding(.bottom, 8)
        .overlay(alignment: .top) {
            Rectangle().fill(PixelTheme.panel).frame(height: 2).allowsHitTesting(false)
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("aquarium.tabs")
        #else
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 6) { navigationItems }
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: [.english, .japanese].contains(L10n.language) ? 2 : 3), spacing: 6) { navigationItems }
        }.padding(8).background(PixelTheme.ink)
        #endif
    }
    var navigationItems: some View {
        ForEach(AquariumTab.allCases) { item in
            Button { tab = item; store.sound.interact() } label: {
                HStack(spacing: 6) {
                    PixelIcon(icon(for: item), color: tab == item ? PixelTheme.ink : PixelTheme.text)
                        .frame(width: PixelTheme.metric(16, 20), height: PixelTheme.metric(16, 20))
                    Text(L10n.key(item.rawValue)).fixedSize(horizontal: true, vertical: false)
                }.frame(minWidth: 48, maxWidth: .infinity)
            }.buttonStyle(PixelButtonStyle(primary: tab == item, compact: PixelTheme.isPad))
                .keyboardShortcut(KeyEquivalent(Character(String((AquariumTab.allCases.firstIndex(of: item) ?? 0) + 1))), modifiers: .command)
                .accessibilityLabel(L10n.key(item.rawValue))
                .accessibilityAddTraits(tab == item ? .isSelected : [])
        }
    }
    func icon(for tab: AquariumTab) -> String {
        switch tab { case .tank: return "fish"; case .breed: return "heart"; case .merge: return "merge"
        case .decor: return "plant"; case .book: return "book"; case .settings: return "gear" }
    }

    var collectionContent: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                Button(L10n.text("鱼种 \(store.state.discovered.count)/29")) { showingMedals = false }
                    .buttonStyle(PixelButtonStyle(primary: !showingMedals))
                Button(L10n.text("勋章 \(store.state.earnedAchievements.count)/14")) { showingMedals = true }
                    .buttonStyle(PixelButtonStyle(primary: showingMedals))
                Spacer()
            }
            if showingMedals { medalsContent } else { bookContent }
        }
    }

    var decorContent: some View {
        VStack(alignment: .leading, spacing: PixelTheme.metric(14, 18)) {
            #if os(macOS)
            HStack(alignment: .center, spacing: 20) {
                PixelAquariumPreview(scene: scene, store: store, paused: scenePaused)
                    .frame(width: 256, height: 144).accessibilityIdentifier("decor.preview")
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text(L10n.text("布置一小片海底")).font(PixelTheme.font(18)).foregroundStyle(gold)
                        Spacer(minLength: 8)
                        Text(L10n.text("\(store.state.decorations.count)/\(store.state.capacity) 位")).foregroundStyle(PixelTheme.muted)
                    }
                    Text(L10n.text("在鱼缸中直接拖动造景调整位置。顶挂灯与海底造景共用槽位，勋章不占位。"))
                        .foregroundStyle(PixelTheme.muted).fixedSize(horizontal: false, vertical: true)
                }.frame(maxWidth: .infinity, alignment: .leading)
            }
            #else
            HStack {
                Text(L10n.text("布置一小片海底")).font(PixelTheme.font(24)).foregroundStyle(gold)
                Spacer()
                Text(L10n.text("\(store.state.decorations.count)/\(store.state.capacity) 位")).foregroundStyle(PixelTheme.muted)
            }
            PixelAquariumPreview(scene: scene, store: store, paused: scenePaused)
                .frame(maxWidth: 640).frame(maxWidth: .infinity)
            Text(L10n.text("在鱼缸中直接拖动造景调整位置。顶挂灯与海底造景共用槽位，勋章不占位。"))
                .foregroundStyle(PixelTheme.muted)
            #endif
            LazyVGrid(columns: [GridItem(.adaptive(minimum: PixelTheme.metric(184, 232)), spacing: 12)], spacing: 12) {
                ForEach(DecorCatalog.all) { item in
                    let placed = store.state.decorations.first { $0.id == item.id }
                    let unlocked = store.state.level >= item.unlockLevel
                    ZStack(alignment: .bottomTrailing) {
                        Button { store.toggleDecoration(item.id) } label: {
                            VStack(alignment: .leading, spacing: PixelTheme.metric(8, 12)) {
                                HStack {
                                    Text(item.top ? L10n.text("顶挂") : L10n.text("海底")).foregroundStyle(PixelTheme.muted)
                                    Spacer()
                                    if !unlocked { PixelIcon("lock") }
                                }.frame(height: PixelTheme.metric(20, 24))
                                Image(decorative: DecorArt.image(item), scale: 1).interpolation(.none).resizable()
                                    .aspectRatio(item.displayAspectRatio, contentMode: .fit)
                                    .padding(6).frame(height: PixelTheme.metric(64, 76)).frame(maxWidth: .infinity).opacity(unlocked ? 1 : 0.3)
                                    .background(PixelSpecimenWell())
                                Text(item.name).foregroundStyle(PixelTheme.text).lineLimit(2).frame(height: PixelTheme.metric(L10n.language == .english ? 38 : 28, 24), alignment: .topLeading)
                                Text(unlocked ? (placed == nil ? L10n.text("已解锁") : L10n.text("可拖动调整位置")) : L10n.text("Lv.\(item.unlockLevel) 解锁"))
                                    .foregroundStyle(unlocked ? PixelTheme.green : PixelTheme.muted)
                                    .lineLimit(1).frame(height: PixelTheme.metric(16, 24), alignment: .leading)
                                Spacer(minLength: PixelTheme.metric(40, 52))
                            }.padding(PixelTheme.metric(12, 14)).frame(maxWidth: .infinity, alignment: .leading).frame(height: PixelTheme.metric(L10n.language == .english ? 240 : 224, 300))
                                .pixelCard(displayed: placed != nil).contentShape(Rectangle())
                        }.buttonStyle(.plain).disabled(!unlocked)
                            .accessibilityIdentifier("decor.card." + item.id)
                            .accessibilityLabel(placed == nil ? L10n.text("放入装饰\(item.name)") : L10n.text("收回装饰\(item.name)"))
                            .accessibilityValue(placed == nil ? L10n.text("未展示") : L10n.text("展示中"))
                        Button(L10n.text("翻转")) { store.flipDecoration(item.id) }.disabled(placed == nil)
                            .buttonStyle(PixelButtonStyle(compact: true)).padding(14)
                            .accessibilityLabel(L10n.text("翻转\(item.name)"))
                    }.overlay(alignment: .topTrailing) {
                        if placed != nil {
                            displayedBadge.padding(8).allowsHitTesting(false)
                                .accessibilityIdentifier("decor.displayed")
                        }
                    }
                }
            }
        }
    }

    var medalsContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(L10n.text("每一次相遇，都值得纪念。")).font(PixelTheme.font(24)).foregroundStyle(gold)
            Text(L10n.text("14 项永久成就。已获得的记录不会因合成或放生消失，可同时挂上多枚。"))
                .foregroundStyle(PixelTheme.muted)
            HStack {
                Button(L10n.text("挂上全部")) { store.displayAchievements(AchievementCatalog.all.map(\.id).filter { store.state.earnedAchievements.contains($0) }) }
                    .disabled(store.state.earnedAchievements.isEmpty)
                Button(L10n.text("全部取下")) { store.displayAchievements([]) }.disabled(store.state.displayedAchievements.isEmpty)
                Spacer()
                Text(L10n.text("展示 \(store.state.displayedAchievements.count) 枚")).foregroundStyle(PixelTheme.muted)
            }
            LazyVGrid(columns: [GridItem(.adaptive(minimum: PixelTheme.metric(184, 232)), spacing: 12)], spacing: 12) {
                ForEach(AchievementCatalog.all) { item in
                    let progress = store.state.achievementProgress.first { $0.id == item.id }!
                    let displayed = store.state.displayedAchievements.contains(item.id)
                    Button {
                        var ids = store.state.displayedAchievements
                        if displayed { ids.removeAll { $0 == item.id } } else { ids.append(item.id) }
                        store.displayAchievements(ids)
                    } label: {
                        VStack(alignment: .leading, spacing: 10) {
                            Image(decorative: DecorArt.medal(item.id), scale: 1).interpolation(.none).resizable().scaledToFit()
                                .padding(6).frame(height: 68).frame(maxWidth: .infinity)
                                .opacity(progress.unlocked ? 1 : 0.25).background(PixelSpecimenWell())
                            Text(item.title).foregroundStyle(gold).lineLimit(1).frame(height: PixelTheme.metric(16, 24), alignment: .leading)
                            Text(item.note).foregroundStyle(PixelTheme.muted).lineSpacing(4).lineLimit(2)
                                .frame(height: PixelTheme.metric(32, 44), alignment: .topLeading)
                            PixelMeter(value: Double(progress.unlocked ? item.total : progress.current), total: Double(item.total), color: gold)
                            Text(progress.unlocked ? L10n.text("永久获得") : "\(progress.current)/\(item.total)").foregroundStyle(PixelTheme.muted)
                                .frame(height: PixelTheme.metric(16, 24), alignment: .leading)
                        }.padding(14).frame(maxWidth: .infinity, alignment: .leading)
                            .pixelCard(displayed: displayed).contentShape(Rectangle())
                    }.buttonStyle(.plain).disabled(!progress.unlocked)
                        .accessibilityIdentifier("medal.card." + item.id)
                        .accessibilityLabel(displayed ? L10n.text("取下勋章\(item.title)") : L10n.text("挂上勋章\(item.title)"))
                        .accessibilityValue(progress.unlocked ? (displayed ? L10n.text("展示中") : L10n.text("未展示")) : L10n.text("尚未获得"))
                        .accessibilityHint(item.note)
                        .overlay(alignment: .topTrailing) {
                            if displayed {
                                displayedBadge.padding(8).allowsHitTesting(false).accessibilityIdentifier("medal.displayed")
                            } else if !progress.unlocked { PixelIcon("lock", color: PixelTheme.muted).padding(8).allowsHitTesting(false) }
                        }
                }
            }
        }
    }

    var settingsContent: some View {
        VStack(alignment: .leading, spacing: 20) {
            #if os(macOS)
            HStack {
                VStack(alignment: .leading, spacing: 8) {
                    Text(L10n.text("应用设置")).foregroundStyle(gold)
                    Text(L10n.text("管理接入、气泡和提示音")).foregroundStyle(PixelTheme.muted)
                }
                Spacer()
                Button(L10n.text("打开设置…")) { openAgentSettings?() }.disabled(openAgentSettings == nil)
            }.padding(16).pixelPanel()
            #endif
            Text(L10n.text("声音与海的颜色")).font(PixelTheme.font(24)).foregroundStyle(gold)
            #if os(iOS)
            LanguageSettingsView().padding(16).pixelPanel()
            #endif
            VStack(alignment: .leading, spacing: 10) {
                audioRow(L10n.text("操作音效"), volumeTitle: L10n.text("音效音量"), enabled: \.sfxEnabled, volume: \.sfxVolume)
                audioRow(L10n.text("背景音乐"), volumeTitle: L10n.text("音乐音量"), enabled: \.musicEnabled, volume: \.musicVolume)
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 8) { musicChoices; Spacer(minLength: 12); soundPreviewButton }
                    VStack(alignment: .leading, spacing: 8) {
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: PixelTheme.metric(L10n.language == .english ? 180 : 140, 210)), spacing: 8)], spacing: 8) { musicChoices }
                        soundPreviewButton
                    }
                }
            }.frame(maxWidth: .infinity, alignment: .leading).padding(16).pixelPanel()
            VStack(alignment: .leading, spacing: 10) {
                Text(L10n.text("鱼缸灯光")).foregroundStyle(gold)
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 8) {
                        railAnimationToggle
                        railSpeedControl
                        Spacer(minLength: 0)
                        lightingModeButtons
                    }
                    VStack(alignment: .leading, spacing: 8) {
                        HStack { railAnimationToggle; Spacer(minLength: 12); lightingModeButtons }
                        railSpeedControl
                    }
                    VStack(alignment: .leading, spacing: 8) {
                        railAnimationToggle
                        railSpeedControl
                        HStack { Spacer(minLength: 0); lightingModeButtons }
                    }
                }
                Text(L10n.text("自动模式在本地时间 19:00–07:00 使用夜景。顶挂灯在夜间显示点阵灯光。"))
                    .foregroundStyle(PixelTheme.muted)
            }.frame(maxWidth: .infinity, alignment: .leading).padding(16).pixelPanel()
            SavedGamePanel(store: store)
            Toggle(L10n.text("成年 / 冷却 / 爱心回满提醒"), isOn: Binding(get: { store.remindersEnabled }, set: { store.setReminders($0) }))
            VStack(alignment: .leading, spacing: 12) {
                Text(L10n.text("养成小贴士")).foregroundStyle(gold)
                Text(L10n.text("爱心每 7 分钟恢复一颗，上限 5 颗。离线也会成长，成年经验只结算一次。投喂只影响观赏动画。"))
                Text(L10n.text("点鱼会惊动它；河豚会鼓起，电鳗也有自己的脾气。同种鱼偶尔结群，海马会依着海草休息。"))
                Text(L10n.text("音效和音乐独立控制；首次操作后开始播放。iPad 在后台暂停声音，尊重静音设置。"))
                Text(L10n.text("进度在本机自动保存。装饰位置、音量和永久成就随存档保留。支持导入原网页版 JSON；暂不提供云同步。"))
            }.font(PixelTheme.captionFont()).foregroundStyle(PixelTheme.muted).frame(maxWidth: .infinity, alignment: .leading).padding(16).pixelPanel()
            VStack(alignment: .leading, spacing: 12) {
                Text(L10n.text("关于这片海")).foregroundStyle(gold)
                Text("Fishtank " + (Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? ""))
                Text(L10n.text("键盘：⌘1–⌘6 切换页面；确认弹窗可用 Return，取消可用 Esc。Mac 从菜单栏隐藏鱼缸后仍会继续成长。"))
                Text(L10n.text("本游戏不联网、不收集个人信息。进度保存在此设备；导出文件由你自行保管。通知需主动开启，可随时关闭。"))
                Text(L10n.text("代码与原创像素图使用 MIT 许可。中文像素字体为 Fusion Pixel，遵循 SIL Open Font License 1.1。完整许可随应用附带。"))
            }.font(PixelTheme.captionFont()).foregroundStyle(PixelTheme.muted).frame(maxWidth: .infinity, alignment: .leading).padding(16).pixelPanel()
        }.frame(maxWidth: .infinity, alignment: .leading).fixedSize(horizontal: false, vertical: true)
    }

    func audioBinding(_ key: WritableKeyPath<AquariumAudio, Bool>) -> Binding<Bool> {
        Binding(get: { store.state.audio[keyPath: key] }, set: { value in
            var config = store.state.audio; config[keyPath: key] = value; store.setAudio(config)
        })
    }
    func audioRow(_ title: String, volumeTitle: String, enabled: WritableKeyPath<AquariumAudio, Bool>, volume: WritableKeyPath<AquariumAudio, Double>) -> some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 12) {
                audioToggle(title, key: enabled).frame(width: max(PixelTheme.metric(116, 152), PixelTheme.textWidth(title) + 64), alignment: .leading)
                volumeControl(volumeTitle, key: volume).frame(minWidth: 180)
            }
            VStack(alignment: .leading, spacing: 6) {
                audioToggle(title, key: enabled)
                volumeControl(volumeTitle, key: volume)
            }
        }
    }
    func audioToggle(_ title: String, key: WritableKeyPath<AquariumAudio, Bool>) -> some View {
        Toggle(title, isOn: audioBinding(key)).fixedSize(horizontal: true, vertical: false)
            .accessibilityIdentifier(key == \.musicEnabled ? "audio.music" : "audio.sfx")
    }
    var musicChoices: some View {
        ForEach(AquariumMusicTrack.allCases, id: \.self) { track in
            Button(track.title) {
                var config = store.state.audio; config.track = track.rawValue; store.setAudio(config)
            }.buttonStyle(PixelButtonStyle(primary: store.state.audio.track == track.rawValue, compact: true))
                .accessibilityIdentifier("audio.track." + track.rawValue)
                .accessibilityValue(store.state.audio.track == track.rawValue ? L10n.text("已选中") : L10n.text("未选中"))
        }
    }
    var soundPreviewButton: some View {
        Button(L10n.text("试听音效")) { store.sound.play("reveal", tier: 3) }.buttonStyle(PixelButtonStyle(compact: true))
            .fixedSize(horizontal: true, vertical: false)
    }
    var lightingModeButtons: some View {
        HStack(spacing: 8) {
            ForEach(AquariumLighting.allCases, id: \.self) { mode in
                Button(mode.title) { store.setLighting(mode) }
                    .buttonStyle(PixelButtonStyle(primary: store.state.lighting == mode, compact: true, fixedWidth: PixelTheme.filterButtonWidth))
                    .fixedSize(horizontal: true, vertical: false)
            }
        }
    }
    var railAnimationToggle: some View {
        Toggle(L10n.text("串灯流光"), isOn: Binding(get: { store.state.railLights.animated }, set: {
            var config = store.state.railLights; config.animated = $0; store.setRailLights(config)
        })).fixedSize(horizontal: true, vertical: false)
    }
    var railSpeedControl: some View {
        HStack(spacing: 8) {
            Text(L10n.text("流光速度")).foregroundStyle(PixelTheme.muted)
            Button("-") { var config = store.state.railLights; config.frequency = max(0.2, (config.frequency * 10 - 1).rounded() / 10); store.setRailLights(config) }
                .accessibilityLabel(L10n.text("降低流光速度"))
            Text(String(format: "%.1f Hz", store.state.railLights.frequency)).frame(width: PixelTheme.metric(48, 72))
            Button("+") { var config = store.state.railLights; config.frequency = min(2, (config.frequency * 10 + 1).rounded() / 10); store.setRailLights(config) }
                .accessibilityLabel(L10n.text("提高流光速度"))
        }.buttonStyle(PixelButtonStyle(compact: true, fixedWidth: 48)).fixedSize(horizontal: true, vertical: false)
    }
    func volumeControl(_ title: String, key: WritableKeyPath<AquariumAudio, Double>) -> some View {
        HStack(spacing: 8) {
            Button("-") { var config = store.state.audio; config[keyPath: key] = max(0, config[keyPath: key] - 0.1); store.setAudio(config) }
                .accessibilityLabel(L10n.text("降低\(title)"))
            PixelMeter(value: store.state.audio[keyPath: key], total: 1)
                .frame(minWidth: 24).accessibilityLabel(title)
            Text("\(Int((store.state.audio[keyPath: key] * 100).rounded()))%")
                .frame(width: 40)
            Button("+") { var config = store.state.audio; config[keyPath: key] = min(1, config[keyPath: key] + 0.1); store.setAudio(config) }
                .accessibilityLabel(L10n.text("提高\(title)"))
        }.buttonStyle(PixelButtonStyle(compact: true, fixedWidth: 48))
    }
}

private struct PixelAquariumPreview: View {
    let scene: AquariumScene
    @ObservedObject var store: AquariumStore
    var openAgentSettings: (() -> Void)? = nil
    var paused: Bool
    @Environment(\.accessibilityReduceMotion) private var reducedMotion
    var body: some View {
        GeometryReader { geometry in
            NativeAquariumView(scene: scene, paused: paused)
                .simultaneousGesture(DragGesture(minimumDistance: 2).onChanged { value in
                    func point(_ p: CGPoint) -> CGPoint { CGPoint(x: p.x / geometry.size.width * 320, y: 180 - p.y / geometry.size.height * 180) }
                    if scene.beginDecorationDrag(at: point(value.startLocation)) { scene.dragDecoration(to: point(value.location)) }
                }.onEnded { _ in scene.endDecorationDrag() })
                .onTapGesture(coordinateSpace: .local) { location in
                    scene.reducedMotion = reducedMotion
                    scene.tapWater(at: CGPoint(x: location.x / geometry.size.width * 320, y: 180 - location.y / geometry.size.height * 180))
                }
        }.aspectRatio(16 / 9, contentMode: .fit)
            .accessibilityLabel(L10n.text("像素鱼缸，\(store.state.tankIDs.count) 条鱼，\(store.state.decorations.count) 件装饰。装饰可拖动。"))
    }
}
