import SwiftUI

struct ReorderView: View {
    let playlists: [String]
    @ObservedObject var settings: AppSettings
    @State private var selected: String = ""
    @State private var isRunning = false
    @State private var output = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Reorder a playlist in place using the sort order set in Preferences.")
                .foregroundStyle(.secondary)

            Text("Sort order: \(settings.sortSpec)")
                .font(.caption)
                .foregroundStyle(.secondary)

            Picker("Playlist", selection: $selected) {
                ForEach(playlists, id: \.self) { Text($0).tag($0) }
            }
            .frame(maxWidth: 400)

            Button(isRunning ? "Reordering…" : "Reorder") {
                run()
            }
            .disabled(selected.isEmpty || isRunning)

            if isRunning {
                ProgressView()
            }

            ScrollView {
                Text(output)
                    .font(.system(.body, design: .monospaced))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .textSelection(.enabled)
            }
        }
        .padding()
        .onAppear {
            if selected.isEmpty { selected = playlists.first ?? "" }
        }
    }

    private func run() {
        isRunning = true
        output = ""
        let playlist = selected
        let sortSpec = settings.sortSpec
        DispatchQueue.global(qos: .userInitiated).async {
            let result = MusicController.reorder(playlist: playlist, sortSpec: sortSpec)
            DispatchQueue.main.async {
                output = result.output
                isRunning = false
            }
        }
    }
}
