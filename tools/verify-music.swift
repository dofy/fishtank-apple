import AVFoundation
import Foundation

// Fully decode bundled music without playing audio or opening a device session.
let directory = URL(fileURLWithPath: CommandLine.arguments.dropFirst().first ?? "Sources/Resources/Audio")
for name in ["lofi", "tide", "chiptune", "japanese", "taiwan", "jazz"] {
    let url = directory.appendingPathComponent("music-\(name).wav")
    let file = try AVAudioFile(forReading: url)
    let format = file.processingFormat
    precondition(format.channelCount == 1 && format.sampleRate == 22050)
    let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(file.length))!
    try file.read(into: buffer)
    precondition(buffer.frameLength == file.length)
    let samples = UnsafeBufferPointer(start: buffer.floatChannelData![0], count: Int(buffer.frameLength))
    precondition(samples.allSatisfy { $0.isFinite })
    let peak = samples.map { abs($0) }.max()!
    let rms = sqrt(samples.reduce(0.0) { $0 + Double($1) * Double($1) } / Double(samples.count))
    precondition(peak < 0.3 && rms > 0.01 && rms < 0.035, "Quiet music must not clip or be silent")
    precondition(abs(samples.first! - samples.last!) < 0.002, "Loop boundary must be smooth")
    let player = try AVAudioPlayer(contentsOf: url)
    player.numberOfLoops = -1
    precondition(player.duration > 7 && player.numberOfLoops == -1)
    if ["japanese", "taiwan", "jazz"].contains(name) {
        precondition(player.duration >= 40 && player.duration <= 51)
    }
    print("PASS \(name): complete AVFoundation decode, quiet level, smooth loop, repeat playback support")
}
