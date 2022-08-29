using Parameters
using Optim
using Plots


include("estimation.jl")


# Callback function to be used during estimation
function callback(os)
	if os.iteration % 20 == 5                                      
		println("----------------------------------------------------")
		print(@green @bold "Iteration : $(os.iteration)")
		time = os.metadata["time"]
		println(@green @bold "\t Time : $(time)")
		println("----------------------------------------------------")
    	# println(@red " * Iteration:       ", os.iteration)
        # print(os.metadata)
		minimizer = os.metadata["centroid"]
		α = minimizer[1]
		σ = minimizer[2]
		ρ = minimizer[3]
		μ = minimizer[4]
		λ = minimizer[5]
		φℓ⁰	= minimizer[6]
		@info "Parameters" α σ ρ μ λ φℓ⁰
		f = os.value
		g_norm = os.g_norm
		println(@green @bold "Objective function value : $(f)")
		println(@green @bold "Convergence : $(g_norm)")
    println("----------------------------------------------------")
	end	
    false
end # callback

# # Define optimization options structure
mutable struct OptimOptions
    optim_problem ::Function # Function to be optimized
    x_0 ::Array{Float64} # Initial parameter values
	method # Optimization method
    g_tol::Float64 # Tolerance for convergence
    iterations::Int # Maximum number of iterations
    callback::Function # Callback function
end # OptimOptions


# Simulation results struct
mutable struct Simulation
    f::Float64 # Objective function value
    g_norm::Float64 # Norm of the gradient
    t::Float64 # Time elapsed
    x_0::Params # Initial parameter values
    x::Params # Parameters
    options::OptimOptions # Optimization options
end # Simulation

# Define optimization problem
function set_optim_problem(x::Vector, data::Data, T::Int64, η_ω::Float64, model::Model, fixed_param::Float64; delta::Vector=[])

	# Check admisible parameter values
	if (0 > x[1]) || (1 < x[1]) || (x[2] > 1)  || (1 < x[3]) 
		return Inf 
	end

	if (0 > x[4]) || (1 < x[4]) || (0 > x[5])  || (1 < x[5]) || (x[6] < 0) 
		return Inf 
	end

    if length(delta) == 0
        p_new = setParams( [x[1:3]...,η_ω] , [x[4:end]..., fixed_param]);
    else
        delta_e, delta_s = delta
        p_new = setParams( [x[1:3]...,η_ω] , [x[4:end]..., fixed_param], δ_e = delta_e, δ_s = delta_s);
    end
    

	shocks = generateShocks(p_new, T);
	update_model!(model, p_new)

	return objectiveFunction(model, p_new, data, shocks)

end # set_optim_problem

# Solve optimization problem
function solve_optim_prob(data::Data, model::Model, fixed_param::Float64, η_ω::Float64, x_0 ::Array{Float64};
                            delta::Vector=[], tol = 1e-4, maxiter=300)

    ### Run optimization
    # set optimization problem
    optim_problem(x::Vector) = set_optim_problem(x, data, T, η_ω, model, fixed_param; delta=delta)

    T = length(data.y) # Time horizon

    ## Set options for estimation
    options = OptimOptions(
        optim_problem, # Function to be optimized
        x_0, # Initial parameter values
        NelderMead(), # Optimization method
        tol, # Tolerance for convergence
        maxiter, # Maximum number of iterations
        callback # Callback function
    )
        
    # Solve optimization problem
    sol = Optim.optimize(   options.optim_problem,
                            options.x_0,
                            options.method,
                            Optim.Options(
                                extended_trace=true,
                                g_tol = options.g_tol,
                                iterations = options.iterations,
                                callback = options.callback 
                                )
                        )

    if length(delta) == 0
        delta_e, delta_s = [0.125, 0.05]
    else
        delta_e, delta_s = delta
    end

    # Create simulation results struct
    return Simulation(  sol.minimum,
                        sol.g_residual,
                        sol.time_run,
                        setParams( [sol.initial_x[1:3]...,η_ω] , [sol.initial_x[4:end]..., fixed_param], δ_e = delta_e, δ_s = delta_s ),
                        setParams( [sol.minimizer[1:3]...,η_ω] , [sol.minimizer[4:end]..., fixed_param], δ_e = delta_e, δ_s = delta_s ),
                        options
                    )
