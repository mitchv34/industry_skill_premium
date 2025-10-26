"""
Compute goodness-of-fit statistics for aggregate KORV replications.

This script:
1. Loads estimated parameters from the three samples
2. Runs the model to generate predictions
3. Computes RMSE, R-squared, and MAE for each series
4. Saves results to a table for the manuscript
"""

using CSV
using DataFrames
using Statistics
using Printf

# Add the estimation code to path
include("../../estimation/estimation.jl")
include("../../estimation/do_estimation.jl")

println("\n" * "="^70)
println("Computing Aggregate Goodness-of-Fit Statistics")
println("="^70 * "\n")

# Helper function to compute R²
function compute_r2(y_actual, y_predicted)
    ss_res = sum((y_actual .- y_predicted).^2)
    ss_tot = sum((y_actual .- mean(y_actual)).^2)
    return 1 - ss_res / ss_tot
end

# Define parameter sets from Table 1 (tab:estimation_korv)
param_sets = Dict(
    "KORV (63-92)" => (
        period = "1963-1992",
        α = 0.117, σ = 0.401, ρ = -0.495, η = 0.043,
        data_file = "data/Data_KORV.csv",
        year_start = 1963, year_end = 1992
    ),
    "Repl. (63-92)" => (
        period = "1963-1992",
        α = 0.113, σ = 0.464, ρ = -0.560, η = 0.043,
        data_file = "data/Data_KORV.csv",
        year_start = 1963, year_end = 1992
    ),
    "Ext. (63-18)" => (
        period = "1963-2018",
        α = 0.118, σ = 0.503, ρ = -0.343, η = 0.083,
        data_file = "data/proclabor_totl.csv",
        year_start = 1963, year_end = 2018
    ),
    "Ind. (88-18)" => (
        period = "1988-2018",
        α = 0.080, σ = 0.313, ρ = -0.154, η = 0.043,
        data_file = "data/proclabor_totl.csv",
        year_start = 1988, year_end = 2018
    )
)

# Initialize model
@parameters α, μ, σ, λ, ρ, δ_e, δ_s
@variables k_e, k_s, h, ℓ, ψ_L, ψ_H, q, y

model = intializeModel()

# Storage for results
results = []

# Process each parameter set
spec_order = ["KORV (63-92)", "Repl. (63-92)", "Ext. (63-18)", "Ind. (88-18)"]

for name in spec_order
    pset = param_sets[name]
    
    println("-"^70)
    println("Processing: $name")
    println("-"^70)
    
    try
        # Load data
        if !isfile(pset.data_file)
            println("  ⚠ Data file not found: $(pset.data_file), skipping...")
            continue
        end
        
        dataframe = CSV.read(pset.data_file, DataFrame)
        println("  Loaded data file: $(pset.data_file)")
        println("  Columns: $(names(dataframe))")
        
        # Filter by period if data has year column
        if "year" in names(dataframe) || "YEAR" in names(dataframe)
            year_col = "year" in names(dataframe) ? :year : :YEAR
            dataframe = filter(row -> row[year_col] >= pset.year_start && row[year_col] <= pset.year_end, dataframe)
            println("  Filtered to $(pset.year_start)-$(pset.year_end): $(nrow(dataframe)) observations")
        else
            # No year column - data is already the correct period
            println("  No year column - using all $(nrow(dataframe)) observations")
        end
        
        # Generate data structure
        data = generateData(dataframe)
        T = length(data.y)
        println("  Time series length: $T")
        
        # Set parameters (using default values for μ, λ, φ_L, φ_H)
        params = setParams(
            [pset.α, pset.σ, pset.ρ, pset.η],
            [0.5, 0.5, 1.0, 1.0]  # Default values for μ, λ, φ_L, φ_H
        )
        
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
        
        # 4. Labor Input Ratio (derived from wbr/ω)
        li_model = wbr_model ./ ω_model
        li_data = data.h[2:end] ./ data.ℓ[2:end]
        rmse_li = sqrt(mean((li_model .- li_data).^2))
        r2_li = compute_r2(li_data, li_model)
        mae_li = mean(abs.(li_model .- li_data))
        
        # Store results
        push!(results, (
            specification = name,
            period = pset.period,
            n_obs = T,
            rmse_skill_premium = rmse_sp,
            rmse_labor_share = rmse_ls,
            rmse_wage_bill_ratio = rmse_wbr,
            rmse_labor_input_ratio = rmse_li,
            r2_skill_premium = r2_sp,
            r2_labor_share = r2_ls,
            r2_wage_bill_ratio = r2_wbr,
            r2_labor_input_ratio = r2_li,
            mae_skill_premium = mae_sp,
            mae_labor_share = mae_ls,
            mae_wage_bill_ratio = mae_wbr,
            mae_labor_input_ratio = mae_li
        ))
        
        println("  ✓ Fit Statistics:")
        println("    RMSE: SP=$(round(rmse_sp, digits=4)), LS=$(round(rmse_ls, digits=4)), WBR=$(round(rmse_wbr, digits=4)), LI=$(round(rmse_li, digits=4))")
        println("    R²:   SP=$(round(r2_sp, digits=4)), LS=$(round(r2_ls, digits=4)), WBR=$(round(r2_wbr, digits=4)), LI=$(round(r2_li, digits=4))")
        println("    MAE:  SP=$(round(mae_sp, digits=4)), LS=$(round(mae_ls, digits=4)), WBR=$(round(mae_wbr, digits=4)), LI=$(round(mae_li, digits=4))")
        
    catch e
        println("  ✗ Error: $e")
        println("  Stacktrace:")
        for (exc, bt) in Base.catch_stack()
            showerror(stdout, exc, bt)
            println()
        end
    end
