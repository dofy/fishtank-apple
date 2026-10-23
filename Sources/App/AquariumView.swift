import SwiftUI
import SpriteKit
#if os(macOS)
import AppKit
#endif

private enum AquariumTab: String, CaseIterable, Identifiable {
    case tank, breed, merge, decor, book, settings
    var id: Self { self }
    var title: String {
        switch self {
        case .tank: return L10n.text("Fish")
        case .breed: return L10n.text("Breed")
        case .merge: return L10n.text("Synthesize")
        case .decor: return L10n.text("Decor")
        case .book: return L10n.text("Collection")
        case .settings: return L10n.text("Settings")
        }
    }
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
    @State private var tierFilter = -1
    @State private var search = ""
    @State private var releaseTarget: AquariumFish?
    @State private var confirmMerge = false
    @State private var reforgeMode = false
    @State private var showingMedals = false
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
                selected = []; search = ""; tierFilter = -1
            }
            #if os(macOS)
            pageFooter
            #else
            if tab == .breed { breedActionBar }
            if tab == .merge { mergeActionBar }
            #endif
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
            if (notification.object as? NSWindow)?.title == L10n.text("Fishtank · Care Guide") { isVisible = false; store.save() }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSWindow.didBecomeKeyNotification)) { notification in
            if (notification.object as? NSWindow)?.title == L10n.text("Fishtank · Care Guide") { isVisible = true }
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
                            Text(confirmMerge ? (reforgeMode ? L10n.text("Confirm reforge?") : L10n.text("Confirm Synthesis?")) : L10n.text("Release Fish?")).font(PixelTheme.font(24)).foregroundStyle(gold)
                            Text(confirmMerge ? (reforgeMode ? L10n.text("Permanently consumes the 3 selected five-star creatures and creates a five-star juvenile inheriting the highest grade. No hearts required.") : L10n.text("Permanently consumes the 10 selected fish. The result inherits the highest grade.")) : L10n.text("Released fish cannot be recovered. Collection records will remain."))
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
        Button(L10n.text("Cancel")) { releaseTarget = nil; confirmMerge = false }
            .buttonStyle(PixelButtonStyle(compact: PixelTheme.isPad))
            .keyboardShortcut(.cancelAction)
    }

    private var confirmationSubmitButton: some View {
        Button(confirmMerge ? (reforgeMode ? L10n.text("Consume and Reforge") : L10n.text("Consume Materials and Synthesize")) : L10n.text("Confirm Release")) {
            if confirmMerge {
                if reforgeMode ? store.reforge(selected) : store.merge(selected) { selected = [] }
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
                    observationFeedback = scene.tapWater(at: point) ? L10n.text("Interacted with fish") : L10n.text("Fed one fish treat")
                }, onDoubleTap: { confirmObservationExit = true })
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .accessibilityLabel(L10n.text("Immersive aquarium. Click to feed or interact with fish; double-click to exit the preview."))
                .accessibilityIdentifier("aquarium.observation")
                .accessibilityValue(observationFeedback)
                .accessibilityAddTraits(.isButton)
                .accessibilityAction(named: L10n.text("Feed")) { store.sound.interact(); scene.feed(reducedMotion: reducedMotion) }
                .accessibilityAction(named: L10n.text("Exit Preview")) { confirmObservationExit = true }
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
                Text(L10n.text("Exit Full-Screen Preview?")).font(PixelTheme.font(24)).foregroundStyle(gold)
                Text(L10n.text("Return to the care screen. Aquarium progress will be preserved."))
                    .fixedSize(horizontal: false, vertical: true)
                HStack(spacing: 16) {
                    Button(L10n.text("Keep Watching")) { confirmObservationExit = false }
                        .keyboardShortcut(.cancelAction)
                    Spacer(minLength: 0)
                    Button(L10n.text("Exit Preview")) { confirmObservationExit = false; immersive = false }
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
            HStack(spacing: 8) { PixelIcon("eye", color: PixelTheme.ink); Text(L10n.text("Full-Screen Preview")) }
        }.buttonStyle(PixelButtonStyle(primary: true))
            .accessibilityLabel(L10n.text("Immersive Aquarium"))
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
            Text(L10n.text("My Aquarium")).font(PixelTheme.font(24)).foregroundStyle(gold)
            Text(L10n.text("Decorations \(store.state.decorations.count)/\(store.state.capacity) · Medals \(store.state.displayedAchievements.count)"))
                .foregroundStyle(PixelTheme.muted)
            observationEntry
            Button(L10n.text("Decorate Aquarium")) { tab = .decor }
            Text(L10n.text("In preview, click to feed or interact with fish, and double-click to confirm exit."))
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
            Text(store.message)
                .font(PixelTheme.captionFont()).foregroundStyle(gold).lineLimit(2).lineSpacing(4)
                .frame(maxWidth: .infinity, alignment: .leading)
                .frame(height: 44, alignment: .topLeading)
                .accessibilityAddTraits(.updatesFrequently)
            #endif
            if let title = store.achievementToast {
                HStack {
                    PixelIcon("medal", color: gold)
                    Text(L10n.text("Medal Earned: ") + title)
                    Spacer()
                    Button(L10n.text("Keep It")) { store.achievementToast = nil }
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
                    Text(L10n.text("Pixel Ocean")).font(PixelTheme.font(18)).foregroundStyle(gold)
                        .accessibilityIdentifier("aquarium.heading")
                    Text("Lv.\(store.state.level)").foregroundStyle(PixelTheme.muted)
                }.fixedSize(horizontal: true, vertical: false)
                Spacer(minLength: 16)
                compactExperience
            }
            HStack(alignment: .firstTextBaseline, spacing: 16) {
                HStack(alignment: .firstTextBaseline, spacing: 16) {
                    heartSummary; collectionSummary; tankSummary
                }.fixedSize(horizontal: true, vertical: false).layoutPriority(1)
                Text(store.message)
                    .font(PixelTheme.captionFont()).foregroundStyle(gold)
                    .lineLimit(1).truncationMode(.tail)
                    .frame(maxWidth: .infinity, alignment: .trailing)
                    .layoutPriority(-1)
                    .help(store.message)
                    .accessibilityIdentifier("aquarium.message")
                    .accessibilityAddTraits(.updatesFrequently)
            }
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
                .accessibilityLabel(L10n.text("Total XP \(store.state.exp) / \(next) · Next level adds a display slot"))
                .help(L10n.text("Total XP \(store.state.exp) / \(next) · Next level adds a display slot"))
            } else {
                Text(L10n.text("Aquarium max level · Total XP \(store.state.exp)"))
                    .font(PixelTheme.captionFont()).foregroundStyle(PixelTheme.muted)
            }
        }.fixedSize(horizontal: true, vertical: false)
    }
    #endif

    private var heading: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                HStack(spacing: 10) { PixelIcon("fish", color: gold); Text(L10n.text("Pixel Ocean")).accessibilityIdentifier("aquarium.heading").font(PixelTheme.font(24)).foregroundStyle(gold) }
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
                Text(L10n.text("Total XP \(store.state.exp) / \(next) · Next level adds a display slot"))
                    .font(PixelTheme.captionFont()).foregroundStyle(PixelTheme.muted)
            } else { Text(L10n.text("Aquarium max level · Total XP \(store.state.exp)")).font(PixelTheme.captionFont()).foregroundStyle(PixelTheme.muted) }
        }
    }

    private var heartSummary: some View {
        HStack(spacing: 6) {
            HStack(spacing: 2) {
                ForEach(0..<5, id: \.self) { index in
                    PixelIcon(index < store.state.hearts ? "heart" : "heartEmpty", color: index < store.state.hearts ? PixelTheme.pink : PixelTheme.muted)
                }
            }
            Text(store.state.hearts < 5 ? L10n.text("Restores in \(countdown(store.state.nextHeartAt))") : L10n.text("Full"))
                .font(PixelTheme.captionFont()).foregroundStyle(PixelTheme.pink)
        }.accessibilityElement(children: .ignore)
            .accessibilityLabel(L10n.text("\(store.state.hearts) of 5 breeding hearts remaining"))
            .accessibilityIdentifier("aquarium.hearts")
    }
    private var collectionSummary: some View { Text(L10n.text("Species \(store.state.regularDiscoveredCount)/29")).font(PixelTheme.captionFont()) }
    private var tankSummary: some View { Text(L10n.text("Displayed \(store.state.tankIDs.count)/\(store.state.capacity) · Inventory \(store.state.fish.count)")).font(PixelTheme.captionFont()).foregroundStyle(PixelTheme.muted) }

    private var tankContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 16) {
                Text(L10n.text("Decorations \(store.state.decorations.count)/\(store.state.capacity) · Medals \(store.state.displayedAchievements.count)"))
                    .foregroundStyle(PixelTheme.muted)
                Button(L10n.text("Decorate Aquarium")) { tab = .decor }
                Spacer(minLength: 0)
            }
            tankInventory
        }
    }

    private var tankInventory: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text(L10n.text("My Fish")).font(PixelTheme.font(PixelTheme.metric(18, 24)))
                Spacer()
                Button { scene.feed(reducedMotion: reducedMotion); store.sound.play("feed"); store.message = L10n.text("Drop some food and watch the fish swim over.") } label: {
                    HStack(spacing: 6) { PixelIcon("food"); Text(L10n.text("Feed")) }
                }
                    .buttonStyle(PixelButtonStyle())
            }
            filters
            fishSorting
            fishGrid(visibleFish)
        }
    }

    private enum FishSort: String, CaseIterable {
        case tier, grade, uses, displayed, acquired
        var title: String {
            switch self {
            case .tier: return L10n.text("Stars")
            case .grade: return L10n.text("Grade")
            case .uses: return L10n.text("Breedings")
            case .displayed: return L10n.text("Display")
            case .acquired: return L10n.text("Date Acquired")
            }
        }
    }

    private var fishSortDirection: some View {
        Button(sortDescending ? L10n.text("Descending") : L10n.text("Ascending")) { sortDescending.toggle() }
            .accessibilityIdentifier("fish.sort.direction")
    }
    private var stackedFishSorting: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(L10n.text("Sort Fish")).foregroundStyle(gold)
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
                Text(L10n.text("Sort Fish")).foregroundStyle(gold).fixedSize()
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
            Button(order.title) { fishSort = order }
                .buttonStyle(PixelButtonStyle(primary: fishSort == order))
                .accessibilityIdentifier("fish.sort." + String(describing: order))
                .accessibilityValue(fishSort == order ? L10n.text("Selected") : L10n.text("Not Selected"))
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
            Text(L10n.text("Two parents, one new encounter.")).font(PixelTheme.font(PixelTheme.metric(18, 24)))
            Text(L10n.text("Each breeding costs 1 heart. Starter fish cool down for 3 minutes; other fish use a breeding count. Locking does not prevent breeding."))
                .font(PixelTheme.font()).lineSpacing(4).foregroundStyle(PixelTheme.muted)
            VStack(alignment: .leading, spacing: 12) {
                if PixelTheme.isPad { Text(L10n.text("Parent Filters")).foregroundStyle(gold) }
                filters
            }.frame(maxWidth: .infinity, alignment: .leading).padding(14).pixelPanel()
            ViewThatFits(in: .horizontal) {
                HStack { breedParentHeading; Spacer(minLength: 12); breedSelectionTools }
                VStack(alignment: .leading, spacing: 8) { breedParentHeading; breedSelectionTools }
            }
            fishGrid(visibleFish)
        }
    }

    private var breedParentHeading: some View {
        HStack(spacing: 8) {
            Text(L10n.text("Select Parents")).foregroundStyle(gold)
            Text(L10n.text("\(visibleFish.filter { $0.canBreed(at: store.now) }.count) can breed")).foregroundStyle(PixelTheme.muted)
        }.fixedSize(horizontal: true, vertical: false)
    }

    private var breedSelectionTools: some View {
        HStack(spacing: 8) {
            Button(L10n.text("Suggested Pair")) { selected = store.state.recommendedPair(at: store.now) }
                .disabled(store.state.breedRecommendation(at: store.now).parentIDs.count < 2)
            Button(L10n.text("Clear")) { selected = [] }.disabled(selected.isEmpty)
        }.buttonStyle(PixelButtonStyle()).fixedSize(horizontal: true, vertical: false)
    }

    private var breedReadout: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(L10n.text("\(selected.count)/2 parents selected")).foregroundStyle(PixelTheme.text)
            if selected.count == 2,
               let a = store.state.fish.first(where: { $0.id == selected[0] }),
               let b = store.state.fish.first(where: { $0.id == selected[1] }),
               let odds = FishBalance.matrix["\(min(a.tier, b.tier))+\(max(a.tier, b.tier))"] {
                Text(L10n.text("Offspring odds: ") + odds.enumerated().filter { $0.element > 0 }.map {
                    "\($0.offset + 1)★ \($0.element.formatted(.number.precision(.fractionLength(0...1))))%"
                }.joined(separator: "  ")).foregroundStyle(gold)
                    .accessibilityIdentifier("breed.odds")
            } else {
                Text(PixelTheme.isPad ? L10n.text("Select fish cards or use the suggested pair, then breed once 2 fish are selected.") : L10n.text("Select two different parent fish."))
                    .foregroundStyle(PixelTheme.muted)
            }
        }.font(PixelTheme.captionFont()).lineSpacing(4).fixedSize(horizontal: false, vertical: true)
    }

    private var breedConfirmButton: some View {
        Button {
            if store.breed(selected) { selected = [] }
        } label: {
            HStack(spacing: 8) { PixelIcon("heart", color: PixelTheme.ink); Text(L10n.text("Breed · 1 Heart")) }
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
            HStack(spacing: 8) {
                Button(L10n.text("Normal Synthesis")) { reforgeMode = false }
                    .buttonStyle(PixelButtonStyle(primary: !reforgeMode))
                    .accessibilityIdentifier("merge.mode.normal")
                Button(L10n.text("Five-Star Reforge")) { reforgeMode = true }
                    .buttonStyle(PixelButtonStyle(primary: reforgeMode))
                    .accessibilityIdentifier("merge.mode.reforge")
            }.onChange(of: reforgeMode) { _ in selected = []; search = ""; tierFilter = -1 }
            if reforgeMode { reforgeContent } else { normalMergeContent }
        }
    }

    private var normalMergeContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(L10n.text("Ten little fish become a new starlight.")).font(PixelTheme.font(PixelTheme.metric(18, 24)))
            Text(L10n.text("Consume 10 fish rated 1–4 stars and inherit the highest grade. Same-star materials guarantee a one-star upgrade. With mixed stars, each fish casts one vote for its own star level +1. Starter, 5-star, and locked fish cannot be selected."))
                .font(PixelTheme.font()).lineSpacing(4).foregroundStyle(PixelTheme.muted)
            VStack(alignment: .leading, spacing: 12) {
                Text(L10n.text("Material Filters")).foregroundStyle(gold)
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 12) { mergeFilterToggles; Spacer(minLength: 0) }
                    VStack(alignment: .leading, spacing: 8) { mergeFilterToggles }
                }
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 12) { Text(L10n.text("Material Stars")).foregroundStyle(PixelTheme.muted); mergeTierButtons; Spacer(minLength: 0) }
                    VStack(alignment: .leading, spacing: 8) { Text(L10n.text("Material Stars")).foregroundStyle(PixelTheme.muted); mergeTierButtons }
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
            materialExclusionSummary
            fishGrid(visibleFish)
        }
    }

    private var reforgeContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(L10n.text("Consume 3 adult five-star creatures with no breeding uses left, unlocked and not displayed, to create 1 five-star juvenile. It inherits the highest grade and receives fresh breeding uses. No hearts required."))
                .font(PixelTheme.font()).foregroundStyle(PixelTheme.muted).fixedSize(horizontal: false, vertical: true)
            VStack(alignment: .leading, spacing: 8) {
                Text(L10n.text("80% Regular five-star · 20% Hidden creature")).foregroundStyle(gold)
                Text(reforgePityText).foregroundStyle(PixelTheme.muted)
            }.font(PixelTheme.captionFont()).fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading).padding(14).pixelPanel()
            ViewThatFits(in: .horizontal) {
                HStack { mergeMaterialHeading; Spacer(minLength: 12); reforgeSelectionTools }
                VStack(alignment: .leading, spacing: 8) { mergeMaterialHeading; reforgeSelectionTools }
            }
            materialExclusionSummary
            if visibleFish.isEmpty {
                Text(L10n.text("No eligible materials. Exhaust five-star breeding uses first. Displayed and locked creatures are protected."))
                    .foregroundStyle(PixelTheme.muted).fixedSize(horizontal: false, vertical: true).padding(.vertical, 20)
            } else { fishGrid(visibleFish) }
        }
    }

    private var reforgePityText: String {
        if store.state.hiddenDiscoveredCount == FishCatalog.hidden.count {
            return L10n.text("All three hidden species discovered. The hidden chance stays at 20%; new-species guarantees end.")
        }
        return L10n.text("\(store.state.reforgeMisses)/9 reforges without a new hidden species. A new one is guaranteed within \(10 - store.state.reforgeMisses) more. Duplicates do not reset the count.")
    }
    private var reforgeSelectionTools: some View {
        HStack(spacing: 8) {
            Button(L10n.text("Auto-Select Materials")) { selected = store.state.autoReforgeSelection(at: store.now) }
                .disabled(store.state.reforgeCandidates(at: store.now).count < ReforgeRules.inputCount)
                .help(L10n.text("Selects one highest-grade and two low-grade materials, preserving locks and display status."))
            Button(L10n.text("Clear")) { selected = [] }.disabled(selected.isEmpty)
        }.buttonStyle(PixelButtonStyle()).fixedSize(horizontal: true, vertical: false)
    }
    private var reforgeSelectionTitle: String {
        L10n.text("\(selected.count)/3 materials selected")
    }
    private var reforgeFooterDetail: String {
        if selected.count == 3 {
            let grade = store.state.fish.filter { selected.contains($0.id) }.map(\.grade).max() ?? 1
            return L10n.text("Grade \(grade) inherited · No hearts")
        }
        return L10n.text("Choose 3 materials. Locked and displayed creatures are protected.")
    }
    private var reforgeConfirmButton: some View {
        Button { confirmMerge = true } label: {
            HStack(spacing: 8) { PixelIcon("merge", color: PixelTheme.ink); Text(L10n.text("Reforge · Use 3")) }
        }.buttonStyle(PixelButtonStyle(primary: true)).fixedSize(horizontal: true, vertical: false)
            .disabled(selected.count != 3 || !Set(selected).isSubset(of: Set(store.state.reforgeCandidates(at: store.now).map(\.id))))
            .accessibilityIdentifier("reforge.confirm")
    }

    private var mergeFilterToggles: some View {
        Group {
            Toggle(L10n.text("Only fish with no breedings left"), isOn: mergeBinding(\.zeroUsesOnly)).fixedSize(horizontal: true, vertical: false)
            Toggle(L10n.text("Exclude fish currently displayed"), isOn: mergeBinding(\.excludeInTank)).fixedSize(horizontal: true, vertical: false)
        }
    }

    private var mergeTierButtons: some View {
        HStack(spacing: 8) {
            ForEach(1...4, id: \.self) { tier in
                Button("\(tier)★") {
                    var preferences = store.state.mergePreferences
                    if preferences.tiers.contains(tier) { preferences.tiers.remove(tier) } else { preferences.tiers.insert(tier) }
                    store.setMergePreferences(preferences); selected = []
                }.buttonStyle(PixelButtonStyle(primary: store.state.mergePreferences.tiers.contains(tier), compact: true, fixedWidth: PixelTheme.filterButtonWidth))
                    .accessibilityValue(store.state.mergePreferences.tiers.contains(tier) ? L10n.text("Selected") : L10n.text("Not Selected"))
            }
        }.fixedSize(horizontal: true, vertical: false)
    }

    private var mergeMaterialHeading: some View {
        HStack(spacing: 8) {
            Text(L10n.text("Select Materials")).foregroundStyle(gold)
            Text(L10n.text("\(visibleFish.count) available")).foregroundStyle(PixelTheme.muted)
        }.fixedSize(horizontal: true, vertical: false)
    }

    @ViewBuilder private var materialExclusionSummary: some View {
        let exclusions = store.state.materialExclusions(reforge: reforgeMode, at: store.now, tierFilter: tierFilter, search: search)
        if !exclusions.isEmpty {
            MaterialReasonLayout(spacing: 6) {
                Text(L10n.text("\(exclusions.reduce(0) { $0 + $1.count }) excluded"))
                    .foregroundStyle(PixelTheme.muted).padding(.trailing, 4).padding(.vertical, 4)
                ForEach(exclusions) { item in
                    HStack(spacing: 6) {
                        if item.id == .locked { PixelIcon("lock", color: gold).frame(width: 12, height: 12) }
                        Text(item.id.title)
                        Text("\(item.count)")
                    }.foregroundStyle(item.id == .locked ? gold : PixelTheme.muted)
                        .padding(.horizontal, 8).padding(.vertical, 4)
                        .background(PixelOutline(cut: 3).fill(PixelTheme.ink.opacity(0.55)))
                        .accessibilityElement(children: .combine)
                }
            }.font(PixelTheme.captionFont())
                .help(L10n.text("Each fish is counted once. Unlock protected fish on the Fish tab."))
                .accessibilityIdentifier("merge.exclusions")
        }
    }

    private var mergeSelectionTools: some View {
        HStack(spacing: 8) {
            Button(L10n.text("Auto-Select Materials")) { selected = store.state.autoMergeSelection() }
                .help(L10n.text("Prioritizes same-star materials: one highest-grade fish and nine low-cost fish."))
            Button(L10n.text("Clear")) { selected = [] }.disabled(selected.isEmpty)
        }.buttonStyle(PixelButtonStyle()).fixedSize(horizontal: true, vertical: false)
    }

    private var mergeReadout: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(L10n.text("\(selected.count)/10 materials selected")).foregroundStyle(PixelTheme.text)
            if selected.isEmpty {
                Text(PixelTheme.isPad ? L10n.text("Select fish cards or auto-select materials, then synthesize once you have 10.") : L10n.text("Synthesis requires 10 different fish."))
                    .foregroundStyle(PixelTheme.muted)
            } else {
                let picked = store.state.fish.filter { selected.contains($0.id) }
                let odds = Dictionary(grouping: picked, by: { $0.tier + 1 })
                Text(L10n.text("Outcome odds: ") + odds.keys.sorted().map { "\($0)★ \(odds[$0]!.count * 100 / max(1, picked.count))%" }.joined(separator: "  ")
                     + L10n.text(" · Inherits grade \(picked.map(\.grade).max() ?? 1)"))
                    .foregroundStyle(gold)
            }
        }.font(PixelTheme.captionFont()).lineSpacing(4).fixedSize(horizontal: false, vertical: true)
    }

    private var mergeConfirmButton: some View {
        Button { confirmMerge = true } label: {
            HStack(spacing: 8) { PixelIcon("merge", color: PixelTheme.ink); Text(L10n.text("Synthesize New Fish · Uses 10")) }
        }.buttonStyle(PixelButtonStyle(primary: true)).disabled(selected.count != 10)
            .fixedSize(horizontal: true, vertical: false)
    }

    private var mergeActionBar: some View {
        Group {
            if reforgeMode {
                selectionActionBar(readout: VStack(alignment: .leading, spacing: 6) {
                    Text(reforgeSelectionTitle); Text(reforgeFooterDetail).foregroundStyle(PixelTheme.muted)
                }.font(PixelTheme.captionFont()), action: reforgeConfirmButton)
            } else { selectionActionBar(readout: mergeReadout, action: mergeConfirmButton) }
        }
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

    #if os(macOS)
    @ViewBuilder private var pageFooter: some View {
        switch tab {
        case .tank:
            AquariumFooter(title: L10n.text("\(visibleFish.count) Matching Fish"), detail: tankFooterDetail) { EmptyView() }
        case .breed:
            AquariumFooter(title: L10n.text("\(selected.count)/2 parents selected"),
                           detail: breedFooterDetail, emphasized: selected.count == 2 && store.state.hearts > 0) {
                breedConfirmButton
            }
        case .merge:
            if reforgeMode {
                AquariumFooter(title: reforgeSelectionTitle, detail: reforgeFooterDetail, emphasized: selected.count == 3) {
                    reforgeConfirmButton
                }
            } else {
                AquariumFooter(title: (selected.isEmpty ? L10n.text("\(selected.count)/10 materials selected") : L10n.text("\(selected.count)/10 materials selected · Grade \(store.state.fish.filter { selected.contains($0.id) }.map(\.grade).max() ?? 1)")),
                           detail: mergeFooterDetail, emphasized: !selected.isEmpty) {
                mergeConfirmButton
            }
            }
        case .decor:
            AquariumFooter(title: L10n.text("Decor \(store.state.decorations.count)/\(store.state.capacity) Slots · Unlocked \(DecorCatalog.all.filter { $0.unlockLevel <= store.state.level }.count)/\(DecorCatalog.all.count)"), detail: decorFooterDetail) { EmptyView() }
        case .book:
            if showingMedals {
                AquariumFooter(title: L10n.text("Medals \(store.state.earnedAchievements.count)/\(AchievementCatalog.all.count) · Displayed \(store.state.displayedAchievements.count)"),
                               detail: L10n.text("Permanent records · Medals use no decor slots.")) {
                    HStack(spacing: 8) {
                        Button(L10n.text("Display All")) { store.displayAchievements(AchievementCatalog.all.map(\.id).filter { store.state.earnedAchievements.contains($0) }) }
                            .disabled(store.state.earnedAchievements.isEmpty)
                        Button(L10n.text("Remove All")) { store.displayAchievements([]) }.disabled(store.state.displayedAchievements.isEmpty)
                    }
                }
            } else {
                AquariumFooter(title: L10n.text("Species \(store.state.regularDiscoveredCount)/\(FishCatalog.regular.count) · Grade Variants \(store.state.regularVariantCount)/\(FishCatalog.regular.reduce(0) { $0 + ($1.tier == 0 ? 1 : 5) })"),
                               detail: L10n.text("Releasing and synthesizing fish never erase collection records.")) { EmptyView() }
            }
        case .settings:
            AquariumFooter(title: L10n.text("Music: \(store.state.audio.musicEnabled ? (AquariumMusicTrack(rawValue: store.state.audio.track) ?? .lofi).title : L10n.text("Off")) · Lighting: \(store.state.lighting.title)"),
                           detail: store.isPreviewOnly ? L10n.text("Temporary preview; restore a valid save to continue.") : L10n.text("Auto-save every 15s · Backup every 5min · Export regularly")) {
                BackupExportButton(store: store)
            }
        }
    }

    private var tankFooterDetail: String {
        guard !visibleFish.isEmpty else { return L10n.text("No fish match the criteria.") }
        return L10n.text("Click a fish card to display or withdraw")
    }
    private var breedFooterDetail: String {
        let parents = selected.compactMap { id in store.state.fish.first { $0.id == id } }
        guard selected.count == 2 && parents.count == 2 else { return L10n.text("Select two different parent fish.") }
        if store.state.hearts == 0 { return L10n.text("Not enough hearts. One restores every 7 minutes.") }
        if parents.contains(where: { !$0.isAdult(at: store.now) }) { return L10n.text("Juveniles and starter fish on cooldown cannot breed yet.") }
        if parents.contains(where: { !$0.canBreed(at: store.now) }) { return L10n.text("The selected parents have no breedings left.") }
        guard let odds = FishBalance.matrix["\(min(parents[0].tier, parents[1].tier))+\(max(parents[0].tier, parents[1].tier))"] else { return L10n.text("Select two different parent fish.") }
        return L10n.text("Offspring odds: ") + odds.enumerated().filter { $0.element > 0 }.map {
            "\($0.offset + 1)★ \($0.element.formatted(.number.precision(.fractionLength(0...1))))%"
        }.joined(separator: "  ")
    }
    private var mergeFooterDetail: String {
        guard !selected.isEmpty else { return L10n.text("Synthesis requires 10 different fish.") }
        let picked = store.state.fish.filter { selected.contains($0.id) }
        let odds = Dictionary(grouping: picked, by: { $0.tier + 1 })
        return L10n.text("Outcome odds: ") + odds.keys.sorted().map { "\($0)★\(odds[$0]!.count * 100 / max(1, picked.count))%" }.joined(separator: "  ")
    }
    private var decorFooterDetail: String {
        if store.state.decorations.count >= store.state.capacity { return L10n.text("Decor slots are full. Remove one before placing another.") }
        if let next = DecorCatalog.all.filter({ $0.unlockLevel > store.state.level }).map(\.unlockLevel).min() {
            return L10n.text("Drag to reposition · Lv.\(next) unlocks \(DecorCatalog.all.filter { $0.unlockLevel == next }.count) new decorations")
        }
        return L10n.text("Drag decor to reposition it. Hanging lights and seabed decor share slots; medals use none.")
    }
    #endif

    private func mergeBinding(_ key: WritableKeyPath<MergePreferences, Bool>) -> Binding<Bool> {
        Binding(get: { store.state.mergePreferences[keyPath: key] }, set: { value in
            var preferences = store.state.mergePreferences
            preferences[keyPath: key] = value
            store.setMergePreferences(preferences); selected = []
        })
    }

    private var fishSearch: some View {
        TextField(L10n.text("Search Species"), text: $search).textFieldStyle(.plain)
            .padding(12).background(PixelTheme.ink).pixelPanel(PixelTheme.ink)
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
            Button(tier == -1 ? L10n.text("All") : tier == 0 ? L10n.text("Starter") : "\(tier)★") { tierFilter = tier }
                .buttonStyle(PixelButtonStyle(primary: tierFilter == tier, compact: true, fixedWidth: PixelTheme.filterButtonWidth))
        }
    }

    private var visibleFish: [AquariumFish] {
        let list = tab == .merge ? (reforgeMode ? store.state.reforgeCandidates(at: store.now) : store.state.mergeCandidates) : store.state.fish
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
        if fish.isEmpty {
            Text(tab == .merge ? L10n.text("No material fish match the filters. Turn off “Only fish with no breedings left” or adjust the star level.") : L10n.text("No fish match the criteria."))
                .foregroundStyle(PixelTheme.muted).padding(.vertical, 30)
        } else {
            LazyVGrid(columns: columns, spacing: 12) {
                ForEach(fish) { item in fishCard(item) }
            }
        }
    }

    private func fishCard(_ fish: AquariumFish) -> some View {
        let isSelected = selected.contains(fish.id)
        let inTank = store.state.tankIDs.contains(fish.id)
        let cardPadding = PixelTheme.metric(14, 16)
        let actionHeight = PixelTheme.metric(40, 48)
        return ZStack(alignment: .bottomTrailing) {
            Button {
                if tab == .tank { store.toggleTank(fish.id) }
                else {
                    if isSelected { selected.removeAll { $0 == fish.id } }
                    else if selected.count < (tab == .breed ? 2 : reforgeMode ? 3 : 10) { selected.append(fish.id) }
                    store.sound.play("click")
                }
            } label: {
                VStack(alignment: .leading, spacing: PixelTheme.metric(8, 10)) {
                    portrait(fish.species, grade: fish.grade).padding(6).frame(height: 68).frame(maxWidth: .infinity)
                        .background(PixelSpecimenWell())
                    Text(fish.name).font(PixelTheme.font()).lineLimit(PixelTheme.isPad ? 1 : 2)
                        .frame(maxWidth: .infinity, alignment: .leading).frame(height: PixelTheme.metric(L10n.language == .english ? 38 : 32, 24), alignment: .topLeading)
                    Text(L10n.text("\(fish.tier == 0 ? L10n.text("Starter [fish]") : String(repeating: "★", count: fish.tier)) · Grade \(fish.grade)"))
                        .font(PixelTheme.captionFont()).foregroundStyle(gold)
                    breedingHearts(fish)
                    fishStatus(fish)
                }
                    // Match the overlaid action row, leaving an eight-point gap after the status.
                    .padding(.bottom, tab == .tank ? actionHeight + 8 : 0)
                    .padding(cardPadding).frame(maxWidth: .infinity, alignment: .leading)
                    .pixelCard(displayed: tab == .tank && inTank, selected: isSelected)
                    .contentShape(Rectangle())
            }.buttonStyle(.plain).disabled(tab == .breed && !fish.canBreed(at: store.now))
                .accessibilityIdentifier("fish.card." + fish.id.uuidString)
                .accessibilityLabel(L10n.text("\(tab == .tank ? (inTank ? L10n.text("Put Away") : L10n.text("Place")) : (isSelected ? L10n.text("Deselect") : L10n.text("Select")))\(fish.name), \(fish.tier) stars, grade \(fish.grade)"))
                .accessibilityValue(tab == .tank ? (inTank ? L10n.text("Displayed") : L10n.text("Not Displayed")) : (isSelected ? L10n.text("Selected [choice]") : L10n.text("None Selected")))
                .accessibilityHint(status(fish))
                .help(tab == .breed && fish.locked ? L10n.text("Locked fish can still breed. Unlock them on the Fish tab.") : status(fish))
            if tab == .tank {
                HStack(spacing: 8) {
                    Spacer(minLength: 0)
                    Button { store.setLocked(fish.id, !fish.locked) } label: { PixelIcon(fish.locked ? "lock" : "unlock") }
                        .accessibilityLabel(fish.locked ? L10n.text("Unlock \(fish.name)") : L10n.text("Lock \(fish.name)"))
                    if fish.tier > 0 {
                        Button(L10n.text("Release"), role: .destructive) { releaseTarget = fish }.disabled(fish.locked)
                    }
                }.buttonStyle(PixelButtonStyle(compact: true)).padding(cardPadding)
            }
        }.overlay(alignment: .topLeading) {
            HStack(spacing: 6) {
                if tab == .breed && fish.locked { lockedBadge }
                if isSelected { PixelIcon("check", color: gold) }
            }.padding(8).allowsHitTesting(false)
        }.overlay(alignment: .topTrailing) { if inTank { displayedBadge.padding(8).allowsHitTesting(false) } }
    }

    private var lockedBadge: some View {
        PixelIcon("lock", color: PixelTheme.ink).frame(width: 16, height: 16).padding(4)
            .background(PixelOutline(cut: 3).fill(gold))
            .overlay(PixelOutline(cut: 3).stroke(PixelTheme.ink, lineWidth: 1))
            .accessibilityLabel(L10n.text("Locked"))
            .help(L10n.text("Locked fish can still breed. Unlock them on the Fish tab."))
            .accessibilityIdentifier("fish.locked")
    }

    @ViewBuilder private func fishStatus(_ fish: AquariumFish) -> some View {
        Group {
            if let deadline = fish.maturesAt, deadline > store.now {
                let color = fish.expBanked ? Color(hex: 0xB9A0E8) : PixelTheme.gold
                HStack(spacing: 6) {
                    Text(fish.expBanked ? L10n.text("Cooldown [badge]") : L10n.text("Juvenile"))
                        .foregroundStyle(PixelTheme.ink).fixedSize(horizontal: true, vertical: false)
                        .padding(.horizontal, 6).padding(.vertical, 3)
                        .background(PixelOutline(cut: 3).fill(color))
                        .overlay(PixelOutline(cut: 3).stroke(PixelTheme.ink, lineWidth: 1).allowsHitTesting(false))
                    Spacer(minLength: 0)
                    Text(countdown(deadline)).foregroundStyle(color).fixedSize(horizontal: true, vertical: false)
                }
            } else {
                Text(status(fish))
                    .foregroundStyle(fish.canBreed(at: store.now) ? PixelTheme.green : PixelTheme.muted)
                    .lineLimit(1).frame(maxWidth: .infinity, alignment: .leading)
            }
        }.font(PixelTheme.captionFont()).frame(height: PixelTheme.metric(24, 30))
            .accessibilityElement(children: .ignore).accessibilityLabel(status(fish))
            .accessibilityIdentifier("fish.status")
    }

    private var displayedBadge: some View {
        HStack(spacing: 4) {
            PixelIcon("eye", color: PixelTheme.ink)
            Text(L10n.text("Displayed")).font(PixelTheme.captionFont()).foregroundStyle(PixelTheme.ink)
        }.padding(.horizontal, 6).padding(.vertical, 2)
            .background(PixelOutline().fill(PixelTheme.green))
            .overlay(PixelOutline().stroke(PixelTheme.ink, lineWidth: 1))
            .accessibilityElement(children: .combine)
            .accessibilityIdentifier("fish.displayed")
    }

    private func breedingHearts(_ fish: AquariumFish) -> some View {
        HStack(spacing: 6) {
            Text(L10n.text("Breed")).foregroundStyle(PixelTheme.muted)
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
            .accessibilityLabel(fish.tier == 0 ? L10n.text("Unlimited breedings") : L10n.text("\(fish.uses) of \(fish.maxUses) breedings remaining"))
            .help(fish.tier == 0 ? L10n.text("Unlimited breedings") : L10n.text("Filled hearts show remaining uses; empty hearts show used ones."))
    }

    private var bookContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(L10n.text("Ocean Catalog")).font(PixelTheme.font(24))
            #if os(iOS)
            Text(L10n.text("Discovered \(store.state.regularDiscoveredCount)/29 species · Grade variants \(store.state.regularVariantCount)/\(FishCatalog.regular.reduce(0) { $0 + ($1.tier == 0 ? 1 : 5) }). Releasing or synthesizing fish will not erase collection records."))
                .font(PixelTheme.font()).foregroundStyle(PixelTheme.muted)
            #endif
            if store.state.hiddenDiscoveredCount > 0 {
                Text(L10n.text("Hidden discoveries \(store.state.hiddenDiscoveredCount)/3")).font(PixelTheme.captionFont()).foregroundStyle(gold)
            }
            LazyVGrid(columns: columns, spacing: 12) {
                ForEach(store.state.catalogSpecies) { species in
                    let found = store.state.discovered.contains(species.id)
                    let displayedCount = store.state.tankFish.filter { $0.speciesID == species.id }.count
                    VStack(alignment: .leading, spacing: 10) {
                        catalogPortrait(species, grade: 1, revealed: found).frame(height: 68).frame(maxWidth: .infinity)
                            .accessibilityHidden(true)
                        Text(found ? species.name : "???").font(PixelTheme.font())
                        Text(species.tier == 0 ? L10n.text("Starter [fish]") : String(repeating: "★", count: species.tier))
                            .font(PixelTheme.font()).foregroundStyle(gold)
                        HStack(spacing: 5) {
                            ForEach(1...(species.tier == 0 ? 1 : 5), id: \.self) { grade in
                                let owned = found && store.state.discoveredVariants.contains("\(species.id):\(grade)")
                                VStack(spacing: 3) {
                                    catalogPortrait(species, grade: grade, revealed: owned).frame(height: 20).accessibilityHidden(true)
                                    Text("\(grade)").font(PixelTheme.font())
                                }.accessibilityLabel(L10n.text("Grade \(grade), \(owned ? L10n.text("Collected") : L10n.text("Not Collected"))"))
                            }
                        }
                        HStack(spacing: 4) {
                            Text(L10n.text("Owned: \(store.state.fish.filter { $0.speciesID == species.id }.count)")).foregroundStyle(PixelTheme.muted)
                            Spacer(minLength: 0)
                            if displayedCount > 0 { Text(L10n.text("Display \(displayedCount)")).foregroundStyle(PixelTheme.green) }
                        }.font(PixelTheme.font())
                    }.padding(14).frame(maxWidth: .infinity, alignment: .leading)
                        .background(PixelOutline().fill(Color(hex: 0x304C5B)))
                        .overlay { PixelOutline().stroke(Color(hex: 0x56727F), lineWidth: 1).allowsHitTesting(false) }
                        .accessibilityElement(children: .contain)
                        .accessibilityIdentifier("catalog.entry." + (found ? species.id : String(FishCatalog.regular.firstIndex { $0.id == species.id } ?? 0)))
                }
            }
        }
    }

    private func outcomeView(_ result: FishOutcome) -> some View {
        VStack(spacing: 20) {
            Text(result.child.species.hidden && result.novel ? L10n.text("A mysterious companion appears") : result.novel ? L10n.text("Discover a new ocean friend") : L10n.text("A new fish is born")).font(PixelTheme.font(24)).foregroundStyle(gold)
            portrait(result.child.species, grade: result.child.grade).frame(width: 192, height: 144)
            if result.child.species.hidden { Text(L10n.text("Hidden Creature")).foregroundStyle(gold) }
            if result.guaranteed { Text(L10n.text("New hidden species guaranteed")).font(PixelTheme.captionFont()).foregroundStyle(PixelTheme.green) }
            VStack(spacing: 10) {
                if result.novel || result.novelVariant {
                    PixelDiscoveryBadge(newSpecies: result.novel)
                }
                Text(result.child.name).font(PixelTheme.font(24))
            }
            Text(L10n.text("\(result.child.tier)★ · Grade \(result.child.grade)"))
            breedingHearts(result.child)
            Text(L10n.text("Grows in \(Int(FishBalance.growth[result.child.tier] / 60)) minutes\(result.expGained > 0 ? L10n.text(" · Birth XP +\(result.expGained)") : "")"))
                .font(PixelTheme.font()).foregroundStyle(PixelTheme.muted)
            Button(L10n.text("Keep Fish")) { store.outcome = nil }.buttonStyle(PixelButtonStyle(primary: true))
                .keyboardShortcut(.defaultAction)
        }.padding(32).frame(minWidth: 280)
            .font(PixelTheme.font()).foregroundStyle(PixelTheme.text)
            .background(PixelTheme.panel).pixelPanel()
            .onAppear { store.sound.play("reveal", tier: result.child.tier) }
            .preferredColorScheme(.dark)
    }

    @ViewBuilder private func catalogPortrait(_ species: FishSpecies, grade: Int, revealed: Bool) -> some View {
        if revealed { portrait(species, grade: grade) }
        else {
            Image(decorative: PixelArt.image(species: species, grade: grade), scale: 1)
                .renderingMode(.template).interpolation(.none).resizable().scaledToFit().foregroundStyle(Color.black)
        }
    }

    private func portrait(_ species: FishSpecies, grade: Int) -> some View {
        Image(decorative: PixelArt.image(species: species, grade: grade), scale: 1)
            .interpolation(.none).resizable().scaledToFit()
    }
    private func status(_ fish: AquariumFish) -> String {
        if let date = fish.maturesAt, date > store.now {
            return L10n.text("\(fish.expBanked ? L10n.text("Cooldown") : L10n.text("Growth")) · \(countdown(date))")
        }
        return fish.canBreed(at: store.now) ? L10n.text("Adult · Can breed") : L10n.text("Adult · Used up")
    }
    private func countdown(_ date: Date) -> String {
        let seconds = max(0, Int(ceil(date.timeIntervalSince(store.now))))
        return String(format: "%02d:%02d", seconds / 60, seconds % 60)
    }
}

