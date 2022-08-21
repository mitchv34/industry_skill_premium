using Parameters
using Optim
using Plots
Plots.theme(:juno); # :dark, :light, :plain, :grid, :tufte, :presentation, :none
default(fontfamily="Computer Modern", framestyle=:box); # LaTex-style

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
function plot_results(simulation::Simulation, data::Data; title::String="Model Results")

    params = simulation.x # Parameters
    T = length(data.y) # Time horizon
    # Genrate shocks
    shocks = generateShocks(params, T);
    # Update model
    update_model!(model, params)
    # Evaluate model
    model_results = evaluateModel(0, model, data, params, shocks)

    # Plot results:
    p1 = plot(  model_results[:rr] .*  data.q[1:end-1], lw = 2, linestyle=:dash,
                label = "Model", legend =:topright, size = (800, 400))
    plot!(data.rr .* data.q[1:end-1], lw = 2, label = "Data")
    title!("Relative Price of Equipment")
    
    p2 = plot(model_results[:ω] , lw = 2,  linestyle=:dash, label = "Model", legend =:topleft,size = (800, 400))
    plot!(data.w_h ./ data.w_ℓ, lw = 2, label = "Data")
    title!("Skill Premium")

    p3 = plot(model_results[:lbr], lw = 2,  linestyle=:dash, label = "Model", legend =:topleft,size = (800, 400))
    plot!(data.lsh, lw = 2, label = "Data")
    ylims!(.30, .90)
    title!("Labor Share of Output")

    p4 = plot(model_results[:wbr], lw = 2,  linestyle=:dash, label = "Model", legend =:topleft,size = (800, 400))
    plot!(data.wbr, lw = 2, label = "Data")
    title!("Wage Bill Ratio")

    title_plot = plot(title = title, grid = false, showaxis = false, bottom_margin = -1Plots.px)
    xticks!([0]); yticks!([0]);

    p = plot(title_plot, p1,p2,p3,p4, layout = @layout([A{0.01h}; [[B C];[D E]]]), size = (800, 600))

    return  p

end # plot_results
