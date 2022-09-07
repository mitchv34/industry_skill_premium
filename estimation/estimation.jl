
# Loading Packages
using LinearAlgebra
using DataFrames
using CSV
using StatsBase
using GLM
using Distributions
using Random
using Parameters
using ModelingToolkit
using Random
using Optimization


## Parameters
@with_kw mutable  struct Params
    α       ::Float64               #
    μ       ::Float64               #
    λ       ::Float64               #
    σ       ::Float64               #
    ρ       ::Float64               #
    η_ε     ::Float64               #
    γ_ℓ=0.0 ::Float64               # Trend of the φ_ℓ stochastic process
    γ_h=0.0 ::Float64               # Trend of the φ_h stochastic process
    η_ω     ::Float64               # Common innovation variance of both processes
	φℓ₀ 	::Float64 				# Initial value for φ_ℓ
	φh₀ 	::Float64 				# Initial value for φ_h
	δ_e		::Float64 				# depreciation rate of the capital euipment
	δ_s		::Float64 		 		# depreciation rate of the capital structures
	nS 		::Int64 				# Number of simulations
end

## Data
mutable struct Data
	
    k_s     ::Array{Float64, 1}     # Capital structures
    k_e     ::Array{Float64, 1}     # Capital equipment 
    h       ::Array{Float64, 1}     # high skill labor input 
    ℓ       ::Array{Float64, 1}     # low skill labor input
    w_h     ::Array{Float64, 1}     # high skill wage
    w_ℓ     ::Array{Float64, 1}     # low skill wage
    y       ::Array{Float64, 1}     # output
	lsh 	::Array{Float64, 1} 	# Labor share of output
	lsh_alt 	::Array{Float64, 1} 	# Labor share of output
	q 		::Array{Float64, 1} 	# Relative prices of capital
	wbr 	::Array{Float64, 1} 	# Labor share of output
	# ψ_L 	::Array{Float64, 1} 	# low skill productivity (initialized at exp(1))
	# ψ_H 	::Array{Float64, 1} 	# high skill productivity (initialized at exp(1))
	δ_s 	::Array{Float64, 1} 	# structures depreciation rate (default is 0.05)
	δ_e 	::Array{Float64, 1} 	# equipment depreciation rate (default is 0.125)
	rr 		::Array{Float64, 1} 	# lhs of equation (8) (initialized at 0)
	
	# Constructor
	function Data( 	k_s::Array{Float64, 1}, k_e::Array{Float64, 1}, 
					h::Array{Float64, 1}, 	ℓ::Array{Float64, 1},
					w_h::Array{Float64, 1}, w_ℓ::Array{Float64, 1},
					y ::Array{Float64, 1}, 	lsh ::Array{Float64, 1}, lsh_alt ::Array{Float64, 1},
					q::Array{Float64, 1})

					rr = q[1:end-1] ./ q[2:end]

					wbr = (w_h .* h) ./ (w_ℓ .* ℓ)

		return new( k_s, k_e, h, ℓ, w_h, w_ℓ, y, lsh,lsh_alt, q, wbr,
					# Default arguments are initialized as vectors of ones 
					# exp.(ones( length( y ) )), 
					# exp.(ones( length( y ) )),
					0.05 .* (ones( length( y ) )), 
					0.125 .* ones( length( y ) ), 
					rr) 
					
	end
	
end

## Shocks
mutable struct Shocks
	
	ψ_H 	::Array{Float64, 2} 	# {{φ_ℓ}ₜ}ⁱ shocks
	ψ_L 	::Array{Float64, 2} 	# {{φ_h}ₜ}ⁱ shocks
	ε 	  	::Array{Float64, 2} 	# {{ε}ₜ}ⁱ shocks
	
	# Constructor
	function Shocks()
		return new( zeros( 2, 1 ), zeros( 2, 1 ), zeros( 2, 1 )) # Initialize shocks as vectors of zeros
	end
	
end


