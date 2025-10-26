"""
Compute decomposition of skill premium growth into three channels:
1. Supply effect (changes in H_s/H_u)
2. Capital-skill complementarity (CSC) effect
3. Efficiency effect (changes in A_s/A_u)

Based on equation (11) from the manuscript:

Δlog(ω) = [supply effect] + [CSC effect] + [efficiency effect]

Where:
- Supply effect: -(1/σ_u + 1/σ_s) * Δlog(H_s/H_u)
- CSC effect: (σ - ρ)/(σ_s * σ_u) * Δlog(K_eq/K_str)
- Efficiency effect: (1/σ_u - 1/σ_s) * Δlog(A_s/A_u)

For CSC to dominate supply, we need: |CSC effect| > |Supply effect|
"""

using Pkg
Pkg.activate(".")

using CSV
using DataFrames
using Statistics

println("\n" * "="^60)
println("Decomposition Analysis: Skill Premium Growth")
println("="^60 * "\n")

# Function to compute elasticities from parameters
function compute_elasticities(α::Float64, σ::Float64, ρ::Float64)
    # Equation (8) from manuscript
    denom_s = 1 - α * (σ - ρ)
    denom_u = 1 + (1 - α) * (σ - ρ)
    
    # Check for numerical issues
    if abs(denom_s) < 1e-6 || abs(denom_u) < 1e-6
        return nothing
    end
    
    σ_s = σ / denom_s
    σ_u = σ / denom_u
    
    # Check for reasonable values
    if !isfinite(σ_s) || !isfinite(σ_u)
        return nothing
    end
    
    return (σ_s=σ_s, σ_u=σ_u)
end

# Function to compute decomposition
function decompose_skill_premium(;
    α::Float64,
    σ::Float64,
    ρ::Float64,
    Δlog_H_ratio::Float64,
    Δlog_K_ratio::Float64,
    Δlog_A_ratio::Float64
)
    # Compute elasticities
    elast = compute_elasticities(α, σ, ρ)
    if isnothing(elast)
        return nothing
    end
    
    σ_s, σ_u = elast.σ_s, elast.σ_u
    
    # Three channels
    supply_effect = -(1/σ_u + 1/σ_s) * Δlog_H_ratio
    csc_effect = (σ - ρ)/(σ_s * σ_u) * Δlog_K_ratio
    efficiency_effect = (1/σ_u - 1/σ_s) * Δlog_A_ratio
    
    # Check for numerical issues
    if !isfinite(supply_effect) || !isfinite(csc_effect) || !isfinite(efficiency_effect)
        return nothing
    end
    
    # Total change
    total_change = supply_effect + csc_effect + efficiency_effect
    
    # Percentage contributions (handle zero total carefully)
    if abs(total_change) < 1e-10
        supply_pct = 0.0
        csc_pct = 0.0
        efficiency_pct = 0.0
    else
        supply_pct = 100 * supply_effect / total_change
        csc_pct = 100 * csc_effect / total_change
        efficiency_pct = 100 * efficiency_effect / total_change
    end
    
    return (
        supply = supply_effect,
        csc = csc_effect,
        efficiency = efficiency_effect,
        total = total_change,
        supply_pct = supply_pct,
        csc_pct = csc_pct,
        efficiency_pct = efficiency_pct
    )
end

# Function to load industry data and compute growth rates
function load_industry_data(ind_code::String, data_dir::String)
    data_path = joinpath(data_dir, "$(ind_code).csv")
    if !isfile(data_path)
        return nothing
    end
    
    df = CSV.read(data_path, DataFrame)
    
    # Filter out rows with missing labor data
    df = df[df.L_S .> 0 .&& df.L_U .> 0, :]
    
    if nrow(df) < 2
        return nothing
    end
    
    return df
end

