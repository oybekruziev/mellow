import AVFoundation
import Observation

/// Bundled CC0 lofi tracks (Resources/Music, 160 kbps AAC), played in a loop over the whole list.
@MainActor @Observable
final class MusicPlayer: NSObject, AVAudioPlayerDelegate {
    struct Track: Equatable { let title: String; let url: URL }

    let tracks: [Track]
    private(set) var index = 0
    private(set) var isPlaying = false
    var volume: Double { didSet { player?.volume = Float(volume) } }
    @ObservationIgnored private var player: AVAudioPlayer?

    var current: Track? { tracks.indices.contains(index) ? tracks[index] : nil }

    init(volume: Double) {
        self.volume = volume
        tracks = ["m4a", "mp3"].flatMap { Bundle.main.urls(forResourcesWithExtension: $0, subdirectory: nil) ?? [] }
            .map { Track(title: $0.deletingPathExtension().lastPathComponent, url: $0) }
            .sorted { $0.title < $1.title }
        super.init()
        index = tracks.isEmpty ? 0 : Int.random(in: tracks.indices)
    }

    func toggle() { isPlaying ? pause() : play() }

    func play() {
        guard current != nil else { return }
        if player == nil { load() }
        player?.play()
        isPlaying = player?.isPlaying ?? false
    }

    func pause() {
        player?.pause()
        isPlaying = false
    }

    func next() {
        guard !tracks.isEmpty else { return }
        let resume = isPlaying
        index = (index + 1) % tracks.count
        load()
        if resume { play() }
    }

    private func load() {
        guard let track = current else { return }
        player?.stop()
        player = try? AVAudioPlayer(contentsOf: track.url)
        player?.delegate = self
        player?.volume = Float(volume)
        player?.prepareToPlay()
    }

    nonisolated func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        Task { @MainActor in
            self.isPlaying = true
            self.next()
        }
    }
}
