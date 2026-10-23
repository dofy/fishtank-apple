import Foundation
import Combine
import UserNotifications

@MainActor
final class AquariumStore: NSObject, ObservableObject, UNUserNotificationCenterDelegate {
    @Published private(set) var state: AquariumState
    @Published private(set) var now = Date()
    @Published var message = L10n.text("Raise a tiny ocean and slowly collect every color.")
    @Published var outcome: FishOutcome?
    @Published var achievementToast: String?
    let sound = AquariumSound()
    @Published private(set) var remindersEnabled: Bool
    private let fileURL: URL
    private let repository: AquariumRepository
    private var timer: AnyCancellable?
    private var localizationObserver: AnyCancellable?
    private var reminderTask: Task<Void, Never>?
    private var authorizationTask: Task<Void, Never>?
    private var notificationAuthorization: Task<Bool, Error>?
    private static let reminderIDs = AquariumReminder.Kind.allCases.map(\.rawValue)
    private var reminderGeneration = UUID().uuidString
    private var scheduledReminders: [String: AquariumReminder] = [:]
    private var lastSavedAt = Date.distantPast

    var adultCount: Int { state.fish.filter { $0.expBanked || $0.isAdult(at: now) }.count }

    override init() {
        var directory = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("FishtankApplePrototype", isDirectory: true)
        #if DEBUG
        if let testID = ProcessInfo.processInfo.environment["FISHTANK_UI_TEST_ID"], UUID(uuidString: testID) != nil {
            directory = FileManager.default.temporaryDirectory.appendingPathComponent("FishtankUITests-" + testID)
        }
        #endif
        fileURL = directory.appendingPathComponent("aquarium-v1.json")
        repository = AquariumRepository(primary: fileURL)
        remindersEnabled = UserDefaults.standard.bool(forKey: "remindersEnabled")
        state = .newGame(at: Date())
        super.init()
        if FileManager.default.fileExists(atPath: fileURL.path) {
            do {
                let data = try repository.read(fileURL)
                let loaded = try AquariumSave.decode(data)
                #if os(macOS)
                if ProcessInfo.processInfo.arguments.contains("--verify-update") {
                    let backup = fileURL.appendingPathExtension("before-update-" + UUID().uuidString + ".json")
                    try data.write(to: backup, options: .atomic)
                }
                #endif
                if let header = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let version = header["version"] as? Int, version < 3 {
                    let backup = fileURL.appendingPathExtension(version == 1 ? "prototype-backup" : "schema-2-backup")
                    if !FileManager.default.fileExists(atPath: backup.path) {
                        try FileManager.default.copyItem(at: fileURL, to: backup)
                    }
                }
                state = loaded
            } catch {
                // Preserve the unreadable file and never overwrite it with a fresh game.
                state = .newGame(at: Date())
                message = L10n.text("The save could not be read, so the original file was preserved. This is only a temporary preview.")
                persistenceBlocked = true
            }
        } else {
            state = .newGame(at: Date())
            #if DEBUG
            if ProcessInfo.processInfo.environment["FISHTANK_UI_TEST_ID"].flatMap(UUID.init(uuidString:)) != nil,
               ProcessInfo.processInfo.environment["FISHTANK_UI_TEST_SCENARIO"] == "reminder" {
                var child = AquariumFish.make(species: FishCatalog.byID["copperband"]!, at: Date())
                child.maturesAt = Date().addingTimeInterval(35)
                state.fish.append(child)
                state.discovered.insert(child.speciesID)
                state.discoveredVariants.insert(child.speciesID + ":1")
            }
            if ProcessInfo.processInfo.environment["FISHTANK_UI_TEST_ID"].flatMap(UUID.init(uuidString:)) != nil,
               ProcessInfo.processInfo.environment["FISHTANK_UI_TEST_SCENARIO"] == "merge" {
                for index in 0..<11 {
                    var material = AquariumFish.make(species: FishCatalog.byID["copperband"]!,
                        grade: index == 10 ? 5 : index == 0 ? 4 : 1, at: Date(), adult: true)
                    material.uses = 0; material.locked = index == 10
                    state.fish.append(material)
                    state.discoveredVariants.insert("copperband:\(material.grade)")
                }
                state.discovered.insert("copperband")
                state.syncAchievements()
            }
            #endif
        }
        let center = UNUserNotificationCenter.current()
        center.delegate = self
        // Remove requests and banners left by an earlier app session/build.
        center.removeAllPendingNotificationRequests()
        center.removeAllDeliveredNotifications()
        refresh()
        sound.reportError = { [weak self] in self?.message = $0 }
        sound.configure(state.audio)
        timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
            .sink { [weak self] _ in self?.refresh() }
        localizationObserver = NotificationCenter.default.publisher(for: .aquariumLanguageDidChange).sink { [weak self] _ in
            self?.rescheduleReminders()
        }
        rescheduleReminders()
    }

