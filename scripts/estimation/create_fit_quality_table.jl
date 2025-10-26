#!/usr/bin/env julia
"""
Create table grouping industries by goodness-of-fit quality
Requires: fit_statistics_all_industries.csv from expand_fit_statistics.jl
"""

using CSV
using DataFrames
using Statistics
using Printf

println("Creating Fit Quality Summary Table...")

# Load fit statistics
fit_stats = CSV.read("data/results/fit_statistics_all_industries.csv", DataFrame)

# Filter to converged industries
converged = filter(row -> row.converged, fit_stats)
println("Loaded fit statistics for $(nrow(converged)) converged industries")

if nrow(converged) == 0
    println("ERROR: No converged industries found!")
    println("Please run expand_fit_statistics.jl first.")
    exit(1)
end

# Compute overall fit score (average R² across all series)
converged.overall_r2 = (converged.r2_skill_premium .+ converged.r2_labor_share .+ 
                        converged.r2_wage_bill_ratio .+ converged.r2_labor_input_ratio) ./ 4

# Compute overall RMSE score (average RMSE, normalized)
converged.overall_rmse = (converged.rmse_skill_premium .+ converged.rmse_labor_share .+ 
                          converged.rmse_wage_bill_ratio .+ converged.rmse_labor_input_ratio) ./ 4

# Sort by overall R²
sort!(converged, :overall_r2, rev=true)

# Classify into terciles
n_tercile = div(nrow(converged), 3)
converged.fit_category = fill("Medium", nrow(converged))
converged.fit_category[1:n_tercile] .= "Good"
converged.fit_category[(2*n_tercile+1):end] .= "Poor"

# Create summary table by fit category
summary_by_fit = combine(groupby(converged, :fit_category),
    :rmse_skill_premium => mean => :mean_rmse_sp,
    :rmse_labor_share => mean => :mean_rmse_ls,
    :rmse_wage_bill_ratio => mean => :mean_rmse_wbr,
    :rmse_labor_input_ratio => mean => :mean_rmse_li,
    :r2_skill_premium => mean => :mean_r2_sp,
    :r2_labor_share => mean => :mean_r2_ls,
    :r2_wage_bill_ratio => mean => :mean_r2_wbr,
    :r2_labor_input_ratio => mean => :mean_r2_li,
    nrow => :n_industries
)

# Order categories
category_order = ["Good", "Medium", "Poor"]
summary_by_fit = summary_by_fit[sortperm([findfirst(==(x), category_order) for x in summary_by_fit.fit_category]), :]

println("\nSummary by Fit Category:")
println(summary_by_fit)

# Create LaTeX table: Full results by industry
latex_full = """
\\begin{landscape}
\\begin{table}[H]
\\caption{Goodness-of-Fit Statistics by Industry}
\\label{tab:fit_statistics_by_industry}
\\begin{center}
\\tiny
\\begin{tabular}{llcccc|cccc}
\\toprule
& & \\multicolumn{4}{c}{\\textbf{RMSE}} & \\multicolumn{4}{c}{\\textbf{R²}} \\\\
\\cmidrule(lr){3-6} \\cmidrule(lr){7-10}
Category & Industry & SP & LS & WBR & LI & SP & LS & WBR & LI \\\\
\\midrule
"""

for category in category_order
    category_rows = filter(row -> row.fit_category == category, converged)
    
    # Add category header
    global latex_full *= "\\multicolumn{10}{l}{\\textbf{$(category) Fit (N=$(nrow(category_rows)))}} \\\\\n"
    
    # Add rows for this category
    for (i, row) in enumerate(eachrow(category_rows))
        if i <= 5 || i > nrow(category_rows) - 2  # Show first 5 and last 2 of each category
            global latex_full *= @sprintf("%s & %s & %.3f & %.3f & %.3f & %.3f & %.3f & %.3f & %.3f & %.3f \\\\\n",
                category, row.industry_name,
                row.rmse_skill_premium, row.rmse_labor_share, row.rmse_wage_bill_ratio, row.rmse_labor_input_ratio,
                row.r2_skill_premium, row.r2_labor_share, row.r2_wage_bill_ratio, row.r2_labor_input_ratio)
        elseif i == 6
            global latex_full *= "\\multicolumn{10}{c}{[...$(nrow(category_rows)-7) industries omitted...]} \\\\\n"
        end
    end
    
    if category != "Poor"
        global latex_full *= "\\midrule\n"
    end
end

latex_full *= """
\\bottomrule
\\end{tabular}
\\end{center}
\\begin{minipage}{\\textwidth}
\\small
\\textit{Note:} SP = Skill Premium, LS = Labor Share, WBR = Wage Bill Ratio, LI = Labor Input Ratio. 
Industries grouped by overall fit quality (terciles based on average R²). RMSE = Root Mean Squared Error.
\\end{minipage}
\\end{table}
\\end{landscape}
"""

