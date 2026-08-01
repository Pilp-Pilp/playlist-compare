# Using this project on Windows

This repo has two kinds of tools, and they don't port the same way.

## Works as-is on Windows

The file-based tools only need Python + pandas — no macOS dependency:

- `main.py` (sort/compare from exported TSV files in `playlists/`)
- `constants.py`, `utils.py`, `playlist_comparer.py`, `playlist_sorter.py`, `logger.py`

To use them on Windows: install Python 3.8+, `pip install pandas`, export your playlist(s) from the Music app (Windows) or classic iTunes into `playlists/`, then run `python main.py`. Nothing in this path talks to macOS at all.

## Does NOT work on Windows as-is

Everything that edits a playlist **live**, without a manual export/import round trip, depends on AppleScript talking to Music.app:

- `reorder_live_playlist.py`
- `compare_live_playlists.py`
- `build_playlist.py`
- `music_app.py` (the shared layer all three call into)
- everything in `applescripts/`
- the `PlaylistOrganizerApp` SwiftUI app (also macOS/AppleScript-only, and Swift itself is macOS-native here)

AppleScript / `osascript` only exists on macOS. There is no direct equivalent on Windows, and this code will not run there.

## If you want the live-editing features on Windows

The only realistic path is if you're running **classic iTunes for Windows** (not the newer standalone "Apple Music" app for Windows — see caveat below). Classic iTunes exposes a COM automation interface (the "iTunes SDK") that plays a similar role to AppleScript's Music dictionary on macOS. From Python you'd use `comtypes` or `pywin32` instead of `subprocess` + `osascript`.

Rough mapping, if you wanted to port `music_app.py`:

| macOS (`music_app.py`) | Windows (conceptual) |
|---|---|
| `osascript get_tracks.applescript` | COM: `iTunes.LibrarySource.Playlists`, iterate `Tracks`, read `.Name`, `.Artist`, `.Album`, `.trackID` |
| `move track id X to end of playlist` | **Not confirmed to exist.** iTunes COM's playlist-ordering support is more limited than AppleScript's; this needs to be verified against the iTunes SDK docs before assuming it's possible. |
| `duplicate track id X to playlist` | COM: `sourcePlaylist.Tracks.ItemByPersistentID(id).???` — iTunes COM has `IITTrack` but the "add existing library track to another playlist by reference" call needs to be looked up specifically; it may only support adding by file path, which would re-import rather than reference. |
| `make new user playlist` | COM: `iTunes.CreatePlaylist("name")` |

None of the reordering/adding behavior above has actually been tested against iTunes COM — it's a starting point for research, not a working recipe. Before porting, you'd want to:

1. Confirm iTunes for Windows (classic, not the new Apple Music app) is what you're running — check Help → About.
2. Look at the iTunes COM SDK docs (Apple used to ship `iTunesCOMInterface.h` with iTunes for Windows) for the exact playlist-editing methods available.
3. Prototype `get_tracks` equivalent first (read-only, lowest risk) before attempting reorder/build.

## The newer "Apple Music" app for Windows

If you're on the newer Apple Music app (replacing iTunes on Windows), there is currently no known public scripting/automation API for it. If that's the case, the live-editing tools in this repo have no Windows equivalent at all — only the file-based `main.py` workflow would be usable.