# Function to compute growth rates from data
function compute_growth_rates(df::DataFrame)
    first_idx = 1
    last_idx = nrow(df)
    
    # Compute log changes over full period
    Δlog_H_ratio = log(df.L_S[last_idx] / df.L_U[last_idx]) - log(df.L_S[first_idx] / df.L_U[first_idx])
    Δlog_K_ratio = log(df.K_EQ[last_idx] / df.K_STR[last_idx]) - log(df.K_EQ[first_idx] / df.K_STR[first_idx])
    Δlog_omega = log(df.SKILL_PREMIUM[last_idx]) - log(df.SKILL_PREMIUM[first_idx])
    
    years = df.YEAR[last_idx] - df.YEAR[first_idx]
    
    return (
        Δlog_H_ratio = Δlog_H_ratio,
        Δlog_K_ratio = Δlog_K_ratio,
        Δlog_omega = Δlog_omega,
        years = years
    )
end

# Load industry results and perform decomposition
function decompose_industry(ind_code::String, results_dir::String, data_dir::String)
    # Load estimation results
    results_path = joinpath(results_dir, "$(ind_code).csv")
    if !isfile(results_path)
        return nothing
    end
    
    results = CSV.read(results_path, DataFrame)
    
    # Filter out NaN values
    results = results[.!isnan.(results.obj_val), :]
    
    # Take the best fit (row with minimum obj_val)
    if nrow(results) > 0
        best_idx = argmin(results.obj_val)
        α = results.alpha[best_idx]
        σ = results.sigma[best_idx]
        ρ = results.rho[best_idx]
        phi_L = results.phi_L[best_idx]
        phi_H = results.phi_H[best_idx]
        
        # Check for NaN parameters
        if isnan(α) || isnan(σ) || isnan(ρ)
            return nothing
        end
    else
        return nothing
    end
    
    # Load data
    df = load_industry_data(ind_code, data_dir)
    if isnothing(df)
        return nothing
    end
    
    # Compute growth rates
    growth_rates = compute_growth_rates(df)
    
    # Estimate efficiency change as residual
    # From equation: Δlog(ω) ≈ supply_effect + CSC_effect + efficiency_effect
    # We back out Δlog(A_s/A_u) as the residual
    
    elast = compute_elasticities(α, σ, ρ)
    if isnothing(elast)
        return nothing
    end
    
    σ_s, σ_u = elast.σ_s, elast.σ_u
    
    # Compute supply and CSC effects
    supply_effect = -(1/σ_u + 1/σ_s) * growth_rates.Δlog_H_ratio
    csc_effect = (σ - ρ)/(σ_s * σ_u) * growth_rates.Δlog_K_ratio
    
    # Back out efficiency effect as residual
    efficiency_effect = growth_rates.Δlog_omega - supply_effect - csc_effect
    
    # Check for numerical issues
    if !isfinite(supply_effect) || !isfinite(csc_effect) || !isfinite(efficiency_effect)
        return nothing
    end
    
    # Use the backed-out efficiency to get implied Δlog_A_ratio
    elasticity_diff = (1/σ_u - 1/σ_s)
    if abs(elasticity_diff) < 1e-10
        Δlog_A_ratio = 0.0
    else
        Δlog_A_ratio = efficiency_effect / elasticity_diff
    end
    
    # Now recompute for verification
    result = decompose_skill_premium(
        α = α,
        σ = σ,
        ρ = ρ,
        Δlog_H_ratio = growth_rates.Δlog_H_ratio,
        Δlog_K_ratio = growth_rates.Δlog_K_ratio,
        Δlog_A_ratio = Δlog_A_ratio
    )
    
    if isnothing(result)
        return nothing
    end
    
    return (
        ind_code = ind_code,
        α = α,
        σ = σ,
        ρ = ρ,
        σ_minus_ρ = σ - ρ,
        supply = result.supply,
        csc = result.csc,
        efficiency = result.efficiency,
        total = result.total,
        observed_change = growth_rates.Δlog_omega,
        supply_pct = result.supply_pct,
        csc_pct = result.csc_pct,
        efficiency_pct = result.efficiency_pct,
        years = growth_rates.years,
        csc_dominates = abs(result.csc_pct) > abs(result.supply_pct)
    )
end