# Create LaTeX table: Summary by category
latex_summary = """
\\begin{table}[H]
\\caption{Summary of Model Fit Quality by Category}
\\label{tab:fit_quality_summary}
\\begin{center}
\\begin{tabular}{lccccc}
\\toprule
Fit Category & N & \\multicolumn{4}{c}{Mean RMSE} \\\\
\\cmidrule(lr){3-6}
& & Skill Prem. & Labor Share & Wage Bill Ratio & Labor Input Ratio \\\\
\\midrule
"""

for row in eachrow(summary_by_fit)
    global latex_summary *= @sprintf("%s & %d & %.3f & %.3f & %.3f & %.3f \\\\\n",
        row.fit_category, row.n_industries,
        row.mean_rmse_sp, row.mean_rmse_ls, row.mean_rmse_wbr, row.mean_rmse_li)
end

latex_summary *= """
\\midrule
\\multicolumn{6}{l}{\\textbf{Mean R² by Category}} \\\\
\\midrule
"""

for row in eachrow(summary_by_fit)
    global latex_summary *= @sprintf("%s & %d & %.3f & %.3f & %.3f & %.3f \\\\\n",
        row.fit_category, row.n_industries,
        row.mean_r2_sp, row.mean_r2_ls, row.mean_r2_wbr, row.mean_r2_li)
end

latex_summary *= """
\\bottomrule
\\end{tabular}
\\end{center}
\\begin{minipage}{\\textwidth}
\\small
\\textit{Note:} Industries classified into terciles based on overall fit quality (average R² across four series). 
Good fit = top tercile, Medium = middle tercile, Poor = bottom tercile. RMSE and R² averaged across industries within each category.
\\end{minipage}
\\end{table}
"""

# Compact table: Top 10 and Bottom 10
latex_compact = """
\\begin{table}[H]
\\caption{Industries with Best and Worst Model Fit}
\\label{tab:best_worst_fit}
\\begin{center}
\\small
\\begin{tabular}{lcc|lcc}
\\toprule
\\multicolumn{3}{c}{\\textbf{Best Fit (Top 10)}} & \\multicolumn{3}{c}{\\textbf{Worst Fit (Bottom 10)}} \\\\
\\cmidrule(lr){1-3} \\cmidrule(lr){4-6}
Industry & Avg R² & Avg RMSE & Industry & Avg R² & Avg RMSE \\\\
\\midrule
"""

top10 = first(converged, min(10, nrow(converged)))
bottom10 = last(converged, min(10, nrow(converged)))

for i in 1:min(10, nrow(top10), nrow(bottom10))
    top = top10[i, :]
    bottom = bottom10[i, :]
    
    global latex_compact *= @sprintf("%s & %.3f & %.3f & %s & %.3f & %.3f \\\\\n",
        top.industry_name, top.overall_r2, top.overall_rmse,
        bottom.industry_name, bottom.overall_r2, bottom.overall_rmse)
end

latex_compact *= """
\\bottomrule
\\end{tabular}
\\end{center}
\\begin{minipage}{\\textwidth}
\\small
\\textit{Note:} Avg R² and Avg RMSE computed as averages across skill premium, labor share, wage bill ratio, and labor input ratio. 
Higher R² indicates better fit; lower RMSE indicates better fit.
\\end{minipage}
\\end{table}
"""

# Save tables
println("\nSaving LaTeX tables...")
open("documents/tables/fit_statistics_by_industry.tex", "w") do f
    write(f, latex_full)
end

open("documents/tables/fit_quality_summary.tex", "w") do f
    write(f, latex_summary)
end

open("documents/tables/best_worst_fit.tex", "w") do f
    write(f, latex_compact)
end

# Save categorized data
CSV.write("data/results/fit_quality_categorized.csv", converged)

println("✓ Tables saved to documents/tables/")
println("  - fit_statistics_by_industry.tex (full table)")
println("  - fit_quality_summary.tex (summary by category)")
println("  - best_worst_fit.tex (top/bottom 10)")
println("✓ Categorized data saved to data/results/fit_quality_categorized.csv")

# Print some interesting patterns
println("\n" * "="^60)
println("KEY FINDINGS")
println("="^60)

println("\nBest Fitting Industries (Top 5):")
for (i, row) in enumerate(eachrow(first(converged, 5)))
    println("  $i. $(row.industry_name): R²=$(round(row.overall_r2, digits=3)), RMSE=$(round(row.overall_rmse, digits=3))")
end

println("\nWorst Fitting Industries (Bottom 5):")
for (i, row) in enumerate(eachrow(last(converged, 5)))
    println("  $i. $(row.industry_name): R²=$(round(row.overall_r2, digits=3)), RMSE=$(round(row.overall_rmse, digits=3))")
end

println("\n✓ Script completed successfully!")
