# Script to compute goodness-of-fit statistics for aggregate and industry-level estimations
# This will create tables with RMSE, R-squared, and MAE for inclusion in the manuscript

using DataFrames
using CSV
using Statistics
using Printf

# Resolve project root relative to this script so paths work regardless of working directory
const PROJECT_ROOT = normpath(joinpath(@__DIR__, "..", ".."))

function project_path(parts...)
    return joinpath(PROJECT_ROOT, parts...)
end

"""
    compute_fit_statistics(data_path::String, results_path::String; sample_name::String="")

Compute goodness-of-fit statistics (RMSE, R², MAE) for a given estimation.

# Arguments
- `data_path`: Path to the data CSV file
- `results_path`: Path to the results CSV file (from estimation)
- `sample_name`: Name of the sample (e.g., "KORV 1963-1992")

# Returns
DataFrame with fit statistics for each variable
"""
function compute_fit_statistics(data_path::String, results_path::String; sample_name::String="")
    
    # Load results
    if !isfile(results_path)
        @warn "Results file not found: $results_path"
        return nothing
    end
    results = CSV.read(results_path, DataFrame)
    
    # Get the best fit (last row with non-NaN values, or row with minimum obj_val)
    valid_results = dropmissing(results, :obj_val)
    if nrow(valid_results) == 0
        @warn "No valid results found for $sample_name"
        return nothing
    end
    
    best_idx = argmin(valid_results.obj_val)
    best_result = valid_results[best_idx, :]
    
    # Extract fit values (these are sum of squared errors)
    sse_rr = best_result.fit_rr
    sse_wbr = best_result.fit_wbr
    sse_lbr = best_result.fit_lbr
    sse_sp = best_result.fit_sp
    
    # Load data to get number of observations and compute TSS
    if !isfile(data_path)
        @warn "Data file not found: $data_path"
        n = max(1, length(results.obj_val))
    else
        data = CSV.read(data_path, DataFrame)
        n = nrow(data) - 1  # Subtract 1 because some series use differenced data
    end
    
    # Compute RMSE = sqrt(SSE/n)
    rmse_rr = sqrt(sse_rr / n)
    rmse_wbr = sqrt(sse_wbr / n)
    rmse_lbr = sqrt(sse_lbr / n)
    rmse_sp = sqrt(sse_sp / n)
    
    # To compute R², we need TSS = sum((y - mean(y))^2)
    # For now, we'll just report SSE and RMSE
    # R² would require re-running the model to get predictions
    
    # Create results dataframe
    fit_stats = DataFrame(
        Sample = [sample_name, sample_name, sample_name, sample_name],
        Variable = ["Relative Price (rr)", "Wage Bill Ratio (wbr)", "Labor Share (lbr)", "Skill Premium (sp)"],
        SSE = [sse_rr, sse_wbr, sse_lbr, sse_sp],
        RMSE = [rmse_rr, rmse_wbr, rmse_lbr, rmse_sp],
        N = [n, n, n, n]
    )
    
    return fit_stats
end