# Main analysis
println("\n" * "="^60)
println("Industry-Level Decomposition Analysis")
println("="^60 * "\n")

results_dir = "data/results"
data_dir = "data/proc/ind"

# Get list of industries with results
industry_codes = String[]
for f in readdir(results_dir)
    if endswith(f, ".csv") && match(r"^[0-9A-Z]{2,6}\.csv$", f) !== nothing
        push!(industry_codes, replace(f, ".csv" => ""))
    end
end

sort!(industry_codes)

println("Found $(length(industry_codes)) industries with estimation results\n")

# Main decomposition function
function run_decomposition_analysis(industry_codes, results_dir, data_dir)
    # Perform decomposition for each industry
    decomp_results = []
    n_failed = 0
    for ind_code in industry_codes
        result = decompose_industry(ind_code, results_dir, data_dir)
        if !isnothing(result)
            push!(decomp_results, result)
            println("✓ $(ind_code): CSC=$(round(result.csc_pct, digits=1))%, Supply=$(round(result.supply_pct, digits=1))%, Eff=$(round(result.efficiency_pct, digits=1))%")
        else
            n_failed += 1
            println("✗ $(ind_code): Failed to compute decomposition (numerical issues or missing data)")
        end
    end

    println("\n" * "="^60)
    println("Summary Statistics")
    println("="^60)
    println("Total industries: $(length(industry_codes))")
    println("Successfully decomposed: $(length(decomp_results)) industries")
    println("Failed (numerical issues): $(n_failed) industries")
    
    if length(decomp_results) == 0
        println("\n⚠️  No industries successfully decomposed!")
        return nothing
    end
    
    return decomp_results
end

decomp_results = run_decomposition_analysis(industry_codes, results_dir, data_dir)

if isnothing(decomp_results)
    exit(1)
end

# Count industries where CSC dominates
csc_dominates_count = sum([r.csc_dominates for r in decomp_results])
println("Industries where CSC dominates supply: $(csc_dominates_count) ($(round(100*csc_dominates_count/length(decomp_results), digits=1))%)")

# Compute summary statistics
supply_pcts = [r.supply_pct for r in decomp_results]
csc_pcts = [r.csc_pct for r in decomp_results]
eff_pcts = [r.efficiency_pct for r in decomp_results]

println("\nMean contributions:")
println("  Supply:     $(round(mean(supply_pcts), digits=1))%")
println("  CSC:        $(round(mean(csc_pcts), digits=1))%")
println("  Efficiency: $(round(mean(eff_pcts), digits=1))%")

println("\nMedian contributions:")
println("  Supply:     $(round(median(supply_pcts), digits=1))%")
println("  CSC:        $(round(median(csc_pcts), digits=1))%")
println("  Efficiency: $(round(median(eff_pcts), digits=1))%")

# Create detailed results table
println("\n" * "="^60)
println("Creating LaTeX Tables")
println("="^60)

# Save detailed results to CSV for reference
decomp_df = DataFrame(
    Industry = [r.ind_code for r in decomp_results],
    Alpha = [r.α for r in decomp_results],
    Sigma = [r.σ for r in decomp_results],
    Rho = [r.ρ for r in decomp_results],
    Sigma_minus_Rho = [r.σ_minus_ρ for r in decomp_results],
    Supply_Effect = [r.supply for r in decomp_results],
    CSC_Effect = [r.csc for r in decomp_results],
    Efficiency_Effect = [r.efficiency for r in decomp_results],
    Total_Change = [r.total for r in decomp_results],
    Observed_Change = [r.observed_change for r in decomp_results],
    Supply_Pct = [r.supply_pct for r in decomp_results],
    CSC_Pct = [r.csc_pct for r in decomp_results],
    Efficiency_Pct = [r.efficiency_pct for r in decomp_results],
    Years = [r.years for r in decomp_results],
    CSC_Dominates = [r.csc_dominates for r in decomp_results]
)

CSV.write("data/results/decomposition_by_industry.csv", decomp_df)
println("✓ Saved detailed results to: data/results/decomposition_by_industry.csv")

