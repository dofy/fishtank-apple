import Foundation

/// Short, softly enveloped PCM cues. The same state uses the same cue for every agent.
struct AgentAlertTone {
    static let sampleRate = 22050
    static let playbackVolume: Float = 0.32
    let status: ClaudeHookEvent.Status

    private var motif: [Double] {
        switch status {
        case .ready: return [0, 7]
        case .working: return [0]
        case .permission: return [0, 4, 0]
        case .input: return [7, 2]
        case .responded: return [0, 4, 7]
        case .failed: return [7, 3, 0]
        case .interrupted: return [5, 0]
        case .ended: return [4, 0]
        }
    }
    private var noteDuration: Double { status == .working ? 0.085 : status == .interrupted ? 0.095 : 0.13 }
    private var gap: Double { status == .permission ? 0.05 : 0.035 }
    var duration: Double { Double(motif.count) * (noteDuration + gap) + 0.025 }

    var samples: [Int16] {
        let length = Int(ceil(duration * Double(Self.sampleRate)))
        var samples = [Int16](repeating: 0, count: length)
        let base = 440.0
        for (index, semitone) in motif.enumerated() {
            let start = Double(index) * (noteDuration + gap)
            let frequency = base * pow(2, semitone / 12)
            let begin = Int(start * Double(Self.sampleRate))
            let count = Int(noteDuration * Double(Self.sampleRate))
            for offset in 0..<count {
                let t = Double(offset) / Double(Self.sampleRate)
                // Sine-squared onset and release avoid sharp clicks at either end.
                let envelope = pow(sin(.pi * t / noteDuration), 2) * exp(-2 * t / noteDuration)
                let phase = 2 * Double.pi * frequency * t
                let voice = (sin(phase) + 0.14 * sin(phase * 2)) / 1.14
                let value = voice * envelope * 0.18
                samples[begin + offset] = Int16((value * Double(Int16.max)).rounded())
            }
        }
        return samples
    }

    var wave: Data {
        let pcm = samples
        var output = Data()
        func text(_ value: String) { output.append(contentsOf: value.utf8) }
        func u16(_ value: UInt16) { output.append(UInt8(value & 255)); output.append(UInt8(value >> 8)) }
        func u32(_ value: UInt32) { for shift in stride(from: 0, through: 24, by: 8) { output.append(UInt8((value >> shift) & 255)) } }
        text("RIFF"); u32(UInt32(36 + pcm.count * 2)); text("WAVEfmt "); u32(16)
        u16(1); u16(1); u32(UInt32(Self.sampleRate)); u32(UInt32(Self.sampleRate * 2)); u16(2); u16(16)
        text("data"); u32(UInt32(pcm.count * 2))
        for sample in pcm { u16(UInt16(bitPattern: sample)) }
        return output
    }
}

/// Independent of gameplay sound/music; queued cues are bounded and expire quickly.
struct AgentSoundQueue {
    private(set) var enabled = true
    private(set) var pending: [ClaudeHookEvent] = []
    mutating func setEnabled(_ value: Bool) { enabled = value; if !value { pending.removeAll() } }
    mutating func receive(_ event: ClaudeHookEvent, notify: Bool) {
        guard enabled else { return }
        pending.removeAll { $0.sessionKey == event.sessionKey && (notify || $0.status != event.status) }
        guard notify, event.status != nil else { return }
        pending.append(event)
        if pending.count > 3 { pending.removeFirst(pending.count - 3) }
    }
    mutating func remove(states: Set<String>) { pending.removeAll { states.contains($0.status?.rawValue ?? "") } }
    mutating func remove(source: ClaudeHookEvent.Source) { pending.removeAll { $0.agent == source } }
    mutating func next(now: Date = Date()) -> ClaudeHookEvent? {
        pending.removeAll { now.timeIntervalSince($0.sentAt) > 5 }
        guard enabled, !pending.isEmpty else { return nil }
        return pending.removeFirst()
    }
}
