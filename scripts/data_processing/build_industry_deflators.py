"""Build industry-specific equipment deflators.

The current industry panels use a single aggregate equipment price. This module
constructs industry-level equipment price indexes from asset-level investment
shares and asset-level price indexes, or passes through a direct KLEMS deflator
if one is available.
"""

from __future__ import annotations

import argparse
import sys
from pathlib import Path

import polars as pl

ROOT = Path(__file__).resolve().parents[2]
if str(ROOT) not in sys.path:
    sys.path.append(str(ROOT))

import config  # noqa: E402

DEFAULT_BASE_YEAR = 1980


def _require_columns(df: pl.DataFrame, columns: set[str], name: str) -> None:
    missing = columns - set(df.columns)
    if missing:
        raise ValueError(f"{name} is missing required columns: {sorted(missing)}")


def _clean_panel_keys(df: pl.DataFrame, include_asset: bool = False) -> pl.DataFrame:
    exprs = [
        pl.col("BEA_CODE").cast(pl.Utf8),
        pl.col("YEAR").cast(pl.Int64),
    ]
    if include_asset:
        exprs.append(pl.col("ASSET_TYPE").cast(pl.Utf8))
    return df.with_columns(exprs)


def _normalize_to_base_year(
    df: pl.DataFrame,
    value_col: str,
    output_col: str,
    base_year: int = DEFAULT_BASE_YEAR,
) -> pl.DataFrame:
    base = (
        df.filter(pl.col("YEAR") == base_year)
        .select("BEA_CODE", pl.col(value_col).alias("_base_value"))
    )

    missing_base = set(df["BEA_CODE"].unique()) - set(base["BEA_CODE"].unique())
    if missing_base:
        raise ValueError(
            f"Cannot normalize to {base_year}; missing base year for "
            f"{sorted(missing_base)[:10]}"
        )

    return (
        df.join(base, on="BEA_CODE", how="left")
        .with_columns((pl.col(value_col) / pl.col("_base_value") * 100.0).alias(output_col))
        .drop("_base_value")
    )


def tornqvist_industry_deflator(
    investment_df: pl.DataFrame,
    price_df: pl.DataFrame,
    base_year: int = DEFAULT_BASE_YEAR,
) -> pl.DataFrame:
    """Construct industry equipment deflators using Tornqvist weights.

    Parameters
    ----------
    investment_df
        Long data with columns BEA_CODE, YEAR, ASSET_TYPE, INVESTMENT.
    price_df
        Long data with columns YEAR, ASSET_TYPE, PRICE_INDEX.
    base_year
        Year normalized to 100. The existing aggregate series is effectively
        chained from a base period, so keeping a visible 1980=100 normalization
        makes the output easy to audit before any later rescaling.
    """
    _require_columns(
        investment_df,
        {"BEA_CODE", "YEAR", "ASSET_TYPE", "INVESTMENT"},
        "investment_df",
    )
    _require_columns(price_df, {"YEAR", "ASSET_TYPE", "PRICE_INDEX"}, "price_df")

    investments = (
        investment_df.select("BEA_CODE", "YEAR", "ASSET_TYPE", "INVESTMENT")
        .pipe(_clean_panel_keys, include_asset=True)
        .with_columns(pl.col("INVESTMENT").cast(pl.Float64))
        .group_by("BEA_CODE", "YEAR", "ASSET_TYPE")
        .agg(pl.col("INVESTMENT").sum())
    )
    totals = investments.group_by("BEA_CODE", "YEAR").agg(
        pl.col("INVESTMENT").sum().alias("_total_investment")
    )
    shares = (
        investments.join(totals, on=["BEA_CODE", "YEAR"], how="left")
        .filter(pl.col("_total_investment") > 0)
        .with_columns((pl.col("INVESTMENT") / pl.col("_total_investment")).alias("_share"))
        .drop("_total_investment")
    )

    prices = (
        price_df.select("YEAR", "ASSET_TYPE", "PRICE_INDEX")
        .with_columns(
            pl.col("YEAR").cast(pl.Int64),
            pl.col("ASSET_TYPE").cast(pl.Utf8),
            pl.col("PRICE_INDEX").cast(pl.Float64),
        )
        .group_by("YEAR", "ASSET_TYPE")
        .agg(pl.col("PRICE_INDEX").mean())
    )

    asset_panel = (
        shares.join(prices, on=["YEAR", "ASSET_TYPE"], how="inner")
        .sort("BEA_CODE", "ASSET_TYPE", "YEAR")
        .with_columns(
            pl.col("_share")
            .shift(1)
            .over("BEA_CODE", "ASSET_TYPE")
            .alias("_share_lag"),
            pl.col("PRICE_INDEX")
            .shift(1)
            .over("BEA_CODE", "ASSET_TYPE")
            .alias("_price_lag"),
        )
        .filter(pl.col("_price_lag").is_not_null())
        .with_columns(
            (
                0.5
                * (pl.col("_share") + pl.col("_share_lag"))
                * (pl.col("PRICE_INDEX").log() - pl.col("_price_lag").log())
            ).alias("_weighted_dlog_price")
        )
    )

    growth = asset_panel.group_by("BEA_CODE", "YEAR").agg(
        pl.col("_weighted_dlog_price").sum().alias("_dlog_q")
    )

    industry_years = investments.select("BEA_CODE", "YEAR").unique()
    chained = (
        industry_years.join(growth, on=["BEA_CODE", "YEAR"], how="left")
        .with_columns(pl.col("_dlog_q").fill_null(0.0))
        .sort("BEA_CODE", "YEAR")
        .with_columns(pl.col("_dlog_q").cum_sum().over("BEA_CODE").alias("_log_q_raw"))
        .with_columns(pl.col("_log_q_raw").exp().alias("_q_raw"))
    )

    return (
        _normalize_to_base_year(chained, "_q_raw", "REL_P_EQ_INDUSTRY", base_year)
        .select("BEA_CODE", "YEAR", "REL_P_EQ_INDUSTRY")
        .sort("BEA_CODE", "YEAR")
    )