# Create summary LaTeX table
function create_summary_latex_table(decomp_results)
    # Sort by CSC percentage contribution
    sorted_results = sort(decomp_results, by = r -> r.csc_pct, rev=true)
    
    # Top 10 industries by CSC contribution
    top_csc = sorted_results[1:min(10, length(sorted_results))]
    
    # Bottom 10 (or industries where supply dominates most)
    bottom_csc = sorted_results[max(1, length(sorted_results)-9):end]
    
    latex = """
\\begin{table}[htbp]
\\centering
\\caption{Decomposition of Skill Premium Growth by Industry}
\\label{tab:decomposition_by_industry}
\\begin{tabular}{lrrrrr}
\\hline\\hline
\\textbf{Industry} & \\textbf{Supply} & \\textbf{CSC} & \\textbf{Efficiency} & \\textbf{Total} & \\boldmath{\$\\sigma - \\rho\$} \\\\
 & \\textbf{(\\%)} & \\textbf{(\\%)} & \\textbf{(\\%)} & \\textbf{(log pts)} &  \\\\ \\hline
\\multicolumn{6}{l}{\\textit{Panel A: Top 10 Industries by CSC Contribution}} \\\\ \\hline
"""
    
    for r in top_csc
        latex *= "$(r.ind_code) & $(round(r.supply_pct, digits=1)) & $(round(r.csc_pct, digits=1)) & $(round(r.efficiency_pct, digits=1)) & $(round(r.total, digits=3)) & $(round(r.σ_minus_ρ, digits=3)) \\\\\n"
    end
    
    latex *= """\\hline
\\multicolumn{6}{l}{\\textit{Panel B: Bottom 10 Industries by CSC Contribution}} \\\\ \\hline
"""
    
    for r in reverse(bottom_csc)
        latex *= "$(r.ind_code) & $(round(r.supply_pct, digits=1)) & $(round(r.csc_pct, digits=1)) & $(round(r.efficiency_pct, digits=1)) & $(round(r.total, digits=3)) & $(round(r.σ_minus_ρ, digits=3)) \\\\\n"
    end
    
    # Add summary statistics
    latex *= """\\hline
\\multicolumn{6}{l}{\\textit{Panel C: Summary Statistics (All $(length(decomp_results)) Industries)}} \\\\ \\hline
Mean & $(round(mean([r.supply_pct for r in decomp_results]), digits=1)) & $(round(mean([r.csc_pct for r in decomp_results]), digits=1)) & $(round(mean([r.efficiency_pct for r in decomp_results]), digits=1)) & $(round(mean([r.total for r in decomp_results]), digits=3)) & $(round(mean([r.σ_minus_ρ for r in decomp_results]), digits=3)) \\\\
Median & $(round(median([r.supply_pct for r in decomp_results]), digits=1)) & $(round(median([r.csc_pct for r in decomp_results]), digits=1)) & $(round(median([r.efficiency_pct for r in decomp_results]), digits=1)) & $(round(median([r.total for r in decomp_results]), digits=3)) & $(round(median([r.σ_minus_ρ for r in decomp_results]), digits=3)) \\\\
Std. Dev. & $(round(std([r.supply_pct for r in decomp_results]), digits=1)) & $(round(std([r.csc_pct for r in decomp_results]), digits=1)) & $(round(std([r.efficiency_pct for r in decomp_results]), digits=1)) & $(round(std([r.total for r in decomp_results]), digits=3)) & $(round(std([r.σ_minus_ρ for r in decomp_results]), digits=3)) \\\\
\\hline\\hline
\\end{tabular}
\\begin{flushleft}
\\footnotesize \\textit{Notes:} Decomposition based on equation (11) in the manuscript. Supply effect captures changes in relative skill supply (\$H_s/H_u\$). CSC effect captures capital-skill complementarity via equipment-structure ratio (\$K_{eq}/K_{str}\$). Efficiency effect captures changes in relative productivity (\$A_s/A_u\$). Percentage contributions sum to 100\\% within each industry. Total change is the observed log change in skill premium. Industries are sorted by CSC contribution percentage. The parameter \$\\sigma - \\rho\$ indicates the strength of capital-skill complementarity (positive values indicate CSC).
\\end{flushleft}
\\end{table}
"""
    
    return latex
