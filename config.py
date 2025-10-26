import os

# Centralized project paths and small helpers for scripts in this repo.
# Update these if you want to change where data is read/written.

ROOT = os.path.abspath(os.path.dirname(__file__))

# Raw data produced by the R fetcher (get_capital_data.r)
PATH_RAW_EXTEND = os.path.join(ROOT, "extend_KORV", "data", "raw") + os.sep

# Interim files created by older ETL steps (kept for reference)
PATH_INTERIM_EXTEND = os.path.join(ROOT, "extend_KORV", "data", "interim") + os.sep

# Canonical path for processed per-industry CSVs that the Julia estimator reads
# estimation/estimation.jl expects `./data/proc/ind/{IND}.csv`
PATH_PROC_IND = os.path.join(ROOT, "data", "proc", "ind") + os.sep

# Path for estimation outputs
PATH_RESULTS = os.path.join(ROOT, "data", "results") + os.sep

# Default location to look for local API key files (can be overridden with env var)
# Set environment variable CENSUS_API_KEYS_PATH to override this value.
_DEFAULT_KEYS = os.path.expanduser("~/my_work/census_data_api/api_key/")
CENSUS_API_KEYS = os.environ.get("CENSUS_API_KEYS_PATH", _DEFAULT_KEYS)

# Ensure directories exist so scripts can write into them without extra checks
for p in (PATH_RAW_EXTEND, PATH_INTERIM_EXTEND, PATH_PROC_IND, PATH_RESULTS):
    try:
        os.makedirs(p, exist_ok=True)
    except Exception:
        # Avoid failing import if running in restricted environment; scripts should handle errors.
        pass
