"""Centralized project paths and secret helpers.

All scripts in this repo should import from here rather than hardcoding paths.
Secrets are retrieved via `pass` (Mitchell's global convention) with environment
variables as fallback for CI/agents.
"""

from __future__ import annotations

import os
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parent

# Auto-load .env (gitignored) if present, so secrets stored there flow into
# os.environ and get picked up by the get_*_api_key helpers below.
try:
    from dotenv import load_dotenv
    load_dotenv(ROOT / ".env")
except ImportError:
    pass

# -----------------------------------------------------------------------------
# Sample window — change here when extending the analysis sample.
# Used by R fetchers, Python ETL, and Julia estimation.
# -----------------------------------------------------------------------------
SAMPLE_START_YEAR = 1947       # Earliest year fetched from FRED/BEA (KORV-era)
SAMPLE_END_YEAR = 2025         # Latest year to attempt; fetchers will silently
                               # cap at each source's actual latest available.
INDUSTRY_SAMPLE_START_YEAR = 1988   # First year for which industry-level capital
                                    # data is consistently available.
INDUSTRY_SAMPLE_END_YEAR = 2024     # Target endpoint for industry sample
                                    # (KLEMS labor share will lag — see plan).

# -----------------------------------------------------------------------------
# Data paths.
# Layout:
#   data/raw/                 — direct API output from R/Python fetchers
#     bea/                    — BEA Fixed Assets, NIPA tables
#     fred/                   — FRED series
#     cps/                    — IPUMS CPS extracts
#     klems/                  — BEA-BLS KLEMS
#     alternative_sources/    — ACS, BEA ICT satellite, IFR robots, NBER-CES, OES
#   data/proc/                — Processed totals + per-industry panels
#     ind/                    — Per-industry CSVs (v1, uses aggregate REL_P_EQ)
#     ind_v2/                 — Per-industry CSVs with industry-specific q_{i,t}
#   data/results/             — Estimation outputs (per-industry + aggregate)
#     bootstrap/              — Bootstrap replication results
# -----------------------------------------------------------------------------
PATH_RAW = ROOT / "data" / "raw"
PATH_RAW_BEA = PATH_RAW / "bea"
PATH_RAW_FRED = PATH_RAW / "fred"
PATH_RAW_CPS = PATH_RAW / "cps"
PATH_RAW_KLEMS = PATH_RAW / "klems"
PATH_RAW_ALT = PATH_RAW / "alternative_sources"

PATH_PROC = ROOT / "data" / "proc"
PATH_PROC_IND = PATH_PROC / "ind"
PATH_PROC_IND_V2 = PATH_PROC / "ind_v2"

PATH_RESULTS = ROOT / "data" / "results"
PATH_RESULTS_BOOTSTRAP = PATH_RESULTS / "bootstrap"

# -----------------------------------------------------------------------------
# Backward-compat aliases. Some older scripts still import these names.
# Point them at the new canonical locations so nothing breaks while we migrate.
# -----------------------------------------------------------------------------
PATH_RAW_EXTEND = PATH_RAW_BEA          # legacy
PATH_INTERIM_EXTEND = PATH_PROC          # legacy

# -----------------------------------------------------------------------------
# Secrets — retrieved via `pass` per Mitchell's global convention.
# -----------------------------------------------------------------------------

def _pass_show(slug: str) -> str | None:
    """Retrieve a secret from `pass`. Returns None if pass is unavailable or
    the slug does not exist; callers should fall back to env vars."""
    try:
        result = subprocess.run(
            ["pass", "show", slug],
            capture_output=True,
            text=True,
            timeout=5,
            check=False,
        )
        if result.returncode == 0:
            return result.stdout.strip()
    except (FileNotFoundError, subprocess.TimeoutExpired):
        pass
    return None


def get_bea_api_key() -> str:
    """BEA API key. Set $BEA_API_KEY or `pass insert api/bea`."""
    return (
        _pass_show("api/bea")
        or os.environ.get("BEA_API_KEY", "")
    )


def get_fred_api_key() -> str:
    """FRED API key. Set $FRED_API_KEY or `pass insert api/fred`."""
    return (
        _pass_show("api/fred")
        or os.environ.get("FRED_API_KEY", "")
    )


def get_census_api_key() -> str:
    """Census Bureau API key (used by QWI fetcher).
    Set $CENSUS_API_KEY or `pass insert api/census`."""
    return (
        _pass_show("api/census")
        or os.environ.get("CENSUS_API_KEY", "")
    )


def get_ipums_api_key() -> str:
    """IPUMS API key (used by ipumspy for CPS + ACS extract submission).
    Get from https://account.ipums.org/api_keys.
    Set $IPUMS_API_KEY or `pass insert api/ipums`."""
    return (
        _pass_show("api/ipums")
        or os.environ.get("IPUMS_API_KEY", "")
    )


# Legacy env var (used by older scripts) — keep working until migration is done.
CENSUS_API_KEYS = os.environ.get(
    "CENSUS_API_KEYS_PATH",
    os.path.expanduser("~/my_work/census_data_api/api_key/"),
)

# -----------------------------------------------------------------------------
# Directory creation. Run on import so scripts can write without extra checks.
# -----------------------------------------------------------------------------
for p in (
    PATH_RAW_BEA, PATH_RAW_FRED, PATH_RAW_CPS, PATH_RAW_KLEMS, PATH_RAW_ALT,
    PATH_PROC_IND, PATH_PROC_IND_V2,
    PATH_RESULTS, PATH_RESULTS_BOOTSTRAP,
):
    try:
        p.mkdir(parents=True, exist_ok=True)
    except Exception:
        pass


if __name__ == "__main__":
    # Quick CLI: `python config.py` prints the resolved paths and key status.
    print(f"ROOT = {ROOT}")
    for name, val in sorted(globals().items()):
        if name.startswith("PATH_"):
            print(f"  {name} = {val}")
    print()
    print("API keys:")
    for label, fn in [("BEA", get_bea_api_key), ("FRED", get_fred_api_key),
                       ("Census", get_census_api_key), ("IPUMS", get_ipums_api_key)]:
        v = fn()
        print(f"  {label}: {'set' if v else 'NOT SET'}")
