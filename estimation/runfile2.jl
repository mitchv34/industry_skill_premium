###################### MAIN ##############################
using Term
using GLM
using PrettyTables

# using Term.Progress
# install_term_logger()

include("estimation.jl")
include("do_estimation.jl")

#  Define parameters and variables of the model
begin
	@parameters α, μ, σ, λ, ρ, δ_e, δ_s
	@variables k_e, k_s, h, ℓ, ψ_L, ψ_H, q, y
end

model = intializeModel();



inds = CSV.read("./data/cross_walk.csv", DataFrame)
codes = inds.code_klems
names = inds.ind_desc


i = 54
names[i]
codes[i]
begin
	ind_proc = readdir("data/results/ind_est")
	ind_code = codes[i]
	ind_name = names[i]

	proc = true
	if ind_code * ".csv" in ind_proc 
		println(@bold @blue "Already done $ind_code press Y to procees again:")
		s = readline()
		if (s == "Y") || ( s == "y" )
			proc = true
		else
			proc = false
		end
	end

if proc

path_data = "./data/proc/ind/$(ind_code).csv";

dataframe = CSV.read(path_data, DataFrame);

data = generateData(dataframe);
delta_e = mean(dataframe.DPR_EQ)
delta_s = mean(dataframe.DPR_ST)

### Set initial parameter values
scale_initial = 20.0
η_ω_0 = 0.002
param_0 = [0.11, .5,.5] 

scale_0 = [0.4, 0.4, scale_initial]
sim = solve_optim_prob(data, model, scale_initial, η_ω_0, vcat(param_0, scale_0),  tol = 0.1, delta=[delta_e, delta_s])
p_ = plot_results(sim, data, years = collect(1988:2018) , scale_font = 1.0)

df_param = DataFrame(
	[	
		:ind_name => ind_name,
		:ind_code => ind_code,
		:alpha => [sim.x.α],
		:mu => [sim.x.μ],
		:sigma => [sim.x.σ],
		:lambda => [sim.x.λ],
		:rho => [sim.x.ρ],
		:eta => [sim.x.η_ω],
		:phi_L => [sim.x.φℓ₀],
		:phi_H => [sim.x.φh₀],
	]
)


CSV.write("./data/results/ind_est/$(ind_code).csv", df_param)


plot(p_[1], p_[2], p_[3], p_[4])

end
end