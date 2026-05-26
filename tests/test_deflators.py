from pathlib import Path
import sys

import polars as pl

ROOT = Path(__file__).resolve().parents[1]
if str(ROOT) not in sys.path:
    sys.path.append(str(ROOT))

from scripts.data_processing.build_industry_deflators import (  # noqa: E402
    merge_into_industry_panel,
    tornqvist_industry_deflator,
)


def test_tornqvist_constant_prices_are_constant() -> None:
    investment = pl.DataFrame(
        {
            "BEA_CODE": ["23", "23", "23", "23"],
            "YEAR": [1980, 1981, 1980, 1981],
            "ASSET_TYPE": ["computers", "computers", "machinery", "machinery"],
            "INVESTMENT": [40.0, 40.0, 60.0, 60.0],
        }
    )
    prices = pl.DataFrame(
        {
            "YEAR": [1980, 1981, 1980, 1981],
            "ASSET_TYPE": ["computers", "computers", "machinery", "machinery"],
            "PRICE_INDEX": [100.0, 100.0, 100.0, 100.0],
        }
    )

    result = tornqvist_industry_deflator(investment, prices)

    assert result["REL_P_EQ_INDUSTRY"].to_list() == [100.0, 100.0]


def test_single_asset_industry_matches_asset_price_index() -> None:
    investment = pl.DataFrame(
        {
            "BEA_CODE": ["334", "334", "334"],
            "YEAR": [1980, 1981, 1982],
            "ASSET_TYPE": ["computers", "computers", "computers"],
            "INVESTMENT": [100.0, 100.0, 100.0],
        }
    )
    prices = pl.DataFrame(
        {
            "YEAR": [1980, 1981, 1982],
            "ASSET_TYPE": ["computers", "computers", "computers"],
            "PRICE_INDEX": [100.0, 80.0, 64.0],
        }
    )

    result = tornqvist_industry_deflator(investment, prices)

    assert result["REL_P_EQ_INDUSTRY"].round(8).to_list() == [100.0, 80.0, 64.0]


def test_computer_industry_deflator_falls_faster_than_construction() -> None:
    investment = pl.DataFrame(
        {
            "BEA_CODE": ["334", "334", "23", "23"],
            "YEAR": [1980, 2010, 1980, 2010],
            "ASSET_TYPE": ["computers", "computers", "machinery", "machinery"],
            "INVESTMENT": [100.0, 100.0, 100.0, 100.0],
        }
    )
    prices = pl.DataFrame(
        {
            "YEAR": [1980, 2010, 1980, 2010],
            "ASSET_TYPE": ["computers", "computers", "machinery", "machinery"],
            "PRICE_INDEX": [100.0, 20.0, 100.0, 110.0],
        }
    )

    result = tornqvist_industry_deflator(investment, prices)
    wide = result.filter(pl.col("YEAR") == 2010).pivot(
        values="REL_P_EQ_INDUSTRY",
        index="YEAR",
        on="BEA_CODE",
    )

    assert wide["334"][0] / wide["23"][0] < 0.25


def test_merge_preserves_aggregate_price_and_replaces_rel_p_eq() -> None:
    panel = pl.DataFrame(
        {
            "YEAR": [1980, 1981],
            "L_SHARE": [0.8, 0.79],
            "REL_P_EQ": [1.0, 0.95],
        }
    )
    deflator = pl.DataFrame(
        {
            "BEA_CODE": ["23", "23"],
            "YEAR": [1980, 1981],
            "REL_P_EQ_INDUSTRY": [100.0, 101.0],
        }
    )

    merged = merge_into_industry_panel(panel, deflator)

    assert merged["REL_P_EQ_AGG"].to_list() == [1.0, 0.95]
    assert merged["REL_P_EQ"].to_list() == [100.0, 101.0]
    assert merged["BEA_CODE"].to_list() == ["23", "23"]