end

# Create compact summary table showing which channel dominates
function create_dominance_summary_table(decomp_results)
    csc_dom = sum([r.csc_dominates for r in decomp_results])
    supply_dom = length(decomp_results) - csc_dom
    
    # Calculate mean effects for each group
    csc_dom_results = filter(r -> r.csc_dominates, decomp_results)
    supply_dom_results = filter(r -> !r.csc_dominates, decomp_results)
    
    latex = """
\\begin{table}[htbp]
\\centering
\\caption{Summary of Dominant Channels by Industry Group}
\\label{tab:decomposition_summary}
\\begin{tabular}{lcccc}
\\hline\\hline
\\textbf{Dominant Channel} & \\textbf{Count} & \\textbf{Mean Supply} & \\textbf{Mean CSC} & \\textbf{Mean Efficiency} \\\\
 & & \\textbf{(\\%)} & \\textbf{(\\%)} & \\textbf{(\\%)} \\\\ \\hline
"""
    
    if length(csc_dom_results) > 0
        latex *= "CSC Effect & $(length(csc_dom_results)) & $(round(mean([r.supply_pct for r in csc_dom_results]), digits=1)) & $(round(mean([r.csc_pct for r in csc_dom_results]), digits=1)) & $(round(mean([r.efficiency_pct for r in csc_dom_results]), digits=1)) \\\\\n"
    end
    
    if length(supply_dom_results) > 0
        latex *= "Supply Effect & $(length(supply_dom_results)) & $(round(mean([r.supply_pct for r in supply_dom_results]), digits=1)) & $(round(mean([r.csc_pct for r in supply_dom_results]), digits=1)) & $(round(mean([r.efficiency_pct for r in supply_dom_results]), digits=1)) \\\\\n"
    end
    
    latex *= """\\hline
Total & $(length(decomp_results)) & $(round(mean([r.supply_pct for r in decomp_results]), digits=1)) & $(round(mean([r.csc_pct for r in decomp_results]), digits=1)) & $(round(mean([r.efficiency_pct for r in decomp_results]), digits=1)) \\\\
\\hline\\hline
\\end{tabular}
\\begin{flushleft}
\\footnotesize \\textit{Notes:} Industries are classified by which effect (CSC or Supply) has the larger absolute percentage contribution. Values show mean percentage contributions within each group.
\\end{flushleft}
\\end{table}
"""
    
    return latex
end

# Generate and save tables
summary_table = create_summary_latex_table(decomp_results)
dominance_table = create_dominance_summary_table(decomp_results)

# Save detailed table
open("documents/tables/decomposition_by_industry.tex", "w") do io
    write(io, summary_table)
end
println("✓ Saved detailed table to: documents/tables/decomposition_by_industry.tex")

# Save summary table
open("documents/tables/decomposition_summary.tex", "w") do io
    write(io, dominance_table)
end
println("✓ Saved summary table to: documents/tables/decomposition_summary.tex")

println("\n" * "="^60)
println("Analysis Complete!")
println("="^60)
println("\nKey Findings:")
println("• CSC effect dominates in $(csc_dominates_count)/$(length(decomp_results)) industries ($(round(100*csc_dominates_count/length(decomp_results), digits=1))%)")
println("• Mean CSC contribution: $(round(mean(csc_pcts), digits=1))%")
println("• Mean Supply contribution: $(round(mean(supply_pcts), digits=1))%")
println("• Mean σ - ρ: $(round(mean([r.σ_minus_ρ for r in decomp_results]), digits=3))")
println("\nOutput files:")
println("  1. data/results/decomposition_by_industry.csv (detailed results)")
println("  2. documents/tables/decomposition_by_industry.tex (main table)")
println("  3. documents/tables/decomposition_summary.tex (summary table)")
println()
