import AppKit

enum SoundService {
    static func preview(volume: Double = 0.65) {
        guard let sound = NSSound(named: NSSound.Name("Glass")) else { return }
        sound.volume = Float(min(max(volume, 0), 1))
        sound.play()
    }
}
