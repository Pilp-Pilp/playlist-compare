import subprocess
from pathlib import Path

APPLESCRIPT_DIR = Path(__file__).parent / 'applescripts'


def _run_applescript(script_name: str, *args: str) -> str:
    result = subprocess.run(
        ['osascript', str(APPLESCRIPT_DIR / script_name), *args],
        capture_output=True, text=True, check=True
    )
    return result.stdout


def _as_int(value: str) -> int:
    try:
        return int(float(value))
    except ValueError:
        return 0


def get_tracks(playlist_name: str) -> list[dict]:
    output = _run_applescript('get_tracks.applescript', playlist_name)

    tracks = []
    for line in output.splitlines():
        if not line.strip():
            continue
        track_id, name, artist, album, genre, year, date_added, plays = line.split('\t', 7)
        tracks.append({
            'id': track_id,
            'name': name,
            'artist': artist,
            'album': album,
            'genre': genre,
            'year': _as_int(year),
            'date_added': _as_int(date_added),
            'plays': _as_int(plays),
        })

    return tracks


def reorder_tracks(playlist_name: str, ordered_ids: list[str]) -> None:
    _run_applescript('reorder_tracks.applescript', playlist_name, *ordered_ids)


def create_playlist(playlist_name: str) -> None:
    _run_applescript('create_playlist.applescript', playlist_name)


def add_tracks(dest_playlist_name: str, source_playlist_name: str, track_ids: list[str]) -> None:
    if not track_ids:
        return
    _run_applescript('add_tracks.applescript', dest_playlist_name, source_playlist_name, *track_ids)
