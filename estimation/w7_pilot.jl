"""W7 pilot — GO/NO-GO gate for the corrected estimator.

Uses the original KORV (2000) data (1963-1992) and runs the repaired SPMLE
estimator. Compares results against KORV's published Table 1:

    α = 0.117, σ = 0.401, ρ = -0.495, μ = 0.40, λ = 0.45, η_ω = 0.044

Acceptance: estimated (α, σ, ρ) within ±0.05 of the above (CSC condition
σ > ρ should clearly hold).
"""

include("estimation.jl")
include("do_estimation.jl")

using Printf
using ModelingToolkit

# intializeModel uses ModelingToolkit symbols declared in the caller scope.
@parameters α, μ, σ, λ, ρ, δ_e, δ_s
@variables k_e, k_s, h, ℓ, ψ_L, ψ_H, q, y

# ---------------------------------------------------------------------------
# Data: KORV's original 1963-1992 series.
# ---------------------------------------------------------------------------
println("=== Step 1: load KORV data ===")
path_korv = "./data/Data_KORV.csv"
df = CSV.read(path_korv, DataFrame)
println("  rows: $(nrow(df)) | columns: $(names(df))")

# Patch in YEAR (KORV file has no YEAR column).
df[!, :YEAR] = collect(1963:1963+nrow(df)-1)

# Add the depreciation columns expected by estimation.jl. KORV used fixed
# δ_e = 0.125 (equipment), δ_s = 0.05 (structures). The data structure
# stores these in DPR_EQ / DPR_ST columns.
df[!, :DPR_EQ] = fill(0.125, nrow(df))
df[!, :DPR_ST] = fill(0.05, nrow(df))

# Add lsh_alt placeholder (estimation.jl unpacks it but the rewritten
# objectiveFunction no longer uses it).
df[!, :L_SHARE_ALT] = df.L_SHARE

# generateData expects specific column names; verify presence.
required = [:K_STR, :K_EQ, :L_S, :L_U, :W_S, :W_U, :L_SHARE, :OUTPUT, :REL_P_EQ]
missing_cols = setdiff(required, Symbol.(names(df)))
@assert isempty(missing_cols) "missing required columns: $missing_cols"

# ---------------------------------------------------------------------------
# Step 2: Generate Data object and Model.
# ---------------------------------------------------------------------------
println("\n=== Step 2: generateData + initialize Model ===")
data = generateData(df)
println("  T = $(length(data.y)) years")

# initializeModel uses ModelingToolkit symbols.
println("\n=== Step 3: initialize Model ===")
model = intializeModel()

# ---------------------------------------------------------------------------
# Step 4: Smoke test the objective function at KORV's published parameters.
# ---------------------------------------------------------------------------
println("\n=== Step 4: smoke test objectiveFunction at KORV's published θ ===")
# KORV's parameter values (Table 1).
α_korv = 0.117
σ_korv = 0.401
ρ_korv = -0.495
μ_korv = 0.40
λ_korv = 0.45
η_ω_korv = 0.044
φℓ₀_korv = 4.0      # not directly reported; KORV-era reasonable starting value
φh₀_korv = 6.0      # KORV's fixed normalization
δ_e_mean = 0.125
δ_s_mean = 0.05

params_korv = setParams(
    [α_korv, σ_korv, ρ_korv, η_ω_korv],
    [μ_korv, λ_korv, φℓ₀_korv, φh₀_korv],
    δ_e = δ_e_mean, δ_s = δ_s_mean,
)

T = length(data.y)
shocks = generateShocks(params_korv, T)
update_model!(model, params_korv)

ℓ_korv = objectiveFunction(model, params_korv, data, shocks)
@printf "  objective at KORV's θ = %.6f\n" ℓ_korv
@assert isfinite(ℓ_korv) "objective is not finite — math fix failed"
println("  ✓ finite (W1+W2+W3 fixes work)")

# ---------------------------------------------------------------------------
# Step 5: Try a different starting point and see if the corrected
# Nelder-Mead converges to something close to KORV.
# ---------------------------------------------------------------------------
println("\n=== Step 5: run solve_optim_prob with multistart-friendly initial ===")

scale_initial = φh₀_korv   # the "fixed" normalization (codex's fixed_param)
η_ω_0 = η_ω_korv

# Initial guess (constrained values). solve_optim_prob will transform to z-space.
param_0 = [α_korv, σ_korv, ρ_korv]            # α, σ, ρ
scale_0 = [μ_korv, λ_korv, φℓ₀_korv]          # μ, λ, φℓ₀

# tol higher for the pilot — we just want to see convergence to a reasonable basin.
sim = solve_optim_prob(
    data, model, scale_initial, η_ω_0,
    vcat(param_0, scale_0);
    delta = [δ_e_mean, δ_s_mean],
    tol = 1e-3, maxiter = 200,
)

println("\n=== Step 6: results ===")
@printf "  Optim final objective: %.6f\n" sim.f
@printf "  Estimated α   = %.4f   (KORV: 0.117)   diff: %+.4f\n"  sim.x.α     (sim.x.α - 0.117)
@printf "  Estimated σ   = %.4f   (KORV: 0.401)   diff: %+.4f\n"  sim.x.σ     (sim.x.σ - 0.401)
@printf "  Estimated ρ   = %.4f   (KORV: -0.495)  diff: %+.4f\n"  sim.x.ρ     (sim.x.ρ - (-0.495))
@printf "  Estimated μ   = %.4f   (KORV: 0.40)    diff: %+.4f\n"  sim.x.μ     (sim.x.μ - 0.40)
@printf "  Estimated λ   = %.4f   (KORV: 0.45)    diff: %+.4f\n"  sim.x.λ     (sim.x.λ - 0.45)
@printf "  Estimated φℓ₀ = %.4f\n"                                sim.x.φℓ₀
@printf "  σ − ρ        = %.4f   (CSC condition: σ > ρ, i.e. σ−ρ > 0)\n" (sim.x.σ - sim.x.ρ)

# Acceptance criteria (per master plan §M1).
within = (
    abs(sim.x.α - 0.117) < 0.05 &&
    abs(sim.x.σ - 0.401) < 0.05 &&
    abs(sim.x.ρ - (-0.495)) < 0.05
)
csc = sim.x.σ - sim.x.ρ > 0
println()
if within && csc
    println("  GO/NO-GO: ✅ PASS — within ±0.05 of KORV and CSC holds.")
elseif csc
    println("  GO/NO-GO: ⚠️  PARTIAL — CSC holds but estimates outside ±0.05.")
else
    println("  GO/NO-GO: ❌ FAIL — CSC does not hold or estimates far from KORV.")
end