## Generate stochastic factors for a given value of η_ω and φ₀
function generateShocks(parameters::Params, T::Int64; seed::Int64=205)
    
	# Set the seed
	Random.seed!(seed)

    @unpack φℓ₀ , φh₀, γ_ℓ, γ_h, η_ω, η_ε, nS = parameters  

	# Generate shocks structure
	shocks = Shocks()

    # Generate random shocks 
    ω_ℓ = rand(Normal(0, sqrt(η_ω)), nS, T);
    ω_h = rand(Normal(0, sqrt(η_ω)), nS, T);

    # Generate the trend factor
    t = repeat(0:T-1, 1, nS)'

	# @info "Generating shocks..." size(t) size(ω_ℓ) size(ω_h)

    φ_ℓ = φℓ₀ .+ γ_ℓ .* t .+ ω_ℓ;
    φ_h = φh₀ .+ γ_h .* t .+ ω_h;

	shocks.ψ_H = exp.(φ_h)
    shocks.ψ_L = exp.(φ_ℓ)


	# Model part rental rate of capital equation (Equation 8 form KORV) 
	
	shocks.ε = rand( Normal(0, sqrt(η_ε)), nS, T-1);

	return shocks

end

# Create a model structure
mutable struct Model
	
	# Symbolic Functions
	prod_fucnt 				::Num 			# Production Function
	skill_prem 				::Num 			# Skill premium
	labor_share_output 		::Num 			# Labor share of Output
	wage_bill_ratio 		::Num 			# Wage Bill Ratio
	wage_ℓ 					::Num 			# Low type wages (functional form)
	wage_h 					::Num 			# High type wages (functional form)
	rr						::Num 			# rhs equation (8) (functional form)		

	# Evaluable functions (Allways initialized as returning nothing)
	prod_fucnt_fun 			::Function 		# Production Function
	skill_prem_fun 			::Function 		# Skill premium
	labor_share_output_fun 	::Function 		# Labor share of Output
	wage_bill_ratio_fun 	::Function 		# Wage Bill Ratio
	wage_ℓ_fun 				::Function 		# Low type wages (evaluable)
	wage_h_fun 				::Function 		# High type wages (evaluable)
	rr_fun 					::Function 		# rhs equation (8) (evaluable)

	# Constructor
	function Model( prod_fucnt::Num, skill_prem::Num, 
					labor_share_output::Num, wage_bill_ratio::Num, 
					wage_ℓ::Num, wage_h::Num, rr::Num )
		
		return new( prod_fucnt, 
					skill_prem,
					labor_share_output,
					wage_bill_ratio,
					wage_ℓ,
                    wage_h,
					rr,
					# Default arguments are f(x) = nothing 
					(x) -> nothing,
					(x) -> nothing,
					(x) -> nothing,
					(x) -> nothing,
					(x) -> nothing,
					(x) -> nothing,
					(x) -> nothing)
		
	end
	
end

# Create a model initializtion function
function intializeModel()

	# Set up the production function a symbolyc object

	G = k_s^(α) * ( μ*(ψ_L*ℓ)^σ+ (1-μ)*(λ*k_e^ρ + (1-λ)*(ψ_H*h)^ρ)^(σ/ρ))^((1-α)/σ)

	# Define the differential operators
	Dℓ = Differential(ℓ)
	Dh = Differential(h)
	
	# Wages of low-skiled workers
	w_ℓ = expand_derivatives( Dℓ(G) )
	w_h = expand_derivatives( Dh(G) )

	# Closed form solution of log-linearized skill premium
	# ω = (k_e/(ψ_H * h))^ρ * λ * ((σ - ρ)/ρ) + (1 - σ) * log(ℓ / h) + σ *log(ψ_H / ψ_L)
	ω = w_h / w_ℓ

	# Closed form solution of the labor share 
	lsh = ( (w_ℓ * ℓ) + (w_h * h) ) / G

	# Close form solution of the wage bill ratio
	wbr = (w_h * h) / ( w_ℓ * ℓ)


	# Obtain derivatives of the production function wrt k_s and k_e
	D_k_s = Differential(k_s)
	D_k_e = Differential(k_e)
	
	G_k_s = expand_derivatives( D_k_s( G ) ) 
	G_k_e = expand_derivatives( D_k_e( G ) ) 

	# rr = q_next * ( (1-δ_s) - G_k_s - q*G_k_e ) / (1 - δ_e)
	rr = ( (1-δ_s) + y * G_k_s/G - q*y*(G_k_e /G)) / (1 - δ_e)

	return Model(   G,
					ω,
					lsh,
					wbr,
					w_ℓ,
					w_h,
					rr
	)
	
end 

