using CSV
using DataFrames
using Plots
using Statistics
using StatsPlots
using RegressionTables

results_path = "./data/results/ind_est/"

files = [f[1:end-4] for f in readdir(results_path)]

results = DataFrame()
for f in files
    df = CSV.read(results_path * f * ".csv", DataFrame)
    results = vcat(results, df)
end

rename!(results, :ind_code => :IND)
results.IND = string.(results.IND)

describe(results, cols = [:alpha, :sigma, :rho, :eta],
        mean => :mean, std => :std)




reg_summary = innerjoin(results, reg_summary, on = :IND)

reg_summary.Group .= ""
reg_summary.Group[reg_summary.sigma .> reg_summary.rho] .= "A"
reg_summary.Group[reg_summary.sigma .<= reg_summary.rho] .= "B"

reg_summary.CSC = reg_summary.sigma - reg_summary.rho

sub_reg_summary = filter(:CSC => x -> x > -3, reg_summary)



scatter(sub_reg_summary.CSC, sub_reg_summary.SP, smooth = true)
@df sub_reg_summary scatter(:CSC, :LI, smooth = true )
@df sub_reg_summary scatter(:CSC, :KR, smooth = true )


p1, reg_1 = plot_correlations(sub_reg_summary, [:CSC, :SP],  title = "1988 - 2018", xlabel = "(slope) Skill Premium", ylabel   = L"\sigma - \rho", level = 0.)

p2, reg_2 = plot_correlations(sub_reg_summary, [:CSC, :LI],  title = "1988 - 2018", xlabel = "(slope) Labor Input Ratio", ylabel   = L"\sigma - \rho", level = 0.)

savefig(p1, "./documents/images/corr_sp_sigma_rho.png")
savefig(p2, "./documents/images/corr_li_sigma_rho.png")

@df reg_summary scatter( :LI, :SP, smooth = false, group =:Group,
alpha = 0.5, xlabel = "xlabel", ylabel = "ylabel", title = "title", label = "",
    markerstrokealpha = 1.0, markerstrokewidth=3,  markersize = 6.5, framestyle = :zerolines)


rename!( results, :ind_code => :ind)

results.ind =  string.(results.ind)

results = innerjoin(dd, results, on =:ind)

sort(results, :sigma)

@df results scatter( :rho, :sigma)
# ylims!(-1, 1.5)
        

        
        
        
        
        
        
        

        
        
include("./estimation/estimation.jl")
include("./estimation/do_estimation.jl")

#  Define parameters and variables of the model
begin
    @parameters α, μ, σ, λ, ρ, δ_e, δ_s
    @variables k_e, k_s, h, ℓ, ψ_L, ψ_H, q, y
end

model = intializeModel();

inds = CSV.read("./data/cross_walk.csv", DataFrame)
codes = inds.code_klems
names = inds.ind_desc



code_retail = "44RT"
code_legal = 5411
educ_code = 61


begin

    init_params = results[results.ind_code .== code_legal, :]
    ind_proc = readdir("data/results/ind_est")
    ind_code = code_legal
    # ind_name = names[i]
    # @show ind_code ind_name 
    # proc = true
    # if ind_code * ".csv" in ind_proc 
    #     println(@bold @blue "Already done $ind_code press Y to procees again:")
    #     s = readline()
    #     if (s == "Y") || ( s == "y" )
    #         proc = true
    #     else
    #         proc = false
    #     end
    # end

# if proc

path_data = "./data/proc/ind/$(ind_code).csv";

dataframe = CSV.read(path_data, DataFrame);

data = generateData(dataframe);
delta_e = mean(dataframe.DPR_EQ)
delta_s = mean(dataframe.DPR_ST)

### Set initial parameter values
scale_initial = 0.001
η_ω_0 = 0.083
param_0 = [init_params.alpha[1], init_params.sigma[1], init_params.rho[1]]

scale_0 = [init_params.lambda[1], init_params.mu[1], scale_initial]

sim = solve_optim_prob(data, model, scale_initial, η_ω_0, vcat(param_0, scale_0),  tol = 0.001, delta=[delta_e, delta_s])
p_legal, m_legal, d_legal  = plot_results(sim, data, years = collect(1988:2018) , scale_font = 1.0, return_data = true);

end

p_legal[2]

sim.x
plot((m_retail[:ω] .- m_retail[:ω][1]) / m_retail[:ω][1])   
plot!((m_legal[:ω] .- m_legal[:ω][1]) / m_legal[:ω][1])
plot!((m_educ[:ω] .- m_educ[:ω][1]) / m_educ[:ω][1])