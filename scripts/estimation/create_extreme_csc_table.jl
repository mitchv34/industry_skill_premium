#!/usr/bin/env julia
"""
Create table showing industries with strongest and weakest CSC (σ-ρ)
Includes industry characteristics to interpret patterns
"""

using CSV
using DataFrames
using Statistics
using Printf

println("Creating Extreme CSC Industries Table...")

# Load cross-walk for industry names
crosswalk = CSV.read("data/cross_walk.csv", DataFrame)

# Load all industry estimation results
results = DataFrame[]
for row in eachrow(crosswalk)
    ind_code = row.code_klems
    result_file = "data/results/ind_est/$(ind_code).csv"
    
    if isfile(result_file)
        try
            params = CSV.read(result_file, DataFrame)
            if nrow(params) > 0
                push!(results, DataFrame(
                    code = ind_code,
                    name = row.ind_desc,
                    sigma = params.sigma[1],
                    rho = params.rho[1],
                    alpha = params.alpha[1],
                    sigma_s = 1 / (1 - params.rho[1]),
                    sigma_u = 1 / (1 - params.sigma[1])
                ))
            end
        catch e
            println("  Warning: Could not load $(ind_code): $e")
        end
    end
end

results_df = vcat(results...)
println("Loaded $(nrow(results_df)) industry parameter estimates")

# Calculate σ-ρ (CSC strength)
results_df.csc_strength = results_df.sigma .- results_df.rho

# Load industry characteristics (skill premium, labor input ratio)
characteristics = DataFrame[]
for row in eachrow(results_df)
    data_file = "data/proc/ind/$(row.code).csv"
    
    if isfile(data_file)
        try
            data = CSV.read(data_file, DataFrame)
            # Calculate average skill premium and labor input ratio
            avg_sp = mean(skipmissing(data.W_S ./ data.W_U))
            avg_li = mean(skipmissing(data.L_S ./ data.L_U))
            
            push!(characteristics, DataFrame(
                code = row.code,
                avg_skill_premium = avg_sp,
                avg_labor_input_ratio = avg_li
            ))
        catch e
            push!(characteristics, DataFrame(
                code = row.code,
                avg_skill_premium = missing,
                avg_labor_input_ratio = missing
            ))
        end
    else
        push!(characteristics, DataFrame(
            code = row.code,
            avg_skill_premium = missing,
            avg_labor_input_ratio = missing
        ))
    end
end

char_df = vcat(characteristics...)

# Merge characteristics with results
results_df = leftjoin(results_df, char_df, on = :code)

# Sort by CSC strength
sort!(results_df, :csc_strength, rev=true)

# Classify sectors (simple heuristic based on industry codes)
function classify_sector(code::AbstractString)
    code_upper = uppercase(String(code))
    if occursin(r"^[12]", code_upper)  # 1xxx, 2xxx
        return "Primary/Construction"
    elseif occursin(r"^3", code_upper)  # 3xxx
        return "Manufacturing"
    elseif occursin(r"^4", code_upper)  # 4xxx
        return "Transportation/Utilities"
    elseif occursin(r"^5[1-4]", code_upper)  # 51xx-54xx
        return "Information/Services"
    elseif occursin(r"^5[5-6]", code_upper)  # 55xx-56xx
        return "Financial/Admin Services"
    elseif occursin(r"^6[1-2]", code_upper)  # 61xx-62xx
        return "Education/Health"
    elseif occursin(r"^[67]", code_upper)  # 6xxx-7xxx
        return "Other Services"
    else
        return "Other"
    end
end

results_df.sector = classify_sector.(results_df.code)

# Get top 10 and bottom 10
top10 = first(results_df, min(10, nrow(results_df)))
bottom10 = last(results_df, min(10, nrow(results_df)))

# Create LaTeX table for top 10 (Strongest CSC)
println("\nGenerating LaTeX table for strongest CSC industries...")

latex_top = """
\\begin{table}[H]
\\caption{Industries with Strongest Capital-Skill Complementarity}
\\label{tab:strongest_csc}
\\begin{center}
\\small
\\begin{tabular}{lcccccc}
\\toprule
Industry & \$\\sigma\$ & \$\\rho\$ & \$\\sigma-\\rho\$ & Sector & Skill Prem. & Labor Ratio \\\\
\\midrule
"""

for row in eachrow(top10)
    sp_str = ismissing(row.avg_skill_premium) ? "---" : @sprintf("%.2f", row.avg_skill_premium)
    li_str = ismissing(row.avg_labor_input_ratio) ? "---" : @sprintf("%.2f", row.avg_labor_input_ratio)
    
    global latex_top *= @sprintf("%s & %.3f & %.3f & %.3f & %s & %s & %s \\\\\n",
        row.name, row.sigma, row.rho, row.csc_strength, 
        row.sector, sp_str, li_str)
end

latex_top *= """
\\bottomrule
\\end{tabular}
\\end{center}
\\begin{minipage}{\\textwidth}
\\small
\\textit{Note:} Industries ranked by \$\\sigma - \\rho\$ (CSC strength). Skill Premium = average \$w_s/w_u\$ over sample period. Labor Ratio = average \$L_s/L_u\$ over sample period.
\\end{minipage}
\\end{table}
"""

