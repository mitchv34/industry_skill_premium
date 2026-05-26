# Chapter Remediation + 2024 Extension Plan

**Chapter:** Industry-level capital-skill complementarity (KORV at the industry level)
**Source:** `documents/manuscript/manuscript.tex`
**Authored:** 2026-05-25 (@claude, synthesized from @gemini-research + @codex via `.colab/chapter-readiness/`)
**Target completion:** 12 weeks (2026-05-25 → 2026-08-17)

---

## 1. Executive summary

The chapter has a complete narrative and a 1,025-line draft, but a 33-item audit revealed that the estimator does not match the manuscript description (three independent bugs in the objective function), the headline decomposition figures are mathematical artifacts, industry counts are inconsistent across the paper, the sample-selection table is fabricated, and there are no standard errors. Separately, the sample currently ends in 2018; all of the 2019–2024 data is published and the chapter should be extended.

This plan combines remediation and extension into a single re-estimation pipeline because (i) every published number in the chapter is suspect under the broken estimator, so re-running on the old sample is wasted work, and (ii) the BEA shift to NAICS 2022 (2023) means the historical 1988–2018 series have been restated and must be re-fetched anyway. We therefore treat 1988–2024 as the new baseline sample, not 1988–2018 plus an extension.

**In scope:** estimator and instrumentation fixes; full data refresh (BEA Fixed Assets, FRED, IPUMS CPS, BEA-BLS KLEMS) through 2024 (KLEMS through 2023, with 2024 substitution); re-estimation of aggregate + all industries; bootstrap standard errors; decomposition rewrite; robustness section; reproducibility infrastructure; full manuscript rewrite of Sections 4 (Data), 5 (Estimation), 6 (Results), 7 (Discussion); literature update.

**Out of scope** (see §7): firm-level extension, occupation-level skill definitions, AI-specific capital separation, international comparison, formal welfare analysis.

**Target completion:** 12 weeks of focused work. Critical-path estimate is ~9 weeks; the remaining 3 weeks are buffer + polish + integration. Compute requirement at peak: ~1–5 wall-clock days on a 32-core machine for the bootstrap.

---

## 2. Decision points (@mitchell must resolve before execution)

These are gating decisions. My recommendations are the first option in each pair; rationale follows.

| # | Decision | Recommendation | Rationale |
|---|---|---|---|
| **D1** | Fix the SPMLE objective vs. rewrite Section 5 to a 1-moment estimator | **Fix the objective (3 moments)** | The current code has three independent bugs (moment_subset override, det/inv mismatch, row-vs-column normalization). A 1-moment estimator would still need the det and normalization fixed; it would also discard identification from no-arbitrage + labor share, which are the moments tying the estimator to capital and to the labor share decline. The fix is 3–5 days; rewriting Section 5 is 2–4 days and ends in a methodologically weaker paper. |
| **D2** | Sample endpoint: 2023 (KLEMS-bound), 2024 (BEA-bound), or 2025 if CPS available | **2024** | BEA Fixed Assets through 2024; CPS ASEC 2024 published Sept 2024; KLEMS only through 2023. For the 2024 labor share we extrapolate KLEMS using its empirical relationship to BEA NIPA value added + compensation, OR drop the 2024 observation from the labor-share moment only (using 1988–2023 for the labor share, 1988–2024 for everything else). 2025 is feasible (CPS ASEC 2025 is out by Sept 2025), but BEA 2025 capital data won't drop until late 2026 and adds little marginal evidence. |
| **D3** | NAICS 2022 strategy: re-fetch BEA-restated historical series, or crosswalk our existing NAICS 2017 series forward | **Re-fetch restated** | BEA has already done the consistent historical restatement; replicating it would be costly and error-prone. Cost: re-running `get_capital_data.r` end-to-end (a few hours of API calls). |
| **D4** | CPS 2019 redesign: use IPUMS bridge files for 2018, or accept a methodology break at 2018→2019 | **Use bridge files** | IPUMS publishes 2018 bridge files specifically for this. The 2019 redesign affected income processing, which is central to our skill premium. Accepting the break would require splitting the sample. |
| **D5** | Bootstrap replications: 200 (baseline) or 500 (archival) | **200 baseline + 500 archival** | 200 is the dissertation-defense bar; do 500 once for the archived/published version. Compute scales linearly. |
| **D6** | Number of multistart starts per industry | **24–32** | Current code uses 24 in the grid (`runfile_ind.jl`) but only a 2×2×3 product = 12 admissible + various combinations; codex flagged this as too sparse. 24 Latin-hypercube starts per industry is the right floor; 32 if we have compute slack. |
| **D7** | Boundary parameter handling | **Reparameterize via logistic** | Estimates of σ = 0.9999 are corner solutions, not interior estimates. Reparameterizing `σ = logistic(s)` with a small ε from bounds makes Nelder-Mead well-behaved and makes the bootstrap percentile intervals interpretable. |
| **D8** | Include the 22 industries in `data/results/ind_est/` that were never run through the converged estimator | **Yes — re-run them all** | Without this, the published "53 industries" claim doesn't have a defensible computation behind it. Marginal cost: a single industry estimation takes ~5 minutes; 22 industries × 24 starts ≈ a few hours. |
| **D9** | Compute resources | **Need access to a 32-core machine for ~1 week** | Bootstrap is the binding compute step. If only a laptop is available, fall back to 100 reps and accept wider intervals. |
| **D10** | Treatment of the efficiency residual in the decomposition | **Report as accounting residual, not interpret structurally** | The current paper interprets the efficiency residual as a third "channel" but it is mechanically backed out from the identity. The cleaner statement is "supply + CSC explain X% of observed log skill premium growth on average; the remainder is unexplained." |

