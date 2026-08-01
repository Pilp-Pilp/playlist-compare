import json
import logging
import sys

from logger import setup_logger
from music_app import add_tracks, create_playlist, get_tracks
from playlist_comparer import PlaylistComparer

logger = logging.getLogger(__name__)


def _annotate(tracks: list[dict]) -> None:
    for t in tracks:
        t['_norm_name'] = PlaylistComparer.normalize_name(t['name'])
        t['_norm_artist'] = PlaylistComparer.normalize_artist(t['artist'])


class _UnionFind:
    def __init__(self, n: int):
        self.parent = list(range(n))

    def find(self, x: int) -> int:
        while self.parent[x] != x:
            self.parent[x] = self.parent[self.parent[x]]
            x = self.parent[x]
        return x

    def union(self, a: int, b: int) -> None:
        ra, rb = self.find(a), self.find(b)
        if ra != rb:
            self.parent[ra] = rb


def compare(names: list[str]) -> list[dict]:
    """Groups tracks across all playlists into rows (one row per song), each row noting
    which of the given playlists it's present in."""
    all_tracks = {name: get_tracks(name) for name in names}
    for tracks in all_tracks.values():
        _annotate(tracks)

    flat = [(name, t) for name in names for t in all_tracks[name]]

    by_norm_name: dict[str, list[int]] = {}
    for i, (_, t) in enumerate(flat):
        by_norm_name.setdefault(t['_norm_name'], []).append(i)

    uf = _UnionFind(len(flat))
    for indices in by_norm_name.values():
        for a in range(len(indices)):
            for b in range(a + 1, len(indices)):
                i, j = indices[a], indices[b]
                if PlaylistComparer.is_artist_subset(flat[i][1]['_norm_artist'], flat[j][1]['_norm_artist']):
                    uf.union(i, j)

    components: dict[int, list[tuple[str, dict]]] = {}
    for i, member in enumerate(flat):
        components.setdefault(uf.find(i), []).append(member)

    rows = []
    for members in components.values():
        presence: dict[str, dict | None] = {name: None for name in names}
        for name, t in members:
            if presence[name] is None:
                presence[name] = {'id': t['id'], 'album': t['album']}

        rep_name, rep_track = members[0]
        rows.append({
            'name': rep_track['name'],
            'artist': rep_track['artist'],
            'overlapping': len({name for name, _ in members}) > 1,
            'presence': presence,
        })

    return rows


def print_summary(names: list[str], rows: list[dict]) -> None:
    print()
    for name in names:
        count = sum(1 for r in rows if not r['overlapping'] and r['presence'][name] is not None)
        print(f"Only in '{name}': {count}")

    overlapping = [r for r in rows if r['overlapping']]
    print(f"Overlapping across playlists: {len(overlapping)}")

    for name in names:
        print(f"\nOnly in '{name}':")
        unique = [r for r in rows if not r['overlapping'] and r['presence'][name] is not None]
        for r in sorted(unique, key=lambda r: (r['artist'].lower(), r['name'].lower())):
            print(f"  {r['artist']} - {r['name']}")
    print()


def print_json(names: list[str], rows: list[dict]) -> None:
    json.dump({'playlists': names, 'rows': rows}, sys.stdout)


def build_non_overlap_playlist(output_name: str, names: list[str], rows: list[dict]) -> None:
    logger.info(f"Creating playlist '{output_name}'")
    create_playlist(output_name)

    by_source: dict[str, list[str]] = {name: [] for name in names}
    for r in rows:
        if r['overlapping']:
            continue
        for name in names:
            if r['presence'][name] is not None:
                by_source[name].append(r['presence'][name]['id'])
                break

    total = 0
    for name, ids in by_source.items():
        add_tracks(output_name, name, ids)
        total += len(ids)

    logger.info(f"Added {total} non-overlapping tracks to '{output_name}'")


if __name__ == '__main__':
    setup_logger()

    args = sys.argv[1:]
    json_mode = '--json' in args
    if json_mode:
        args.remove('--json')

    if json_mode:
        if len(args) < 2:
            print('Usage: python compare_live_playlists.py --json "Playlist 1" "Playlist 2" [...]')
            raise SystemExit(1)
        logger.info(f"Comparing: {', '.join(args)}")
        print_json(args, compare(args))
    else:
        if len(args) < 3:
            print('Usage: python compare_live_playlists.py "Playlist 1" "Playlist 2" [...] "Non-Overlap Playlist Name"')
            raise SystemExit(1)
        *playlist_names, output_playlist = args

        logger.info(f"Comparing: {', '.join(playlist_names)}")
        result_rows = compare(playlist_names)
        print_summary(playlist_names, result_rows)
        build_non_overlap_playlist(output_playlist, playlist_names, result_rows)