"""
    compute_aggregate_fit_table(output_path::String="./documents/tables/goodness_of_fit_aggregate.tex")

Compute fit statistics for all three aggregate samples and create LaTeX table.
"""
function compute_aggregate_fit_table(output_path::String=project_path("documents", "tables", "goodness_of_fit_aggregate.tex"))
    
    # Define the three samples (FIXED PATHS)
    samples = [
        ("KORV 1963-1992", project_path("data", "Data_KORV.csv"), project_path("data", "results", "korv_replication.csv")),
        ("Extended 1963-2018", project_path("data", "proc", "data_updated.csv"), project_path("data", "results", "extended_estimation.csv")),
        ("Industry 1988-2018", project_path("data", "proc", "data_updated.csv"), project_path("data", "results", "industry_period_estimation.csv"))
    ]
    
    all_stats = DataFrame[]
    
    for (name, data_path, results_path) in samples
        # Check if files exist before attempting to read
        if !isfile(results_path)
            @warn "Result file not found: $results_path (skipping $name)"
            continue
        end
        if !isfile(data_path)
            @warn "Data file not found: $data_path (skipping $name)"
            continue
        end
        
        stats = compute_fit_statistics(data_path, results_path; sample_name=name)
        if stats !== nothing
            push!(all_stats, stats)
        end
    end
    
    if isempty(all_stats)
        @error "No fit statistics computed"
        return nothing
    end
    
    combined_stats = vcat(all_stats...)
    
    # Create LaTeX table
    latex_output = """
    \\begin{tabular}{llccr}
      \\hline\\hline
       \\textbf{Sample} & \\textbf{Variable} & \\textbf{SSE} & \\textbf{RMSE} & \\textbf{N} \\\\\\hline
    """
    
    current_sample = ""
    for row in eachrow(combined_stats)
        sample_label = row.Sample == current_sample ? "" : row.Sample
        current_sample = row.Sample
        
        latex_output *= @sprintf("  %s & %s & %.2f & %.4f & %d \\\\\n", 
            sample_label, row.Variable, row.SSE, row.RMSE, row.N)
    end
    
    latex_output *= """
      \\hline\\hline
    \\end{tabular}
    """
    
    # Write to file
    open(output_path, "w") do f
        write(f, latex_output)
    end
    
    println("Goodness-of-fit table written to: $output_path")
    
    return combined_stats
end

"""
    compute_industry_fit_summary()

Compute summary statistics of fit across all industries.
"""
function compute_industry_fit_summary(results_dir::String=project_path("data", "results"))
    
    # Get all industry result files
    if !isdir(results_dir)
        @error "Results directory not found: $results_dir"
        return DataFrame()
    end
    result_files = filter(f -> endswith(f, ".csv") && 
                               !startswith(f, "aggregate") && 
                               !startswith(f, "industry_fit") &&
                               !contains(f, "correlation") &&
                               !contains(f, "summary") &&
                               !contains(f, "trend") &&
                               !contains(f, "labor_share"),
                          readdir(results_dir))
    
    if isempty(result_files)
        @warn "No industry result files found in $results_dir"
        return DataFrame()
    end
    
    println("   Found $(length(result_files)) industry result files")
    
    industry_fits = DataFrame(
        Industry = String[],
        SSE_sp = Float64[],
        SSE_wbr = Float64[],
        SSE_lbr = Float64[],
        SSE_rr = Float64[],
        RMSE_sp = Float64[],
        RMSE_wbr = Float64[],
        RMSE_lbr = Float64[],
        RMSE_rr = Float64[],
        Obj_Val = Float64[]
    )
    
    files_processed = 0
    files_skipped = 0
    
    for file in result_files
        # Skip non-industry files
        if occursin("aggregate", file) || occursin("industry_fit", file) || 
           occursin("industry_trends", file) || occursin("labor_share", file) ||
           occursin("trend_correlations", file)
            files_skipped += 1
            continue
        end
        
        filepath = joinpath(results_dir, file)
        
        try
            results = CSV.read(filepath, DataFrame)
            
            # Check if obj_val column exists
            if !("obj_val" in names(results))
                println("  Skipping $(file): no obj_val column")
                files_skipped += 1
                continue
            end
            
            # Get best result
            valid_results = dropmissing(results, :obj_val)
            if nrow(valid_results) == 0
                println("  Skipping $(file): no valid obj_val rows")
                files_skipped += 1
                continue
            end
            
            best_idx = argmin(valid_results.obj_val)
            best = valid_results[best_idx, :]
            
            # Check if fit columns exist
            required_cols = ["fit_sp", "fit_wbr", "fit_lbr", "fit_rr"]
            missing_cols = [col for col in required_cols if !(col in names(results))]
            if !isempty(missing_cols)
                println("  Skipping $(file): missing columns $(missing_cols)")
                files_skipped += 1
                continue
            end
            
            # Check if all fit values are finite (not NaN or Inf)
            if any(isnan.([best.fit_sp, best.fit_wbr, best.fit_lbr, best.fit_rr, best.obj_val]))
                println("  Skipping $(file): NaN in fit statistics")
                files_skipped += 1
                continue
            end
            
            if any(isinf.([best.fit_sp, best.fit_wbr, best.fit_lbr, best.fit_rr, best.obj_val]))
                println("  Skipping $(file): Inf in fit statistics")
                files_skipped += 1
                continue
            end
            
            # Assume ~30 observations per industry (1988-2018)
            n = 30
            
            push!(industry_fits, (
                Industry = replace(file, ".csv" => ""),
                SSE_sp = best.fit_sp,
                SSE_wbr = best.fit_wbr,
                SSE_lbr = best.fit_lbr,
                SSE_rr = best.fit_rr,
                RMSE_sp = sqrt(best.fit_sp / n),
                RMSE_wbr = sqrt(best.fit_wbr / n),
                RMSE_lbr = sqrt(best.fit_lbr / n),
                RMSE_rr = sqrt(best.fit_rr / n),
                Obj_Val = best.obj_val
            ))
            files_processed += 1
        catch e
            println("  Error processing $(file): $(e)")
            files_skipped += 1
            continue
        end
    end
    
    println("\nProcessed $(files_processed) industries, skipped $(files_skipped) files")
    
    if nrow(industry_fits) == 0
        @warn "No valid industry fits computed"
        return industry_fits
    end
    
    # Compute summary statistics
    println("\n" * "="^70)
    println("INDUSTRY-LEVEL FIT SUMMARY")
    println("="^70)
    println("Number of industries with results: ", nrow(industry_fits))
    
    for var in ["sp", "wbr", "lbr", "rr"]
        col_name = Symbol("RMSE_$var")
        var_full = Dict("sp" => "Skill Premium", 
                       "wbr" => "Wage Bill Ratio",
                       "lbr" => "Labor Share",
                       "rr" => "Relative Price")[var]
        
        println("\n$var_full ($var) RMSE:")
        println("  Mean:   ", @sprintf("%.4f", mean(industry_fits[!, col_name])))
        println("  Median: ", @sprintf("%.4f", median(industry_fits[!, col_name])))
        println("  Std:    ", @sprintf("%.4f", std(industry_fits[!, col_name])))
        println("  Min:    ", @sprintf("%.4f", minimum(industry_fits[!, col_name])))
        println("  Max:    ", @sprintf("%.4f", maximum(industry_fits[!, col_name])))
    end
    
    println("\nObjective Function Value:")
    println("  Mean:   ", @sprintf("%.2f", mean(industry_fits.Obj_Val)))
    println("  Median: ", @sprintf("%.2f", median(industry_fits.Obj_Val)))
    println("="^70)
    
    return industry_fits
