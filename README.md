# Playlist Compare

A Python tool to organize and compare Apple Music playlist files (TSV format).

## Features

- **Sort mode** (1 file in `playlists/`): sorts an exported playlist by Artist, Album, then Name, and saves the result.
- **Compare mode** (2 files in `playlists/`): compares tracks using normalized names and artist sets, and outputs common/unique tracks.
- **Live reorder** (`reorder_live_playlist.py`): reorders a playlist directly inside Music.app by Artist, Album, then Name — no export/import needed, so play counts and ratings are preserved.
- **Live compare + non-overlap playlist** (`compare_live_playlists.py` + `build_playlist.py`): compares two or more playlists directly from Music.app, then builds a new playlist from whichever non-overlapping (or overlapping) tracks you choose.
- **Playlist Organizer app** (`PlaylistOrganizerApp/`): a small native macOS app wrapping the live tools above with dropdowns, a track table, and checkboxes — see the "Playlist Organizer app" section below.
- Logs progress and summary information.

## Requirements

- Python 3.8+
- pandas
- macOS with Music.app (for live reorder/compare and the app; file-based sort/compare work anywhere — see [WINDOWS.md](WINDOWS.md) for what does and doesn't port)

## Usage: file-based sort / compare

1. Export one or two playlists from Music.app (select the playlist → File → Library → Export Playlist…) into the `playlists/` directory. Apple's exported `.txt` files (UTF-16, tab-separated) are read automatically — no conversion needed.
   - **One file** → sort mode.
   - **Two files** → compare mode.
2. Each file should have columns: `Name`, `Artist`, `Date Modified`, `Date Added`, `Last Played`, `Last Skipped` (compare mode); sort mode also needs `Album`.
3. Run the script:

   ```bash
   python main.py
   ```

4. Results are saved as TSV files in the `results/` directory:
   - Sort mode: `<playlist>_sorted.tsv`.
   - Compare mode: `common.tsv`, `<playlist1>_uniques.tsv`, `<playlist2>_uniques.tsv`.

Note: this only produces a sorted export file — Music.app doesn't let you re-import a file to reorder an existing playlist. For that, use the live reorder below.

## Usage: live reorder (updates the actual playlist in Music.app)

```bash
python reorder_live_playlist.py "Playlist Name"
```

This reads the playlist's current tracks directly from Music.app, computes the Artist/Album/Name order, then moves the tracks into that order in place. Run it any time after adding new songs to keep the playlist sorted.

- The playlist name must match exactly and be a regular (non-Smart) playlist.
- The first run will prompt macOS for permission to let your terminal/Python control Music.app (System Settings → Privacy & Security → Automation) — approve it.
- For large playlists this can take a little while since each move is a separate command to Music.app.

## Usage: live compare + non-overlap playlist

Analyze two or more playlists directly from Music.app (no export needed):

```bash
python compare_live_playlists.py --json "Playlist 1" "Playlist 2" [...]
```

Prints a JSON object (`{"playlists": [...], "tracks": [...]}`) to stdout, with each track flagged `overlapping: true/false`. This is what the Playlist Organizer app uses to populate its table; you can also pipe it into `jq` or a script.

For a quick terminal-only run that also builds the playlist automatically (no selection step):

```bash
python compare_live_playlists.py "Playlist 1" "Playlist 2" [...] "Non-Overlap Playlist Name"
```

To build a playlist from a hand-picked selection instead (what the app does after you check/uncheck rows):

```bash
echo '[{"source": "Playlist 1", "id": "12345"}, {"source": "Playlist 2", "id": "67890"}]' \
  | python build_playlist.py "My New Playlist"
```

Each `id` is the Music.app track id from the compare step's JSON output, and `source` is the playlist it came from.

## Playlist Organizer app

`PlaylistOrganizerApp/` is a native SwiftUI app wrapping the live reorder and compare tools:

```bash
cd PlaylistOrganizerApp
./build.sh
open PlaylistOrganizer.app
```

- **Reorder tab**: pick a playlist, click Reorder.
- **Compare tab**: pick two or more playlists, click Compare to see every track in a table with overlap badges. Non-overlapping tracks start checked, overlapping ones unchecked — toggle any row, then name and build a playlist from exactly what's checked.

The app shells out to the same Python scripts above (`repoPath` is hardcoded in `MusicController.swift`), so it needs this repo's `.venv` (or a system Python) with `pandas` installed at the path it expects.

## Example

```
playlists/
  └── playlist.tsv
results/
  └── playlist_sorted.tsv
```

```
playlists/
  ├── playlist1.tsv
  └── playlist2.tsv
results/
  ├── common.tsv
  ├── playlist1_uniques.tsv
  └── playlist2_uniques.tsv
```

## Sort key

Both sort mode and live reorder sort by `Artist`, `Album`, then `Name` (case-insensitive). File-based sort mode is configured via `SORT_COLUMNS` in `constants.py`.