end # solve_optim_prob 

# Plot the results 
function plot_results(simulation::Simulation, data::Data; years::Array=[], scale_font::Float64 = 1.0)
    

    Plots.theme(:vibrant); # :dark, :light, :plain, :grid, :tufte, :presentation, :none
    default(fontfamily="Computer Modern", framestyle=:box ); # LaTex-style1
    Plots.scalefontsizes(scale_font)
    params = simulation.x # Parameters
    T = length(data.y) # Time horizon
    # Genrate shocks
    shocks = generateShocks(params, T);
    # Update model
    
    update_model!(model, params)
    # Evaluate model
    model_results = evaluateModel(0, model, data, params, shocks)

    if length(years) == 0
        years = 1:length(data.y)-1
    end

    # @info "MODEL" size( model_results[:rr] ), size( model_results[:ω] ), size( model_results[:lbr] ), size( model_results[:wbr] )
    # @info "DATA" size(  data.rr ), size(  data.w_h ), size( data.lsh ), size( data.wbr )

    # Plot results:
    p1 = plot( years, model_results[:rr] .*  data.q[1:end-1], lw = 2, linestyle=:dash,color = :red,
                label = "Model", legend =:topright, size = (800, 200))
    plot!(years, data.rr .* data.q[1:end-1], lw = 2, label = "Data", color = :black)
    title!("Relative Price of Equipment")
    
    p2 = plot(years, model_results[:ω] , lw = 2,  linestyle=:dash, color = :red,
    label = "Model", legend =:topleft,size = (800, 400))
    plot!(years, data.w_h[2:end] ./ data.w_ℓ[2:end], lw = 2, label = "Data", color = :black)
    title!("Skill Premium")

    p3 = plot(years, model_results[:lbr], lw = 2,  linestyle=:dash, color = :red, label = "Model", legend =:topleft,size = (800, 400))
    plot!(years, data.lsh[2:end], lw = 2, label = "Data", color = :black)
    y_max = max( maximum( model_results[:lbr] ), maximum(data.lsh[2:end]) ) .* 1.05
    y_min = min( minimum(model_results[:lbr] ) , minimum(data.lsh[2:end]) ).* 0.95
    ylims!(y_min, y_max)
    title!("Labor Share of Output")

    p4 = plot(years, model_results[:wbr], lw = 2,  linestyle=:dash, color = :red, label = "Model", legend =:topleft,size = (800, 400))
    plot!(years, data.wbr[2:end], lw = 2, label = "Data", color = :black)
    title!("Wage Bill Ratio")

    # title_plot = plot(title = title, grid = false, showaxis = false, bottom_margin = -1Plots.px)
    # xticks!([0]); yticks!([0]);

    # p = plot(p1,p2,p3,p4, layout = (2,2), size = (800, 600))
    # p = plot(p2,p3,p4, layout = (1,3), size = (800, 600))

    return  (p1, p2, p3, p4)
end # plot_results


mutable struct InitParams
	scale_initial::Float64
	η_ω_0::Float64
	param_0::Vector{Float64}
	scale_0::Vector{Float64}
end

