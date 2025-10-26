## Quick orientation for AI coding agents

This repository mixes data-fetch (R), ETL (Python), and estimation/analysis (Julia). The goal of an agent here is to keep the data pipeline intact and produce reproducible per-industry estimations.

Core pieces you should know (big picture)
- Data ingestion (BEA, FRED, Census/QWI): `get_capital_data.r`, `qwi_data.py` and other small scripts under the project root. These produce raw CSV files to disk.
- ETL / processing: `process_capital_data.py` and related scripts read the raw CSVs and produce per-industry CSVs (naming: `capital_{BEAIND}.csv` in `extend_KORV/data/interim/` or similar). Note: the code expects semicolon-separated CSVs and often replaces comma decimals with dots.
- Estimation & plotting: `estimation/estimation.jl`, `estimation/do_estimation.jl` and other `.jl` files implement the model, objective function, and the optimization flow. They read processed per-industry CSVs from a `./data/proc/ind/` or `./data/proc/` folder and write results to `./data/results/`.

Practical run/development notes
- Most scripts use hard-coded or local API key paths. Before running, update API keys and paths:
  - `get_capital_data.r` defines `beaKey` and `fredKey` at the top.
  - `qwi_data.py` reads an API key from a local directory (`api_keys_path` near the top of the file).
  - Search for `api_key`, `beaKey`, `fredKey`, or absolute paths before running.
- Typical workflow (order):
  1. Run the R fetcher: `Rscript get_capital_data.r` (requires `pacman`, `bea.R`, `fredr`).
  2. Run the Python ETL: `python3 process_capital_data.py` (requires `pandas`, `rich`). This script reads `./extend_KORV/data/raw/` and writes `./extend_KORV/data/interim/`.
  3. Run Julia estimation: `julia --project=./ estimation/do_estimation.jl` (requires `DataFrames`, `CSV`, `Optim`, `Plots`, `ModelingToolkit`, etc.).

File / data conventions and examples to follow
- CSVs: many files use `sep=";"` and decimal commas in raw files. `process_capital_data.py` explicitly replaces `","` with `"."` before saving interim CSVs.
- BEA industry codes: `process_capital_data.py` extracts `BEAIND` via `SeriesCode[3:7]` — produced interim filenames like `capital_{BEAIND}.csv`.
- Estimation expects per-industry files under `./data/proc/ind/{IND}.csv` (see `estimation/estimation.jl` — `estimate_industry` reads `./data/proc/ind/$(ind_code).csv`). Ensure ETL outputs are placed or symlinked there.

Patterns and risky conventions to watch
- Hard-coded user paths and API key locations — update before automation.
- Mixing of storage locations: `extend_KORV/data/...` vs `data/proc/...` vs `data/interim/` — double-check where each step writes/reads.
- Different languages and separators — maintain consistent CSV conventions when connecting steps (semicolon, decimal comma/dot).

How to modify code safely (contract & edge cases)
- Inputs: small scripts expect CSVs with columns like `K_EQ`, `K_STR`, `L_S`, `L_U`, `W_S`, `W_U`, `OUTPUT`, `L_SHARE`, `REL_P_EQ` (see `estimation/estimation.jl` -> `generateData`).
- Outputs: `estimation` writes per-industry result CSVs to `./data/results/{ind_code}.csv`.
- Error modes to handle: missing API keys, empty/malformed raw CSVs, mismatched decimal separators, and missing per-industry CSVs. Add clear checks and user-facing errors rather than silent exceptions.

Examples taken from the repo (copy/paste safe snippets for agents)
- Extract BEA industry code in Python ETL: `data["BEAIND"] = data.SeriesCode.apply(lambda x: x[3:7])` (in `process_capital_data.py`).
- R data fetch writes raw CSVs to `./extend_KORV/data/raw/` (see `get_capital_data.r` — `write.csv2(..., quote=FALSE)`).
- Julia estimator reads `./data/proc/ind/$(ind_code).csv` and appends results to `./data/results/$(ind_code).csv` (see `estimation/estimation.jl` -> `estimate_industry`).

When adding or editing code, prefer small, local changes
- Preserve existing file I/O conventions unless you also update the downstream consumer.
- If you move a folder or change a separator, update all three layers (R fetcher -> Python ETL -> Julia estimation) or add a small adapter script.

If you need to run tests or verify a change
- There are no unit tests in the repo. Validate changes by running the three-stage pipeline on a single industry file:
  - fetch (or use an existing raw CSV), run ETL for that file, then run `estimate_industry` for one `ind_code` using `estimation/estimation.jl`.

Questions for the maintainer (ask the user if unclear)
- Which data path (extend_KORV vs data/proc) is canonical for CI or reproducible runs?
- Where should API keys live for automated CI runs (and which keys are placeholders)?

If anything in this summary looks off or you'd like a different focus (tests, CI, or automated runs), tell me which area to expand and I'll update this file.
