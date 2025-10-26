#!/usr/bin/env julia
"""
Master script to generate all supplementary tables and analyses
Runs in sequence:
1. Parameter distribution plots
2. Extreme CSC industries table
3. Expanded fit statistics (all industries)
4. Fit quality summary tables
"""

using Dates

println("="^70)
println("MASTER SCRIPT: Generating Supplementary Tables and Figures")
println("Started: $(now())")
println("="^70)

# Get the directory where this script is located
script_dir = @__DIR__

# Script 1: Parameter Distribution Plots
println("\n" * "="^70)
println("STEP 1/4: Creating Parameter Distribution Plots")
println("="^70)
include(joinpath(script_dir, "plot_parameter_distributions.jl"))

# Script 2: Extreme CSC Industries Table
println("\n" * "="^70)
println("STEP 2/4: Creating Extreme CSC Industries Table")
println("="^70)
include(joinpath(script_dir, "create_extreme_csc_table.jl"))

# Script 3: Expand Fit Statistics (computationally intensive)
println("\n" * "="^70)
println("STEP 3/4: Computing Fit Statistics for All Industries")
println("="^70)
println("⚠️  This step may take 5-15 minutes depending on number of industries...")
include(joinpath(script_dir, "expand_fit_statistics.jl"))

# Script 4: Fit Quality Summary Tables
println("\n" * "="^70)
println("STEP 4/4: Creating Fit Quality Summary Tables")
println("="^70)
include(joinpath(script_dir, "create_fit_quality_table.jl"))

# Summary
println("\n" * "="^70)
println("ALL TASKS COMPLETED SUCCESSFULLY!")
println("Finished: $(now())")
println("="^70)

println("\nGenerated Files:")
println("\nFigures (documents/images/):")
println("  ✓ parameter_distributions.pdf")

println("\nTables (documents/tables/):")
println("  ✓ strongest_csc_industries.tex")
println("  ✓ weakest_csc_industries.tex")
println("  ✓ extreme_csc_industries.tex")
println("  ✓ fit_statistics_by_industry.tex")
println("  ✓ fit_quality_summary.tex")
println("  ✓ best_worst_fit.tex")

println("\nData (data/results/):")
println("  ✓ extreme_csc_analysis.csv")
println("  ✓ fit_statistics_all_industries.csv")
println("  ✓ fit_quality_categorized.csv")

println("\nNext Steps:")
println("1. Review generated figures and tables")
println("2. Update manuscript.tex to include these tables/figures")
println("3. Add interpretation paragraphs in Results section")
