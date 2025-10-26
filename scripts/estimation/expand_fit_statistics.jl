#!/usr/bin/env julia
"""
Compute comprehensive goodness-of-fit statistics for all industries
Expands on the partial compute_fit_statistics.jl to cover all 53 industries
"""

using CSV
using DataFrames
using Statistics
using Printf

# Add estimation functions to path
push!(LOAD_PATH, joinpath(pwd(), "estimation"))
using ModelingToolkit

println("Computing Goodness-of-Fit Statistics for All Industries...")

# Load cross-walk for industry names
crosswalk = CSV.read("data/cross_walk.csv", DataFrame)

# Include estimation functions (they're in the main estimation/ directory)
include("../../estimation/estimation.jl")
include("../../estimation/do_estimation.jl")

# Initialize model
@parameters α, μ, σ, λ, ρ, δ_e, δ_s
@variables k_e, k_s, h, ℓ, ψ_L, ψ_H, q, y

model = intializeModel()

# Storage for fit statistics
fit_results = DataFrame(
    industry_code = String[],
    industry_name = String[],
    rmse_skill_premium = Float64[],
    rmse_labor_share = Float64[],
    rmse_wage_bill_ratio = Float64[],
    rmse_labor_input_ratio = Float64[],
    r2_skill_premium = Float64[],
    r2_labor_share = Float64[],
    r2_wage_bill_ratio = Float64[],
    r2_labor_input_ratio = Float64[],
    mae_skill_premium = Float64[],
    mae_labor_share = Float64[],
    mae_wage_bill_ratio = Float64[],
    mae_labor_input_ratio = Float64[],
    n_obs = Int[],
    converged = Bool[]
)

# Helper function to compute R²
function compute_r2(actual::Vector, predicted::Vector)
    ss_res = sum((actual .- predicted).^2)
    ss_tot = sum((actual .- mean(actual)).^2)
    return 1 - ss_res / ss_tot
end

# Process each industry
n_success = 0
n_failed = 0

for (idx, row) in enumerate(eachrow(crosswalk))
    ind_code = row.code_klems
    ind_name = row.ind_desc
    
    println("\n[$idx/$(nrow(crosswalk))] Processing: $ind_name ($ind_code)")
    
    # Check if parameter estimates exist
    param_file = "data/results/ind_est/$(ind_code).csv"
    data_file = "data/proc/ind/$(ind_code).csv"
    
    if !isfile(param_file)
        println("  ⚠ No parameter file found, skipping...")
        global n_failed += 1
        continue
    end
    
    if !isfile(data_file)
        println("  ⚠ No data file found, skipping...")
        global n_failed += 1
        continue
    end
    
    try
        # Load parameters
        param_df = CSV.read(param_file, DataFrame)
        
        # Check for NaN values
        if any(isnan, [param_df.alpha[1], param_df.sigma[1], param_df.rho[1], param_df.eta[1]])
            println("  ⚠ Parameters contain NaN, skipping...")
            push!(fit_results, (
                ind_code, ind_name, 
                NaN, NaN, NaN, NaN,  # RMSE
                NaN, NaN, NaN, NaN,  # R²
                NaN, NaN, NaN, NaN,  # MAE
                0, false
            ))
            global n_failed += 1
            continue
        end
        
        params = setParams(
            [param_df.alpha[1], param_df.sigma[1], param_df.rho[1], param_df.eta[1]],
            [param_df.mu[1], param_df.lambda[1], param_df.phi_L[1], param_df.phi_H[1]]
        )
        
        # Load data
        dataframe = CSV.read(data_file, DataFrame)
        data = generateData(dataframe)
        T = length(data.y)
        
        # Generate shocks
        shocks = generateShocks(params, T)
        
        # Update model and evaluate
        update_model!(model, params)
        model_results = evaluateModel(0, model, data, params, shocks)
        
        # Compute fit statistics for each series
        
        # 1. Skill Premium
        ω_model = model_results[:ω]
        ω_data = data.w_h[2:end] ./ data.w_ℓ[2:end]
        rmse_sp = sqrt(mean((ω_model .- ω_data).^2))
        r2_sp = compute_r2(ω_data, ω_model)
        mae_sp = mean(abs.(ω_model .- ω_data))
        
        # 2. Labor Share
        ls_model = model_results[:lbr]
        ls_data = data.lsh[2:end]
        rmse_ls = sqrt(mean((ls_model .- ls_data).^2))
        r2_ls = compute_r2(ls_data, ls_model)
        mae_ls = mean(abs.(ls_model .- ls_data))
        
        # 3. Wage Bill Ratio
        wbr_model = model_results[:wbr]
        wbr_data = data.wbr[2:end]
        rmse_wbr = sqrt(mean((wbr_model .- wbr_data).^2))
        r2_wbr = compute_r2(wbr_data, wbr_model)
        mae_wbr = mean(abs.(wbr_model .- wbr_data))
        
        # 4. Labor Input Ratio - calculate from wage bill ratio and skill premium
        # wbr = (w_h * h_h) / (w_ℓ * h_ℓ) = ω * (h_h / h_ℓ)
        # Therefore: h_h / h_ℓ = wbr / ω
        li_model = wbr_model ./ ω_model
        li_data = data.h[2:end] ./ data.ℓ[2:end]
        rmse_li = sqrt(mean((li_model .- li_data).^2))
        r2_li = compute_r2(li_data, li_model)
        mae_li = mean(abs.(li_model .- li_data))
        
        # Store results
        push!(fit_results, (
            ind_code, ind_name,
            rmse_sp, rmse_ls, rmse_wbr, rmse_li,
            r2_sp, r2_ls, r2_wbr, r2_li,
            mae_sp, mae_ls, mae_wbr, mae_li,
            T, true
        ))
        
        println("  ✓ RMSE: SP=$(round(rmse_sp, digits=3)), LS=$(round(rmse_ls, digits=3)), WBR=$(round(rmse_wbr, digits=3)), LI=$(round(rmse_li, digits=3))")
        println("  ✓ R²:   SP=$(round(r2_sp, digits=3)), LS=$(round(r2_ls, digits=3)), WBR=$(round(r2_wbr, digits=3)), LI=$(round(r2_li, digits=3))")
        global n_success += 1
        
    catch e
        println("  ✗ Error computing fit: $e")
        push!(fit_results, (
            ind_code, ind_name,
            NaN, NaN, NaN, NaN,
            NaN, NaN, NaN, NaN,
            NaN, NaN, NaN, NaN,
            0, false
        ))
        global n_failed += 1
    end