    private var persistenceBlocked = false

    func refresh() {
        now = max(Date(), state.lastUpdated)
        let previousExp = state.exp, previousHearts = state.hearts
        state.advance(to: now)
        if state.exp != previousExp || state.hearts != previousHearts || now.timeIntervalSince(lastSavedAt) >= 15 { save() }
    }

    func save() {
        guard !persistenceBlocked else { return }
        do {
            try persist(state)
        } catch {
            message = L10n.text("Save failed: \(error.localizedDescription)")
        }
    }

    private func persist(_ state: AquariumState) throws {
        guard state.isValid else { throw AquariumError.invalidSave }
        try repository.persist(state)
        lastSavedAt = now
    }

    var recoveryURLs: [(String, URL)] { [(L10n.text("Recent Auto-Backup"), repository.recent), (L10n.text("Save Before Import"), repository.preRestore)] }
    var isPreviewOnly: Bool { persistenceBlocked }
    func exportBackup() throws -> Data {
        guard !persistenceBlocked else { throw AquariumError.invalidSave }
        refresh()
        return try AquariumBackup.export(state)
    }
    func previewImport(_ url: URL) throws -> AquariumState {
        let access = url.startAccessingSecurityScopedResource()
        defer { if access { url.stopAccessingSecurityScopedResource() } }
        return try AquariumBackup.parse(repository.read(url))
    }
    func importBackup(_ imported: AquariumState) -> Bool {
        do {
            var candidate = imported
            let timestamp = max(Date(), candidate.lastUpdated)
            candidate.advance(to: timestamp)
            try repository.persist(candidate, replacing: true)
            persistenceBlocked = false; now = timestamp; lastSavedAt = timestamp
            state = candidate; outcome = nil; achievementToast = nil
            sound.configure(candidate.audio)
            rescheduleReminders()
            message = L10n.text("Save imported. The previous file was preserved and can be recovered from Restore.")
            return true
        } catch { message = L10n.text("Import failed. Current progress was not replaced: \(error.localizedDescription)"); return false }
    }

    private func commit(_ operation: (inout AquariumState) throws -> Void) -> Bool {
        guard !persistenceBlocked else { message = L10n.text("The save file is not writable. The action was blocked to protect your progress."); return false }
        refresh()
        do {
            var candidate = state
            try operation(&candidate)
            candidate.syncAchievements()
            try persist(candidate)
            let earned = candidate.earnedAchievements.subtracting(state.earnedAchievements)
            state = candidate
            if let id = AchievementCatalog.all.first(where: { earned.contains($0.id) })?.id {
                achievementToast = AchievementCatalog.all.first { $0.id == id }?.title
            }
            rescheduleReminders()
            return true
        } catch {
            message = error.localizedDescription
            sound.play("error")
            return false
        }
    }

    func breed(_ ids: [UUID]) -> Bool {
        var result: FishOutcome?
        let success = commit { state in
            var random = state.random
            result = try state.breed(ids, at: now, random: &random)
            state.random = random
        }
        if success, let result {
            outcome = result
            message = L10n.text("Breeding complete: \(result.child.name). Gained \(result.expGained) XP.")
            sound.play("breed")
        }
        return success
    }

    func merge(_ ids: [UUID]) -> Bool {
        var result: FishOutcome?
        let success = commit { state in
            var random = state.random
            result = try state.merge(ids, at: now, random: &random)
            state.random = random
        }
        if success, let result {
            outcome = result
            message = L10n.text("Synthesis complete: \(result.child.tier)-star \(result.child.name), inheriting grade \(result.child.grade).")
            sound.play("merge")
        }
        return success
    }

    func reforge(_ ids: [UUID]) -> Bool {
        var result: FishOutcome?
        let success = commit { state in
            var random = state.random
            result = try state.reforge(ids, at: now, random: &random)
            state.random = random
        }
        if success, let result {
            outcome = result
            message = L10n.text("Reforged: \(result.child.name) · Grade \(result.child.grade) inherited.")
            sound.play("merge")
        }
        return success
    }

    func toggleTank(_ id: UUID) { if commit({ try $0.toggleTank(id) }) { message = L10n.text("Aquarium display updated."); sound.play("place") } }
    func setLocked(_ id: UUID, _ locked: Bool) { if commit({ $0.setLocked(id, locked) }) { message = locked ? L10n.text("Locked for protection.") : L10n.text("Unlocked."); sound.play("select") } }
    /// A fish lost to repeated shaking. Collection records stay, like a release.
    func loseToShaking(_ id: UUID) {
        guard let victim = state.fish.first(where: { $0.id == id }) else { return }
        if commit({ $0.removeShakeCasualty(id) }) {
            message = L10n.text("\(victim.name) could not take the shaking and floated to the surface.")
            sound.play("release")
        }
    }

