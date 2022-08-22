using Plots
using JLD2
using Term

include("estimation.jl")
include("do_estimation.jl")


using Optim


#  Load Data
ind_code = "44RT"
# # Define parameters and variables of the model
begin
	@parameters α, μ, σ, λ, ρ, δ_e, δ_s
	@variables k_e, k_s, h, ℓ, ψ_L, ψ_H, q, y
end
model = intializeModel();
###  INITIAL PARAMETERS ###
sigma = [-0.5, 0.1, 0.5]
rho = [-0.5, -1.0, 0.5]
eta = [0.01, 0.1 , 0.3]
phi = [2.0, 6.0, 12.0]
lambda = [0.25, 0.5, 0.75]
mu = [0.25, 0.5, 0.75]

param_values = collect.(collect(Iterators.product(sigma, rho, eta, phi, lambda, mu))[:])

alpha_0 = 0.22

for p ∈ param_values[11:end]

	# params_init = InitParams( 
	# 			5.0, # scale_initial
	# 			0.08, # η_ω_0
	# 			[0.1, 0.6, 0.2], # param_0
	# 			[0.4, 0.4, 5.0] # scale_0
	# 			)
	params_init = InitParams( 
				p[4], # scale_initial
				p[3], # η_ω_0
				[alpha_0, p[1], p[2]], # param_0
				[p[5], p[6], p[4]] # scale_0
				)

	sim, ploT = estimate_industry(ind_code, params_init, tol = 0.5);
	try
	# Save Figure
	savefig(ploT, "./data/results/figures/$(ind_code)_$( join( p, "_" ) ).png")
	catch e
		print(@red string(e))
	end
	# Using JDL
	@save "./data/results/vars/$(ind_code)_$( join( p, "_" ) ).jld2" sim ploT	


end



# η_ω = η_ω_0
# param_1 = copy(param_0)
# scale_1 = copy(scale_0)

# # for i = 1:10

# # 	outer_problem(x::Vector) = set_outer_problem(x, vcat(param, scale), data_korv, model, scale_initial)

# # 	sol_η = Optim.optimize(	outer_problem, [η_ω],
# # 	Optim.Options(
# # 	g_tol = 1e-10,
# # 	show_trace = true,
# # 	iterations = 300,
# # 	show_every=20,
# # 	)
# # 	)

# # 	print("η_ω = ", η_ω, " η_ω_next = ", sol_η.minimizer[1], " diff = ", abs(η_ω - sol_η.minimizer[1]))

# # 	η_ω = sol_η.minimizer[1]

# # 	### Set options for estimation
# # 	optim_options = OptimOptions(
# # 		optim_problem_korv, # Function to be optimized
# # 		vcat(param, scale), # Initial parameter values
# # 		NelderMead(), # Optimization method
# # 		1e-2, # Tolerance for convergence
# # 		300, # Maximum number of iterations
# # 		callback # Callback function
# # 	)

# # 	sim = solve_optim_prob(optim_options, scale_initial, η_ω_0)

# # 	param = [sim.x.α, sim.x.σ, sim.x.ρ]
# # 	scale = [sim.x.μ, sim.x.λ, sim.x.φℓ₀]

# # 	@info "Iteration ", i, ": ", param, " ", scale

# # end

# η_ω_vals = 0.001:0.05:1 |> collect


# objs_ =[]
# sims = []

# for i ∈ 1:length(η_ω_vals)

# 	η_ω = η_ω_vals[i]

# 	# optim_problem_korv(x::Vector) = set_optim_problem(x, data_korv, T, η_ω,

# 	sim = solve_optim_prob(data, model, scale_initial, η_ω, vcat(param_0, scale_0),
# 										tol = 0.1; delta=[delta_e, delta_s]);
	
	
# 	@info "Final Params:" sim.x
	
# 	push!(sims, sim)
	
# 	param = [sim.x.α, sim.x.σ, sim.x.ρ]
# 	scale = [sim.x.μ, sim.x.λ, sim.x.φℓ₀]

# 	# outer_problem(x::Vector) = set_outer_problem(x, vcat(param, scale), data_korv, model, scale_initial, off=false)

# 	outer_problem(x::Vector) = set_outer_problem(x, vcat(param, scale), data, model, scale_initial, off=false)

# 	obj = outer_problem([η_ω])

# 	push!(objs_, obj)

# end


# for i in 1:length(sims)
# 	println("i = " , i, " η_ω = ", η_ω_vals[i], " obj = ", objs_[i])
# end

# plot(η_ω_vals, objs_, markerstyle=:x)

# sims[1].x

# begin
# 	i = 1
# 	plot_results(sims[i], data, title="Updated model η_ω =   $(η_ω_vals[i])")
# end


# for i ∈ eachindex(sims)
# 	println("i = " , i, " η_ω = ", η_ω_vals[i], " obj = ", objs_[i])
# end

# sim.x.α = param[1]
# sim.x.σ = param[2]
# sim.x.ρ = param[3]
# sim.x.μ = scale[1]
# sim.x.λ = scale[2]
# sim.x.φℓ₀ = scale[3]
# sim.x.η_ω = η_ω


# plot_results(sim_2, data_korv)