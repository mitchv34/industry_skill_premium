###################### Parameter Distribution Plots ##############################
# This script creates distribution plots (histograms with kernel density overlays)
# for all estimated parameters across industries
##############################################################################

using CSV
using DataFrames
using Plots
using StatsPlots
using Statistics
using KernelDensity
using LaTeXStrings

# Read industry cross-walk
inds = CSV.read("./data/cross_walk.csv", DataFrame)
codes = inds.code_klems
names = inds.ind_desc

println("Loading parameter estimates from all industries...")

# Initialize vectors to store parameters
α_values = Float64[]
σ_values = Float64[]
ρ_values = Float64[]
μ_values = Float64[]
λ_values = Float64[]
η_values = Float64[]
φ_L_values = Float64[]
φ_H_values = Float64[]
σ_s_values = Float64[]  # Elasticity: equipment-skilled
σ_u_values = Float64[]  # Elasticity: equipment-unskilled
σ_ρ_diff = Float64[]    # CSC strength: σ - ρ

successful_inds = String[]

# Load all parameter estimates
for i in 1:length(codes)
    ind_code = codes[i]
    ind_name = names[i]
    
    try
        params = CSV.read("./data/results/ind_est/$(ind_code).csv", DataFrame)
        
        push!(α_values, params.alpha[1])
        push!(σ_values, params.sigma[1])
        push!(ρ_values, params.rho[1])
        push!(μ_values, params.mu[1])
        push!(λ_values, params.lambda[1])
        push!(η_values, params.eta[1])
        push!(φ_L_values, params.phi_L[1])
        push!(φ_H_values, params.phi_H[1])
        
        # Calculate implied elasticities
        σ_s = 1.0 / (1.0 - params.rho[1])
        σ_u = 1.0 / (1.0 - params.sigma[1])
        push!(σ_s_values, σ_s)
        push!(σ_u_values, σ_u)
        
        # CSC strength
        push!(σ_ρ_diff, params.sigma[1] - params.rho[1])
        
        push!(successful_inds, ind_name)
    catch e
        println("Skipping industry $(ind_code) - $(ind_name): $(e)")
        continue
    end
end

println("Successfully loaded $(length(α_values)) industry parameter estimates")
println("Mean α: $(round(mean(α_values), digits=3)), Std: $(round(std(α_values), digits=3))")
println("Mean σ: $(round(mean(σ_values), digits=3)), Std: $(round(std(σ_values), digits=3))")
println("Mean ρ: $(round(mean(ρ_values), digits=3)), Std: $(round(std(ρ_values), digits=3))")
println("Mean σ-ρ: $(round(mean(σ_ρ_diff), digits=3)), Std: $(round(std(σ_ρ_diff), digits=3))")

# Set plot defaults for publication quality
default(fontfamily="Computer Modern", framestyle=:box)
Plots.scalefontsizes(1.2)

# Function to create histogram with KDE overlay
function plot_param_distribution(values, param_name, xlabel_text; 
                                  bins=:auto, xlim=nothing, color=:steelblue)
    
    # Calculate statistics
    μ = mean(values)
    σ = std(values)
    med = median(values)
    
    # Create histogram with appropriate size and margins
    p = histogram(values, 
                  bins=bins,
                  normalize=:pdf,
                  alpha=0.6,
                  color=color,
                  label="",
                  xlabel=xlabel_text,
                  ylabel="Density",
                  title=param_name,
                  legend=:topright,
                  titlefontsize=10,
                  legendfontsize=8,
                  guidefontsize=9)
    
    # Add kernel density estimate
    try
        kde_result = kde(values)
        plot!(p, kde_result.x, kde_result.density, 
              linewidth=3, 
              color=:darkred, 
              label="Kernel Density",
              linestyle=:solid)
    catch e
        println("Warning: Could not compute KDE for $(param_name)")
    end
    
    # Add vertical lines for mean and median
    vline!(p, [μ], linewidth=2, linestyle=:dash, color=:black, 
           label="Mean: $(round(μ, digits=2))")
    vline!(p, [med], linewidth=2, linestyle=:dot, color=:darkgreen, 
           label="Median: $(round(med, digits=2))")
    
    # Add text annotation with statistics - position in top-left to avoid legend overlap
    y_pos = ylims(p)[2] * 0.95
    x_pos = xlim !== nothing ? xlim[1] + (xlim[2] - xlim[1]) * 0.05 : xlims(p)[1] + (xlims(p)[2] - xlims(p)[1]) * 0.05
    annotate!(p, x_pos, y_pos,
              text("N = $(length(values))\nStd = $(round(σ, digits=2))", 
                   :left, 9, :top))
    
    if xlim !== nothing
        xlims!(p, xlim)
    end
    
    return p
