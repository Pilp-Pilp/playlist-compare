import AppKit
import SwiftUI

struct SongRow: Identifiable {
    let id: String
    let name: String
    let artist: String
    let overlapping: Bool
    let presence: [String: PresenceDTO?]
    var selected: Bool
}

private struct ColumnResizeHandle: View {
    @Binding var width: CGFloat
    let minWidth: CGFloat
    let maxWidth: CGFloat
    var handleHeight: CGFloat = 18
    @State private var lastTranslation: CGFloat = 0

    var body: some View {
        Rectangle()
            .fill(Color.primary.opacity(0.001))
            .frame(width: 8, height: handleHeight)
            .overlay(Rectangle().fill(Color.secondary.opacity(0.35)).frame(width: 1, height: handleHeight))
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        let delta = value.translation.width - lastTranslation
                        width = min(max(width + delta, minWidth), maxWidth)
                        lastTranslation = value.translation.width
                    }
                    .onEnded { _ in lastTranslation = 0 }
            )
            .onHover { inside in
                if inside {
                    NSCursor.resizeLeftRight.push()
                } else {
                    NSCursor.pop()
                }
            }
    }
}

private struct RowHeightHandle: View {
    @Binding var padding: CGFloat
    let minPadding: CGFloat
    let maxPadding: CGFloat
    @State private var lastTranslation: CGFloat = 0

    var body: some View {
        Rectangle()
            .fill(Color.secondary.opacity(0.1))
            .frame(height: 7)
            .overlay(Capsule().fill(Color.secondary.opacity(0.5)).frame(width: 36, height: 3))
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        let delta = value.translation.height - lastTranslation
                        padding = min(max(padding + delta, minPadding), maxPadding)
                        lastTranslation = value.translation.height
                    }
                    .onEnded { _ in lastTranslation = 0 }
            )
            .onHover { inside in
                if inside {
                    NSCursor.resizeUpDown.push()
                } else {
                    NSCursor.pop()
                }
            }
    }
}

private enum BuildMode {
    case new
    case existing
}

struct CompareView: View {
    let playlists: [String]
    @ObservedObject var settings: AppSettings
    @State private var selections: [String] = ["", ""]
    @State private var outputName: String = ""
    @State private var buildMode: BuildMode = .new
    @State private var existingPlaylistTarget: String = ""
    @State private var isComparing = false
    @State private var isBuilding = false
    @State private var errorMessage = ""
    @State private var buildResult = ""
    @State private var quickAddResult = ""
    @State private var rows: [SongRow] = []
    @State private var comparedPlaylists: [String] = []
    @State private var filterText = ""
    @State private var hideOverlapping = false

    @State private var songWidth: CGFloat = 160
    @State private var artistWidth: CGFloat = 120
    @State private var playlistColumnWidths: [String: CGFloat] = [:]
    @State private var rowVerticalPadding: CGFloat = 4

    private let minColumnWidth: CGFloat = 50
    private let maxColumnWidth: CGFloat = 420
    private let defaultPlaylistColumnWidth: CGFloat = 90
    private let checkboxWidth: CGFloat = 24
    private let statusWidth: CGFloat = 70
    private let minRowPadding: CGFloat = 0
    private let maxRowPadding: CGFloat = 20
    private let tablePadding: CGFloat = 10

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            playlistPickers

            Button {
                selections.append(playlists.first ?? "")
                updateDefaultName()
            } label: {
                Label("Add Playlist", systemImage: "plus.circle")
            }

            Button(isComparing ? "Comparing…" : "Compare") {
                runCompare()
            }
            .disabled(!canCompare)

            if isComparing {
                ProgressView()
            }

            if !errorMessage.isEmpty {
                Text(errorMessage)
                    .foregroundStyle(.red)
                    .textSelection(.enabled)
            }

