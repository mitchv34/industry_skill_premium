using Plots
using JLD2
using Term

include("estimation.jl")
include("do_estimation.jl")


using Optim

codes = CSV.read("./data/cross_walk.csv", DataFrame).code_klems
# # Define parameters and variables of the model
begin
	@parameters α, μ, σ, λ, ρ, δ_e, δ_s
	@variables k_e, k_s, h, ℓ, ψ_L, ψ_H, q, y
end
model = intializeModel();


mem = true
params_list = []
#  Load Data
for ind_code in codes
	try
		memory = CSV.read("./data/results/$ind_code.csv", DataFrame)[:, [:alpha_0,:sigma_0,:rho_0,:eta_0,:mu_0,:lambda_0,:phi_L_0,:phi_H_0]] 

		println(@bold @blue "$ind_code Done ")
		continue 
		# for row in eachrow(memory)
		# 	push!(params_list, Array(row))
		# end

		# @show mem

	catch 
		println(@bold @red "No data for $ind_code")
		params_list = []
		mem = false
	end

	###  INITIAL PARAMETERS ###
	sigma = [0.5, -0.45]
	rho = [-0.5, 0.45]
	eta = [0.01, 0.04, 0.3]
	phi_L = [4.0]
	phi_H = [6.0]
	lambda = [0.4]
	mu = [0.4]

	param_values = collect.(collect(Iterators.product(sigma, rho, eta, phi_L, phi_H, lambda, mu))[:])
	param_values = [p for p in param_values if p[1] > p[2]]
	n = length(param_values)
	alpha_0 = 0.2

	for i in eachindex(param_values)
		p = param_values[i]

		println(@bold @yellow "Estimating parameters $i of $n for $ind_code")
		p_current = [alpha_0, p[1], p[2], p[3], p[6], p[7], p[4], p[5]]
		# println(@bold "\t $p")
		# @show p_current
		# @show params_list
		# @show p_current ∈ params_list
		# @show mem
		if mem
			p_current = [alpha_0, p[1], p[2], p[3], p[6], p[7], p[4], p[5]]
			if p_current ∈ params_list
				println(@bold @blue "$p_current Already done")
				continue
			end
		end
		# params_init = InitParams( 
		# 			5.0, # scale_initial
		# 			0.08, # η_ω_0
		# 			[0.1, 0.6, 0.2], # param_0
		# 			[0.4, 0.4, 5.0] # scale_0
		# 			)
		params_init = InitParams( 
					p[5], # scale_initial
					p[3], # η_ω_0
					[alpha_0, p[1], p[2]], # param_0
					[p[6], p[7], p[4]] # scale_0
					)

		sim, ploT = estimate_industry(ind_code, params_init, tol = 0.01);
		try
		# Save Figure
		savefig(ploT, "./data/results/figures/$(ind_code)_$( join( p, "_" ) ).png")
		catch e
			print(@red @bold string(e))
		end
		# Using JDL
		@save "./data/results/vars/$(ind_code)_$( join( p, "_" ) ).jld2" sim ploT	


	end
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