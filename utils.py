import logging
from pathlib import Path
from typing import Dict

from pandas import DataFrame, read_csv

from constants import DATE_COLUMNS

logger = logging.getLogger(__name__)


def load_playlist(file_path: Path) -> DataFrame:
    with open(file_path, 'rb') as f:
        encoding = 'utf-16' if f.read(2) in (b'\xff\xfe', b'\xfe\xff') else 'utf-8'

    df = read_csv(
        file_path,
        sep='\t',
        encoding=encoding,
        parse_dates=DATE_COLUMNS,
        dayfirst=True
    )
    logger.info(f"Loaded {len(df)} tracks from {file_path.name}")

    return df


def save_playlist(df: DataFrame, file_path: Path, columns: list = None) -> None:
    if columns is not None:
        df = df[columns]
    df.to_csv(
        file_path,
        sep='\t',
        index=False
    )


def save_results(results: Dict[str, DataFrame], output_dir: Path) -> None:
    output_dir.mkdir(parents=True, exist_ok=True)

    for key, df in results.items():
        csv_path = output_dir / f"{key}.tsv"
        save_playlist(df, csv_path)