end

println("\nGenerating distribution plots...")

# 1. Substitution parameters (most important)
p1 = plot_param_distribution(σ_values, "Equipment-Unskilled Substitution", 
                            "σ (elasticity parameter)", 
                            xlim=(-4, 1.5), bins=15, color=:steelblue)
plot!(p1, legend=:topleft)

p2 = plot_param_distribution(ρ_values, "Equipment-Skilled Substitution", 
                              "ρ (elasticity parameter)", 
                              xlim=(-2.5, 1.5), bins=15, color=:coral)

p3 = plot_param_distribution(σ_ρ_diff, "Capital-Skill Complementarity Strength", 
                              "σ - ρ (CSC measure)", 
                              xlim=(-2, 2), bins=15, color=:mediumseagreen)

p4 = plot_param_distribution(α_values, "Capital Structures Share", 
                              "α (structures parameter)", 
                              xlim=(0, 0.6), bins=15, color=:orchid)

# Combine main parameters
p_main = plot(p1, p2, p3, p4, layout=(2,2), size=(1400, 1000), 
              left_margin=5Plots.mm, bottom_margin=5Plots.mm, 
              top_margin=3Plots.mm, right_margin=3Plots.mm)
savefig(p_main, "./documents/images/parameter_distributions_main.pdf")
println("Saved: parameter_distributions_main.pdf")

# 2. Implied elasticities
# Note: Filter extreme values for visualization (ρ very close to 1 causes σ_s → ∞)
σ_s_filtered = filter(x -> abs(x) < 50, σ_s_values)
σ_u_filtered = filter(x -> abs(x) < 50, σ_u_values)
n_extreme_s = length(σ_s_values) - length(σ_s_filtered)
n_extreme_u = length(σ_u_values) - length(σ_u_filtered)

p5 = plot_param_distribution(σ_s_filtered, "Elasticity: Equipment-Skilled", 
                              L"\sigma_s = 1/(1-\rho)", 
                              xlim=(-10, 50), bins=20, color=:dodgerblue)
if n_extreme_s > 0
    annotate!(p5, 25, ylims(p5)[2] * 0.7, 
              text("($(n_extreme_s) extreme values\n|σₛ| > 50 excluded)", :center, 8))
end

p6 = plot_param_distribution(σ_u_filtered, "Elasticity: Equipment-Unskilled", 
                              L"\sigma_u = 1/(1-\sigma)", 
                              xlim=(-10, 50), bins=20, color=:indianred)
if n_extreme_u > 0
    annotate!(p6, 25, ylims(p6)[2] * 0.7,
              text("($(n_extreme_u) extreme values\n|σᵤ| > 50 excluded)", :center, 8))
end

# Combine elasticities
p_elast = plot(p5, p6, layout=(1,2), size=(1400, 500),
               left_margin=5Plots.mm, bottom_margin=5Plots.mm)
savefig(p_elast, "./documents/images/parameter_distributions_elasticities.pdf")
println("Saved: parameter_distributions_elasticities.pdf")

# 3. Share parameters
p7 = plot_param_distribution(μ_values, "Unskilled Labor Share", 
                              "μ", 
                              xlim=(0, 1), bins=12, color=:lightseagreen)

p8 = plot_param_distribution(λ_values, "Equipment Share", 
                              "λ", 
                              xlim=(0, 1), bins=12, color=:goldenrod)

p_shares = plot(p7, p8, layout=(1,2), size=(1400, 500),
                left_margin=5Plots.mm, bottom_margin=5Plots.mm)
savefig(p_shares, "./documents/images/parameter_distributions_shares.pdf")
println("Saved: parameter_distributions_shares.pdf")

# 4. Efficiency parameters
p9 = plot_param_distribution(η_values, "Shock Variance", 
                              "η_ω", 
                              bins=12, color=:slateblue)

p10 = plot_param_distribution(φ_L_values, "Unskilled Efficiency Scale", 
                               "φ_L", 
                               bins=12, color=:salmon)

p11 = plot_param_distribution(φ_H_values, "Skilled Efficiency Scale", 
                               "φ_H", 
                               bins=12, color=:turquoise)

p_efficiency = plot(p9, p10, p11, layout=(1,3), size=(1800, 500),
                    left_margin=5Plots.mm, bottom_margin=5Plots.mm)
savefig(p_efficiency, "./documents/images/parameter_distributions_efficiency.pdf")
println("Saved: parameter_distributions_efficiency.pdf")

# 5. Create a comprehensive 6-panel figure for the main paper
println("\nCreating comprehensive figure for manuscript...")

