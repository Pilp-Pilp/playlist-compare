import SwiftUI

struct ContentView: View {
    @State private var playlists: [String] = []
    @StateObject private var settings = AppSettings()
    @StateObject private var musicStatus = MusicStatus()

    var body: some View {
        VStack(spacing: 0) {
            statusBar

            TabView {
                ReorderView(playlists: playlists, settings: settings)
                    .tabItem { Label("Reorder", systemImage: "arrow.up.arrow.down") }

                CompareView(playlists: playlists, settings: settings)
                    .tabItem { Label("Compare", systemImage: "rectangle.on.rectangle") }

                PreferencesView(settings: settings)
                    .tabItem { Label("Preferences", systemImage: "gearshape") }
            }
        }
        .frame(minWidth: 700, minHeight: 550)
        .onAppear {
            refreshPlaylists()
        }
    }

    private var statusBar: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(musicStatus.color)
                .frame(width: 10, height: 10)
            Text(musicStatus.text)
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
            Button {
                musicStatus.refresh()
                refreshPlaylists()
            } label: {
                Image(systemName: "arrow.clockwise")
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(.regularMaterial)
    }

    private func refreshPlaylists() {
        DispatchQueue.global(qos: .userInitiated).async {
            let names = MusicController.listPlaylists()
            DispatchQueue.main.async {
                playlists = names
            }
        }
    }
}
