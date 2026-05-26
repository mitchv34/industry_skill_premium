"""Submit/download the IPUMS USA ACS extract for the chapter extension."""

from __future__ import annotations

import argparse
import json
from pathlib import Path

from ipumspy import MicrodataExtract

try:
    from ipums_extract_utils import add_common_args, as_list, run_extract
except ModuleNotFoundError:
    from scripts.data_fetch.ipums_extract_utils import add_common_args, as_list, run_extract


ACS_VARIABLES = as_list(
    [
        "YEAR",
        "SERIAL",
        "PERWT",
        "HHWT",
        "AGE",
        "SEX",
        "RACE",
        "HISPAN",
        "EDUC",
        "EDUCD",
        "DEGFIELD",
        "DEGFIELDD",
        "EMPSTAT",
        "CLASSWKR",
        "CLASSWKRD",
        "WKSWORK1",
        "WKSWORK2",
        "UHRSWORK",
        "IND1990",
        "OCC1990",
        "IND",
        "OCC",
        "INCWAGE",
    ]
)


def acs_samples(start_year: int = 2000, end_year: int = 2023) -> list[str]:
    if start_year != 2000:
        raise ValueError("This helper currently expects ACS start year 2000.")
    if end_year < 2000:
        raise ValueError("end_year must be >= 2000.")
    samples = ["us2000d"]
    samples.extend(f"us{year}a" for year in range(2001, end_year + 1))
    return as_list(samples)


def build_extract(end_year: int = 2023) -> MicrodataExtract:
    return MicrodataExtract(
        collection="usa",
        samples=acs_samples(end_year=end_year),
        variables=ACS_VARIABLES,
        description=f"industry_skill_premium ACS 2000-{end_year}",
        data_format="csv",
        data_structure={"rectangular": {"on": "P"}},
        case_select_who="individuals",
    )


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    add_common_args(parser)
    parser.add_argument("--end-year", type=int, default=2023)
    return parser.parse_args()


def main() -> None:
    args = parse_args()
    extract = build_extract(end_year=args.end_year)
    metadata_path = args.metadata_dir / "ipums_acs_extract.json"
    result = run_extract(extract, "acs", metadata_path, args)

    note_path = Path(".colab/chapter-readiness/artifacts/4-ipums-acs-last-run.json")
    note_path.parent.mkdir(parents=True, exist_ok=True)
    note_path.write_text(json.dumps(result, indent=2) + "\n")


if __name__ == "__main__":
    main()