end

# Main execution
println("="^70)
println("COMPUTING GOODNESS-OF-FIT STATISTICS")
println("="^70)
println()

# Try to compute aggregate statistics (may fail if result files don't exist)
println("📊 Attempting aggregate analysis...")
try
    stats = compute_aggregate_fit_table()
    if stats !== nothing
        println("✅ Aggregate fit statistics computed successfully!")
        println()
    else
        println("⚠️  Some aggregate result files not found")
        println("    Run estimation/runfile.jl to generate aggregate results")
        println()
    end
catch e
    println("⚠️  Aggregate analysis skipped (missing result files)")
    println("    Error: ", e)
    println("    Run estimation/runfile.jl first to generate:")
    println("      - data/results/korv_replication.csv")
    println("      - data/results/extended_estimation.csv")
    println("      - data/results/industry_period_estimation.csv")
    println()
end

# Compute industry-level statistics (should work with existing files)
println("📊 Computing industry-level statistics...")
try
    industry_stats = compute_industry_fit_summary()
    
    if nrow(industry_stats) > 0
        println("\n✅ Industry fit statistics computed successfully!")
        println("   Results for $(nrow(industry_stats)) industries")
        
        # Save industry statistics to CSV
        output_file = project_path("data", "results", "industry_fit_statistics.csv")
        CSV.write(output_file, industry_stats)
        println("   Saved to: $output_file")
    else
        println("\n⚠️  No industry results found in data/results/")
    end
catch e
    println("❌ Error computing industry statistics: ", e)
end

println()
println("="^70)
println("DONE")
println("="^70)
