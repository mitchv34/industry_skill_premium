"""W7 multistart diagnostic — is α drift due to multistart sensitivity or
genuine identification?

Runs the corrected estimator from a grid of starting points on KORV's
original 1963-1992 data. Reports the converged (α, σ, ρ, σ-ρ, obj) across
starts so we can see whether they cluster or scatter.
"""

include("estimation.jl")
include("do_estimation.jl")

using Printf
using ModelingToolkit
using Random

@parameters α, μ, σ, λ, ρ, δ_e, δ_s
@variables k_e, k_s, h, ℓ, ψ_L, ψ_H, q, y

# Data setup
path_korv = "./data/Data_KORV.csv"
df = CSV.read(path_korv, DataFrame)
df[!, :YEAR] = collect(1963:1963+nrow(df)-1)
df[!, :DPR_EQ] = fill(0.125, nrow(df))
df[!, :DPR_ST] = fill(0.05, nrow(df))
df[!, :L_SHARE_ALT] = df.L_SHARE

# Multistart grid: vary the initial (α, σ, ρ, μ, λ, φℓ₀) across plausible
# values. η_ω and φh₀ kept fixed (current architecture).
starts = [
    # KORV's own published values:
    (α=0.117, σ=0.401, ρ=-0.495, μ=0.40, λ=0.45, φℓ₀=4.0),
    # Pilot's converged values:
    (α=0.308, σ=0.333, ρ=-0.431, μ=0.36, λ=0.44, φℓ₀=5.1),
    # Low-α anchor:
    (α=0.08,  σ=0.50,  ρ=-0.50,  μ=0.40, λ=0.40, φℓ₀=3.5),
    # High-α anchor:
    (α=0.40,  σ=0.30,  ρ=-0.30,  μ=0.40, λ=0.40, φℓ₀=5.5),
    # Mid-CSC:
    (α=0.20,  σ=0.20,  ρ=-0.20,  μ=0.50, λ=0.50, φℓ₀=4.5),
    # σ < 0 (test the unconstrained reparam):
    (α=0.15,  σ=-0.10, ρ=-0.80,  μ=0.45, λ=0.45, φℓ₀=4.0),
    # high σ, mild ρ:
    (α=0.10,  σ=0.60,  ρ=-0.20,  μ=0.35, λ=0.40, φℓ₀=4.0),
    # asymmetric μ/λ:
    (α=0.15,  σ=0.30,  ρ=-0.40,  μ=0.30, λ=0.55, φℓ₀=4.0),
]

η_ω_0 = 0.044
φh₀_fixed = 6.0
δ_e = 0.125
δ_s = 0.05

results = []
for (i, s) in enumerate(starts)
    @printf "\n=== Start %d/%d ===\n" i length(starts)
    @printf "  initial: α=%.3f σ=%.3f ρ=%.3f μ=%.3f λ=%.3f φℓ₀=%.2f\n" s.α s.σ s.ρ s.μ s.λ s.φℓ₀

    param_0 = [s.α, s.σ, s.ρ]
    scale_0 = [s.μ, s.λ, s.φℓ₀]

    # Re-initialize data + model per start to avoid the shared-mutation
    # issue codex flagged. This is wasteful (~2s per start for ModelingToolkit
    # setup) but isolates state.
    data = generateData(df)
    model = intializeModel()
    # Warmup: parameterize the model once before letting Optim drive it.
    warmup_params = setParams([s.α, s.σ, s.ρ, η_ω_0], [s.μ, s.λ, s.φℓ₀, φh₀_fixed], δ_e=δ_e, δ_s=δ_s)
    update_model!(model, warmup_params)

    sim = nothing
    try
        sim = solve_optim_prob(
            data, model, φh₀_fixed, η_ω_0,
            vcat(param_0, scale_0);
            delta = [δ_e, δ_s],
            tol = 1e-3, maxiter = 150,
        )
        @printf "  converged: α=%.4f σ=%.4f ρ=%.4f μ=%.4f λ=%.4f φℓ₀=%.4f obj=%.4f\n" sim.x.α sim.x.σ sim.x.ρ sim.x.μ sim.x.λ sim.x.φℓ₀ sim.f
        push!(results, (start=i, ok=true,
            α_init=s.α, σ_init=s.σ, ρ_init=s.ρ,
            α=sim.x.α, σ=sim.x.σ, ρ=sim.x.ρ,
            μ=sim.x.μ, λ=sim.x.λ, φℓ₀=sim.x.φℓ₀,
            obj=sim.f, σ_minus_ρ=sim.x.σ - sim.x.ρ))
    catch e
        @printf "  ERROR: %s\n" e
        push!(results, (start=i, ok=false))
    end
end

# Summary table
println("\n\n=============================================================")
println("MULTISTART SUMMARY")
println("=============================================================")
@printf "%-2s | %-7s | %-7s | %-7s | %-7s | %-7s | %-9s | %s\n" "i" "α" "σ" "ρ" "σ-ρ" "obj" "α_init" "→"
println("-"^85)
for r in results
    if r.ok
        @printf "%-2d | %7.4f | %7.4f | %7.4f | %7.4f | %7.4f | %7.3f   → α=%.3f\n" r.start r.α r.σ r.ρ r.σ_minus_ρ r.obj r.α_init r.α
    else
        @printf "%-2d | FAILED\n" r.start
    end
end

# Stats on α
ok_results = [r for r in results if r.ok]
if !isempty(ok_results)
    αs = [r.α for r in ok_results]
    σs = [r.σ for r in ok_results]
    ρs = [r.ρ for r in ok_results]
    σmρs = [r.σ_minus_ρ for r in ok_results]
    objs = [r.obj for r in ok_results]
    @printf "\nα across %d converged runs: mean=%.4f  sd=%.4f  min=%.4f  max=%.4f\n" length(αs) (sum(αs)/length(αs)) sqrt(sum((αs .- sum(αs)/length(αs)).^2)/length(αs)) minimum(αs) maximum(αs)
    @printf "σ:   mean=%.4f  sd=%.4f  min=%.4f  max=%.4f\n" (sum(σs)/length(σs)) sqrt(sum((σs .- sum(σs)/length(σs)).^2)/length(σs)) minimum(σs) maximum(σs)
    @printf "ρ:   mean=%.4f  sd=%.4f  min=%.4f  max=%.4f\n" (sum(ρs)/length(ρs)) sqrt(sum((ρs .- sum(ρs)/length(ρs)).^2)/length(ρs)) minimum(ρs) maximum(ρs)
    @printf "σ-ρ: mean=%.4f  sd=%.4f  min=%.4f  max=%.4f\n" (sum(σmρs)/length(σmρs)) sqrt(sum((σmρs .- sum(σmρs)/length(σmρs)).^2)/length(σmρs)) minimum(σmρs) maximum(σmρs)
    best = argmin(objs)
    @printf "\nBest run (lowest obj): start %d, obj=%.4f, α=%.4f σ=%.4f ρ=%.4f\n" ok_results[best].start ok_results[best].obj ok_results[best].α ok_results[best].σ ok_results[best].ρ
end