function estimate_industry(ind_code, initParams::InitParams; tol = 1e-2, path_to_results::String="./data/results")

    if ind_code*".csv" in readdir(path_to_results)
        results = CSV.read(path_to_results * "/" * ind_code * ".csv", DataFrame)
    else
        results = DataFrame(
            [
                :alpha_0 => [],
                :sigma_0 => [],
                :rho_0 => [],
                :eta_0 => [],
                :mu_0 => [],
                :lambda_0 => [],
                :phi_L_0 => [],
                :phi_H_0 => [],
                :alpha => [],
                :sigma => [],
                :rho => [],
                :eta => [],
                :mu => [],
                :lambda => [],
                :phi_L => [],
                :phi_H => [],
                :fit_rr => [],
                :fit_wbr => [],
                :fit_lbr => [],
                :fit_sp => [],
                :obj_val => [],
                :tol => [],
            ]
        )
    end

	scale_initial = initParams.scale_initial
	η_ω_0 = initParams.η_ω_0
	param_0 = initParams.param_0
	scale_0 = initParams.scale_0


    path_data = "./data/proc/ind/$(ind_code).csv";
    dataframe = CSV.read(path_data, DataFrame);

    data = generateData(dataframe);
    delta_e = mean(dataframe.DPR_EQ)
    delta_s = mean(dataframe.DPR_ST)

    try
        sim = solve_optim_prob(data, model, scale_initial, η_ω_0, vcat(param_0, scale_0), tol = tol; delta=[delta_e, delta_s]);

        p = plot_results(sim, data)

        T = length(data.y) # Time horizon
        # Genrate shocks
        shocks = generateShocks(sim.x, T);
        # Update model
        update_model!(model, sim.x)

        # Evaluate model
        model_results = evaluateModel(0, model, data, sim.x, shocks)
        ω_model = model_results[:ω];
        rr_model = model_results[:rr];
        lbr_model = model_results[:lbr];
        wbr_model = model_results[:wbr];
        # Data
        ω_data = data.w_h ./ data.w_ℓ;
        rr_data = data.rr;
        lbr_data = data.lsh;
        wbr_data = data.wbr;

        # Check fitness

        f1 = sum((ω_model .- ω_data[2:end]).^ 2)
        f2 = sum((rr_model .- rr_data).^ 2)
        f3 = sum((lbr_model .- lbr_data[2:end]).^ 2)
        f4 = sum((wbr_model .- wbr_data[2:end]).^ 2)

        # # Save results
        temp_df = DataFrame(
            [
                :alpha_0 => [sim.x_0.α],
                :sigma_0 => [sim.x_0.σ],
                :rho_0 => [sim.x_0.ρ],
                :eta_0 => [sim.x_0.η_ω],
                :mu_0 => [sim.x_0.μ],
                :lambda_0 => [sim.x_0.λ],
                :phi_L_0 => [sim.x_0.φℓ₀],
                :phi_H_0 => [sim.x_0.φh₀],
                :alpha => [sim.x.α],
                :sigma => [sim.x.σ],
                :rho => [sim.x.ρ],
                :eta => [sim.x.η_ω],
                :mu => [sim.x.μ],
                :lambda => [sim.x.λ],
                :phi_L => [sim.x.φℓ₀],
                :phi_H => [sim.x.φh₀],
                :fit_rr => [f2],
                :fit_wbr => [f4],
                :fit_lbr => [f3],
                :fit_sp => [f1],
                :obj_val => [sim.f],
                :tol => [tol]
            ]
        )

        append!(results, temp_df)
        CSV.write(path_to_results * "/" * ind_code * ".csv", results)


        return sim, p
    catch  e
        println(@red string(e))
        temp_df = DataFrame(
            [
                :alpha_0 => [initParams.param_0[1]],
                :sigma_0 => [initParams.param_0[2]],
                :rho_0 => [initParams.param_0[3]],
                :eta_0 => [initParams.η_ω_0],
                :mu_0 => [initParams.scale_0[1]],
                :lambda_0 => [initParams.scale_0[2]],
                :phi_L_0 => [initParams.scale_0[3]],
                :phi_H_0 => [initParams.scale_initial],
                :alpha => NaN,
                :sigma => NaN,
                :rho => NaN,
                :eta => NaN,
                :mu => NaN,
                :lambda => NaN,
                :phi_L => NaN,
                :phi_H => NaN,
                :fit_rr => NaN,
                :fit_wbr => NaN,
                :fit_lbr => NaN,
                :fit_sp => NaN,
                :obj_val => NaN,
                :tol => [tol]
            ]
        )
        append!(results, temp_df)
        CSV.write(path_to_results * "/" * ind_code * ".csv", results)

        return nothing, nothing
    end
	

end 
