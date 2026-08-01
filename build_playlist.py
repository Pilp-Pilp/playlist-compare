import json
import logging
import sys
from collections import defaultdict

from logger import setup_logger
from music_app import add_tracks, create_playlist

logger = logging.getLogger(__name__)


def build_playlist(output_name: str, selections: list[dict]) -> None:
    by_source: dict[str, list[str]] = defaultdict(list)
    for sel in selections:
        by_source[sel['source']].append(sel['id'])

    logger.info(f"Creating playlist '{output_name}'")
    create_playlist(output_name)

    total = 0
    for source, ids in by_source.items():
        add_tracks(output_name, source, ids)
        total += len(ids)

    logger.info(f"Added {total} tracks to '{output_name}'")


if __name__ == '__main__':
    setup_logger()

    if len(sys.argv) != 2:
        print('Usage: python build_playlist.py "Output Playlist Name" < selections.json')
        print('selections.json: [{"source": "Playlist Name", "id": "12345"}, ...]')
        raise SystemExit(1)

    selected = json.load(sys.stdin)
    build_playlist(sys.argv[1], selected)
