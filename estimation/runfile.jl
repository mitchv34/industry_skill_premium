###################### MAIN ##############################
using Term
using GLM
# using Term.Progress
# install_term_logger()

include("estimation.jl")
include("do_estimation.jl")

#  Define parameters and variables of the model
begin
	@parameters α, μ, σ, λ, ρ, δ_e, δ_s
	@variables k_e, k_s, h, ℓ, ψ_L, ψ_H, q, y
end


#  Load Data
path_data_korv = "./extend_KORV/data/Data_KORV.csv";
path_updated_labor = "./extend_KORV/data/proc/labor_totl.csv";
path_updated_capital = "./extend_KORV/data/proc/capital_totl.csv";

dataframe_korv = CSV.read(path_data_korv, DataFrame);
updated_labor = CSV.read(path_updated_labor, DataFrame);
updated_capital = CSV.read(path_updated_capital, DataFrame);

dataframe_updated = innerjoin(updated_capital, updated_labor, on = :YEAR)
dataframe_updated.REL_P_EQ = dataframe_updated.REL_P_EQ / dataframe_updated.REL_P_EQ[1];

data_korv = generateData(dataframe_korv);
data_updated = generateData(dataframe_updated[1:end, :]);
model = intializeModel();

## Instrument L_S and L_U ######
data_for_reg_updated = DataFrame(
	[
		:L_S => dataframe_updated.L_S[2:end],
		:L_U => dataframe_updated.L_U[2:end],
		:trend => 1:length(dataframe_updated.L_S[2:end]),
		:K_EQ => dataframe_updated.K_EQ[2:end],
		:K_STR => dataframe_updated.K_STR[2:end],
		:K_EQ_lagged => dataframe_updated.K_EQ[1:end-1],
		:K_STR_lagged => dataframe_updated.K_STR[1:end-1],
		:Q_lagged => dataframe_updated.REL_P_EQ[1:end-1],
	]
)


## Run regression  first stage for L_S and L_U ######
formula_S = @formula( L_S ~ trend + K_EQ + K_STR + K_EQ_lagged + K_STR_lagged + Q_lagged)
formula_U = @formula( L_U ~ trend + K_EQ + K_STR + K_EQ_lagged + K_STR_lagged + Q_lagged)
reg_S = lm(formula_S,  data_for_reg_updated)
reg_U = lm(formula_U,  data_for_reg_updated)
L_S_hat = predict(reg_S, data_for_reg_updated)
L_U_hat = predict(reg_U, data_for_reg_updated)

# Todo: add original labor series to data structure
data_updated.h = vcat([0], L_S_hat)
data_updated.ℓ = vcat([0], L_U_hat)

# plot(data_for_reg_updated.L_S, label = "L_S", legend=:top)
# plot!(L_S_hat, label = "L_S_hat")

# plot(data_for_reg_updated.L_U, label = "L_U", legend=:top)
# plot!(L_U_hat, label = "L_U_hat")

## Estimate model with data from KORV
### Set initial parameter values
# T = length(data_korv.y);
T = length(data_updated.y);
scale_initial = 5.0
η_ω_0 = 0.065
param_0 = [0.1, 0.35, -0.4] 
scale_0 = [0.4, 0.4, scale_initial]
### Set optimization problem
optim_problem_korv(x::Vector) = set_optim_problem(x, data_korv, T, η_ω_0, model, scale_initial)
optim_problem_updated(x::Vector) = set_optim_problem(x, data_updated, T, η_ω_0, model, scale_initial)

# out_prob = set_outter_problem(x, params::Array{Float64}, data::Data, T::Int64, η_ω::Float64,
# 													model::Model, fixed_param::Float64)

### Set options for estimation
# optim_options = OptimOptions(
#     optim_problem_korv, # Function to be optimized
#     vcat(param_0, scale_0), # Initial parameter values
#     NelderMead(), # Optimization method
#     1e-4, # Tolerance for convergence
#     300, # Maximum number of iterations
#     callback # Callback function
# )


### Set options for estimation
optim_options = OptimOptions(
    optim_problem_updated, # Function to be optimized
    vcat(param_0, scale_0), # Initial parameter values
    NelderMead(), # Optimization method
    1e-4, # Tolerance for convergence
    300, # Maximum number of iterations
    callback # Callback function
)

sim = solve_optim_prob(optim_options, scale_initial, η_ω_0)

p = plot_results(sim, data_updated)


@save "./extend_KORV/data/results/example.jld2" sim optim_options p

@load "./extend_KORV/data/results/example.jld2" sim optim_options p



