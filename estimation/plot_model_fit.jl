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

years = 1988:2018

for i ∈ 1:length(codes)
    try
ind_code = codes[i]
ind_name = names[i]
# Read estimated parameters
params = CSV.read("./data/results/ind_est/$(ind_code).csv", DataFrame)

params = setParams(
    [params.alpha[1], params.sigma[1], params.rho[1], params.eta[1]],
    [params.mu[1], params.lambda[1], params.phi_L[1], params.phi_H[1]]
    )

path_data = "./data/proc/ind/$(ind_code).csv";

dataframe = CSV.read(path_data, DataFrame);

data = generateData(dataframe);
T = length(data.y) # Time horizon
# Genrate shocks
shocks = generateShocks(params, T);
# Update model

update_model!(model, params)
# Evaluate model
model_results = evaluateModel(0, model, data, params, shocks)


# Plots.theme(:vibrant); # :dark, :light, :plain, :grid, :tufte, :presentation, :none
# if scale_font != 1 
#     default(fontfamily="Helvetica", framestyle=:box ); # LaTex-style1
# else
#     default(fontfamily="Computer Modern", framestyle=:box ); # LaTex-style1
# end
# Plots.scalefontsizes(scale_font)

# Plot results:
p1 = plot( years, model_results[:rr] .*  data.q[1:end-1], lw = 2, linestyle=:dash,color = :red,
            label = "Model", legend =:topright, size = (800, 200))
plot!(years, data.rr .* data.q[1:end-1], lw = 2, label = "Data", color = :black)
title!("Relative Price of Equipment")
ω_model = model_results[:ω]
p2 = plot(years, ω_model , lw = 2,  linestyle=:dash, color = :red,
label = "Model", legend =:topleft,size = (800, 400))
ω_data =  data.w_h[2:end] ./ data.w_ℓ[2:end]
plot!(years, ω_data   , lw = 2, label = "Data", color = :black)
# title!("Skill Premium")

p3 = plot(years, model_results[:lbr], lw = 2,  linestyle=:dash, color = :red, label = "Model", legend =:topleft,size = (800, 400))
plot!(years, data.lsh[2:end], lw = 2, label = "Data", color = :black)
y_max = max( maximum( model_results[:lbr] ), maximum(data.lsh[2:end]) ) .* 1.05
y_min = min( minimum(model_results[:lbr] ) , minimum(data.lsh[2:end]) ).* 0.95
ylims!(y_min*0.65, min(y_max*1.35, 1.0))
# title!("Labor Share of Output")

wbr_model = model_results[:wbr]
p4 = plot(years, wbr_model, lw = 2,  linestyle=:dash, color = :red, label = "Model", legend =:topleft,size = (800, 400))
wbr_data = data.wbr[2:end]
plot!(years, wbr_data , lw = 2, label = "Data", color = :black)
title!(ind_name)

plot(p3, p4, p2, layout = (1,3), size = (900, 300))

savefig("./documents/images/model_fit/$(ind_code).pdf")
    catch
        continue
    end
end # end of loop over industries

# Generate an inport .tex file
import_Tex = []
files = [f for f in readdir("./documents/images/model_fit/") if occursin(".pdf", f)]
for i in 1:length(files)
    file = files[i]
    if i % 4 == 1
        push!(import_Tex, "\\begin{figure}[H]\n\\centering")
    end
    push!(import_Tex, "\\includegraphics[width=0.97\\textwidth]{../images/model_fit/$(file)}")
    if i % 4 == 0
        push!(import_Tex, "\\end{figure}\\pagebreak\n")
    end
end
if ~occursin("\\end{figure}", import_Tex[end])
    push!(import_Tex, "\\end{figure}")
end

import_Tex = join(import_Tex, "\n")


file = open("./documents/images/model_fit/industries.tex", "w")

write(file, import_Tex)

close(file)


# Generate an inport .tex file
import_Tex = []
table_begin = """\\begin{table}[H]
\\begin{center}
\\begin{tabular}{lcccc}
\\hline\\hline 
& \$ \\sigma\$ & \$\\rho\$ & \$\\sigma_s\$ & \$\\sigma_s \$ \\\\\\hline"""

end_table = """\\end{tabular}
\\end{center}
\\end{table}"""

results = [f for f in readdir("./data/results/ind_est") if occursin(".csv", f)]
## Load estimation results
for i ∈ 1:length(codes)
    # try
    if i%30 == 1
        push!(import_Tex, table_begin)
    end
    ind_code = codes[i]
    ind_name = names[i]
    try
    params = CSV.read("./data/results/ind_est/$(ind_code).csv", DataFrame)
    catch
        continue
    end
    sigma = params.sigma[1]
    rho = params.rho[1]
    sigma_s = 1 / ( 1 - rho )
    sigma_u = 1 / (1 - sigma )
    push!(import_Tex, "$ind_name & $(round(sigma, digits=3)) & $(round(rho, digits=3)) & $(round(sigma_s, digits=3)) & $(round(sigma_u, digits=3)) \\\\")
    if i%30 == 0
        push!(import_Tex, end_table)
    end
end

push!(import_Tex, end_table)


import_Tex = join(import_Tex, "\n")


file = open("./documents/tables/params_ind_estimates.tex", "w")

write(file, import_Tex)

close(file)