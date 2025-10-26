# How to Run Supplementary Analysis Scripts

These scripts generate tables and figures for the manuscript.

## Running from Project Root (Recommended)

```bash
cd /Users/mitchv34/Work/industry_skill_premium

# Run all scripts in sequence
julia scripts/estimation/run_all_supplementary_analyses.jl

# Or run individually:
julia scripts/estimation/plot_parameter_distributions.jl
julia scripts/estimation/create_extreme_csc_table.jl
julia scripts/estimation/expand_fit_statistics.jl
julia scripts/estimation/create_fit_quality_table.jl
```

## Script Descriptions

1. **`plot_parameter_distributions.jl`** (Fast, ~30 seconds)
   - Creates histogram + KDE plots for all parameters
   - Output: `documents/images/parameter_distributions_*.pdf`

2. **`create_extreme_csc_table.jl`** (Fast, ~10 seconds)
   - Creates tables of top/bottom industries by CSC strength
   - Output: `documents/tables/*_csc_industries.tex`

3. **`expand_fit_statistics.jl`** (Slow, ~5-15 minutes)
   - Computes goodness-of-fit for all industries
   - Output: `data/results/fit_statistics_all_industries.csv`

4. **`create_fit_quality_table.jl`** (Fast, ~10 seconds)
   - Groups industries by fit quality
   - Output: `documents/tables/fit_*.tex`

## Dependencies

All scripts should be run from the project root directory where these files exist:
- `data/cross_walk.csv`
- `data/results/ind_est/*.csv`
- `data/proc/ind/*.csv`
- `estimation/estimation.jl`
- `estimation/do_estimation.jl`

## Troubleshooting

**Error: "No such file or directory"**
- Make sure you're in the project root: `/Users/mitchv34/Work/industry_skill_premium`
- Check with: `pwd` (should show the project root)

**Error: "cannot open file"**
- Make sure estimation has been run first
- Check that `data/results/ind_est/` contains CSV files

**KDE Warning**
- This is normal for parameters with few unique values
- The histogram will still be created