function update_model!(model::Model, parameters::Params)

	params_dict = Dict( α => parameters.α,
						μ => parameters.μ,
						σ => parameters.σ,
						λ => parameters.λ,
						ρ => parameters.ρ,
						δ_s => parameters.δ_s,
						δ_e => parameters.δ_e)
	
	vars = [k_e, k_s, h, ℓ,  ψ_L, ψ_H, q, y]

	prod_fucnt_fun = build_function(substitute(model.prod_fucnt, params_dict), vars, expression=Val{false}) 			
	skill_prem_fun = build_function(substitute(model.skill_prem, params_dict), vars, expression=Val{false}) 			
	labor_share_output_fun = build_function(substitute(model.labor_share_output, params_dict), vars, expression=Val{false}) 
	wage_bill_ratio_fun = build_function(substitute(model.wage_bill_ratio, params_dict), vars, expression=Val{false})
	wage_ℓ_fun =  build_function( substitute( model.wage_ℓ , params_dict ), vars, expression=Val{false})
	wage_h_fun =  build_function( substitute( model.wage_h , params_dict ), vars, expression=Val{false})
	rr = build_function( substitute( model.rr , params_dict ), vars, expression=Val{false})

	model.prod_fucnt_fun = prod_fucnt_fun
	model.skill_prem_fun = skill_prem_fun
	model.labor_share_output_fun = labor_share_output_fun
	model.wage_bill_ratio_fun = wage_bill_ratio_fun
	model.wage_ℓ_fun = wage_ℓ_fun
	model.wage_h_fun = wage_h_fun
	model.rr_fun = rr

end 

function evaluateModel(sim_id::Int64, model::Model, data::Data, parameters::Params, shocks::Shocks)

	@unpack ψ_L, ψ_H, ε = shocks
	
	y_data = data.y 
	k_s_data = data.k_s
	k_e_data = data.k_e
	h_data = data.h
	ℓ_data = data.ℓ
	q_data = data.q

	n = length(k_s_data)

	if sim_id == 0 # This means no simulation therefore turn off the shocks
		params_no_shock = Params(
			α = parameters.α,   
			μ = parameters.μ,
			λ = parameters.λ,
			σ = parameters.σ,
			ρ = parameters.ρ,
			η_ε = 0.0,
			γ_ℓ = 0.0,
			γ_h = 0.0,
			η_ω = 0.0,
			φℓ₀ = parameters.φℓ₀,
			φh₀ = parameters.φh₀,
			δ_s = parameters.δ_s,
			δ_e = parameters.δ_e,
			nS = 1)
		T = length(y_data)
		shocks_dumb = generateShocks(params_no_shock, T)
		return evaluateModel(1, model, data, params_no_shock, shocks_dumb)
	end

	data_points = []
	for i ∈ 2:n
		x = [ k_e_data[i],k_s_data[i],h_data[i],ℓ_data[i],ψ_L[sim_id, i],ψ_H[sim_id, i], q_data[i-1], y_data[i] ] 
		# @info "Simulation $(sim_id)" "Evaluating model for period $(i)" x
		push!(data_points, x)
	end

	# Update model with new parameters
	# update_model!(model, parameters)

	# Y 	= model.prod_fucnt_fun.( data_points )
	# try
	ω 	= model.skill_prem_fun.( data_points )
	lbr = model.labor_share_output_fun.( data_points )
	wbr = model.wage_bill_ratio_fun.( data_points )
	# w_ℓ = model.wage_ℓ_fun.( data_points )
	# w_h = model.wage_h_fun.( data_points )
	try
	rr  = model.rr_fun.( data_points ) 
	catch
		print("\n\n\n\nHERE")
		for d ∈	data_points
			print(d[1:4])
		end
		print("\n\n\n\n")
		return 0
	end


	# add schock to rr
	rr = rr .+ ε[sim_id, :]

	return Dict([ 	
					# :Y => Y,
					:ω => ω, 
					:lbr => lbr,
					:wbr => wbr,
					# :w_ℓ => w_ℓ,
					# :w_h => w_h,
					:rr  => rr]
					)

end