# Create LaTeX table for bottom 10 (Weakest/Negative CSC)
println("Generating LaTeX table for weakest CSC industries...")

latex_bottom = """
\\begin{table}[H]
\\caption{Industries with Weakest Capital-Skill Complementarity}
\\label{tab:weakest_csc}
\\begin{center}
\\small
\\begin{tabular}{lcccccc}
\\toprule
Industry & \$\\sigma\$ & \$\\rho\$ & \$\\sigma-\\rho\$ & Sector & Skill Prem. & Labor Ratio \\\\
\\midrule
"""

for row in eachrow(bottom10)
    sp_str = ismissing(row.avg_skill_premium) ? "---" : @sprintf("%.2f", row.avg_skill_premium)
    li_str = ismissing(row.avg_labor_input_ratio) ? "---" : @sprintf("%.2f", row.avg_labor_input_ratio)
    
    global latex_bottom *= @sprintf("%s & %.3f & %.3f & %.3f & %s & %s & %s \\\\\n",
        row.name, row.sigma, row.rho, row.csc_strength, 
        row.sector, sp_str, li_str)
end

latex_bottom *= """
\\bottomrule
\\end{tabular}
\\end{center}
\\begin{minipage}{\\textwidth}
\\small
\\textit{Note:} Industries ranked by \$\\sigma - \\rho\$ (CSC strength, ascending). Negative \$\\sigma - \\rho\$ indicates capital-skill substitutability rather than complementarity.
\\end{minipage}
\\end{table}
"""

# Combined table (alternative format)
latex_combined = """
\\begin{table}[H]
\\caption{Industries with Extreme Capital-Skill Complementarity}
\\label{tab:extreme_csc}
\\begin{center}
\\small
\\begin{tabular}{lccc|lccc}
\\toprule
\\multicolumn{4}{c}{\\textbf{Strongest CSC (Top 10)}} & \\multicolumn{4}{c}{\\textbf{Weakest CSC (Bottom 10)}} \\\\
\\cmidrule(lr){1-4} \\cmidrule(lr){5-8}
Industry & \$\\sigma\$ & \$\\rho\$ & \$\\sigma-\\rho\$ & Industry & \$\\sigma\$ & \$\\rho\$ & \$\\sigma-\\rho\$ \\\\
\\midrule
"""

for i in 1:min(10, nrow(top10), nrow(bottom10))
    top_row = top10[i, :]
    bottom_row = bottom10[i, :]
    
    global latex_combined *= @sprintf("%s & %.2f & %.2f & %.2f & %s & %.2f & %.2f & %.2f \\\\\n",
        top_row.name, top_row.sigma, top_row.rho, top_row.csc_strength,
        bottom_row.name, bottom_row.sigma, bottom_row.rho, bottom_row.csc_strength)
end

latex_combined *= """
\\bottomrule
\\end{tabular}
\\end{center}
\\begin{minipage}{\\textwidth}
\\small
\\textit{Note:} Left panel shows industries with highest \$\\sigma - \\rho\$ (strongest complementarity). Right panel shows lowest \$\\sigma - \\rho\$ (weakest or negative complementarity).
\\end{minipage}
\\end{table}
"""

# Save tables
println("\nSaving LaTeX tables...")
open("documents/tables/strongest_csc_industries.tex", "w") do f
    write(f, latex_top)
end

open("documents/tables/weakest_csc_industries.tex", "w") do f
    write(f, latex_bottom)
end

open("documents/tables/extreme_csc_industries.tex", "w") do f
    write(f, latex_combined)
end

# Save CSV for analysis
CSV.write("data/results/extreme_csc_analysis.csv", results_df)

println("\n✓ Tables saved to documents/tables/")
println("  - strongest_csc_industries.tex")
println("  - weakest_csc_industries.tex")
println("  - extreme_csc_industries.tex")
println("✓ Full data saved to data/results/extreme_csc_analysis.csv")

# Print summary statistics
println("\n" * "="^60)
println("SUMMARY STATISTICS")
println("="^60)
println("Total industries: $(nrow(results_df))")
println("Industries with σ-ρ > 0 (CSC holds): $(sum(results_df.csc_strength .> 0)) ($(round(100*mean(results_df.csc_strength .> 0), digits=1))%)")
println("Industries with σ-ρ ≤ 0 (CSC fails): $(sum(results_df.csc_strength .<= 0))")
println("\nCSC Strength (σ-ρ) statistics:")
println("  Mean:   $(round(mean(results_df.csc_strength), digits=3))")
println("  Median: $(round(median(results_df.csc_strength), digits=3))")
println("  Std:    $(round(std(results_df.csc_strength), digits=3))")
println("  Min:    $(round(minimum(results_df.csc_strength), digits=3)) ($(results_df.name[argmin(results_df.csc_strength)]))")
println("  Max:    $(round(maximum(results_df.csc_strength), digits=3)) ($(results_df.name[argmax(results_df.csc_strength)]))")

println("\n✓ Script completed successfully!")
