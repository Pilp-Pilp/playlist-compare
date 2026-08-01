import logging
from pathlib import Path

from pandas import DataFrame

from constants import SORT_COLUMNS
from utils import load_playlist

logger = logging.getLogger(__name__)


class PlaylistSorter:
    def __init__(self, path: Path):
        self.path = path
        self.name = self.path.stem
        self.df = load_playlist(self.path)

    def sort(self) -> DataFrame:
        sorted_df = self.df.sort_values(
            SORT_COLUMNS,
            key=lambda col: col.fillna('').str.lower()
        ).reset_index(drop=True)
        logger.info(f"Sorted {len(sorted_df)} tracks in {self.name} by {', '.join(SORT_COLUMNS)}")

        return sorted_df