end

# Save results
println("\n" * "="^60)
println("Saving results...")
CSV.write("data/results/fit_statistics_all_industries.csv", fit_results)
println("✓ Saved to: data/results/fit_statistics_all_industries.csv")

# Summary statistics
println("\n" * "="^60)
println("SUMMARY")
println("="^60)
println("Successfully computed: $n_success industries")
println("Failed: $n_failed industries")
println("Success rate: $(round(100*n_success/(n_success+n_failed), digits=1))%")

# Get statistics for converged industries only
converged_df = filter(row -> row.converged, fit_results)

if nrow(converged_df) > 0
    println("\nFit Statistics (converged industries only, N=$(nrow(converged_df))):")
    println("\nRMSE Statistics:")
    println("  Skill Premium:     Mean=$(round(mean(converged_df.rmse_skill_premium), digits=3)), Median=$(round(median(converged_df.rmse_skill_premium), digits=3))")
    println("  Labor Share:       Mean=$(round(mean(converged_df.rmse_labor_share), digits=3)), Median=$(round(median(converged_df.rmse_labor_share), digits=3))")
    println("  Wage Bill Ratio:   Mean=$(round(mean(converged_df.rmse_wage_bill_ratio), digits=3)), Median=$(round(median(converged_df.rmse_wage_bill_ratio), digits=3))")
    println("  Labor Input Ratio: Mean=$(round(mean(converged_df.rmse_labor_input_ratio), digits=3)), Median=$(round(median(converged_df.rmse_labor_input_ratio), digits=3))")
    
    println("\nR² Statistics:")
    println("  Skill Premium:     Mean=$(round(mean(converged_df.r2_skill_premium), digits=3)), Median=$(round(median(converged_df.r2_skill_premium), digits=3))")
    println("  Labor Share:       Mean=$(round(mean(converged_df.r2_labor_share), digits=3)), Median=$(round(median(converged_df.r2_labor_share), digits=3))")
    println("  Wage Bill Ratio:   Mean=$(round(mean(converged_df.r2_wage_bill_ratio), digits=3)), Median=$(round(median(converged_df.r2_wage_bill_ratio), digits=3))")
    println("  Labor Input Ratio: Mean=$(round(mean(converged_df.r2_labor_input_ratio), digits=3)), Median=$(round(median(converged_df.r2_labor_input_ratio), digits=3))")
end

println("\n✓ Script completed successfully!")
