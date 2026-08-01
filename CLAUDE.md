# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

A small toolset for organizing Apple Music playlists, in three layers that share code:

1. **File-based mode** (`main.py`) — sorts or compares exported `.txt`/`.tsv` playlist files offline, no Music.app needed. Works on any OS (see `WINDOWS.md` for exact portability notes).
2. **Live mode** (`reorder_live_playlist.py`, `compare_live_playlists.py`, `build_playlist.py`) — talks directly to Music.app via AppleScript, so it can reorder/compare/build real playlists in place without export/import. macOS only.
3. **PlaylistOrganizerApp/** — a native SwiftUI macOS app that is a thin GUI wrapper around the live-mode Python scripts (it shells out to them, it does not reimplement their logic).

## Commands

```bash
# File-based sort/compare (reads whatever is in playlists/, 1 file = sort, 2 files = compare)
python main.py

# Live reorder (mutates the real playlist in Music.app)
python reorder_live_playlist.py "Playlist Name" ["field:asc|desc,field2:asc|desc,..."]

# Live compare across N playlists, JSON output (what the Swift app consumes)
python compare_live_playlists.py --json "Playlist 1" "Playlist 2" [...]

# Live compare + auto-build a non-overlap playlist, terminal summary
python compare_live_playlists.py "Playlist 1" "Playlist 2" [...] "Non-Overlap Playlist Name"

# Build a playlist from a hand-picked selection (what the app does after checkbox edits)
echo '[{"source": "Playlist 1", "id": "12345"}]' | python build_playlist.py "My New Playlist"

# Swift app: build and run
cd PlaylistOrganizerApp && ./build.sh && open PlaylistOrganizer.app
# Or for iterating without repackaging the .app bundle:
cd PlaylistOrganizerApp && swift build -c release
```

There is no test suite, linter, or CI config in this repo. Verification is manual: run the relevant script/AppleScript against real (or a scratch) Music.app playlist and inspect output/log lines, or `swift build -c release` for the app (must say "Build complete!").

## Architecture

### Live mode ↔ Music.app boundary

All Music.app I/O is isolated in `music_app.py`, which shells out to `.applescript` files in `applescripts/` via `osascript` and parses their tab-separated stdout. Nothing else in the Python codebase talks to AppleScript directly — `compare_live_playlists.py`, `reorder_live_playlist.py`, and `build_playlist.py` all go through `music_app.py`'s functions (`get_tracks`, `reorder_tracks`, `create_playlist`, `add_tracks`).

Two different performance profiles exist in `applescripts/` and both are intentional, not inconsistent:
- **Reads** (`get_tracks.applescript`) use bulk `(property of every track of thePlaylist) as list` queries — one Apple Event per *property* regardless of track count, instead of one per property per track. This is on the order of 100x+ faster at scale and is why `get_tracks` is cheap to call repeatedly. Bulk list queries can return `missing value` for some fields (year, plays, date added) on certain tracks (e.g. Apple Music catalog/streaming tracks) even where a per-track scalar access would default to 0 — the script guards each of these explicitly. The `as list` coercions guard against AppleScript silently collapsing a one-track result to a bare scalar.
- **Mutations** (`reorder_tracks.applescript`, `add_tracks.applescript`) must still issue one Apple Event per track — Music.app's dictionary has no batch move/duplicate command. `reorder_live_playlist.py` compensates at the Python layer instead: it diffs current vs. target order and only moves the tracks after the first mismatched position, so a playlist that's already (or mostly) in order does little to no work on repeat runs.

### Track identity and matching

Tracks are matched across playlists/files by normalized name + artist, not raw string equality or Music.app IDs (IDs aren't stable across playlists). The normalization/matching logic lives in `PlaylistComparer` (`playlist_comparer.py`) and is reused by both compare paths:
- `normalize_name` strips parentheticals and `feat./featuring ...` suffixes, and normalizes whitespace/case.
- `normalize_artist` further splits on `&`, `,`, `and`, `/`, `;` into a token set.
- `is_artist_subset` treats two tracks as the same artist if one's token set is a subset of the other's (handles "Artist A" matching "Artist A feat. Artist B" across sources with different join conventions).

`compare_live_playlists.py` extends this to N playlists (not just 2) using union-find: tracks are grouped into components by normalized-name buckets plus artist-subset matching within each bucket, so a song present in 3+ playlists collapses into a single row rather than pairwise comparisons.

### File-based vs. live compare are separate implementations

`playlist_comparer.py` (file-based, 2 playlists, pandas `DataFrame`s, reads exported `.txt`/`.tsv` via `utils.load_playlist`) and `compare_live_playlists.py` (live, N playlists, plain dicts, reads via `music_app.get_tracks`) both call into `PlaylistComparer`'s static normalization methods but do not share a compare loop — don't assume a fix in one path applies to the other.

### Swift app

`PlaylistOrganizerApp/Sources/PlaylistOrganizer/MusicController.swift` is the sole bridge to Python: it hardcodes `repoPath` to this repo's absolute path and shells out to the scripts above using the repo's `.venv` Python if present, else falls through to system Python. If this repo is relocated, `repoPath` must be updated there. `compareJSON` decodes the same JSON shape `compare_live_playlists.py --json` prints; keep the two in sync when changing either side (the row shape is `{name, artist, overlapping, presence: {playlistName: {id, album} | null}}`).

Views: `ReorderView` and `CompareView` under the same directory drive the two tabs; `CompareView` owns per-column width state and manual layout (a `ScrollView`/`LazyVStack` combo, not `List`, since `List`'s implicit row insets break alignment with a custom flush header).

### Sort key configuration

File-based sort/compare use `SORT_COLUMNS`/`KEY_COLUMNS`/`DATE_COLUMNS` in `constants.py`. Live reorder takes its sort spec as a CLI arg / from `AppSettings` in the Swift app (default `artist,album,name`, see `FIELD_GETTERS` in `reorder_live_playlist.py` for valid fields) — the two are independently configured, not shared.