            if !rows.isEmpty {
                resultsSection
            }
        }
        .padding()
        .onAppear {
            if selections[0].isEmpty { selections[0] = playlists.first ?? "" }
            if selections.count > 1 && selections[1].isEmpty { selections[1] = playlists.dropFirst().first ?? "" }
            updateDefaultName()
        }
    }

    private var playlistPickers: some View {
        ForEach(selections.indices, id: \.self) { index in
            HStack {
                Picker("Playlist \(index + 1)", selection: Binding(
                    get: { selections[index] },
                    set: { selections[index] = $0; updateDefaultName() }
                )) {
                    ForEach(playlists, id: \.self) { Text($0).tag($0) }
                }
                .frame(maxWidth: 400)

                if selections.count > 2 {
                    Button(role: .destructive) {
                        selections.remove(at: index)
                        updateDefaultName()
                    } label: {
                        Image(systemName: "minus.circle")
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var resultsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Divider()

            HStack {
                Text("\(selectedCount) of \(rows.count) selected")
                    .foregroundStyle(.secondary)
                Spacer()
                Button("Fit Columns") { autoFitColumns() }
                Button("Select All Non-Overlap") { setSelection(to: { !$0.overlapping }) }
                Button("Select All") { setSelection(to: { _ in true }) }
                Button("Deselect All") { setSelection(to: { _ in false }) }
            }

            HStack {
                TextField("Filter by song or artist", text: $filterText)
                Toggle("Hide overlapping", isOn: $hideOverlapping)
            }

            ScrollView(.horizontal) {
                VStack(alignment: .leading, spacing: 0) {
                    tableHeader
                        .padding(.vertical, 6)
                        .padding(.horizontal, tablePadding)
                        .background(Color.gray.opacity(0.12))
                    Divider()
                    RowHeightHandle(padding: $rowVerticalPadding, minPadding: minRowPadding, maxPadding: maxRowPadding)
                    ScrollView(.vertical) {
                        LazyVStack(spacing: 0) {
                            ForEach(filteredIndices, id: \.self) { idx in
                                tableRow(idx)
                                    .padding(.vertical, rowVerticalPadding)
                                    .padding(.horizontal, tablePadding)
                                    .background(idx % 2 == 0 ? Color.clear : Color.gray.opacity(0.06))
                                Divider()
                            }
                        }
                    }
                    .frame(height: 320)
                }
                .frame(width: totalTableWidth)
            }
            .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.gray.opacity(0.3)))

            Divider()

            Picker("", selection: $buildMode) {
                Text("New Playlist").tag(BuildMode.new)
                Text("Existing Playlist").tag(BuildMode.existing)
            }
            .labelsHidden()
            .pickerStyle(.segmented)
            .frame(maxWidth: 260)

            HStack {
                if buildMode == .new {
                    TextField("New playlist name", text: $outputName)
                } else {
                    Picker("Target playlist", selection: $existingPlaylistTarget) {
                        ForEach(playlists, id: \.self) { Text($0).tag($0) }
                    }
                    .frame(maxWidth: 300)
                }
                Button(isBuilding ? "Working…" : buildButtonTitle) {
                    runBuild()
                }
                .disabled(selectedCount == 0 || targetPlaylistName.isEmpty || isBuilding)
            }

            if isBuilding {
                ProgressView()
            }
            if !buildResult.isEmpty {
                Text(buildResult).textSelection(.enabled)
            }
            if !quickAddResult.isEmpty {
                Text(quickAddResult)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
            }
        }
    }

    private var targetPlaylistName: String {
        buildMode == .new ? outputName : existingPlaylistTarget
    }

    private var buildButtonTitle: String {
        buildMode == .new ? "Build Playlist from Selection" : "Add Selection to Playlist"
    }

    private var totalTableWidth: CGFloat {
        var total = checkboxWidth + songWidth + artistWidth + statusWidth + tablePadding * 2
        total += 8 * CGFloat(2 + comparedPlaylists.count) // resize handles: song, artist, one per playlist
        for name in comparedPlaylists {
            total += playlistColumnWidths[name] ?? defaultPlaylistColumnWidth
        }
        return total
    }

    private func playlistColumnWidthBinding(for name: String) -> Binding<CGFloat> {
        Binding(
            get: { playlistColumnWidths[name] ?? defaultPlaylistColumnWidth },
            set: { playlistColumnWidths[name] = $0 }
        )
    }

    private var tableHeader: some View {
        HStack(spacing: 0) {
            Text("").frame(width: checkboxWidth)

            Text("Song")
                .lineLimit(1)
                .frame(width: songWidth, alignment: .center)
            ColumnResizeHandle(width: $songWidth, minWidth: minColumnWidth, maxWidth: maxColumnWidth)

            Text("Artist")
                .lineLimit(1)
                .frame(width: artistWidth, alignment: .center)
            ColumnResizeHandle(width: $artistWidth, minWidth: minColumnWidth, maxWidth: maxColumnWidth)

            ForEach(comparedPlaylists, id: \.self) { name in
                let widthBinding = playlistColumnWidthBinding(for: name)
                Text(name)
                    .lineLimit(1)
                    .frame(width: widthBinding.wrappedValue, alignment: .center)
                ColumnResizeHandle(width: widthBinding, minWidth: minColumnWidth, maxWidth: maxColumnWidth)
            }

            Text("Status").frame(width: statusWidth, alignment: .center)
        }
        .font(.caption.bold())
        .foregroundStyle(.secondary)
    }

    private func tableRow(_ idx: Int) -> some View {
        HStack(spacing: 0) {
            Toggle("", isOn: $rows[idx].selected)
                .labelsHidden()
                .frame(width: checkboxWidth)

            Text(rows[idx].name)
                .multilineTextAlignment(.center)
                .frame(width: songWidth, alignment: .center)
                .lineLimit(1)
            Spacer().frame(width: 8)

            Text(rows[idx].artist)
                .multilineTextAlignment(.center)
                .frame(width: artistWidth, alignment: .center)
                .lineLimit(1)
                .foregroundStyle(.secondary)
            Spacer().frame(width: 8)

            ForEach(comparedPlaylists, id: \.self) { name in
                Group {
                    if (rows[idx].presence[name] ?? nil) != nil {
                        Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
                    } else {
                        Image(systemName: "circle.dashed").foregroundStyle(.tertiary)
                    }
                }
                .frame(width: playlistColumnWidths[name] ?? defaultPlaylistColumnWidth, alignment: .center)
                Spacer().frame(width: 8)
            }

            if rows[idx].overlapping {
                Text("overlap")
                    .font(.caption2)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(.orange.opacity(0.2))
                    .clipShape(Capsule())
                    .frame(width: statusWidth, alignment: .center)
            } else {
                Text("").frame(width: statusWidth, alignment: .center)
            }
        }
        .contextMenu {
            Menu("Add to Playlist") {
                ForEach(playlists, id: \.self) { name in
                    Button(name) {
                        quickAdd(rowIdx: idx, to: name)
                    }
                }
            }
        }
    }

    private var canCompare: Bool {
        let nonEmpty = selections.filter { !$0.isEmpty }
        return nonEmpty.count == selections.count && Set(nonEmpty).count == selections.count && !isComparing
    }

    private var selectedCount: Int {
        rows.filter(\.selected).count
    }

    private var filteredIndices: [Int] {
        rows.indices.filter { idx in
            let row = rows[idx]
            if hideOverlapping && row.overlapping { return false }
            guard !filterText.isEmpty else { return true }
            let needle = filterText.lowercased()
            return row.name.lowercased().contains(needle) || row.artist.lowercased().contains(needle)
        }
    }

    private func setSelection(to predicate: (SongRow) -> Bool) {
        for idx in rows.indices {
            rows[idx].selected = predicate(rows[idx])
        }
    }

    private func updateDefaultName() {
        let names = selections.filter { !$0.isEmpty }
        if existingPlaylistTarget.isEmpty {
            existingPlaylistTarget = playlists.first(where: { !names.contains($0) }) ?? playlists.first ?? ""
        }
        guard names.count >= 2 else { return }
        outputName = names.joined(separator: " vs ") + " - Non-Overlap"
    }

    private func textWidth(_ text: String, font: NSFont) -> CGFloat {
        (text as NSString).size(withAttributes: [.font: font]).width
    }

    private func autoFitColumns() {
        let bodyFont = NSFont.preferredFont(forTextStyle: .body)
        let captionFont = NSFont.preferredFont(forTextStyle: .caption1)
        let padding: CGFloat = 24

        let longestName = rows.map { textWidth($0.name, font: bodyFont) }.max() ?? 0
        songWidth = min(max(max(longestName, textWidth("Song", font: captionFont)) + padding, minColumnWidth), maxColumnWidth)

        let longestArtist = rows.map { textWidth($0.artist, font: bodyFont) }.max() ?? 0
        artistWidth = min(max(max(longestArtist, textWidth("Artist", font: captionFont)) + padding, minColumnWidth), maxColumnWidth)

        for name in comparedPlaylists {
            let headerWidth = textWidth(name, font: captionFont) + padding
            playlistColumnWidths[name] = min(max(headerWidth, minColumnWidth), maxColumnWidth)
        }
    }

    private func runCompare() {
        isComparing = true
        errorMessage = ""
        buildResult = ""
        rows = []
        let names = selections
        DispatchQueue.global(qos: .userInitiated).async {
            let outcome = MusicController.compareJSON(playlists: names)
            DispatchQueue.main.async {
                isComparing = false
                if let compareResult = outcome.result {
                    comparedPlaylists = compareResult.playlists
                    rows = compareResult.rows
                        .sorted { ($0.artist.lowercased(), $0.name.lowercased()) < ($1.artist.lowercased(), $1.name.lowercased()) }
                        .enumerated()
                        .map { index, r in
                            SongRow(
                                id: "\(index)",
                                name: r.name,
                                artist: r.artist,
                                overlapping: r.overlapping,
                                presence: r.presence,
                                selected: !r.overlapping
                            )
                        }
                    playlistColumnWidths = [:]
                    autoFitColumns()
                } else {
                    errorMessage = outcome.error ?? "Unknown error"
                }
            }
        }
    }

    private func pick(for row: SongRow) -> PlaylistSelection? {
        for playlist in comparedPlaylists {
            if let presence = row.presence[playlist] ?? nil {
                return PlaylistSelection(source: playlist, id: presence.id)
            }
        }
        return nil
    }

    private func runBuild() {
        isBuilding = true
        buildResult = ""
        quickAddResult = ""
        let name = targetPlaylistName
        let shouldReorder = buildMode == .existing
        let sortSpec = settings.sortSpec
        let picks: [PlaylistSelection] = rows.filter(\.selected).compactMap(pick(for:))
        DispatchQueue.global(qos: .userInitiated).async {
            let result = MusicController.buildPlaylist(name: name, selections: picks)
            var output = result.output
            if result.success && shouldReorder {
                let reorderResult = MusicController.reorder(playlist: name, sortSpec: sortSpec)
                output += (output.isEmpty ? "" : "\n") + reorderResult.output
            }
            DispatchQueue.main.async {
                buildResult = output
                isBuilding = false
            }
        }
    }

    private func quickAdd(rowIdx: Int, to playlist: String) {
        guard let selection = pick(for: rows[rowIdx]) else { return }
        let trackLabel = "\(rows[rowIdx].artist) - \(rows[rowIdx].name)"
        let sortSpec = settings.sortSpec
        buildResult = ""
        quickAddResult = "Adding \"\(trackLabel)\" to \(playlist)…"
        DispatchQueue.global(qos: .userInitiated).async {
            let result = MusicController.buildPlaylist(name: playlist, selections: [selection])
            if result.success {
                _ = MusicController.reorder(playlist: playlist, sortSpec: sortSpec)
            }
            DispatchQueue.main.async {
                quickAddResult = result.success
                    ? "Added \"\(trackLabel)\" to \(playlist) and reordered it"
                    : "Failed to add \"\(trackLabel)\": \(result.output)"
            }
        }
    }
}
