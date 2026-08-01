import logging

from constants import PLAYLIST_DIR, RESULTS_DIR
from logger import setup_logger
from utils import save_results

logger = logging.getLogger(__name__)

from playlist_comparer import PlaylistComparer
from playlist_sorter import PlaylistSorter


def main():
    setup_logger()

    files = sorted([p for p in PLAYLIST_DIR.iterdir() if p.is_file() and not p.name.startswith('.')])

    if len(files) == 1:
        logger.info("Starting playlist sort")
        sorter = PlaylistSorter(files[0])
        results = {f'{sorter.name}_sorted': sorter.sort()}
    elif len(files) == 2:
        logger.info("Starting playlist comparison")
        comparer = PlaylistComparer(files[0], files[1])
        results = comparer.compare()
    else:
        logger.error(f"Expected 1 or 2 files in {PLAYLIST_DIR.name} directory, found {len(files)}.")
        raise SystemExit(1)

    save_results(results, RESULTS_DIR)
    logger.info(f"Finished successfully (saved in {RESULTS_DIR.name} directory)")


if __name__ == '__main__':
    main()