    func release(_ id: UUID) { if commit({ try $0.release(id) }) { message = L10n.text("Released. Collection records were preserved."); sound.play("release") } }
    func setMergePreferences(_ preferences: MergePreferences) { _ = commit { $0.mergePreferences = preferences } }

    func toggleDecoration(_ id: String) {
        if commit({ try $0.toggleDecoration(id) }) { message = L10n.text("Decorations updated."); sound.play("place") }
    }
    func moveDecoration(_ id: String, to x: Double) {
        if commit({ try $0.moveDecoration(id, to: x) }) { message = L10n.text("Decoration positions saved.") }
    }
    func flipDecoration(_ id: String) {
        if commit({ try $0.flipDecoration(id) }) { sound.play("select") }
    }
    func displayAchievements(_ ids: [String]) {
        if commit({ try $0.setDisplayedAchievements(ids) }) { message = L10n.text("Medal display updated."); sound.play("place") }
    }
    func setAudio(_ config: AquariumAudio) {
        if commit({ $0.audio = config }) { sound.configure(config); sound.interact() }
    }
    func setRailLights(_ config: AquariumRailLights) { _ = commit { $0.railLights = config } }
    func setLighting(_ lighting: AquariumLighting) { _ = commit { $0.lighting = lighting } }

    private func ensureNotificationAuthorization() async throws -> Bool {
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()
        if settings.authorizationStatus != .notDetermined {
            return settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional
        }
        if let pending = notificationAuthorization { return try await pending.value }
        let pending = Task { try await center.requestAuthorization(options: [.alert, .sound]) }
        notificationAuthorization = pending
        defer { notificationAuthorization = nil }
        return try await pending.value
    }

    func setReminders(_ enabled: Bool) {
        authorizationTask?.cancel()
        reminderTask?.cancel()
        if !enabled {
            remindersEnabled = false
            UserDefaults.standard.set(false, forKey: "remindersEnabled")
            UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
            UNUserNotificationCenter.current().removeAllDeliveredNotifications()
            message = L10n.text("Alerts Off")
            return
        }
        authorizationTask = Task {
            do {
                let allowed = try await ensureNotificationAuthorization()
                guard !Task.isCancelled else { return }
                remindersEnabled = allowed
                UserDefaults.standard.set(allowed, forKey: "remindersEnabled")
                message = allowed ? L10n.text("Growth, cooldown, and full-heart alerts enabled") : L10n.text("Notifications are not authorized. Enable them in System Settings.")
                rescheduleReminders()
            } catch {
                message = L10n.text("Notification setup failed: \(error.localizedDescription)")
            }
        }
    }