private extension AquariumView {
    var chrome: some View {
        #if os(macOS)
        PixelWindowChrome(title: L10n.text("Fishtank / Pocket Ocean"), closeLabel: L10n.text("Close Care Guide"), bottomSpacing: 0) { NSApp.keyWindow?.close() }
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
                        Text(item.title)
                    }
                }.buttonStyle(PixelTabStyle(selected: tab == item, edge: .bottom))
                    .keyboardShortcut(KeyEquivalent(Character(String((AquariumTab.allCases.firstIndex(of: item) ?? 0) + 1))), modifiers: .command)
                    .accessibilityLabel(item.title)
                    .accessibilityAddTraits(tab == item ? .isSelected : [])
            }
        }
        .padding(.horizontal, 12).padding(.bottom, 8)
        .overlay(alignment: .top) {
            ZStack(alignment: .topLeading) {
                Rectangle().fill(PixelTheme.panel)
                GeometryReader { geometry in
                    let count = CGFloat(AquariumTab.allCases.count)
                    let tabWidth = max(0, (geometry.size.width - 24 - 6 * (count - 1)) / count)
                    let index = CGFloat(AquariumTab.allCases.firstIndex(of: tab) ?? 0)
                    let start = 12 + index * (tabWidth + 6)
                    Path { path in
                        path.move(to: CGPoint(x: 0, y: 0.5))
                        path.addLine(to: CGPoint(x: start, y: 0.5))
                        path.move(to: CGPoint(x: start + tabWidth, y: 0.5))
                        path.addLine(to: CGPoint(x: geometry.size.width, y: 0.5))
                    }.stroke(PixelTheme.shell, lineWidth: 1)
                }
            }.frame(height: 2).allowsHitTesting(false).accessibilityHidden(true)
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
                    Text(item.title).fixedSize(horizontal: true, vertical: false)
                }.frame(minWidth: 48, maxWidth: .infinity)
            }.buttonStyle(PixelButtonStyle(primary: tab == item, compact: PixelTheme.isPad))
                .keyboardShortcut(KeyEquivalent(Character(String((AquariumTab.allCases.firstIndex(of: item) ?? 0) + 1))), modifiers: .command)
                .accessibilityLabel(item.title)
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
                Button(PixelTheme.isPad ? L10n.text("Species \(store.state.regularDiscoveredCount)/29") : L10n.text("Species")) { showingMedals = false }
                    .buttonStyle(PixelButtonStyle(primary: !showingMedals))
                Button(PixelTheme.isPad ? L10n.text("Medals \(store.state.earnedAchievements.count)/\(AchievementCatalog.all.count)") : L10n.text("Medals")) { showingMedals = true }
                    .buttonStyle(PixelButtonStyle(primary: showingMedals))
                Spacer()
            }
            if showingMedals { medalsContent } else { bookContent }
        }
    }

    var decorContent: some View {
        VStack(alignment: .leading, spacing: PixelTheme.metric(14, 18)) {
            #if os(macOS)
            Text(L10n.text("Decorate a little seabed")).font(PixelTheme.font(18)).foregroundStyle(gold)
                .frame(maxWidth: .infinity, alignment: .leading)
            #else
            HStack {
                Text(L10n.text("Decorate a little seabed")).font(PixelTheme.font(24)).foregroundStyle(gold)
                Spacer()
                Text(L10n.text("\(store.state.decorations.count)/\(store.state.capacity) slots")).foregroundStyle(PixelTheme.muted)
            }
            PixelAquariumPreview(scene: scene, store: store, paused: scenePaused)
                .frame(maxWidth: 640).frame(maxWidth: .infinity)
            Text(L10n.text("Drag scenery directly in the aquarium to reposition it. Hanging lights and seabed scenery share slots; medals use none."))
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
                                    Text(item.top ? L10n.text("Hanging") : L10n.text("Seabed")).foregroundStyle(PixelTheme.muted)
                                    Spacer()
                                    if !unlocked { PixelIcon("lock") }
                                }.frame(height: PixelTheme.metric(20, 24))
                                Image(decorative: DecorArt.image(item), scale: 1).interpolation(.none).resizable()
                                    .aspectRatio(item.displayAspectRatio, contentMode: .fit)
                                    .padding(6).frame(height: PixelTheme.metric(64, 76)).frame(maxWidth: .infinity).opacity(unlocked ? 1 : 0.3)
                                    .background(PixelSpecimenWell())
                                Text(item.name).foregroundStyle(PixelTheme.text).lineLimit(2).frame(height: PixelTheme.metric(L10n.language == .english ? 38 : 28, 24), alignment: .topLeading)
                                Text(unlocked ? (placed == nil ? L10n.text("Unlocked") : L10n.text("Drag to reposition")) : L10n.text("Unlocks at Lv.\(item.unlockLevel)"))
                                    .foregroundStyle(unlocked ? PixelTheme.green : PixelTheme.muted)
                                    .lineLimit(1).frame(height: PixelTheme.metric(16, 24), alignment: .leading)
                                Spacer(minLength: PixelTheme.metric(40, 52))
                            }.padding(PixelTheme.metric(12, 14)).frame(maxWidth: .infinity, alignment: .leading).frame(height: PixelTheme.metric(L10n.language == .english ? 240 : 224, 300))
                                .pixelCard(displayed: placed != nil).contentShape(Rectangle())
                        }.buttonStyle(.plain).disabled(!unlocked)
                            .accessibilityIdentifier("decor.card." + item.id)
                            .accessibilityLabel(placed == nil ? L10n.text("Place \(item.name)") : L10n.text("Store \(item.name)"))
                            .accessibilityValue(placed == nil ? L10n.text("Not Displayed") : L10n.text("Displayed"))
                        Button(L10n.text("Flip")) { store.flipDecoration(item.id) }.disabled(placed == nil)
                            .buttonStyle(PixelButtonStyle(compact: true)).padding(14)
                            .accessibilityLabel(L10n.text("Flip \(item.name)"))
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
            Text(L10n.text("Every encounter is worth remembering.")).font(PixelTheme.font(24)).foregroundStyle(gold)
            #if os(iOS)
            Text(L10n.text("\(AchievementCatalog.all.count) permanent achievements. Synthesis and release never erase earned records. Display several at once."))
                .foregroundStyle(PixelTheme.muted)
            HStack {
                Button(L10n.text("Display All")) { store.displayAchievements(AchievementCatalog.all.map(\.id).filter { store.state.earnedAchievements.contains($0) }) }
                    .disabled(store.state.earnedAchievements.isEmpty)
                Button(L10n.text("Remove All")) { store.displayAchievements([]) }.disabled(store.state.displayedAchievements.isEmpty)
                Spacer()
                Text(L10n.text("Display \(store.state.displayedAchievements.count) [medals]")).foregroundStyle(PixelTheme.muted)
            }
            #endif
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
                                .frame(height: PixelTheme.metric(L10n.language == .english ? 48 : 40, 60), alignment: .topLeading)
                            PixelMeter(value: Double(progress.unlocked ? item.total : progress.current), total: Double(item.total), color: gold)
                            Text(progress.unlocked ? L10n.text("Earned Permanently") : "\(progress.current)/\(item.total)").foregroundStyle(PixelTheme.muted)
                                .frame(height: PixelTheme.metric(16, 24), alignment: .leading)
                        }.padding(14).frame(maxWidth: .infinity, alignment: .leading)
                            .pixelCard(displayed: displayed).contentShape(Rectangle())
                    }.buttonStyle(.plain).disabled(!progress.unlocked)
                        .accessibilityIdentifier("medal.card." + item.id)
                        .accessibilityLabel(displayed ? L10n.text("Remove \(item.title)") : L10n.text("Display \(item.title) [medal action]"))
                        .accessibilityValue(progress.unlocked ? (displayed ? L10n.text("Displayed") : L10n.text("Not Displayed")) : L10n.text("Not Earned"))
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
                    Text(L10n.text("App Settings")).foregroundStyle(gold)
                    Text(L10n.text("Manage integrations, bubbles, and alert sounds")).foregroundStyle(PixelTheme.muted)
                }
                Spacer()
                Button(L10n.text("Open Settings…")) { openAgentSettings?() }.disabled(openAgentSettings == nil)
            }.padding(16).pixelPanel()
            #endif
            Text(L10n.text("Sound and Sea Color")).font(PixelTheme.font(24)).foregroundStyle(gold)
            #if os(iOS)
            LanguageSettingsView().padding(16).pixelPanel()
            #endif
            VStack(alignment: .leading, spacing: 10) {
                audioRow(L10n.text("Action Sounds"), volumeTitle: L10n.text("Sound Effects Volume"), enabled: \.sfxEnabled, volume: \.sfxVolume)
                audioRow(L10n.text("Background Music"), volumeTitle: L10n.text("Music Volume"), enabled: \.musicEnabled, volume: \.musicVolume)
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 8) { musicChoices; Spacer(minLength: 12); soundPreviewButton }
                    VStack(alignment: .leading, spacing: 8) {
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: PixelTheme.metric(L10n.language == .english ? 180 : 140, 210)), spacing: 8)], spacing: 8) { musicChoices }
                        soundPreviewButton
                    }
                }
            }.frame(maxWidth: .infinity, alignment: .leading).padding(16).pixelPanel()
            VStack(alignment: .leading, spacing: 10) {
                Text(L10n.text("Aquarium Lighting")).foregroundStyle(gold)
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
                Text(L10n.text("Auto mode uses the night scene from 19:00–07:00 local time. Hanging lights show pixel lights at night."))
                    .foregroundStyle(PixelTheme.muted)
            }.frame(maxWidth: .infinity, alignment: .leading).padding(16).pixelPanel()
            SavedGamePanel(store: store)
            Toggle(L10n.text("Growth / Cooldown / Full-Heart Alerts"), isOn: Binding(get: { store.remindersEnabled }, set: { store.setReminders($0) }))
            VStack(alignment: .leading, spacing: 12) {
                Text(L10n.text("Care Tips")).foregroundStyle(gold)
                Text(L10n.text("One heart restores every 7 minutes, up to 5. Fish grow while offline, and adult XP is awarded only once. Feeding affects only the viewing animation."))
                Text(L10n.text("Tap a fish to startle it. Pufferfish puff up, and electric eels have a temper of their own. Fish of the same species may school, while seahorses rest against seagrass."))
                Text(L10n.text("Sound effects and music are controlled separately and begin after your first interaction. iPad pauses audio in the background and respects Silent Mode."))
                #if os(iOS)
                Text(L10n.text("Progress is saved locally. Decoration positions, volume, and permanent achievements stay with the save. Original web JSON can be imported; cloud sync is not currently available."))
                #endif
            }.font(PixelTheme.captionFont()).foregroundStyle(PixelTheme.muted).frame(maxWidth: .infinity, alignment: .leading).padding(16).pixelPanel()
            VStack(alignment: .leading, spacing: 12) {
                Text(L10n.text("About This Ocean")).foregroundStyle(gold)
                Text("Fishtank " + (Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? ""))
                Text(L10n.text("Keyboard: ⌘1–⌘6 switches pages; Return confirms dialogs and Esc cancels. On Mac, fish keep growing when the aquarium is hidden from the menu bar."))
                Text(L10n.text("This game does not connect to the internet or collect personal data. Progress stays on this device; you are responsible for exported files. Notifications are opt-in and can be turned off anytime."))
                Text(L10n.text("Code and original pixel art are licensed under MIT. The Fusion Pixel Chinese font is licensed under SIL Open Font License 1.1. Full licenses are included with the app."))
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
                .accessibilityValue(store.state.audio.track == track.rawValue ? L10n.text("Selected") : L10n.text("Not Selected"))
        }
    }
    var soundPreviewButton: some View {
        Button(L10n.text("Preview Sound")) { store.sound.play("reveal", tier: 3) }.buttonStyle(PixelButtonStyle(compact: true))
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
        Toggle(L10n.text("Twinkling Lights"), isOn: Binding(get: { store.state.railLights.animated }, set: {
            var config = store.state.railLights; config.animated = $0; store.setRailLights(config)
        })).fixedSize(horizontal: true, vertical: false)
    }
    var railSpeedControl: some View {
        HStack(spacing: 8) {
            Text(L10n.text("Shimmer Speed")).foregroundStyle(PixelTheme.muted)
            Button("-") { var config = store.state.railLights; config.frequency = max(0.2, (config.frequency * 10 - 1).rounded() / 10); store.setRailLights(config) }
                .accessibilityLabel(L10n.text("Decrease shimmer speed"))
            Text(String(format: "%.1f Hz", store.state.railLights.frequency)).frame(width: PixelTheme.metric(48, 72))
            Button("+") { var config = store.state.railLights; config.frequency = min(2, (config.frequency * 10 + 1).rounded() / 10); store.setRailLights(config) }
                .accessibilityLabel(L10n.text("Increase shimmer speed"))
        }.buttonStyle(PixelButtonStyle(compact: true, fixedWidth: 48)).fixedSize(horizontal: true, vertical: false)
    }
    func volumeControl(_ title: String, key: WritableKeyPath<AquariumAudio, Double>) -> some View {
        HStack(spacing: 8) {
            Button("-") { var config = store.state.audio; config[keyPath: key] = max(0, config[keyPath: key] - 0.1); store.setAudio(config) }
                .accessibilityLabel(L10n.text("Decrease \(title)"))
            PixelMeter(value: store.state.audio[keyPath: key], total: 1)
                .frame(minWidth: 24).accessibilityLabel(title)
            Text("\(Int((store.state.audio[keyPath: key] * 100).rounded()))%")
                .frame(width: 40)
            Button("+") { var config = store.state.audio; config[keyPath: key] = min(1, config[keyPath: key] + 0.1); store.setAudio(config) }
                .accessibilityLabel(L10n.text("Increase \(title)"))
        }.buttonStyle(PixelButtonStyle(compact: true, fixedWidth: 48))
    }
}