def klems_direct_deflator(
    klems_capital_df: pl.DataFrame,
    base_year: int | None = None,
) -> pl.DataFrame:
    """Return a direct industry equipment deflator from KLEMS-like data."""
    _require_columns(klems_capital_df, {"BEA_CODE", "YEAR"}, "klems_capital_df")
    candidates = [
        "REL_P_EQ_INDUSTRY",
        "EQUIPMENT_PRICE_INDEX",
        "PRICE_INDEX",
        "PXEQ",
        "P_EQ",
        "REL_P_EQ",
    ]
    price_col = next((col for col in candidates if col in klems_capital_df.columns), None)
    if price_col is None:
        raise ValueError(
            "klems_capital_df needs one deflator column; tried "
            f"{', '.join(candidates)}"
        )

    out = (
        klems_capital_df.select("BEA_CODE", "YEAR", price_col)
        .pipe(_clean_panel_keys)
        .with_columns(pl.col(price_col).cast(pl.Float64).alias("REL_P_EQ_INDUSTRY"))
        .select("BEA_CODE", "YEAR", "REL_P_EQ_INDUSTRY")
        .sort("BEA_CODE", "YEAR")
    )
    if base_year is not None:
        out = _normalize_to_base_year(out, "REL_P_EQ_INDUSTRY", "REL_P_EQ_INDUSTRY", base_year)
    return out


