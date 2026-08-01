import logging
import sys

from logger import setup_logger
from music_app import get_tracks, reorder_tracks

logger = logging.getLogger(__name__)

DEFAULT_SORT_SPEC = 'artist,album,name'

FIELD_GETTERS = {
    'artist': lambda t: t['artist'].lower(),
    'album': lambda t: t['album'].lower(),
    'name': lambda t: t['name'].lower(),
    'genre': lambda t: t['genre'].lower(),
    'year': lambda t: t['year'],
    'plays': lambda t: t['plays'],
    'dateadded': lambda t: t['date_added'],
}


def parse_sort_spec(spec: str) -> list[tuple[str, bool]]:
    keys = []
    for part in spec.split(','):
        part = part.strip()
        if not part:
            continue
        field, _, direction = part.partition(':')
        field = field.strip().lower()
        if field not in FIELD_GETTERS:
            raise ValueError(f"Unknown sort field '{field}'. Valid fields: {', '.join(FIELD_GETTERS)}")
        keys.append((field, direction.strip().lower() == 'desc'))

    if not keys:
        raise ValueError("Sort spec must contain at least one field")

    return keys


def sort_tracks(tracks: list[dict], sort_keys: list[tuple[str, bool]]) -> list[dict]:
    result = list(tracks)
    for field, descending in reversed(sort_keys):
        result.sort(key=FIELD_GETTERS[field], reverse=descending)
    return result


def reorder_playlist(playlist_name: str, sort_spec: str = DEFAULT_SORT_SPEC) -> None:
    logger.info(f"Reading tracks from '{playlist_name}' in Music.app")
    tracks = get_tracks(playlist_name)

    if not tracks:
        logger.error(f"No tracks found in playlist '{playlist_name}'.")
        raise SystemExit(1)

    current_ids = [t['id'] for t in tracks]
    sort_keys = parse_sort_spec(sort_spec)
    sorted_tracks = sort_tracks(tracks, sort_keys)
    target_ids = [t['id'] for t in sorted_tracks]

    # Tracks already sitting in their final position don't need to be touched: moving a
    # track is one Apple Event round-trip each, so skipping an already-correct prefix keeps
    # routine re-reorders (e.g. after adding a couple of songs) fast regardless of playlist size.
    prefix_len = 0
    while prefix_len < len(current_ids) and current_ids[prefix_len] == target_ids[prefix_len]:
        prefix_len += 1
    moves = target_ids[prefix_len:]

    if not moves:
        logger.info(f"'{playlist_name}' is already in order by {sort_spec}; nothing to do")
        return

    logger.info(
        f"Reordering {len(moves)} of {len(tracks)} tracks in Music.app by {sort_spec} "
        f"({prefix_len} already in place)"
    )
    reorder_tracks(playlist_name, moves)

    logger.info(f"Finished reordering '{playlist_name}'")


if __name__ == '__main__':
    setup_logger()

    if len(sys.argv) not in (2, 3):
        print('Usage: python reorder_live_playlist.py "Playlist Name" ["field:asc|desc,field2:asc|desc,..."]')
        print(f"Valid fields: {', '.join(FIELD_GETTERS)}")
        raise SystemExit(1)

    name = sys.argv[1]
    spec = sys.argv[2] if len(sys.argv) == 3 else DEFAULT_SORT_SPEC

    reorder_playlist(name, spec)