/// Keep each reason and count together while allowing translated chips to wrap.
private struct MaterialReasonLayout: Layout {
    var spacing: CGFloat

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        arrangement(width: proposal.width, subviews: subviews).size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let layout = arrangement(width: bounds.width, subviews: subviews)
        for index in subviews.indices {
            let rect = layout.frames[index]
            subviews[index].place(at: CGPoint(x: bounds.minX + rect.minX, y: bounds.minY + rect.minY),
                                  anchor: .topLeading, proposal: ProposedViewSize(rect.size))
        }
    }

    private func arrangement(width: CGFloat?, subviews: Subviews) -> (size: CGSize, frames: [CGRect]) {
        let limit = width.flatMap { $0.isFinite ? max(0, $0) : nil } ?? .greatestFiniteMagnitude
        var frames: [CGRect] = []
        var x: CGFloat = 0, y: CGFloat = 0, rowHeight: CGFloat = 0, right: CGFloat = 0
        for item in subviews {
            let size = item.sizeThatFits(ProposedViewSize(width: limit, height: nil))
            if x > 0 && x + size.width > limit {
                x = 0; y += rowHeight + spacing; rowHeight = 0
            }
            frames.append(CGRect(origin: CGPoint(x: x, y: y), size: size))
            right = max(right, x + size.width)
            x += size.width + spacing; rowHeight = max(rowHeight, size.height)
        }
        return (CGSize(width: min(limit, right), height: y + rowHeight), frames)
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
            .accessibilityLabel(L10n.text("Pixel aquarium with \(store.state.tankIDs.count) fish and \(store.state.decorations.count) decorations. Decorations can be dragged."))
    }
}
