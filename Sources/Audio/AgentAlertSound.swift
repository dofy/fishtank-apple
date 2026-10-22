#if os(macOS)
import AVFoundation

/// PCM generation, decoding and playback stay off the UI thread. No overlapping alert players.
@MainActor
final class AgentAlertSound {
    private let queue = DispatchQueue(label: "net.yahaha.fishtank.agent-audio", qos: .userInitiated)
    private let playback: AgentAlertPlayback
    var reportError: ((String) -> Void)?

    init() {
        playback = AgentAlertPlayback(queue: queue)
        playback.reportError = { [weak self] in Task { @MainActor in self?.reportError?(L10n.text("提醒音暂不可用")) } }
    }
    func setEnabled(_ enabled: Bool) { queue.async { [playback] in playback.setEnabled(enabled) } }
    func setVolume(_ value: Float) { queue.async { [playback] in playback.setVolume(value) } }
    func submit(_ event: ClaudeHookEvent, notify: Bool) { queue.async { [playback] in playback.submit(event, notify: notify) } }
    func preview(status: ClaudeHookEvent.Status) {
        queue.async { [playback] in playback.preview(status: status) }
    }
    #if DEBUG
    func inspect(_ report: @escaping @Sendable (Bool, Int, Float, [ClaudeHookEvent.Status]) -> Void) {
        queue.async { [playback] in playback.inspect(report) }
    }
    #endif
    func discardDisabledStates(_ states: Set<String>) { queue.async { [playback] in playback.discardDisabledStates(states) } }
    func remove(source: ClaudeHookEvent.Source) { queue.async { [playback] in playback.remove(source: source) } }
}

private final class AgentAlertPlayback: @unchecked Sendable {
    private let queue: DispatchQueue
    private var model = AgentSoundQueue()
    private var player: AVAudioPlayer?
    private var volume = AgentAlertTone.playbackVolume
    private var currentSource: ClaudeHookEvent.Source?
    private var currentStatus: ClaudeHookEvent.Status?
    private var completion: DispatchWorkItem?
    private var cache: [String: Data] = [:]
    private var previews: [ClaudeHookEvent.Status] = []
    #if DEBUG
    private var played: [ClaudeHookEvent.Status] = []
    func inspect(_ report: (Bool, Int, Float, [ClaudeHookEvent.Status]) -> Void) {
        report(player?.isPlaying == true, model.pending.count + previews.count, player?.volume ?? 0, played)
    }
    #endif
    var reportError: (() -> Void)?
    init(queue: DispatchQueue) { self.queue = queue }

    func setVolume(_ value: Float) { volume = value.isFinite ? min(0.5, max(0, value)) : AgentAlertTone.playbackVolume; player?.volume = volume }
    func setEnabled(_ enabled: Bool) {
        model.setEnabled(enabled)
        if !enabled { previews.removeAll(); completion?.cancel(); completion = nil; player?.stop(); player = nil; currentSource = nil; currentStatus = nil }
    }
    func remove(source: ClaudeHookEvent.Source) {
        model.remove(source: source)
        if currentSource == source {
            completion?.cancel(); completion = nil; player?.stop(); player = nil; currentSource = nil; currentStatus = nil
            advance()
        }
    }
    func discardDisabledStates(_ states: Set<String>) {
        model.remove(states: states)
        if currentSource != nil, states.contains(currentStatus?.rawValue ?? "") {
            completion?.cancel(); completion = nil; player?.stop(); player = nil; currentSource = nil; currentStatus = nil
            advance()
        }
    }
    func submit(_ event: ClaudeHookEvent, notify: Bool) { model.receive(event, notify: notify); advance() }
    func preview(status: ClaudeHookEvent.Status) {
        guard model.enabled else { return }
        previews = [status]
        advance()
    }
    private func advance() {
        guard player == nil, model.enabled else { return }
        let source: ClaudeHookEvent.Source?
        let status: ClaudeHookEvent.Status
        if !previews.isEmpty {
            status = previews.removeFirst(); source = nil
        } else {
            guard let next = model.next(), let state = next.status else { return }
            source = next.agent; status = state
        }
        let key = status.rawValue
        do {
            let data: Data
            if let cached = cache[key] { data = cached }
            else { data = AgentAlertTone(status: status).wave; cache[key] = data }
            let next = try AVAudioPlayer(data: data, fileTypeHint: AVFileType.wav.rawValue)
            next.volume = volume
            next.prepareToPlay()
            guard next.play() else { throw CocoaError(.fileReadUnknown) }
            player = next; currentSource = source; currentStatus = status
            #if DEBUG
            played.append(status)
            if played.count > 32 { played.removeFirst() }
            #endif
            let work = DispatchWorkItem { [weak self, weak next] in
                guard let self, self.player === next else { return }
                self.player = nil; self.currentSource = nil; self.currentStatus = nil; self.completion = nil; self.advance()
            }
            completion = work
            queue.asyncAfter(deadline: .now() + next.duration + 0.035, execute: work)
        } catch { reportError?(); player = nil; currentSource = nil; currentStatus = nil }
    }
}
#endif
