# Q2: Cross-industry estimation — options memo

**Status:** parked. Revisit during Phase 3 (estimation), after the baseline independent-industry estimator is fixed and re-running.
**Question raised by @mitchell (2026-05-25):** Industries are currently estimated independently — no parameter linkage across industries. Is that defensible? If not, what can we do?

## Current state

Each of the 56 BEA industries is fit independently with its own parameter vector `(α_i, μ_i, λ_i, σ_i, ρ_i, η_ωi, φℓ_i, φh_i)`. There are no cross-equation restrictions, no shared parameters, no common shocks, no informational borrowing across industries. The reported "industry heterogeneity" (`σ ∈ [-3.75, 1.00]`, `ρ ∈ [-2.23, 1.00]`) is therefore a pure cross-section of point estimates, with no measurement-error correction and no formal test of heterogeneity vs noise.

**Is this defensible?** Yes — *given the paper's research question*. The chapter is about heterogeneity in CSC across industries, not about estimating a common CSC parameter or characterizing a population distribution. Independence is the correct null. But the paper currently neither (i) acknowledges this design choice explicitly, nor (ii) corrects for the estimation noise that contaminates the cross-industry regression of σ−ρ on industry characteristics.

## Options spectrum

Ordered from cheapest to most ambitious. The first three are reasonable for a dissertation; the last three are journal-paper extensions.

### Option A — Status quo + explicit acknowledgement (baseline)

- Continue independent-industry estimation.
- Add a one-paragraph methodology note in Section 5 explaining the independence and why it's appropriate for the research question.
- In the cross-industry regression (manuscript line 754), use **measurement-error-corrected** estimators (e.g., FGLS weighted by bootstrap variance of σ−ρ) instead of OLS on point estimates.
- **Cost:** already in the master plan (W25). No extra effort.

### Option B — Empirical Bayes shrinkage (⭐ cheap win)

- Estimate each industry independently (current pipeline).
- Post-hoc: shrink point estimates toward a population mean via James-Stein / EB:
  `θ̂_i_EB = θ̄ + (1 − B_i)(θ̂_i − θ̄)`
  where `B_i = σ²_θ / (σ²_θ + s²_i)` is the shrinkage factor and `s²_i` is the bootstrap variance of `θ̂_i`.
- Report both raw and shrunken estimates; the shrinkage factor `B_i` itself is informative ("how much does industry i borrow from the population?").
- Provides a natural Bayesian-flavored summary of heterogeneity without requiring full MCMC.
- **Cost:** ~2–3 days; depends on bootstrap (W20) being done first.
- **Win:** noisy industries (the ones with `|σ_s| > 50` from `parameter_distribution_summary.csv`) get pulled to sensible values; figures look much cleaner; the headline "44 of 53 industries with σ>ρ" becomes meaningful because we're testing a posterior probability, not a point estimate sign.

### Option C — Common-σ, heterogeneous ρ (or vice versa) as robustness

- Re-estimate the full panel under the restriction `σ_i = σ ∀ i` (with industry-specific everything else).
- Likelihood-ratio test of the restriction.
- Same exercise with `ρ_i = ρ ∀ i`.
- Tells us *which* form of heterogeneity matters: if pooling σ doesn't worsen fit much but pooling ρ does, then capital-skill complementarity is heterogeneous primarily through the equipment-skill substitution channel, not the equipment-unskilled channel.
- **Cost:** ~1 week (estimation re-run + LR-test logic). Goes in robustness section.

### Option D — Common factor structure on shocks

- Decompose efficiency shocks as `ψ^k_{i,t} = α^k_i + λ^k_i · F_t + ε^k_{i,t}` for `k ∈ {s, u}`, where `F_t` is a common (possibly latent) aggregate productivity factor.
- Estimable via standard factor-model machinery (PCA on residuals; or joint with structural estimation).
- Doesn't restrict the substitution-elasticity parameters but allows industries to share business-cycle / aggregate-tech shocks.
- Useful if reviewer asks "are your cross-industry σ estimates biased because industries face correlated demand shocks not in the model?"
- **Cost:** ~1–2 weeks (factor extraction + joint estimation). Probably overkill for dissertation defense; consider for revision.

### Option E — Hierarchical / Bayesian (the "right" answer)

- `θ_i ~ N(θ̄, Σ_θ)` jointly with industry-level moment conditions.
- Implementation: Stan or Turing.jl (Julia native, integrates with the existing estimation code).
- Outputs: population mean `θ̄`, between-industry variance `Σ_θ`, and per-industry posteriors.
- Natural cross-industry test: posterior probability that two industries have the same σ.
- Subsumes empirical Bayes (Option B) and gives proper joint inference.
- **Cost:** ~3–4 weeks. Stan/Turing porting + tuning + convergence diagnostics.
- **Verdict:** This is the journal-paper version. For dissertation defense, do Options A+B+C and flag E as "future work."

### Option F — Network / input-output linkages

- Industries connected via intermediate inputs (BEA Use Table) and labor flows.
- Skill demand in one industry affects another through the supply chain.
- Acemoglu-Restrepo (2022) does something like this for automation.
- **Cost:** 6–8 weeks; out of scope for this chapter; separate paper.

## Recommendation

For the dissertation:

| Phase | What | When |
|---|---|---|
| Baseline | Option A — explicit acknowledgement + measurement-error-corrected cross-industry regression | Already in master plan (W25) |
| Add | Option B — Empirical Bayes shrinkage | After W20 bootstrap; ~2–3 days |
| Robustness | Option C — Common-σ pooling as LR test | Phase 4 robustness suite (W24); ~1 week |
| Future work | Options D, E, F | Mention in Section 8.4 ("Future research") |

This combination is the sweet spot for dissertation defense: methodologically defensible, computationally feasible, and meaningfully addresses a referee question that would otherwise come up. It avoids the 3–4 week Bayesian commitment while still showing the committee that we've thought about cross-industry information.

## When to revisit

Revisit during Phase 3 (estimation), specifically after the W19 industry estimation and W20 bootstrap are done. At that point we have everything needed for Option B (point estimates + bootstrap variance) and the marginal cost of Option C is fixed by the multistart compute already in place.

## Open implementation questions (to resolve when we revisit)

1. EB shrinkage target: pool across all 56 industries or within sector groups (manufacturing / services / extractive)? My instinct: full pool, then sector-level as robustness.
2. How to handle the boundary estimates (σ≈1) in EB? After logistic reparameterization (Decision D7 in the master plan), this should be a non-issue.
3. For Option C, do we pool on `σ`, `ρ`, or `σ−ρ`? Pooling `σ−ρ` directly tests "is CSC strength the same across industries" — probably the most policy-relevant restriction.
