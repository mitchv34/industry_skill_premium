###################### MAIN ##############################
# using Term
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


#  Load Data
path_data_korv = "../data/Data_KORV.csv";
path_updated_labor = "../data/proc/labor_totl.csv";
path_updated_capital = "../data/proc/capital_totl.csv";

dataframe_korv = CSV.read(path_data_korv, DataFrame);
updated_labor = CSV.read(path_updated_labor, DataFrame)
updated_capital = CSV.read(path_updated_capital, DataFrame);

dataframe_updated = innerjoin(updated_capital, updated_labor, on = :YEAR)
dataframe_updated.REL_P_EQ = dataframe_updated.REL_P_EQ / dataframe_updated.REL_P_EQ[1];

Plots.theme(:vibrant); # :dark, :light, :plain, :grid, :tufte, :presentation, :none
    default(fontfamily="Computer Modern", framestyle=:box ); # LaTex-style1
plot(updated_labor.L_U , lw = 2, linestyle=:dash,color = :red,
                label = "Updated", legend =:topright, size = (600, 600))
plot!(dataframe_korv.L_U , lw = 2, label = "KORV", color = :black)
title!("Unskilled Labor Input")
savefig("../documents/images/labor_input_unskilled_doc.pdf")
plot(updated_labor.L_S , lw = 2, linestyle=:dash,color = :red,
                label = "Updated", legend =:topright, size = (600, 600))
plot!(dataframe_korv.L_S , lw = 2, label = "KORV", color = :black)
title!("Skilled Labor Input")
savefig("../documents/images/labor_input_skilled_doc.pdf")

wbr_u = (updated_labor.L_S .* updated_labor.W_S ) ./ (updated_labor.L_U .* updated_labor.W_U)
wbr_k = (dataframe_korv.L_S .* dataframe_korv.W_S ) ./ (dataframe_korv.L_U .* dataframe_korv.W_U)
plot(wbr_u , lw = 2, linestyle=:dash,color = :red,
				label = "Updated", legend =:topleft, size = (600, 600))
plot!(wbr_k , lw = 2, label = "KORV", color = :black)
title!("Wage-Bill Ratio")
savefig("../documents/images/wbr_doc.pdf")

sp_u = ( updated_labor.W_S ) ./ ( updated_labor.W_U)
sp_k = ( dataframe_korv.W_S ) ./ ( dataframe_korv.W_U)
plot(sp_u , lw = 2, linestyle=:dash,color = :red,
				label = "Updated", legend =:topleft, size = (600, 600))
plot!(sp_k , lw = 2, label = "KORV", color = :black)
title!("Skill Premium")
savefig("../documents/images/sp_doc.pdf")


# Capital Data
plot(updated_capital.K_STR , lw = 2, linestyle=:dash,color = :red,
				label = "Updated", legend =:topleft, size = (600, 600))
plot!(dataframe_korv.K_STR , lw = 2, label = "KORV", color = :black)
title!("Capital Structures")
savefig("../documents/images/capital_structures_doc.pdf")
plot(updated_capital.K_EQ , lw = 2, linestyle=:dash,color = :red,
				label = "Updated", legend =:topleft, size = (600, 600))
plot!(dataframe_korv.K_EQ , lw = 2, label = "KORV", color = :black)
title!("Capital Equipment")
savefig("../documents/images/capital_equipment_doc.pdf")
plot(updated_capital.REL_P_EQ, lw = 2, linestyle=:dash,color = :red,
				label = "Updated", legend =:topright, size = (600, 600))
plot!(dataframe_korv.REL_P_EQ, lw = 2, label = "KORV", color = :black)
title!("Relative Price of Equipment")
savefig("../documents/images/capital_price_doc.pdf")

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

dataframe_updated.L_S = vcat([0], L_S_hat)
dataframe_updated.L_U = vcat([0], L_U_hat)

dropmissing!(dataframe_updated)

data_korv = generateData(dataframe_korv);
data_updated_korv = generateData(dataframe_updated[1:30, :]);
data_updated = generateData(dataframe_updated);
data_updated_ind = generateData(dataframe_updated[26:end, :]);

plot(dataframe_updated.YEAR, dataframe_updated.L_SHARE, lw = 2, linestyle=:dash,color = :red,
				label = "Updated", size = (600, 600))
plot!(dataframe_updated.YEAR[1:30], dataframe_korv.L_SHARE, lw = 2, label = "KORV", color = :black)
savefig("../documents/images/fig:labor_share_updated.pdf")


model = intializeModel();


## Estimate model with data from KORV
### Set initial parameter values
scale_initial = 5.5
η_ω_0 = 0.043
param_0 = [0.1, 0.4, -0.5] 
scale_0 = [0.4, 0.4, scale_initial]