# generate moments
function generateMoments(model::Model, parameters::Params, data::Data, shocks::Shocks)

	@unpack nS = parameters
	T = length(data.h) - 1
	
	z = zeros(3, T , nS)
	
	# Each iteration is a simulation of the model
	for i ∈ 1:nS
		model_results = evaluateModel(i, model, data, parameters, shocks)
	
		z[1, :, i] = model_results[:wbr];# z[1, :, i] = z[1, :, i] / z[1, 1, i]
		z[2, :, i] = model_results[:lbr];# z[2, :, i] = z[2, :, i] / z[2, 1, i]
		z[3, :, i] = model_results[:rr] ;# z[3, :, i] = z[3, :, i] / z[3, 1, i]
		
	end 

	mS = mean(z, dims = 3)[:,:,1]

	temp = z .- mS
	vS = zeros(T, 3, 3)
	for t ∈ 1:T
		# vSₜ = zeros(3,3)
		# for s ∈ 1:nS
		# 	vSₜ += temp[:, t, s] * temp[:, t, s]' 
		# end 
		vS[t, :, :] = cov( z[:, t, :] , dims = 2 )
		# vS[t, :, :] = vSₜ ./ (nS - 1) 
	end
	
	return mS', vS
	
end

function objectiveFunction(model::Model, parameters::Params, data::Data, shocks::Shocks; moment_subset = [1,2,3])
	
	@unpack wbr, lsh, rr, y, lsh_alt = data
	@unpack ε = shocks
	
	@parameters α, μ, σ, λ, ρ, δ_s, δ_e
	@variables k_e, k_s, h, ℓ, ψ_L, ψ_H, q

	# model = intializeModel()
	# update_model!(model, parameters)

	T = length(lsh) - 1
	mS, vS = generateMoments(model, parameters, data, shocks)
	
	#! Normalize moments to growth rates
	mS[1, :] = (mS[1, :] .- mS[1, 1] ) ./ mS[1, 1]
	mS[2, :] = (mS[2, :] .- mS[2, 1] ) ./ mS[2, 1]
	mS[3, :] = (mS[3, :] .- mS[3, 1] ) ./ mS[3, 1]
	

	# Z = hcat(wbr[1:end-1] / wbr[1] , lsh_alt[1:end-1]/lsh_alt[1], rr/rr[1])
	Z = hcat(wbr[2:end] , lsh[2:end], rr)
	
	#! Normalize moments to growth rates
	Z[1, :] = (Z[1, :] .- Z[1, 1] ) ./ Z[1, 1]
	Z[2, :] = (Z[2, :] .- Z[2, 1] ) ./ Z[2, 1]
	Z[3, :] = (Z[3, :] .- Z[3, 1] ) ./ Z[3, 1]


	ℓ²ₛ = 0
	moment_subset = [1]
	for t ∈ 1:T
		# @info ℓ²ₛ

		a = (Z[t,moment_subset] - mS[t,moment_subset])
		# ℓ²ₛ += 	(a' * pinv(vS[t,:,:]) * a) + log( abs(det(vS[t,:,:])) +  eps(0.0) )
		# ℓ²ₛ += 	(a' * inv(vS[t, :, :]) * a)# + log( abs(det(vS[t,:,:])) +  eps(0.0) )
		ℓ²ₛ += 	(a' * inv(vS[t, moment_subset, moment_subset]) * a) + log( abs(det(vS[t,:,:]))  )
		# if ℓ²ₛ < 0 
		# 	termshow(a)
		# 	termshow(a'a)
		# end

	end
	
	return (ℓ²ₛ / (2*T))
	
end



function generateData(data::DataFrame)

	data = Data(data.K_STR, 
				data.K_EQ,
				data.L_S, 
				data.L_U,
				data.W_S,
				data.W_U,
				data.OUTPUT,
				data.L_SHARE,
				(data.W_S .* data.L_S + data.W_U .* data.L_U ) ./ data.OUTPUT,
				data.REL_P_EQ);

	return data
		
end


function setParams(param::Vector{Float64}, scale_params::Vector{Float64}; δ_e::Float64=0.125, δ_s::Float64 =0.05)
	parameters = Params(
						α   = param[1],
						μ   = scale_params[1],    
						λ   = scale_params[2],    
						σ   = param[2],    
						ρ   = param[3],    
						η_ε = 0.02,    
						γ_ℓ= 0.0,
						γ_h= 0.0,
						η_ω =  param[4],
						φℓ₀ = scale_params[3], 
						φh₀ = scale_params[4],
						δ_e = δ_e,
						δ_s = δ_s,
						nS = 500
	);
	
	return parameters 
end 