end

# Convert to DataFrame and save
if length(results) > 0
    results_df = DataFrame(results)
    
    println("\n" * "="^70)
    println("Saving results...")
    CSV.write("data/results/aggregate_fit_statistics.csv", results_df)
    println("✓ Saved to: data/results/aggregate_fit_statistics.csv")
    
    # Generate LaTeX table
    println("\nGenerating LaTeX table...")
    
    latex_table = """
\\begin{table}[H]
\\caption{Goodness-of-Fit Statistics for Aggregate Model Across Sample Periods}
\\label{tab:aggregate_fit_statistics}
\\begin{center}
\\small
\\begin{tabular}{lcccc}
\\toprule
& \\multicolumn{4}{c}{\\textbf{RMSE}} \\\\
\\cmidrule(lr){2-5}
Specification & Skill Prem. & Labor Share & Wage Bill Ratio & Labor Input Ratio \\\\
\\midrule
"""
    
    for row in eachrow(results_df)
        latex_table *= @sprintf("%s & %.4f & %.4f & %.4f & %.4f \\\\\n",
            row.specification,
            row.rmse_skill_premium, row.rmse_labor_share, 
            row.rmse_wage_bill_ratio, row.rmse_labor_input_ratio)
    end
    
    latex_table *= """
\\midrule
& \\multicolumn{4}{c}{\\textbf{R²}} \\\\
\\cmidrule(lr){2-5}
Specification & Skill Prem. & Labor Share & Wage Bill Ratio & Labor Input Ratio \\\\
\\midrule
"""
    
    for row in eachrow(results_df)
        latex_table *= @sprintf("%s & %.4f & %.4f & %.4f & %.4f \\\\\n",
            row.specification,
            row.r2_skill_premium, row.r2_labor_share, 
            row.r2_wage_bill_ratio, row.r2_labor_input_ratio)
    end
    
    latex_table *= """
\\bottomrule
\\end{tabular}
\\end{center}
\\begin{minipage}{\\textwidth}
\\small
\\textit{Note:} Goodness-of-fit statistics for aggregate model using parameter estimates from Table~\\ref{tab:estimation_korv}. 
KORV = Original KORV estimation (1963-1992), Repl. = This paper's replication (1963-1992), 
Ext. = Extended sample (1963-2018), Ind. = Industry-coverage period (1988-2018). 
RMSE = Root Mean Squared Error (lower is better), R² = coefficient of determination (higher is better, 1.0 = perfect fit). 
Skill Premium = \$w_s/w_u\$, Labor Share = total labor compensation / output, 
Wage Bill Ratio = \$(w_s \\cdot h_s)/(w_u \\cdot h_u)\$, Labor Input Ratio = \$h_s/h_u\$.
\\end{minipage}
\\end{table}
"""
    
    open("documents/tables/aggregate_fit_statistics.tex", "w") do f
        write(f, latex_table)
    end
    println("✓ Saved LaTeX table to: documents/tables/aggregate_fit_statistics.tex")
    
    # Print summary
    println("\n" * "="^70)
    println("SUMMARY")
    println("="^70)
    println("Successfully computed fit statistics for $(nrow(results_df)) specifications:")
    for row in eachrow(results_df)
        println("  • $(row.specification): $(row.n_obs) observations")
    end
    
    println("\nAverage fit quality across specifications:")
    println("  RMSE: SP=$(round(mean(results_df.rmse_skill_premium), digits=4)), " *
            "LS=$(round(mean(results_df.rmse_labor_share), digits=4)), " *
            "WBR=$(round(mean(results_df.rmse_wage_bill_ratio), digits=4)), " *
            "LI=$(round(mean(results_df.rmse_labor_input_ratio), digits=4))")
    println("  R²:   SP=$(round(mean(results_df.r2_skill_premium), digits=4)), " *
            "LS=$(round(mean(results_df.r2_labor_share), digits=4)), " *
            "WBR=$(round(mean(results_df.r2_wage_bill_ratio), digits=4)), " *
            "LI=$(round(mean(results_df.r2_labor_input_ratio), digits=4))")
    
else
    println("\n⚠ No results to save - all specifications failed")
end

println("\n" * "="^70)
println("Script completed!")
println("="^70)