def merge_into_industry_panel(panel_df: pl.DataFrame, deflator_df: pl.DataFrame) -> pl.DataFrame:
    """Replace panel REL_P_EQ with the industry-specific deflator.

    The original aggregate series is preserved as REL_P_EQ_AGG. If panel_df does
    not include BEA_CODE, deflator_df must contain exactly one BEA_CODE.
    """
    _require_columns(panel_df, {"YEAR", "REL_P_EQ"}, "panel_df")
    _require_columns(deflator_df, {"BEA_CODE", "YEAR", "REL_P_EQ_INDUSTRY"}, "deflator_df")

    panel = panel_df.with_columns(pl.col("YEAR").cast(pl.Int64))
    deflators = _clean_panel_keys(deflator_df).select(
        "BEA_CODE", "YEAR", "REL_P_EQ_INDUSTRY"
    )

    join_keys = ["YEAR"]
    if "BEA_CODE" in panel.columns:
        panel = panel.with_columns(pl.col("BEA_CODE").cast(pl.Utf8))
        join_keys = ["BEA_CODE", "YEAR"]
    else:
        codes = deflators["BEA_CODE"].unique().to_list()
        if len(codes) != 1:
            raise ValueError(
                "panel_df has no BEA_CODE; pass a deflator_df filtered to exactly "
                "one industry"
            )
        panel = panel.with_columns(pl.lit(codes[0]).alias("BEA_CODE"))
        join_keys = ["BEA_CODE", "YEAR"]

    if "REL_P_EQ_AGG" not in panel.columns:
        panel = panel.rename({"REL_P_EQ": "REL_P_EQ_AGG"})
    else:
        panel = panel.drop("REL_P_EQ")

    merged = panel.join(deflators, on=join_keys, how="left")
    missing_years = merged.filter(pl.col("REL_P_EQ_INDUSTRY").is_null())["YEAR"].to_list()
    if missing_years:
        raise ValueError(f"Missing industry deflator for years: {sorted(set(missing_years))}")

    return (
        merged.with_columns(pl.col("REL_P_EQ_INDUSTRY").alias("REL_P_EQ"))
        .drop("REL_P_EQ_INDUSTRY")
        .select(
            [
                col
                for col in panel_df.columns
                if col not in {"REL_P_EQ", "REL_P_EQ_AGG", "BEA_CODE"}
            ]
            + ["BEA_CODE", "REL_P_EQ_AGG", "REL_P_EQ"]
        )
    )


def _read_csv(path: Path) -> pl.DataFrame:
    if not path.exists():
        raise FileNotFoundError(path)
    return pl.read_csv(path, infer_schema_length=10000)


def _write_panel_outputs(
    panel_dir: Path,
    output_dir: Path,
    deflator_df: pl.DataFrame,
) -> None:
    output_dir.mkdir(parents=True, exist_ok=True)
    for panel_path in sorted(panel_dir.glob("*.csv")):
        code = panel_path.stem
        panel = pl.read_csv(panel_path)
        one_deflator = deflator_df.filter(pl.col("BEA_CODE").cast(pl.Utf8) == code)
        if one_deflator.is_empty():
            raise ValueError(f"No deflator found for {code}")
        merged = merge_into_industry_panel(panel, one_deflator)
        merged.write_csv(output_dir / panel_path.name)


def _default_method(args: argparse.Namespace) -> str:
    if args.method != "auto":
        return args.method
    if args.klems and args.klems.exists():
        return "klems"
    return "tornqvist"


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--method", choices=["auto", "tornqvist", "klems"], default="auto")
    parser.add_argument("--investment", type=Path, help="BEA 3.7E long investment CSV")
    parser.add_argument("--prices", type=Path, help="NIPA 5.6.4 long price-index CSV")
    parser.add_argument("--klems", type=Path, help="KLEMS direct industry deflator CSV")
    parser.add_argument("--panel-dir", type=Path, default=config.PATH_PROC_IND)
    parser.add_argument("--output-dir", type=Path, default=config.PATH_PROC_IND_V2)
    parser.add_argument(
        "--out-deflator",
        type=Path,
        default=config.PATH_PROC / "industry_equipment_deflators.csv",
    )
    parser.add_argument("--base-year", type=int, default=DEFAULT_BASE_YEAR)
    return parser.parse_args()


def main() -> None:
    args = parse_args()
    method = _default_method(args)

    if method == "klems":
        if args.klems is None:
            raise ValueError("--klems is required when --method klems")
        deflators = klems_direct_deflator(_read_csv(args.klems), base_year=args.base_year)
    else:
        if args.investment is None or args.prices is None:
            raise ValueError("--investment and --prices are required for Tornqvist mode")
        deflators = tornqvist_industry_deflator(
            _read_csv(args.investment),
            _read_csv(args.prices),
            base_year=args.base_year,
        )

    args.out_deflator.parent.mkdir(parents=True, exist_ok=True)
    deflators.write_csv(args.out_deflator)
    _write_panel_outputs(args.panel_dir, args.output_dir, deflators)


if __name__ == "__main__":
    main()