sim_korv = solve_optim_prob(data_korv, model, scale_initial, η_ω_0, vcat(param_0, scale_0), tol = 1e-1);

# scale_initial = 2.0
# η_ω_0 = 0.043
# param_0 = [0.1, 0.4, -0.5] 
# scale_0 = [0.4, 0.4, scale_initial]

# sim_updated_korv = solve_optim_prob(data_updated_korv, model, scale_initial, η_ω_0, vcat(param_0, scale_0), tol = 1e-1);
# p_updated_korv = plot_results(sim_korv, data_updated_korv, years = Int64.(dataframe_updated.YEAR[2:30]))

scale_initial = 4.2
η_ω_0 = 0.083
param_0 = [0.1, 0.4, -0.5] 
scale_0 = [0.4, 0.4, scale_initial]

sim_updated = solve_optim_prob(data_updated, model, scale_initial, η_ω_0, vcat(param_0, scale_0), tol = 1e-1);
p_updated = plot_results(sim_updated, data_updated, years = Int64.(dataframe_updated.YEAR[2:end]))


scale_initial = 3.8
η_ω_0 = 0.049
param_0 = [0.1, 0.4, -0.2] 
scale_0 = [0.4, 0.4, scale_initial]

sim_updated_ind = solve_optim_prob(data_updated_ind, model, scale_initial, η_ω_0, vcat(param_0, scale_0), tol = 1e-1);
p_updated_ind = plot_results(sim_updated_ind, data_updated_ind, years = Int64.(dataframe_updated.YEAR[27:end, :]))
plot(p_updated_ind[2],
p_updated_ind[3],
p_updated_ind[4],)

using LaTeXStrings
# Table Parameters
table = hcat(	
				[L"\alpha", L"\sigma",L"\rho", L"\eta_\omega"],
				[0.117, 0.401, -0.495, 0.043],
				round.(hcat([sim_korv.x.α,  sim_korv.x.σ, sim_korv.x.ρ, sim_korv.x.η_ω],
				[sim_updated.x.α, sim_updated.x.σ, sim_updated.x.ρ, sim_updated.x.η_ω],
				[sim_updated_ind.x.α, sim_updated_ind.x.σ, sim_updated_ind.x.ρ, sim_updated_ind.x.η_ω]
				), digits = 3)
)

header = (["", "KORV Estimation", "Replication", "Updated Data", "Updated Data"],
                ["", "\$1963\$ - \$1992\$", "\$1963\$ - \$1992\$", "\$1963\$ - \$2018\$", "\$1988\$ - \$2018\$"]);

latex_table = pretty_table(String,
table,  backend = Val(:latex), header = header, label = "tab:estimation_korv", wrap_table = false)


file = open("../documents/tables/estimation_korv.tex", "w")

write(file, latex_table)

close(file)

# Table Eslasticities
table_2 =  hcat(	[L"\sigma_s", L"\sigma_u"],
					[1 / (1 -(-0.495)), 1 / (1-0.401)],
					hcat(
						[1 / (1-sim_korv.x.ρ), 1 / (1-sim_korv.x.σ)],
						[1 / (1-sim_updated.x.ρ), 1 / (1-sim_updated.x.σ)],
						[1 / (1-sim_updated_ind.x.ρ), 1 / (1-sim_updated_ind.x.σ)]
					)
					)

latex_table_2 = pretty_table(String,
table_2,  backend = Val(:latex), header = header, label = "tab:estimation_korv", wrap_table = false)

file = open("../documents/tables/estimation_elasticities_korv.tex", "w")

write(file, latex_table_2)

close(file)


# Document
p_korv = plot_results(sim_korv, data_korv, years = collect(1963:1991) , scale_font = 1.0)
plot(p_korv[2], size = (600,600) )
savefig("../documents/images/fig:korv_estimation_sp_doc.pdf")
plot(p_korv[3], size = (600,600) )
savefig("../documents/images/fig:korv_estimation_ls_doc.pdf")
plot(p_korv[4], size = (600,600) )
savefig("../documents/images/fig:korv_estimation_wbr_doc.pdf")
p_updated = plot_results(sim_updated, data_updated, years = Int64.(dataframe_updated.YEAR[2:end]), scale_font = 1.0)
plot(p_updated[2], size = (600,600) )
savefig("../documents/images/fig:updated_estimation_sp_doc.pdf")
plot(p_updated[3], size = (600,600) )
savefig("../documents/images/fig:updated_estimation_ls_doc.pdf")
plot(p_updated[4], size = (600,600) )
savefig("../documents/images/fig:updated_estimation_wbr_doc.pdf")
p_updated_ind = plot_results(sim_updated_ind, data_updated_ind, years =  Int64.(dataframe_updated.YEAR[27:end, :]) , scale_font = 1.0)
plot(p_updated_ind[2], size = (600,600) )
savefig("../documents/images/fig:updated_ind_estimation_sp_doc.pdf")
plot(p_updated_ind[3], size = (600,600) )
savefig("../documents/images/fig:updated_ind_estimation_ls_doc.pdf")
plot(p_updated_ind[4], size = (600,600) )
savefig("../documents/images/fig:updated_ind_estimation_wbr_doc.pdf")

