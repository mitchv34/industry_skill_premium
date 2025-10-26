using CSV
using DataFrames
using StatsBase
using Plots
using StatsPlots

theme(:default) 
default(fontfamily="Computer Modern", framestyle=:box) # LaTex-style


# Load KORV for comparison
KORV = CSV.read("./data/Data_KORV.csv", DataFrame)

capital_data = CSV.read("./data/interim/capital_totl.csv", DataFrame)
gdpdef = CSV.read("./data/raw/gdpdef.csv", DataFrame)
consdef = CSV.read("./data/raw/consdef.csv", DataFrame)
peric = CSV.read("./data/raw/peric.csv", DataFrame)
gdp = CSV.read("./data/raw/gdp.csv", DataFrame)
# Obtain equipment deflator by muiltipliying PERIC by CONSDEF
equip_def = peric.value .* consdef.value


# Obtain implied depreciation rate
## time- varying depreciation rate
δ_st = 1 .- (capital_data.stock_st .- capital_data.dpr_st)./capital_data.stock_st
δ_eq = 1 .- (capital_data.stock_eq .- capital_data.dpr_eq)./capital_data.stock_eq
δ_ip = 1 .- (capital_data.stock_ip .- capital_data.dpr_ip)./capital_data.stock_ip
# constant depreciation rate
δ_st_c =  mean(δ_st[17,:])
δ_eq_c =  mean(δ_eq[17,:])
δ_ip_c =  mean(δ_ip[17,:])

## Obtain initial stock levels using Hall and Jones (1999)
g_st = mean((capital_data.inv_st[2:21] .-capital_data.inv_st[1:20]) ./ capital_data.inv_st[1:20]) # Average geometric growth rate
g_eq = mean((capital_data.inv_eq[2:21] .-capital_data.inv_eq[1:20]) ./ capital_data.inv_eq[1:20]) # Average geometric growth rate
g_ip = mean((capital_data.inv_ip[2:21] .-capital_data.inv_ip[1:20]) ./ capital_data.inv_ip[1:20]) # Average geometric growth rate

K_st_0 = capital_data.inv_st[1] / (g_st + δ_st[1])  # Initial value
K_eq_0 = capital_data.inv_eq[1] / (g_eq + δ_eq[1])  # Initial value
K_ip_0 = capital_data.inv_ip[1] / (g_ip + δ_ip[1])  # Initial value

# Initialize empty vectors for stock levels
K_st = zeros(length(capital_data.year)); K_st[1] = K_st_0 / (gdpdef.value[1]/100) # Initial value
K_eq = zeros(length(capital_data.year)); K_eq[1] = K_eq_0 / equip_def[1]    # Initial value
K_ip = zeros(length(capital_data.year)); K_ip[1] = K_ip_0 / equip_def[1]    # Initial value

# Iteratively calculate stock levels next period
for i ∈ 2:length(capital_data.year)
    K_st[i] = K_st[i-1] * (1 - δ_st[i]) + capital_data.inv_st[i] / (gdpdef.value[i]/100)
    K_eq[i] = K_eq[i-1] * (1 - δ_eq[i]) + capital_data.inv_eq[i] / equip_def[i]
    K_ip[i] = K_ip[i-1] * (1 - δ_ip[i]) + capital_data.inv_ip[i] / equip_def[i]
end

K_st = (K_st / K_st[18]) * KORV.K_STR[1]
K_eq = (K_eq / K_eq[18]) * KORV.K_EQ[1]

## Uncoment to plot results
p1 = plot(capital_data.year, K_st , label = "Updated", lw = 2, c =:red, linestyle = :dash, legend = :topleft)
    plot!(capital_data.year[18:18+29], KORV.K_STR , lw = 2, label = "KORV", c = :black)
title!("Stock of Structures")
xlims!(1964, 2018)


p2 = plot(capital_data.year[18:end], K_eq[18:end] / K_eq[18], label = "Updated", c =:red, lw = 2, linestyle = :dash, legend = :topleft)
    plot!(capital_data.year[18:18+29], KORV.K_EQ / KORV.K_EQ[1], lw = 2, label = "KORV", c=:black)
title!("Stock of Equipment")
xlims!(1964, 2018)

p3 = plot(capital_data.year[18:end],peric.value[18:end] / peric.value[18] , label = "Updated", c = :red, lw = 2, linestyle = :dash)
    plot!(capital_data.year[18:18+29], KORV.REL_P_EQ / KORV.REL_P_EQ[1], lw = 2, label = "KORV", c=:black)
title!("Realtive Price of Equipment")
xlims!(1964, 2018)

savefig(p1, "./documents/images/capital_equipment_doc.pdf")
savefig(p2, "./documents/images/capital_structures_doc.pdf")
savefig(p3, "./documents/images/capital_price_doc.pdf")


p4 = plot(capital_data.year[18:end], δ_st[18:end], label = "Structures", lw = 2)
    plot!(capital_data.year[18:end], δ_eq[18:end], lw = 2, label = "Equipment")
    ylims!(0,0.2)

title!("Depreciation Rates")

# plot(p3, p4, p2, p1, size = (800, 600))
# plot(capital_data.year[18:end], gdp.value[18:end] / gdp.value[18] , label = "Updated", lw = 2, linestyle = :dash)
#     plot!(capital_data.year[18:18+29], KORV.OUTPUT / KORV.OUTPUT[1] , lw = 2, label = "KORV")
# # title!("Realtive Price of Equipment")
gdp_ = ( gdp.value[1:end] / gdp.value[18] ) * KORV.OUTPUT[1]
REL_P_EQ = (peric.value[18:end] / peric.value[18]) * KORV.REL_P_EQ[1]


# Save results to file
final_df = DataFrame(
    [
        :YEAR => capital_data.year[17:end-1],
        :K_STR => K_st[18:end],
        :K_EQ => K_eq[18:end],
        :DPR_STR => δ_st[18:end],
        :DPR_EQ => δ_eq[18:end],
        :REL_P_EQ => REL_P_EQ,
        :OUTPUT =>gdp_[18:end]
    ]
)

CSV.write("./data/proc/capital_totl.csv", final_df)

# plot(final_df.OUTPUT)
# plot!(KORV.OUTPUT)