function set_outer_problem(x::Vector, Φ::Array{Float64}, data::Data, model::Model, fixed_param::Float64; off::Bool=false) 
	
	# Check admisible parameter values
	if ( x[1] < 0 ) 
		return Inf 
	end

	params = setParams( [Φ[1:3]...,  x[1]], [Φ[4:end]..., fixed_param] )

	params.η_ω = x[1]
	# Genrate shocks
	shocks = generateShocks(params, T);
	# Update model
	update_model!(model, params)

	if off
		model_results = evaluateModel(0, model, data, params, shocks)
		ω_model[ :, i] = model_results[:ω];
		rr_model[:, i] = model_results[:rr];
	else
		ω_model = zeros(T-1 , params.nS)
		rr_model = zeros(T-1 , params.nS)
		for i ∈ 1:params.nS
			model_results = evaluateModel(i, model, data, params, shocks)
			ω_model[ :, i] = model_results[:ω];
			rr_model[:, i] = model_results[:rr];
		end 
		model_moments = vcat(mean(ω_model, dims=2), mean(rr_model, dims=2))
		data_moments = vcat(data.w_h[1:end-1] ./ data.w_ℓ[1:end-1], data.rr)
	end
	W = diagm(vcat(ones(T-1), 0.5 * ones(T-1)))
	obj_fun = ((model_moments - data_moments)'*W*(model_moments - data_moments))[1]

	return obj_fun
end 

η_ω = η_ω_0
param_1 = copy(param_0)
scale_1 = copy(scale_0)

# for i = 1:10

# 	outer_problem(x::Vector) = set_outer_problem(x, vcat(param, scale), data_korv, model, scale_initial)

# 	sol_η = Optim.optimize(	outer_problem, [η_ω],
# 	Optim.Options(
# 	g_tol = 1e-10,
# 	show_trace = true,
# 	iterations = 300,
# 	show_every=20,
# 	)
# 	)

# 	print("η_ω = ", η_ω, " η_ω_next = ", sol_η.minimizer[1], " diff = ", abs(η_ω - sol_η.minimizer[1]))

# 	η_ω = sol_η.minimizer[1]

# 	### Set options for estimation
# 	optim_options = OptimOptions(
# 		optim_problem_korv, # Function to be optimized
# 		vcat(param, scale), # Initial parameter values
# 		NelderMead(), # Optimization method
# 		1e-2, # Tolerance for convergence
# 		300, # Maximum number of iterations
# 		callback # Callback function
# 	)

# 	sim = solve_optim_prob(optim_options, scale_initial, η_ω_0)

# 	param = [sim.x.α, sim.x.σ, sim.x.ρ]
# 	scale = [sim.x.μ, sim.x.λ, sim.x.φℓ₀]

# 	@info "Iteration ", i, ": ", param, " ", scale

# end

η_ω_vals = 0.001:0.01:0.2 |> collect


objs_ =[]
sims = []

for i ∈ 1:length(η_ω_vals)

	η_ω = η_ω_vals[i]

	# optim_problem_korv(x::Vector) = set_optim_problem(x, data_korv, T, η_ω,
	# 												model, scale_initial)

	optim_problem_updated(x::Vector) = set_optim_problem(x, data_updated, length(data_updated.y), η_ω,
													model, scale_initial)

	### Set options for estimation
	# optim_options = OptimOptions(
	# 	optim_problem_korv, # Function to be optimized
	# 	vcat(param_0, scale_0), # Initial parameter values
	# 	NelderMead(), # Optimization method
	# 	1e-2, # Tolerance for convergence
	# 	300, # Maximum number of iterations
	# 	callback # Callback function
	# )
	# params_last = sims[i].x

	# init_params = [ params_last.α, params_last.σ, params_last.ρ, 
	# 				params_last.μ, params_last.λ, params_last.φℓ₀
	# 				]
	init_params = vcat(param_0, scale_0)
	print(init_params)
	optim_options = OptimOptions(
		optim_problem_updated, # Function to be optimized
		init_params, # Initial parameter values
		NelderMead(), # Optimization method
		1e-3, # Tolerance for convergence
		300, # Maximum number of iterations
		callback # Callback function
	)


	sim = solve_optim_prob(optim_options, scale_initial, η_ω)
	
	
	@info "Final Params:" sim.x
	
	push!(sims, sim)
	
	param = [sim.x.α, sim.x.σ, sim.x.ρ]
	scale = [sim.x.μ, sim.x.λ, sim.x.φℓ₀]

	# outer_problem(x::Vector) = set_outer_problem(x, vcat(param, scale), data_korv, model, scale_initial, off=false)

	outer_problem(x::Vector) = set_outer_problem(x, vcat(param, scale), data_updated, model, scale_initial, off=false)

	obj = outer_problem([η_ω])

	push!(objs_, obj)

end


for i in 1:length(sims)
	println("i = " , i, " η_ω = ", η_ω_vals[i], " obj = ", objs_[i])
end

plot(η_ω_vals, objs_, markerstyle=:x)

sims[1].x

begin
	i = 17
	plot_results(sims[i], data_updated, title="Updated model η_ω =   $(η_ω_vals[i])")
end


for i ∈ eachindex(sims)
	println("i = " , i, " η_ω = ", η_ω_vals[i], " obj = ", objs_[i])
end

sim.x.α = param[1]
sim.x.σ = param[2]
sim.x.ρ = param[3]
sim.x.μ = scale[1]
sim.x.λ = scale[2]
sim.x.φℓ₀ = scale[3]
sim.x.η_ω = η_ω


plot_results(sim_2, data_korv)
