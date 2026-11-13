import Foundation
import AVFoundation
import Combine

struct SongSection: Identifiable {
    let id: String
    let entries: [PakEntry]
}

final class PlayerModel: NSObject, ObservableObject, AVAudioPlayerDelegate {
    @Published var entries: [PakEntry] = []
    @Published var searchText = ""
    @Published var playingEntry: PakEntry?
    @Published var isPlaying = false
    @Published var currentTime: Double = 0
    @Published var duration: Double = 0
    @Published var seekFraction: Double = 0
    @Published var isSeeking = false
    @Published var hasLibrary = false
    @Published var libraryInfo = "muzik.pak bulunamadı"
    @Published var errorMessage: String?

    @Published var volume: Double = 0.8

    private var library: PakLibrary?
    private var player: AVAudioPlayer?
    private var timer: AnyCancellable?

    override init() {
        super.init()
        configureSession()
        reload()
        startTimer()
    }

    // MARK: - Session

    private func configureSession() {
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.playback, mode: .default, options: [])
        try? session.setActive(true)
    }

    // MARK: - Library

    func reload() {
        let url = PakLibrary.documentsURL

        guard FileManager.default.fileExists(atPath: url.path) else {
            library = nil
            entries = []
            hasLibrary = false
            libraryInfo = "muzik.pak bulunamadı"
            return
        }

        do {
            let loaded = try PakLibrary(url: url)
            library = loaded
            entries = loaded.entries
            hasLibrary = true
            libraryInfo = "\(loaded.entries.count) şarkı"
        } catch {
            library = nil
            entries = []
            hasLibrary = false
            errorMessage = "muzik.pak okunamadı: \(error.localizedDescription)"
        }
    }

    private func ensureLibrary() -> PakLibrary? {
        if let library { return library }

        let url = PakLibrary.documentsURL
        if !FileManager.default.fileExists(atPath: url.path) {
            FileManager.default.createFile(atPath: url.path, contents: nil)
            if let handle = try? FileHandle(forWritingTo: url) {
                var header = Data("MUSPAK1_".utf8)
                header.append(contentsOf: [0, 0, 0])
                try? handle.write(contentsOf: header)
                try? handle.close()
            }
        }

        do {
            let loaded = try PakLibrary(url: url)
            library = loaded
            return loaded
        } catch {
            errorMessage = "Kütüphane oluşturulamadı: \(error.localizedDescription)"
            return nil
        }
    }

    // MARK: - Filtering

    var sections: [SongSection] {
        let query = searchText.trimmingCharacters(in: .whitespaces)
        let filtered = query.isEmpty
            ? entries
            : entries.filter { contains($0.title, query) || contains($0.group, query) }

        let grouped = Dictionary(grouping: filtered, by: { $0.group })

        let keys = grouped.keys.sorted { left, right in
            let leftAdded = left.caseInsensitiveCompare("Added") == .orderedSame
            let rightAdded = right.caseInsensitiveCompare("Added") == .orderedSame
            if leftAdded != rightAdded { return !leftAdded }
            return left.localizedCaseInsensitiveCompare(right) == .orderedAscending
        }

        return keys.map { key in
            let songs = (grouped[key] ?? []).sorted {
                $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending
            }
            return SongSection(id: key, entries: songs)
        }
    }

    var playableEntries: [PakEntry] {
        sections.flatMap { $0.entries }
    }

    private func contains(_ haystack: String, _ needle: String) -> Bool {
        let trimmed = needle.trimmingCharacters(in: .whitespaces)
        if trimmed.isEmpty { return true }
        return haystack.range(of: trimmed, options: [.caseInsensitive, .diacriticInsensitive]) != nil
    }

    // MARK: - Playback

    func play(_ entry: PakEntry) {
        guard let library else { return }

        do {
            let data = try library.data(for: entry)
            let audio = try AVAudioPlayer(data: data)
            audio.delegate = self
            audio.volume = Float(volume)
            audio.prepareToPlay()

            player?.stop()
            player = audio

            playingEntry = entry
            duration = audio.duration
            currentTime = 0
            seekFraction = 0
            isSeeking = false

            audio.play()
            isPlaying = true
            errorMessage = nil
        } catch {
            errorMessage = "Çalınamadı: \(error.localizedDescription)"
        }
    }

    func togglePlayPause() {
        guard let player else {
            if let first = playableEntries.first ?? entries.first {
                play(first)
            }
            return
        }

        if player.isPlaying {
            player.pause()
            isPlaying = false
        } else {
            player.play()
            isPlaying = true
        }
    }

    func step(_ direction: Int) {
        let list = playableEntries.isEmpty ? entries : playableEntries
        guard !list.isEmpty else { return }

        let nextIndex: Int
        if let playingEntry, let index = list.firstIndex(where: { $0.id == playingEntry.id }) {
            nextIndex = ((index + direction) % list.count + list.count) % list.count
        } else {
            nextIndex = direction > 0 ? 0 : list.count - 1
        }

        play(list[nextIndex])
    }

    func setVolume(_ value: Double) {
        volume = value
        player?.volume = Float(value)
    }

    func commitSeek() {
        guard let player else {
            isSeeking = false
            return
        }
        let target = duration * seekFraction
        player.currentTime = target
        currentTime = target
        isSeeking = false
    }

    private func startTimer() {
        timer = Timer.publish(every: 0.25, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                guard let self, let player = self.player, player.isPlaying else { return }
                self.currentTime = player.currentTime
                self.duration = player.duration
                if !self.isSeeking, self.duration > 0 {
                    self.seekFraction = self.currentTime / self.duration
                }
            }
    }

    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        DispatchQueue.main.async { [weak self] in
            self?.step(1)
        }
    }

    // MARK: - Import

    func importPak(from url: URL) {
        let access = url.startAccessingSecurityScopedResource()
        defer { if access { url.stopAccessingSecurityScopedResource() } }

        let destination = PakLibrary.documentsURL
        let manager = FileManager.default

        do {
            if manager.fileExists(atPath: destination.path) {
                try manager.removeItem(at: destination)
            }
            try manager.copyItem(at: url, to: destination)
            reload()
        } catch {
            errorMessage = "İçe aktarılamadı: \(error.localizedDescription)"
        }
    }

    func addSongs(from urls: [URL]) {
        guard let library = ensureLibrary() else { return }

        var added = 0
        for url in urls {
            do {
                _ = try library.add(sourceURL: url, fileName: url.lastPathComponent)
                added += 1
            } catch {
                errorMessage = "Eklenemedi: \(error.localizedDescription)"
            }
        }

        if added > 0 {
            reload()
        }
    }
}