    func rescheduleReminders() {
        // Invalidate before asynchronous cancellation: a queued old banner must
        // never claim five hearts after another breeding operation spent one.
        reminderGeneration = UUID().uuidString
        scheduledReminders = [:]
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: Self.reminderIDs)
        center.removeDeliveredNotifications(withIdentifiers: Self.reminderIDs)
        let previous = reminderTask
        previous?.cancel()
        reminderTask = Task {
            // A cancelled add can finish after a new schedule. Complete its cleanup
            // before replacing requests, so it cannot remove the newer request IDs.
            await previous?.value
            guard !Task.isCancelled else { return }
            await scheduleReminders()
        }
    }

    private func scheduleReminders() async {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: Self.reminderIDs)
        guard remindersEnabled, !persistenceBlocked, !Task.isCancelled else { return }
        do {
            guard try await ensureNotificationAuthorization() else { return }
        } catch { message = L10n.text("Notification setup failed: \(error.localizedDescription)"); return }
        guard !Task.isCancelled, remindersEnabled else { return }
        refresh()
        let generation = reminderGeneration
        for event in AquariumReminder.scheduled(in: state, at: now) {
            guard !Task.isCancelled, generation == reminderGeneration else { return }
            let id = event.kind.rawValue
            scheduledReminders[id] = event
            let content = UNMutableNotificationContent()
            content.title = event.title
            content.body = event.body
            content.sound = .default
            content.userInfo = ["generation": generation]
            let components = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute, .second], from: Date(timeIntervalSince1970: ceil(event.date.timeIntervalSince1970)))
            // Absolute deadlines do not drift while async scheduling is suspended.
            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
            do {
                try await center.add(UNNotificationRequest(identifier: id, content: content, trigger: trigger))
                if Task.isCancelled {
                    center.removePendingNotificationRequests(withIdentifiers: [id])
                    return
                }
            } catch {
                message = L10n.text("Could not schedule alert: \(error.localizedDescription)")
            }
        }
    }
    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        let id = notification.request.identifier
        let generation = notification.request.content.userInfo["generation"] as? String
        Task { @MainActor [weak self] in
            guard let self else { completionHandler([]); return }
            if id == "fishtank.test" { completionHandler([.banner, .sound]); return }
            self.refresh()
            guard self.remindersEnabled, generation == self.reminderGeneration,
                  let event = self.scheduledReminders[id], event.isSatisfied(in: self.state, at: self.now) else {
                center.removeDeliveredNotifications(withIdentifiers: [id])
                completionHandler([])
                return
            }
            completionHandler([.banner, .sound])
        }
    }

    #if os(macOS)
    func restoreMigratedPlacementOnce() {
        let defaults = UserDefaults.standard
        guard !defaults.bool(forKey: "aquarium.installationPlacementRestored") else { return }
        let transfer = fileURL.deletingLastPathComponent().appendingPathComponent("installation-transfer.json")
        guard FileManager.default.fileExists(atPath: transfer.path),
              let data = try? repository.read(transfer),
              let snapshot = try? AquariumInstallation.decode(data) else { return }
        if let frame = snapshot.preferences.floatingFrame {
            defaults.set(frame, forKey: "NSWindow Frame FishtankFloatingAquarium")
        }
        defaults.set(true, forKey: "aquarium.installationPlacementRestored")
    }

    func installationSnapshot() throws -> AquariumInstallation {
        guard !persistenceBlocked else { throw AquariumError.invalidSave }
        refresh()
        var recovery: [String: Data] = [:]
        for name in AquariumInstallation.recoveryNames {
            let url = fileURL.deletingLastPathComponent().appendingPathComponent(name)
            if FileManager.default.fileExists(atPath: url.path) { recovery[name] = try repository.read(url) }
        }
        return AquariumInstallation(sourceBundleID: Bundle.main.bundleIdentifier ?? "", state: state,
            preferences: .init(defaults: .standard), recovery: recovery)
    }

    func stopRemindersForTransfer() {
        authorizationTask?.cancel()
        reminderTask?.cancel()
        reminderGeneration = UUID().uuidString
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
        UNUserNotificationCenter.current().removeAllDeliveredNotifications()
    }
    #endif

    /// Explicit local smoke test; never changes hearts or other game progress.
    func testNotification() async {
        let content = UNMutableNotificationContent()
        content.title = L10n.text("Fishtank Alert Test")
        content.body = L10n.text("This is an icon test alert. It does not mean your hearts are full.")
        content.sound = .default
        do {
            let center = UNUserNotificationCenter.current()
            let allowed = try await ensureNotificationAuthorization()
            guard allowed else { message = L10n.text("Test alert not authorized"); return }
            try await center.add(UNNotificationRequest(identifier: "fishtank.test", content: content,
                trigger: UNTimeIntervalNotificationTrigger(timeInterval: 5, repeats: false)))
            let pending = await center.pendingNotificationRequests()
            let diagnostics: [String: Any] = [
                "hearts": state.hearts,
                "expectedFullAt": state.heartsFullAt?.timeIntervalSince1970 ?? 0,
                "pending": pending.map { request -> [String: Any] in
                    ["id": request.identifier, "date": ((request.trigger as? UNCalendarNotificationTrigger)?.nextTriggerDate() ?? (request.trigger as? UNTimeIntervalNotificationTrigger)?.nextTriggerDate())?.timeIntervalSince1970 ?? 0,
                     "currentGeneration": request.content.userInfo["generation"] as? String == reminderGeneration]
                }
            ]
            let url = FileManager.default.temporaryDirectory.appendingPathComponent("Fishtank-notification-verification.json")
            try JSONSerialization.data(withJSONObject: diagnostics, options: [.prettyPrinted, .sortedKeys]).write(to: url)
            #if os(macOS)
            if ProcessInfo.processInfo.arguments.contains("--verify-update") {
                let save = try JSONSerialization.jsonObject(with: JSONEncoder().encode(state))
                let preferences = try JSONSerialization.jsonObject(with: JSONEncoder().encode(AquariumInstallation.Preferences(defaults: .standard)))
                let verification = try JSONSerialization.data(withJSONObject: ["save": save, "notification": diagnostics, "preferences": preferences], options: [.sortedKeys])
                FileHandle.standardOutput.write(verification)
            }
            #endif
        } catch { message = L10n.text("Test alert failed: \(error.localizedDescription)") }
    }

}
