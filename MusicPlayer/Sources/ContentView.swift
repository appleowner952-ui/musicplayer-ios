import SwiftUI
import Foundation
import UniformTypeIdentifiers

struct ContentView: View {
    @EnvironmentObject private var model: PlayerModel

    @State private var showPakImporter = false
    @State private var showSongImporter = false

    var body: some View {
        ZStack {
            Theme.canvas.ignoresSafeArea()

            VStack(spacing: 12) {
                header
                songList
                nowPlaying
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
        .preferredColorScheme(.dark)
        .fileImporter(
            isPresented: $showPakImporter,
            allowedContentTypes: pakTypes,
            allowsMultipleSelection: false
        ) { result in
            handleImport(result, isPak: true)
        }
        .fileImporter(
            isPresented: $showSongImporter,
            allowedContentTypes: [.mp3, .audio],
            allowsMultipleSelection: true
        ) { result in
            handleImport(result, isPak: false)
        }
        .alert("Hata", isPresented: errorBinding) {
            Button("Tamam") { model.errorMessage = nil }
        } message: {
            Text(model.errorMessage ?? "")
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(Theme.muted)

                TextField("Ara...", text: $model.searchText)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .foregroundStyle(Theme.text)

                if !model.searchText.isEmpty {
                    Button {
                        model.searchText = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(Theme.muted)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 12)
            .frame(height: 40)
            .background(RoundedRectangle(cornerRadius: 12).fill(Theme.surface))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.stroke, lineWidth: 1))

            Menu {
                Button {
                    showPakImporter = true
                } label: {
                    Label("muzik.pak içe aktar", systemImage: "doc.badge.plus")
                }
                Button {
                    showSongImporter = true
                } label: {
                    Label("MP3 ekle", systemImage: "music.note.list")
                }
            } label: {
                Text("+  Ekle")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Theme.text)
                    .padding(.horizontal, 14)
                    .frame(height: 40)
                    .background(RoundedRectangle(cornerRadius: 11).fill(Theme.track))
            }
        }
    }

    // MARK: - Song list

