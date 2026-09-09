import AppKit
import Foundation

enum SoundService {
    private static let chime = NSSound(data: makeChimeData())

    static func preview(volume: Double = 0.65) {
        guard let chime else { return }
        chime.stop()
        chime.volume = Float(min(max(volume, 0), 1))
        chime.play()
    }

    // A short original three-note chime generated locally at runtime.
    private static func makeChimeData() -> Data {
        let sampleRate = 44_100
        let duration = 1.05
        let sampleCount = Int(Double(sampleRate) * duration)
        let notes: [(frequency: Double, start: Double, length: Double, gain: Double)] = [
            (523.25, 0.00, 0.42, 0.42),
            (659.25, 0.18, 0.48, 0.34),
            (783.99, 0.40, 0.58, 0.30)
        ]
        var pcm = Data(capacity: sampleCount * 2)
        for index in 0..<sampleCount {
            let time = Double(index) / Double(sampleRate)
            var value = 0.0
            for note in notes where time >= note.start && time <= note.start + note.length {
                let position = time - note.start
                let attack = min(1, position / 0.025)
                let release = min(1, (note.length - position) / 0.18)
                let envelope = max(0, min(attack, release))
                value += sin(2 * .pi * note.frequency * position) * envelope * note.gain
                value += sin(2 * .pi * note.frequency * 2 * position) * envelope * note.gain * 0.08
            }
            var sample = Int16(max(-1, min(1, value)) * Double(Int16.max)).littleEndian
            withUnsafeBytes(of: &sample) { pcm.append(contentsOf: $0) }
        }

        var data = Data()
        func appendASCII(_ string: String) { data.append(contentsOf: string.utf8) }
        func appendUInt16(_ value: UInt16) {
            var little = value.littleEndian
            withUnsafeBytes(of: &little) { data.append(contentsOf: $0) }
        }
        func appendUInt32(_ value: UInt32) {
            var little = value.littleEndian
            withUnsafeBytes(of: &little) { data.append(contentsOf: $0) }
        }
        appendASCII("RIFF")
        appendUInt32(UInt32(36 + pcm.count))
        appendASCII("WAVEfmt ")
        appendUInt32(16)
        appendUInt16(1)
        appendUInt16(1)
        appendUInt32(UInt32(sampleRate))
        appendUInt32(UInt32(sampleRate * 2))
        appendUInt16(2)
        appendUInt16(16)
        appendASCII("data")
        appendUInt32(UInt32(pcm.count))
        data.append(pcm)
        return data
    }
}