# Select the 6 most important parameters
p_comp1 = plot_param_distribution(σ_values, "A. Equipment-Unskilled (σ)", 
                                   "σ parameter", 
                                   xlim=(-4, 1.5), bins=15, color=:steelblue)

p_comp2 = plot_param_distribution(ρ_values, "B. Equipment-Skilled (ρ)", 
                                   "ρ parameter", 
                                   xlim=(-2.5, 1.5), bins=15, color=:coral)

p_comp3 = plot_param_distribution(σ_ρ_diff, "C. CSC Strength (σ - ρ)", 
                                   "σ - ρ", 
                                   xlim=(-2, 2), bins=15, color=:mediumseagreen)

p_comp4 = plot_param_distribution(α_values, "D. Structures Share (α)", 
                                   "α", 
                                   xlim=(0, 0.6), bins=15, color=:orchid)

p_comp5 = plot_param_distribution(σ_s_filtered, L"E. Elasticity $\sigma_s$", 
                                   L"\sigma_s = 1/(1-\rho)", 
                                   xlim=(-10, 50), bins=20, color=:dodgerblue)
if n_extreme_s > 0
    annotate!(p_comp5, 20, ylims(p_comp5)[2] * 0.6, 
              text("($(n_extreme_s) extreme\nvalues excluded)", :center, 7))
end

p_comp6 = plot_param_distribution(σ_u_filtered, L"F. Elasticity $\sigma_u$", 
                                   L"\sigma_u = 1/(1-\sigma)", 
                                   xlim=(-10, 50), bins=20, color=:indianred)
if n_extreme_u > 0
    annotate!(p_comp6, 20, ylims(p_comp6)[2] * 0.6,
              text("($(n_extreme_u) extreme\nvalues excluded)", :center, 7))
end

p_comprehensive = plot(p_comp1, p_comp2, p_comp3, p_comp4, p_comp5, p_comp6, 
                       layout=(3,2), size=(1400, 1600),
                       left_margin=5Plots.mm, bottom_margin=5Plots.mm,
                       top_margin=5Plots.mm, right_margin=3Plots.mm)
savefig(p_comprehensive, "./documents/images/parameter_distributions_comprehensive.pdf")
println("Saved: parameter_distributions_comprehensive.pdf")

# 7. Summary statistics table
println("\n" * "="^80)
println("PARAMETER DISTRIBUTION SUMMARY STATISTICS")
println("="^80)

summary_stats = DataFrame(
    Parameter = ["α (structures)", "σ (equip-unskilled)", "ρ (equip-skilled)", 
                 "σ - ρ (CSC)", "σₛ (elasticity)", "σᵤ (elasticity)",
                 "μ (unskilled share)", "λ (equipment share)", "η_ω (shock var)"],
    Mean = [mean(α_values), mean(σ_values), mean(ρ_values), mean(σ_ρ_diff),
            mean(σ_s_values), mean(σ_u_values), mean(μ_values), 
            mean(λ_values), mean(η_values)],
    Median = [median(α_values), median(σ_values), median(ρ_values), median(σ_ρ_diff),
              median(σ_s_values), median(σ_u_values), median(μ_values), 
              median(λ_values), median(η_values)],
    Std = [std(α_values), std(σ_values), std(ρ_values), std(σ_ρ_diff),
           std(σ_s_values), std(σ_u_values), std(μ_values), 
           std(λ_values), std(η_values)],
    Min = [minimum(α_values), minimum(σ_values), minimum(ρ_values), minimum(σ_ρ_diff),
           minimum(σ_s_values), minimum(σ_u_values), minimum(μ_values), 
           minimum(λ_values), minimum(η_values)],
    Max = [maximum(α_values), maximum(σ_values), maximum(ρ_values), maximum(σ_ρ_diff),
           maximum(σ_s_values), maximum(σ_u_values), maximum(μ_values), 
           maximum(λ_values), maximum(η_values)]
)

# Round for display
for col in [:Mean, :Median, :Std, :Min, :Max]
    summary_stats[!, col] = round.(summary_stats[!, col], digits=3)
end

println(summary_stats)

# Save summary statistics to CSV
CSV.write("./data/results/parameter_distribution_summary.csv", summary_stats)
println("\nSaved summary statistics to: parameter_distribution_summary.csv")

println("\n" * "="^80)
println("Distribution plots completed successfully!")
println("Files created:")
println("  - parameter_distributions_main.pdf")
println("  - parameter_distributions_elasticities.pdf")
println("  - parameter_distributions_shares.pdf")
println("  - parameter_distributions_efficiency.pdf")
println("  - parameter_distributions_comprehensive.pdf (FOR MANUSCRIPT)")
println("="^80)