---

## 3. Work breakdown (DAG)

35 work items grouped into 6 phases. ID format: `Wn`. Effort estimates assume focused work, not calendar days.

### Phase 1 — Estimator and instrumentation surgery (no compute, code only)

| ID | Work item | Depends on | Effort |
|---|---|---|---|
| W1 | Fix `objectiveFunction` moment_subset default (use `[1,2,3]` end-to-end; pass through call chain) | — | 0.5 d |
| W2 | Fix det/inv inconsistency in `estimation.jl:397-400` (use submatrix `vS[t, ms, ms]` for both terms) | W1 | 0.5 d |
| W3 | Fix column-wise vs row-wise normalization for `mS` and `Z` in `objectiveFunction` (operate per-moment over time) | W1 | 0.5 d |
| W4 | Reparameterize bounded params via logistic transform (`α, μ, λ, σ, ρ`); replace the `Inf` penalty in `set_optim_problem` | W1–W3 | 1 d |
| W5 | Rewrite `instrument_labor.jl`: instrument labor only (not wages); write to `{IND}_iv.csv` not in-place; make idempotent; document first-observation handling | — | 1 d |
| W6 | Add unit tests for `objectiveFunction` against a known parameter point (e.g. KORV's reported θ at 1963–1992); ensure deterministic given a seed | W1–W3 | 0.5 d |
| W7 | **Pilot estimation** — aggregate (1963–1992 with KORV data) + 5 representative industries (e.g. 5411, 334, 311FT, 23, 42). Compare to manuscript Table 1. **GO/NO-GO checkpoint.** | W1–W6 | 1 d |

**Phase 1 total: ~5 days**

### Phase 2 — Data refresh and 2024 extension (parallel to Phase 1 from W11 onward)

| ID | Work item | Depends on | Effort |
|---|---|---|---|
| W8 | Update `scripts/data_fetch/get_capital_data.r`: BEA Fixed Assets through 2024 (FAAt301E, FAAt304E, FAAt307E, structures + IP equivalents); switch to NAICS 2022; replace dead `./extend_KORV/` paths with `config.py` paths | — | 1 d |
| W9 | Update FRED fetcher: GDPDEF, CONSDEF, PERIC through 2025 | — | 0.5 d |
| W10 | KLEMS extension strategy: pull KLEMS through 2023; build extrapolation for 2024 labor share using BEA NIPA value added/compensation, OR mark 2024 missing for the labor-share moment only. Document the choice. | — | 2 d |
| W11 | New IPUMS CPS ASEC extract 1962–2024 (or 2025 if available) **with 2018 bridge files** and `QINCWAGE` flag. Document the extract number and date in `data/raw/README.md`. | — | 1 d (mostly waiting on IPUMS) |
| W12 | Rewrite `proc_labor_data.jl`: add sample-selection logging (writes CSV at each filter step); add allocated-income filter (drop `QINCWAGE == 1`); make hours threshold + filters configuration-driven; verify military filter; document 1963–75 imputation. Use bridge-file weighting for 2018 boundary. | W11 | 2 d |
| W13 | Re-build aggregate labor totals (1962–2024) using corrected `proc_labor_data.jl` | W12 | 0.5 d |
| W14 | Industry crosswalk: verify all 56 BEA industries in `industry_names.csv` against NAICS 2022 BEA codes; flag 44RT, 51x for composition shift; produce a documented `cross_walk.csv` | W8 | 1 d |
| W15 | Re-build per-industry CSVs (1988–2024) using corrected capital + labor + KLEMS pipeline; output to `data/proc/ind/{IND}.csv` | W8, W9, W10, W13, W14 | 2 d |
| W16 | Regenerate CPS sample-selection table from W12 logging output → `documents/tables/sample_selection.tex` | W12 | 0.5 d |
| W17 | Sanity check: aggregate decade output growth (verify 1990s growth is positive, debug if not) | W13 | 0.5 d |

**Phase 2 total: ~11 days** (substantial chunks parallelizable; IPUMS extract is the long-pole — submit W11 on day 1)

### Phase 3 — Re-estimation (compute-heavy)

| ID | Work item | Depends on | Effort |
|---|---|---|---|
| W18 | Full aggregate re-estimation, 3 samples: 1963–1992 (KORV original data), 1963–2024 (extended), 1988–2024 (industry-coverage) | W7, W15 | 2 d incl. multistart |
| W19 | Full per-industry estimation, all 56 industries × 24+ starts × corrected estimator; convergence triage; export `data/results/{IND}.csv` (overwrite existing) and consolidate or delete `data/results/ind_est/` | W7, W15 | 3 d incl. compute |
| W20 | Bootstrap inference: 200 nonparametric block-bootstrap reps × all converged industries × multistart. Implement in `scripts/estimation/bootstrap.jl`. Output `data/results/bootstrap/{IND}.csv` with one row per rep. | W18, W19 | 5 d (1 d code + 4 d compute on 32-core) |
| W21 | Bootstrap summary: percentile intervals for `σ, ρ, σ−ρ`, implied elasticities; bootstrap probability `P(σ > ρ)` per industry; convergence/boundary reporting | W20 | 1 d |

**Phase 3 total: ~11 days** (W20 is the wall-clock bottleneck; budget extra slack)

### Phase 4 — Post-estimation analysis

| ID | Work item | Depends on | Effort |
|---|---|---|---|
| W22 | Rewrite `compute_decomposition.jl`: report log-point contributions as headline; flag/winsorize % when |total| < threshold; treat efficiency as residual not a channel | W19 | 1 d |
| W23 | Aggregate goodness-of-fit analysis (the comment block at manuscript.tex:746-750 says deferred; now run it): RMSE / R² for skill premium, labor share, wbr, rr across the 3 aggregate samples | W18 | 1 d |
| W24 | Robustness suite: (i) exclude poor-fit industries (R²_wbr < 0); (ii) alternative depreciation rates (±50%); (iii) alternative hours threshold (35 vs 30); (iv) skip 1963–75 imputation (start 1976); (v) exclude post-2008 (financial crisis); (vi) NAICS 2017 vs 2022 sensitivity on 44RT and 51x | W19 | 3 d |
| W25 | Recompute the CSC vs skill-intensity regression with bootstrap-CI-weighted IV-style approach (account for estimation error in dependent variable) | W21 | 1 d |
| W26 | Generate all final tables: param estimates (with CIs), decomposition (log-point), fit, robustness summary. Regenerate from CSVs; standardize LaTeX templates. | W19, W21, W22, W23, W24 | 2 d |
| W27 | Generate all final figures: model fit panels (3 aggregate + per-industry appendix); parameter distributions; CSC vs covariates scatter | W19 | 1 d |

**Phase 4 total: ~9 days**

### Phase 5 — Manuscript revision

| ID | Work item | Depends on | Effort |
|---|---|---|---|
| W28 | Rewrite Section 5 (Estimation) — honestly describe the three-moment SPMLE with the fixes; document multistart; document bootstrap | W7 | 1.5 d |
| W29 | Update Section 4 (Data) — extension to 2024, bridge files, NAICS 2022, sample selection table, 1963–75 imputation documentation, allocated-income filter, military filter, 2014 redesign | W12, W16 | 2 d |
| W30 | Update Section 6 (Results) — all numbers replaced with corrected estimates; bootstrap CIs; convergence/boundary breakdown; aggregate fit subsection | W21, W26 | 3 d |
| W31 | Write missing Robustness subsection (replaces `\textcolor{red}{TODO}` placeholder at line 752) | W24 | 1.5 d |
| W32 | Update Section 7 (Discussion) — remove the 7× repeated percentage figures; rewrite around log-point dominance counts; integrate new lit (Acemoglu-Restrepo 2022, Hubmer-Restrepo 2025) | W30 | 1.5 d |
| W33 | Update Section 8 (Conclusion) — same number replacements; remove the "541,216 log points" mislabel; integrate robustness findings | W30 | 1 d |
| W34 | Update Literature Review — Ohanian-Orak-Shen 2023 (RED), Maliar-Maliar-Tsener 2022, Castex-Cho-Dechter 2022, Acemoglu-Restrepo 2022, Hubmer-Restrepo 2025. Add to `references.bib`. | — | 1 d |
| W35 | Polish pass — fix typo `valdsbobes` → `valdesbobes`; fix `polred2008capital` → `polgreen2008capital`; verify `maliar2020capital` in bib; fix figure filenames with colons; consolidate duplicate `result_analisis.jl` / `result_analisys.jl`; remove stale TODO comments; update CODE_MANUSCRIPT_DISCREPANCIES.md to "resolved" or delete | W32, W33 | 1 d |

**Phase 5 total: ~12 days**

### Phase 6 — Reproducibility & documentation

| ID | Work item | Depends on | Effort |
|---|---|---|---|
| W36 | End-to-end driver (`Justfile` or `Makefile`) chaining: fetch → process → instrument → estimate → bootstrap → tables. Pin Julia + Python + R versions. Replace hardcoded user paths. | W15 | 1.5 d |
| W37 | Update README with current pipeline; document data sources, API key requirements, expected runtimes; replicate-from-scratch instructions | W36 | 0.5 d |

**Phase 6 total: ~2 days**

---

## 4. Critical path

The dependency graph collapses to this critical path (longest chain by wall-clock):

```
W1 → W2 → W3 → W4 (estimator fixes, 2.5 d)
  → W7 (pilot, GO/NO-GO, 1 d)
  → W15 (rebuilt per-industry data, depends on W8+W11+W12, ~7 d wall-clock incl. IPUMS turnaround)
  → W19 (full industry estimation, 3 d compute)
  → W20 (bootstrap, 4 d wall-clock on 32-core)
  → W21 → W26 → W30 → W32, W33 → W35 (manuscript)
```

**Minimum wall-clock: ~9 weeks** assuming IPUMS extract turnaround is ~24h, compute is available on demand, and no methodology surprises at W7 pilot. The 12-week target adds 3 weeks of buffer for surprises, integration, and final polish.

**Parallelization opportunities:**
- Phase 2 data work (W8, W9, W10, W11) runs in parallel with Phase 1 estimator fixes. Submit IPUMS extract on Day 1.
- W18 (aggregate estimation) and W19 (industry estimation) run in parallel after W15.
- W22, W23, W24 run in parallel after Phase 3 is done.
- W28–W34 can all be drafted in parallel (different sections); only W35 (polish) sequences after.

---

## 5. Milestones

| M | Name | Exit criteria | Target week |
|---|---|---|---|
| **M1** | Estimator fixed + pilot validated | W7 complete; pilot run reproduces KORV Table 1 to within ±0.05 on all params; aggregate sample fit RMSE ≤ original report | Week 1–2 |
| **M2** | Data refresh complete (1962–2024 master panel) | W15 complete; aggregate decade table looks sane (1990s growth > 0); sample-selection table generated from code | Week 4 |
| **M3** | All estimates + bootstrap done | W19 + W20 complete; per-industry CSVs + bootstrap CSVs in repo; convergence ≥ 80% of industries | Week 7 |
| **M4** | Dissertation-defense draft | W32 + W33 + W35 complete; manuscript compiles; all numbers traceable to a CSV; robustness section present | Week 11 |

---

## 6. Risks (top 5)

| # | Risk | Impact | Mitigation |
|---|---|---|---|
| **R1** | The fixed 3-moment estimator gives qualitatively different results from the published 1-moment estimates (CSC no longer holds for many industries) | High — would force a narrative rewrite | Build the pilot (W7) as an explicit go/no-go: if 5 representative industries fail to confirm CSC, pause and convene with advisor before proceeding to full rerun. Have a Plan B narrative ready ("CSC holds aggregately but is more nuanced at industry level"). |
| **R2** | KLEMS 2024 release slips further than spring 2026 | Medium — would force ending at 2023 | Build the extrapolation path now (W10) so we can publish a 2024 endpoint with KLEMS-extrapolated labor share. Document the choice transparently. |
| **R3** | Many industries don't converge even with corrected estimator + 24 starts | Medium — reduces sample size and weakens headline | Run a Latin-hypercube start grid + simulated annealing fallback for non-convergers. Pre-register the convergence threshold (≥ 80% of industries). If convergence is widespread failure, paper pivots to aggregate-only with industry sensitivity. |
| **R4** | Bootstrap compute exceeds budget (e.g., > 5 days wall-clock) | Medium — would force fewer reps | Stage: run aggregate bootstrap (cheap) first; estimate per-industry cost from one industry's cycle time; calibrate reps to available compute. 100 reps is the absolute floor; report this transparently. |
| **R5** | Data fetcher breakage (BEA API changes, IPUMS variable name changes, FRED retiring a series) | Low–Medium — could lose days | Allocate W37 polish time as buffer. Keep a snapshot of working data alongside the fetch code (commit `data/proc/` outputs to LFS so the paper compiles even if fetchers break). |

---

## 7. Out of scope (deliberately deferred)

These were raised in the audit or are natural extensions but are explicitly not in this 12-week plan:

| Item | Reason |
|---|---|
| Firm-level / establishment-level estimation | Requires LBD or QCEW microdata; >3 months alone |
| Occupation-level skill definitions (vs. college/non-college) | Methodologically interesting but doubles the empirical complexity; separate paper |
| Separating AI/robotics capital from general equipment | BEA does not break out AI capital; would require Acemoglu-Restrepo style construction |
| International comparison (replicate for Germany/UK/Japan) | Separate data architecture; out of dissertation scope |
| Formal welfare / optimal-policy analysis | Adds a normative model layer; separate paper |
| Endogenous technology adoption | Adds dynamics + identification issues; flagged in "Future Research" instead |
| Establishment-level CSC firm-pay-premium link | Requires matched employer-employee data (LEHD); future research |

---

## 8. Open questions for @mitchell

Before kicking off Phase 1, please confirm:

1. **D1 (fix estimator)** — agree?
2. **D2 (sample endpoint)** — 2024 with KLEMS-extrapolation OK, or do you want a strict 2023 endpoint?
3. **D9 (compute)** — do you have access to a 32-core (or comparable) machine for W20? If not, what's the alternative?
4. **Calendar** — is the 12-week window (today → mid-August 2026) realistic given other commitments? If shorter, we may need to drop W25 (CSC regression IV) and W24 partial (fewer robustness specs).
5. **Advisor checkpoints** — should we schedule M1 (pilot) and M3 (estimates done) explicitly with your committee?

---

## 9. Execution protocol

This plan is the master TODO. Execution will happen **one work item at a time** with @mitchell approving each change before it is implemented. The 17-item Claude Code todo list is the working tracker. The colab worksheet at `.colab/chapter-readiness/WORKSHEET.md` is the source of truth for the underlying audit + research.

Phase 1 (W1–W7) is the unblocking work; everything else stalls until W7 passes. Start there.