# Presentation
p_korv = plot_results(sim_korv, data_korv, years = collect(1963:1991) , scale_font = 1.75)
plot(p_korv[2], size = (600,600) )
savefig("../documents/images/fig:korv_estimation_sp_slides.pdf")
plot(p_korv[3], size = (600,600) )
savefig("../documents/images/fig:korv_estimation_ls_slides.pdf")
plot(p_korv[4], size = (600,600) )
savefig("../documents/images/fig:korv_estimation_wbr_slides.pdf")
p_updated = plot_results(sim_updated, data_updated, years = Int64.(dataframe_updated.YEAR[2:end]) , scale_font = 1.75)
plot(p_updated[2], size = (600,600) )
savefig("../documents/images/fig:updated_estimation_sp_slides.pdf")
plot(p_updated[3], size = (600,600) )
savefig("../documents/images/fig:updated_estimation_ls_slides.pdf")
plot(p_updated[4], size = (600,600) )
savefig("../documents/images/fig:updated_estimation_wbr_slides.pdf")
p_updated_ind = plot_results(sim_updated_ind, data_updated_ind, years = Int64.(dataframe_updated.YEAR[27:end, :]), scale_font = 1.75)
plot(p_updated_ind[2], size = (600,600) )
savefig("../documents/images/fig:updated_ind_estimation_sp_slides.pdf")
plot(p_updated_ind[3], size = (600,600) )
savefig("../documents/images/fig:updated_ind_estimation_ls_slides.pdf")
plot(p_updated_ind[4], size = (600,600) )
savefig("../documents/images/fig:updated_ind_estimation_wbr_slides.pdf")

# Labor data presentation version
plot(updated_labor.L_U , lw = 2, linestyle=:dash,color = :red,
                label = "Updated", legend =:topright, size = (600, 600))
plot!(dataframe_korv.L_U , lw = 2, label = "KORV", color = :black)
title!("Unskilled Labor Input")
savefig("../documents/images/labor_input_unskilled_slides.pdf")
plot(updated_labor.L_S , lw = 2, linestyle=:dash,color = :red,
                label = "Updated", legend =:topright, size = (600, 600))
plot!(dataframe_korv.L_S , lw = 2, label = "KORV", color = :black)
title!("Skilled Labor Input")
savefig("../documents/images/labor_input_skilled_slides.pdf")

wbr_u = (updated_labor.L_S .* updated_labor.W_S ) ./ (updated_labor.L_U .* updated_labor.W_U)
wbr_k = (dataframe_korv.L_S .* dataframe_korv.W_S ) ./ (dataframe_korv.L_U .* dataframe_korv.W_U)
plot(wbr_u , lw = 2, linestyle=:dash,color = :red,
				label = "Updated", legend =:topleft, size = (600, 600))
plot!(wbr_k , lw = 2, label = "KORV", color = :black)
title!("Wage-Bill Ratio")
savefig("../documents/images/wbr_slides.pdf")

sp_u = ( updated_labor.W_S ) ./ ( updated_labor.W_U)
sp_k = ( dataframe_korv.W_S ) ./ ( dataframe_korv.W_U)
plot(sp_u , lw = 2, linestyle=:dash,color = :red,
				label = "Updated", legend =:topleft, size = (600, 600))
plot!(sp_k , lw = 2, label = "KORV", color = :black)
title!("Skill Premium")
savefig("../documents/images/sp_slides.pdf")

# Capital Data (Presentation version)
plot(updated_capital.K_STR , lw = 2, linestyle=:dash,color = :red,
				label = "Updated", legend =:topleft, size = (600, 600))
plot!(dataframe_korv.K_STR , lw = 2, label = "KORV", color = :black)
title!("Capital Structures")
savefig("../documents/images/capital_structures_slides.pdf")
plot(updated_capital.K_EQ , lw = 2, linestyle=:dash,color = :red,
				label = "Updated", legend =:topleft, size = (600, 600))
plot!(dataframe_korv.K_EQ , lw = 2, label = "KORV", color = :black)
title!("Capital Equipment")
savefig("../documents/images/capital_equipment_slides.pdf")
plot(updated_capital.REL_P_EQ, lw = 2, linestyle=:dash,color = :red,
				label = "Updated", legend =:topright, size = (600, 600))
plot!(dataframe_korv.REL_P_EQ, lw = 2, label = "KORV", color = :black)
title!("Relative Price of Equipment")
savefig("../documents/images/capital_price_slides.pdf")

