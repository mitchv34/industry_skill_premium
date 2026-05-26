"""Submit/download the IPUMS CPS ASEC extract for the chapter extension."""

from __future__ import annotations

import argparse
import json
from pathlib import Path

from ipumspy import MicrodataExtract

try:
    from ipums_extract_utils import add_common_args, as_list, run_extract
except ModuleNotFoundError:
    from scripts.data_fetch.ipums_extract_utils import add_common_args, as_list, run_extract


CPS_VARIABLES = as_list(
    [
        "YEAR",
        "SERIAL",
        "MONTH",
        "ASECWT",
        "HFLAG",
        "AGE",
        "SEX",
        "RACE",
        "EDUC",
        "HIGRADE",
        "EDUC99",
        "EMPSTAT",
        "CLASSWLY",
        "WKSWORK1",
        "WKSWORK2",
        "UHRSWORKLY",
        "AHRSWORKT",
        "IND1990",
        "OCC1990",
        "INCWAGE",
        "OINCWAGE",
    ]
)


def cps_asec_samples(end_year: int = 2025, include_2018_bridge: bool = True) -> list[str]:
    samples = [f"cps{year}_03s" for year in range(1962, end_year + 1)]
    if include_2018_bridge:
        samples.append("cps2018_03b")
    return as_list(samples)


def build_extract(end_year: int = 2025, include_2018_bridge: bool = True) -> MicrodataExtract:
    return MicrodataExtract(
        collection="cps",
        samples=cps_asec_samples(end_year=end_year, include_2018_bridge=include_2018_bridge),
        variables=CPS_VARIABLES,
        description=(
            "industry_skill_premium CPS ASEC 1962-"
            f"{end_year} with 2018 bridge, allocation flag"
        ),
        data_format="csv",
        data_structure={"rectangular": {"on": "P"}},
        case_select_who="individuals",
    )


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    add_common_args(parser)
    parser.add_argument("--end-year", type=int, default=2025)
    parser.add_argument("--no-2018-bridge", action="store_true")
    return parser.parse_args()


def main() -> None:
    args = parse_args()
    extract = build_extract(
        end_year=args.end_year,
        include_2018_bridge=not args.no_2018_bridge,
    )
    metadata_path = args.metadata_dir / "ipums_cps_extract.json"
    result = run_extract(extract, "cps", metadata_path, args)

    note_path = Path(".colab/chapter-readiness/artifacts/4-ipums-cps-last-run.json")
    note_path.parent.mkdir(parents=True, exist_ok=True)
    note_path.write_text(json.dumps(result, indent=2) + "\n")


if __name__ == "__main__":
    main()
