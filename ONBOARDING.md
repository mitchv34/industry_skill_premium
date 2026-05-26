# Onboarding for the next Claude Code agent (HPC takeover)

You are continuing work on Mitchell Valdes-Bobes's dissertation chapter on **industry-level capital-skill complementarity**. The chapter estimates a Krusell-Ohanian-Ríos-Rull-Violante (KORV 2000) nested CES production model for 56 BEA industries, decomposes skill premium growth, and tests CSC heterogeneity across sectors. The previous agent (Claude on a WSL2 box) completed Phase 1 of a 12-week remediation plan; you're picking up at the start of Phase 2/3.

## First thing: read these, in order

1. **`documents/CHAPTER_REMEDIATION_PLAN.md`** — the master plan. 35 work items in 6 phases, 10 decision points, milestones, risks. Phase 1 (W1–W7) is ✅ complete; you're starting at W8/W12 onward.
2. **`.colab/chapter-readiness/WORKSHEET.md`** — the full multi-agent collab record. Has @gemini-research's data findings, @codex's methodology audit (with the three estimator bugs), and @claude's synthesis. The artifacts at `.colab/chapter-readiness/artifacts/` are essential context — read at minimum:
   - `codex-methodology-audit.md` — the three SPMLE bugs that were fixed
   - `5-w4-w5-design.md` — logistic reparam + instrument_labor rewrite
   - `3d-v2-panel-design.md` — industry-specific deflator construction (this is the BIG result that you'll use)
   - `4-ipums-extract-design.md` — CPS + ACS extract specs
3. **`documents/manuscript/manuscript.tex`** — the current draft (~1,025 lines). Note: many of the numbers in there are **stale**; W19 + W20 will regenerate them.
4. **`documents/EXTENSIONS_CROSS_INDUSTRY.md`** — six options for cross-industry estimation (status quo + EB shrinkage + common-σ recommended for the dissertation; hierarchical Bayesian deferred for journal version).
5. **The prior conversation** — `~/.claude/projects/-project-high_tech_ind-industry_skill_premium/fd455d67-14c0-4b2b-a3f8-caec49e73bae.jsonl` (4.6 MB JSONL). The user typically continues without needing you to read it, but it's there if you need deep history.

## State of the world

### Code (all on `master` at `acc786d`):

- **Estimator (`estimation/estimation.jl`, `estimation/do_estimation.jl`)**: three SPMLE bugs fixed (W1–W3 in `objectiveFunction`), logistic reparam in `set_optim_problem` (W4 — exposed helpers `constrained_to_free` / `free_to_constrained` / `free_to_params`), pilot test `w7_pilot.jl`, multistart diagnostic `w7_multistart.jl`. The optimizer now works in unconstrained 6-D z-space; result CSVs report constrained θ.
- **Instrumentation (`scripts/estimation/instrument_labor.jl`)**: labor-only, idempotent, writes to `{IND}_iv.csv` (originals at `data/proc/ind/{IND}.csv` never touched). Two-run diff verified byte-identical.
- **Industry deflator (`scripts/data_processing/build_industry_deflators.py`, `build_v2_panels.py`)**: BEA T3.7E / T3.8E with industry deviation × aggregate q_t. Output: `data/proc/ind_v2/{IND}.csv` for all 56 industries + `data/proc/industry_relative_prices.csv` (1947–2024). All other panel columns byte-identical to v1.
- **IPUMS extraction (`scripts/data_fetch/ipums_*.py`)**: programmatic submission/poll/download via `ipumspy 0.8.2`. CPS extract 106 (10.2M rows, 1962–2025) and ACS extract 175 (64M rows, 2000–2023) are at `data/raw/cps/`.
- **Plots (`scripts/data_processing/plot_premium_and_relprices.py`)**: aggregate + industry skill premium (1976–2025) and equipment relative prices (1976–2024) at `documents/images/`.
- **Config (`config.py`)**: `pass`-based + `.env` (via `python-dotenv`) secret helpers, canonical `data/raw/{bea,fred,cps,klems,alternative_sources}` layout, sample-window constants.

### Data on disk:

```
data/raw/
├── cps/
│   ├── cps_extract_106.csv.gz       205 MB  (1962–2025 CPS ASEC, 10.2M rows)
│   ├── cps_extract_106.xml
│   ├── acs_extract_175.csv.gz       1.3 GB  (2000–2023 ACS, 64M rows)
│   └── acs_extract_175.xml
└── alternative_sources/
    ├── bea_fixed_assets/            40 detail tables + Section3All (2.5 MB)
    ├── bls_klems/                   2 production-account xlsx (656 KB)
    ├── nber_ces/                    NBER-CES manufacturing csv (5 MB)
    └── bls_oes/                     OES 2005 + 2024 (162 MB)

data/proc/
├── ind/{56}.csv                     v1 panels, 1987–2018 (originals)
├── ind/{56}_iv.csv                  W5 instrumented labor outputs (1987–2018)
├── ind_v2/{56}.csv                  v2 panels with industry-specific REL_P_EQ
├── industry_relative_prices.csv     1947–2024 deviation reference
├── skill_premium_aggregate.csv      1962–2025 CPS-derived
└── skill_premium_by_industry.csv    2634 industry-year cells
```

`.env` (gitignored) at `<project_root>/.env` has `BEA_API_KEY`, `FRED_API_KEY`, `IPUMS_API_KEY`. **Read once via `config.get_*_api_key()`, never log.**

### What Phase 1 W7 told us

GO/NO-GO PASS. Pilot multistart on KORV 1963–1992 data with 8 starts:
- 3 of 8 starts converged to the **best basin** at `(α=0.07, σ=0.46, ρ=-0.51)` — within ±0.05 of KORV's published `(0.117, 0.401, -0.495)`.
- 4 of 8 found suboptimal local minima (e.g., `α=0.31, σ=0.33` from KORV-anchored starting point — counterintuitive).
- 1 of 8 (start with `σ_init = -0.1`) found a degenerate point with `obj = +49` — the optimizer fell off; the unconstrained reparam doesn't prevent σ from going very negative.
- **σ−ρ in [0.78, 0.98] for all 7 non-degenerate runs** — CSC robust across the basin landscape.

**Implications for industry estimation:**
- Multistart is mandatory. Pick the lowest-`obj` solution per industry.
- Add an outlier guard: reject any final estimate with `obj > 0` (degenerate). Track these separately.
- Starting from KORV's published values is NOT a reliable warmup — diversified start grid is required.

## What's next (priorities for you to pick up)

### Open todos (transcribed verbatim from prior session)

1. **W12 — `proc_labor_data` rewrite** using CPS extract 106 + ACS extract 175. Requires:
   - `OINCWAGE == 0` filter (allocation flag; the audit caught the manuscript claims this but code didn't apply it)
   - Sample selection logging at each filter step → CSV → `documents/tables/sample_selection.tex` (replaces the fabricated table at `manuscript.tex:952`)
   - Pre-1976 imputation: WKSWORK1 ← WKSWORK2 midpoint; UHRSWORKLY ← AHRSWORKT (the prior agent did this in plot_premium_and_relprices.py — port the same logic)
   - Bridge-file weighting for the 2018 CPS redesign break
   - Per-industry breakdown via Census IND1990 → BEA crosswalk (`data/cross_walk.csv`)
   - **Outputs**: `data/proc/labor_totl.csv` (extended through 2024), `data/proc/labor_by_industry.csv` (industry-year × skill), sample selection table tex

2. **Extend v2 panels 2019–2024** once W12 lands labor. Will need:
   - K_EQ, K_STR, DPR_EQ, DPR_ST extended from BEA Section 3 (tables FAAt301E/S, FAAt304E/S, FAAt307E/S) — partially in hand
   - OUTPUT from BEA GDPbyIndustry or KLEMS Value Added (1997–2024)
   - L_SHARE from KLEMS (Labor_Col_Comp + Labor_NoCol_Comp ÷ Value Added)
   - Industry deflator already in `industry_relative_prices.csv` through 2024
   - Labor variables (L_S, L_U, W_S, W_U) from W12 output

3. **Industry-level estimation with multistart** on v2 panels:
   - 56 industries × ≥24 starts (Latin hypercube or grid)
   - Outlier guard: reject `obj > 0`
   - Per-industry: pick min-obj across starts; flag boundary estimates (e.g., σ approaching 1)
   - Write to `data/results/{IND}.csv` (overwriting current stale results — back them up first)

4. **Bootstrap inference (W20 from the master plan)**:
   - Nonparametric block bootstrap, 5-year moving blocks
   - 200 replications baseline (500 archival if compute allows)
   - Dimensions: 56 industries × 200 reps × 24 starts = **~270k optimization runs**
   - At ~80s per run on this WSL: 21.6M CPU-seconds = 600 CPU-hours (single core). **This is your big compute hit.**

5. **Decomposition rewrite (W22)** — current decomposition reports percentages that explode when total skill premium change is near zero (Wholesale Trade reports 541,216%). Replace with log-point reporting; only use percentages when |total| > some threshold.

6. **Robustness suite (W24)** — exclude poor-fit industries, alt depreciation, alt hours threshold, no-1963-1975 sample, exclude post-2008.

7. **Aggregate goodness-of-fit (W23)** — three samples (1963–1992, 1963–2024, 1988–2024). Manuscript currently claims this is "deferred due to missing data" but the data exists.

8. **Manuscript revision (W28–W35)** — Sections 4, 5, 6, 7, 8 + robustness subsection + lit review update with Ohanian-Orak-Shen 2023, Acemoglu-Restrepo 2022, Hubmer-Restrepo 2025.

The full list is in `documents/CHAPTER_REMEDIATION_PLAN.md` §3.

## You now have ~~"more compute"~~ — use it

The previous agent estimated bootstrap at "~1–5 wall-clock days on a 32-core machine." You're on **UW SSCC (hathor)** which has Slurm. Don't run things directly on the login node — submit jobs.

### Parallelization opportunities

The work is embarrassingly parallel across three axes:

| Axis | Cardinality | Notes |
|---|---|---|
| **Industry** | 56 | Each is a separate Julia process; no cross-industry communication needed |
| **Bootstrap replication** | 200 | Each rep resamples CPS independently |
| **Start** | 24+ | For each (industry, rep), run multistart serially within one job |

Total jobs: 56 × 200 = 11,200 array tasks for the bootstrap. Each task runs ~24 starts × 80s ≈ 30 min on one core. Total CPU time: ~5,600 core-hours. On a 100-core allocation, that's ~56 wall-clock hours = ~2.5 days. With a bigger allocation, faster.

### Slurm sketch (you should refine)

```bash
#!/bin/bash
#SBATCH --job-name=korv-boot
#SBATCH --array=0-11199%200       # 11200 tasks, 200 concurrent
#SBATCH --cpus-per-task=1
#SBATCH --mem=4G                   # each industry data is ~80 KB; loaded model ~100 MB
#SBATCH --time=01:00:00            # 1 hour per task (generous)
#SBATCH --output=logs/boot_%A_%a.out

module load julia/1.12             # check actual module name on hathor
cd /project/high_tech_ind/industry_skill_premium

# Decode task id → (industry_idx, rep)
INDUSTRIES=(111CA 113FF 211 212 213 22 23 ...)  # 56 entries
TASK=${SLURM_ARRAY_TASK_ID}
IND_IDX=$(( TASK / 200 ))
REP=$(( TASK % 200 ))
IND=${INDUSTRIES[$IND_IDX]}

julia --project=. scripts/estimation/bootstrap_one.jl --ind ${IND} --rep ${REP}
```

`bootstrap_one.jl` doesn't exist yet — **you write it.** It should:
1. Read industry panel from `data/proc/ind_v2/{IND}.csv` (or `_iv.csv` for IV labor)
2. Resample the CPS microdata or industry-year moments (block-resample years; see codex's design in artifact 1b)
3. Re-construct the moments
4. Run 24-start multistart estimation
5. Write `data/results/bootstrap/{IND}/rep{REP}.csv` (atomic write)

### Setup checklist before you run anything heavy

```bash
# 1. Verify Julia + Python environments
module avail julia
julia --project=. -e 'using Pkg; Pkg.instantiate(); Pkg.precompile()'
python3 -m venv .venv && .venv/bin/pip install -r requirements.txt

# 2. Sanity-check the pilot still passes on hathor (5 minutes)
julia --project=. estimation/w7_pilot.jl

# 3. Sanity-check the v2 panel build still works
.venv/bin/python scripts/data_processing/build_v2_panels.py

# 4. Sanity-check IPUMS data loads
.venv/bin/python -c "import polars as pl; df = pl.read_csv('data/raw/cps/cps_extract_106.csv.gz', n_rows=100); print(df.shape, df.columns)"
```

If any of those fail, fix the local environment before proceeding.

## How to work with Mitchell

- **One task at a time, approval before each change.** This is his stated preference from the start of the project.
- **Don't run destructive things without asking.** That includes overwriting `data/results/` (back it up first), force-pushing, dropping committed data, etc.
- **The codex agent is available** if you want a code review or methodology pair. Use `/colab` to coordinate; the existing worksheet `.colab/chapter-readiness/WORKSHEET.md` is the open collab.
- **Don't waste compute.** Submit small smoke-tests before committing to a big array job. The bootstrap is the biggest spend — make sure one (industry, rep) works end-to-end before launching 11,199 more.
- **Stop-hook discipline**: every assistant turn ends with a one-sentence summary of what changed + a `Next:` line. Mitchell's WSL hook enforces this; respect it on the HPC too.

## Three things the prior agent didn't get to that matter

1. **`α` anomaly investigation**: in the W7 multistart, the lowest-`obj` solution has `α ≈ 0.07` — *below* KORV's published 0.117. Within ±0.05, so technically passes. But the basin landscape has a *second* attractor around `α ≈ 0.21` (also CSC-positive) and a *third* around `α ≈ 0.31` (the original pilot's bad local min). Verify which basin the corrected estimator selects on industry-level data and document the choice.

2. **The "degenerate σ" guard**: one of the 8 starts found `σ = -0.16, ρ = -1.27, obj = +49`. The reparam transform allows `σ → -∞` (`σ = 1 - exp(z)` is unbounded below). For industry estimation across 56 sectors × 24 starts, you'll see this more often. Implement explicit rejection: `if abs(σ) > 5 || obj > 0: skip`. Document in the methodology section.

3. **The `model` mutation issue**: `solve_optim_prob` mutates a shared `intializeModel()` object. In the multistart diagnostic the prior agent had to re-init Data + Model per start to avoid the bug. Refactor to either (a) per-process model isolation (every Slurm task creates its own model — easy; default for array jobs), or (b) thread-safe copies. Codex flagged this in their audit (see `artifacts/codex-methodology-audit.md`).

## Memory notes from the prior agent

- This project uses **`.env`** for secrets, not `pass` (which is the global convention). The `.env` is gitignored. See `~/.claude/projects/-project-high_tech_ind-industry_skill_premium/memory/secrets.md`.
- Mitchell strongly prefers **`uv`** for Python and **`polars`** over pandas.
- Repository convention: BEA industry codes (e.g., `334`, `5411`, `622HO`, `3361MV`) for industry identifiers; see `data/industry_names.csv`.
- Color palette for plots used so far: warm `#c0392b/#e67e22/#d35400/#922b21` (highlight non-IT industries), cool `#1f3a5f/#2874a6/#117a65/#0e6655` (IT-heavy). Black dashed for aggregate. See `scripts/data_processing/plot_premium_and_relprices.py:style_axes` for the clean-axis theme.

## Tell Mitchell when you start

The first thing he'll want to know: confirmation that you have the same environmental setup as the WSL (Julia 1.12.x, Python 3.12 + polars, `.env` keys load via `config.get_*_api_key()`). Run the setup checklist above and report. Then ask which Phase 2/3 item he wants to tackle first.

Good luck. The chapter's headline result (industry heterogeneity in CSC, σ−ρ varying across sectors) is robust through Phase 1; your job is to make it defendable through Phase 6.
