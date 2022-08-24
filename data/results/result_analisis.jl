using CSV
using DataFrames
using Plots
using StatsBase

files = [f for f in readdir("./data/results/") if occursin(".csv", f)]

ind_dict = Dict()
for f in files
    temp = CSV.read("./data/results/$(f)", DataFrame)
    filter!(row -> all(x -> !(x isa Number && isnan(x)), row), temp)
    ind_dict[f[1:end-4]] = temp
end

# Give me the best fit for each industry
best_fit = Dict()
for(k, v) in ind_dict
    i = argmax(v.fit_sp)
    best_fit[k] = Vector(v[i, [:sigma_0, :rho_0, :eta_0, :mu_0, :lambda_0, :phi_L_0, :phi_H_0, 
    :sigma, :rho, :eta, :mu, :lambda, :phi_L, :phi_H]])
end

best_fit

d = ind_dict["327"]