    private var songList: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0, pinnedViews: [.sectionHeaders]) {
                if model.sections.isEmpty {
                    Text(model.hasLibrary
                         ? "Şarkı bulunamadı"
                         : "Henüz müzik yok.\n+ → muzik.pak içe aktar")
                        .font(.system(size: 15))
                        .multilineTextAlignment(.center)
                        .foregroundStyle(Theme.muted)
                        .frame(maxWidth: .infinity)
                        .padding(.top, 64)
                } else {
                    ForEach(model.sections) { section in
                        Section {
                            ForEach(section.entries) { entry in
                                row(entry)
                            }
                        } header: {
                            Text(section.id.uppercased())
                                .font(.system(size: 12, weight: .bold))
                                .foregroundStyle(Theme.accent)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.horizontal, 12)
                                .padding(.top, 12)
                                .padding(.bottom, 4)
                                .background(Theme.surface)
                        }
                    }
                }
            }
            .padding(.bottom, 8)
        }
        .background(RoundedRectangle(cornerRadius: 16).fill(Theme.surface))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private func row(_ entry: PakEntry) -> some View {
        let isCurrent = model.playingEntry?.id == entry.id

        return Button {
            model.play(entry)
        } label: {
            HStack(spacing: 12) {
                Group {
                    if isCurrent {
                        Image(systemName: model.isPlaying ? "waveform" : "pause.fill")
                            .foregroundStyle(Theme.accent)
                    } else {
                        Color.clear
                    }
                }
                .frame(width: 18, height: 18)

                VStack(alignment: .leading, spacing: 2) {
                    Text(entry.title)
                        .font(.system(size: 15, weight: isCurrent ? .semibold : .regular))
                        .foregroundStyle(isCurrent ? Theme.accent : Theme.text)
                        .lineLimit(1)
                    Text(entry.group)
                        .font(.system(size: 12))
                        .foregroundStyle(Theme.muted)
                        .lineLimit(1)
                }

                Spacer(minLength: 0)
            }
            .padding(.vertical, 9)
            .padding(.horizontal, 12)
            .background(
                RoundedRectangle(cornerRadius: 9)
                    .fill(isCurrent ? Theme.accent.opacity(0.14) : Color.clear)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Now playing

    private var nowPlaying: some View {
        VStack(spacing: 10) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(model.playingEntry?.title ?? "Şarkı seçilmedi")
                        .font(.system(size: 17, weight: .bold))
                        .foregroundStyle(Theme.text)
                        .lineLimit(1)
                    Text(model.playingEntry?.group ?? "")
                        .font(.system(size: 12))
                        .foregroundStyle(Theme.muted)
                        .lineLimit(1)
                }
                Spacer()
                Text(model.libraryInfo)
                    .font(.system(size: 11))
                    .foregroundStyle(Theme.muted)
            }

            Slider(
                value: Binding(
                    get: { model.seekFraction },
                    set: {
                        model.seekFraction = $0
                        model.isSeeking = true
                    }
                ),
                in: 0...1,
                onEditingChanged: { editing in
                    if editing {
                        model.isSeeking = true
                    } else {
                        model.commitSeek()
                    }
                }
            )
            .tint(Theme.accent)

            HStack {
                Text(time(model.currentTime))
                Spacer()
                Text(time(model.duration))
            }
            .font(.system(size: 11))
            .foregroundStyle(Theme.muted)

            HStack(spacing: 26) {
                transportButton("backward.fill", size: 26) { model.step(-1) }

                Button {
                    model.togglePlayPause()
                } label: {
                    ZStack {
                        Circle()
                            .fill(Theme.accent)
                            .frame(width: 58, height: 58)
                        Image(systemName: model.isPlaying ? "pause.fill" : "play.fill")
                            .font(.system(size: 22, weight: .bold))
                            .foregroundStyle(Theme.accentInk)
                            .offset(x: model.isPlaying ? 0 : 1.5)
                    }
                }
                .buttonStyle(.plain)

                transportButton("forward.fill", size: 26) { model.step(1) }
            }

            HStack(spacing: 8) {
                Image(systemName: "speaker.fill")
                    .font(.system(size: 11))
                    .foregroundStyle(Theme.muted)
                Slider(value: Binding(
                    get: { model.volume },
                    set: { model.setVolume($0) }
                ), in: 0...1)
                .tint(Theme.accent)
                Image(systemName: "speaker.wave.3.fill")
                    .font(.system(size: 11))
                    .foregroundStyle(Theme.muted)
            }
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 16).fill(Theme.surface))
    }

    private func transportButton(_ symbol: String, size: CGFloat, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: size, weight: .semibold))
                .foregroundStyle(Theme.text)
                .frame(width: 52, height: 52)
                .background(Circle().fill(Theme.track))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Helpers

    private var pakTypes: [UTType] {
        if let pak = UTType(filenameExtension: "pak") {
            return [pak, .data]
        }
        return [.data]
    }

    private var errorBinding: Binding<Bool> {
        Binding(
            get: { model.errorMessage != nil },
            set: { if !$0 { model.errorMessage = nil } }
        )
    }

    private func handleImport(_ result: Result<[URL], Error>, isPak: Bool) {
        switch result {
        case .success(let urls):
            guard let first = urls.first else { return }
            if isPak {
                model.importPak(from: first)
            } else {
                model.addSongs(from: urls)
            }
        case .failure(let error):
            model.errorMessage = error.localizedDescription
        }
    }

    private func time(_ seconds: Double) -> String {
        guard seconds.isFinite, seconds > 0 else { return "0:00" }
        let total = Int(seconds)
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        let secs = total % 60
        let two = { (value: Int) in value < 10 ? "0\(value)" : "\(value)" }
        if hours > 0 {
            return "\(hours):\(two(minutes)):\(two(secs))"
        }
        return "\(minutes):\(two(secs))"
    }
}
