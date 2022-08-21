###################### MAIN ##############################
using Term
using Term.Progress
install_term_logger()

using Plots
Plots.theme(:juno); # :dark, :light, :plain, :grid, :tufte, :presentation, :none
default(fontfamily="Computer Modern", framestyle=:box); # LaTex-style

include("estimation.jl")

using Optim

# # Define parameters and variables of the model
begin
	@parameters α, μ, σ, λ, ρ, δ_e, δ_s
	@variables k_e, k_s, h, ℓ, ψ_L, ψ_H, q, y
end

#  Load Data
ind_code = "44RT"
path_data = "./extend_KORV/data/proc/ind/$(ind_code).csv";
dataframe = CSV.read(path_data, DataFrame);

data = generateData(dataframe);
model = intializeModel();


### Estimate model with data from KORV

# Define the optimizaiton problem to estimate the model # TODO: this should be done in a separate file
begin
scale_param_fixed = 6.0;

T = length(data.y);
function optim_problem(x)

	# Check admisible parameter values
	if (0 > x[1]) || (1 < x[1]) || (x[2] > 1)  || (1 < x[3]) 
		return Inf 
	end


	if (0 > x[4]) || (1 < x[4]) || (0 > x[5])  || (1 < x[5]) || (x[6] < 0) 
		return Inf 
	end

	p_new = setParams( x[1:3], x[4:end]);
	# p_new = setParams( x[1:3], [x[4:end]..., scale_param_fixed]);
	
	shocks = generateShocks(p_new, T);
	update_model!(model, p_new)

	return objectiveFunction(model, p_new, data, shocks)

end


# Set initial parameter values
param_0 = [0.29655668731713436
0.4012832851663651
-1.0611728986687934]
scale_0 = [0.027890845668247413
0.17287751342253802
12.070228321665113
3.8893943097551804]


@time sol = Optim.optimize(	optim_problem,
				vcat(param_0, scale_0),
				Optim.Options(
				g_tol = 1e-4,
				show_trace = true,
				iterations = 300,
				show_every=10
				)
			)

# Plot the results
p = setParams(sol.minimizer[1:3], sol.minimizer[4:end]);
# p_korv = setParams(sol.minimizer[1:3], [sol.minimizer[4:end]..., scale_param_fixed]);
T = length(data.y);
shocks = generateShocks(p, T);
update_model!(model, p)
model_results = evaluateModel(0, model, data, p, shocks)

rr_model = model_results[:rr] .*  data.q[2:end] #/model_results[:rr][1]
ω_model = model_results[:ω]# /model_results[:ω][1]
lbr_model = model_results[:lbr]# / model_results[:lbr][1]
wbr_model = model_results[:wbr]#/model_results[:wbr][1]

rr_data = data.rr .* data.q[2:end]  #/ data.rr[1]
ω_data = data.w_h ./ data.w_ℓ; #ω_data = ω_data/ω_data[1]
lbr_data = data.lsh# / data.lsh[1]
wbr_data = data.wbr;# wbr_data /= wbr_data[1]

p1 = plot(rr_model, lw = 2, linestyle=:dash, label = "Model", legend =:topright, size = (800, 400))
plot!(rr_data, lw = 2, label = "Data")
title!("Eq (8)")
p2 = plot(ω_model , lw = 2,  linestyle=:dash, label = "Model", legend =:topleft,size = (800, 400))
plot!(ω_data, lw = 2, label = "Data")
title!("Skill Premium")
p3 = plot(lbr_model, lw = 2,  linestyle=:dash, label = "Model", legend =:topleft,size = (800, 400))
plot!(lbr_data, lw = 2, label = "Data")
ylims!(.40, .80)
title!("Labor Share of Output")
p4 = plot(wbr_model, lw = 2,  linestyle=:dash, label = "Model", legend =:topleft,size = (800, 400))
plot!(wbr_data, lw = 2, label = "Data")
title!("Wage Bill Ratio")

plot(p1,p2,p3,p4, layout = (2,2), size = (800, 600))

end
