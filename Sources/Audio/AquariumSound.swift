import AVFoundation

/// UI-facing commands are ordered on a dedicated audio queue. No decoder or audio
/// session activation runs on the main thread, including first-interaction playback.
@MainActor
final class AquariumSound {
    private let queue = DispatchQueue(label: "net.yahaha.fishtank.audio", qos: .userInitiated)
    private let playback = AquariumPlayback()
    var reportError: ((String) -> Void)?

    init() {
        playback.reportError = { [weak self] message in
            Task { @MainActor in self?.reportError?(message) }
        }
    }
    func configure(_ config: AquariumAudio) { queue.async { [playback] in playback.configure(config) } }
    func interact() { queue.async { [playback] in playback.interact() } }
    func setSuspended(_ value: Bool) { queue.async { [playback] in playback.setSuspended(value) } }
    func play(_ name: String, tier: Int = 1) { queue.async { [playback] in playback.play(name, tier: tier) } }
}

/// Confined to AquariumSound.queue after initialization.
private final class AquariumPlayback: @unchecked Sendable {
    private var configuration = AquariumAudio()
    private var music: AVAudioPlayer?
    private var effects: [AVAudioPlayer] = []
    private var currentTrack = ""
    private var unlocked = false
    private var suspended = false
    #if os(iOS)
    private var sessionReady = false
    #endif
    var reportError: ((String) -> Void)?

    func configure(_ config: AquariumAudio) {
        let changed = config.track != configuration.track
        configuration = config
        if changed { music?.stop(); music = nil }
        if !config.sfxEnabled { effects.forEach { $0.stop() }; effects = [] }
        effects.forEach { $0.volume = Float(config.sfxVolume) }
        updateMusic()
    }
    func interact() { unlocked = true; updateMusic() }
    func setSuspended(_ value: Bool) {
        suspended = value
        if value { effects.forEach { $0.stop() }; effects = [] }
        updateMusic()
    }
    func play(_ name: String, tier: Int) {
        interact()
        guard configuration.sfxEnabled, configuration.sfxVolume > 0.001, !suspended else { return }
        do {
            try prepareSession()
            let resource = name == "reveal" ? "reveal-\(max(0, min(5, tier)))" : name
            let player = try AVAudioPlayer(contentsOf: resourceURL(resource))
            player.volume = Float(configuration.sfxVolume)
            effects.removeAll { !$0.isPlaying }
            if effects.count >= 8 { effects.removeFirst().stop() }
            effects.append(player)
            player.play()
        } catch { reportError?(L10n.text("音效不可用：\(error.localizedDescription)")) }
    }
    private func updateMusic() {
        guard unlocked, !suspended, configuration.musicEnabled, configuration.musicVolume > 0.001 else { music?.pause(); return }
        do {
            try prepareSession()
            if music == nil || currentTrack != configuration.track {
                music = try AVAudioPlayer(contentsOf: resourceURL("music-\(configuration.track)"))
                music?.numberOfLoops = -1
                currentTrack = configuration.track
            }
            music?.volume = Float(configuration.musicVolume)
            if music?.isPlaying != true { music?.play() }
        } catch { reportError?(L10n.text("音乐不可用：\(error.localizedDescription)")) }
    }
    private func prepareSession() throws {
        #if os(iOS)
        if !sessionReady {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.ambient, options: [.mixWithOthers])
            try session.setActive(true)
            sessionReady = true
        }
        #endif
    }
    private func resourceURL(_ name: String) throws -> URL {
        guard let url = Bundle.main.url(forResource: name, withExtension: "wav") else { throw CocoaError(.fileNoSuchFile) }
        return url
    }
}
