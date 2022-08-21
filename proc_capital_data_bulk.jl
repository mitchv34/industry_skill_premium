using CSV
using DataFrames
using StatsBase
using JSON
using Term
using Plots # Dont really need this 
using StatsPlots # Or this

# Get industry codes
ind_code_dict = JSON.parse(read("./extend_KORV/data/interim/equi_bea_naics.json", String))

gdpdef = CSV.read("extend_KORV/data/raw/gdpdef.csv", DataFrame)
consdef = CSV.read("extend_KORV/data/raw/consdef.csv", DataFrame)
peric = CSV.read("extend_KORV/data/raw/peric.csv", DataFrame)
gdp = CSV.read("extend_KORV/data/raw/gdp.csv", DataFrame)

# Obtain equipment deflator by muiltipliying PERIC by CONSDEF
equip_def = peric.value .* consdef.value


for ind_ ∈ keys(ind_code_dict)
    try
        capital_data = CSV.read("extend_KORV/data/interim/capital_$(ind_).csv", DataFrame)
        println(@green @bold "Succes rocessing capital data for industry: $(ind_)")
        # Obtain implied depreciation rate
        ## time- varying depreciation rate
        δ_st = 1 .- (capital_data.stock_st .- capital_data.dpr_st)./capital_data.stock_st
        δ_eq = 1 .- (capital_data.stock_eq .- capital_data.dpr_eq)./capital_data.stock_eq
        δ_ip = 1 .- (capital_data.stock_ip .- capital_data.dpr_ip)./capital_data.stock_ip
        δ_st = [(isnan(δ)) ? 0 : δ for δ in δ_st]
        δ_eq = [(isnan(δ)) ? 0 : δ for δ in δ_eq]
        δ_ip = [(isnan(δ)) ? 0 : δ for δ in δ_ip]
        # constant depreciation rate
        δ_st_c =  mean(δ_st[17:end])
        δ_eq_c =  mean(δ_eq[17:end])
        δ_ip_c =  mean(δ_ip[17:end])

        ## Obtain initial stock levels using Hall and Jones (1999)
        g_st = mean((capital_data.inv_st[2:21] .-capital_data.inv_st[1:20]) ./ capital_data.inv_st[1:20]) # Average geometric growth rate
        g_eq = mean((capital_data.inv_eq[2:21] .-capital_data.inv_eq[1:20]) ./ capital_data.inv_eq[1:20]) # Average geometric growth rate
        g_ip = mean((capital_data.inv_ip[2:21] .-capital_data.inv_ip[1:20]) ./ capital_data.inv_ip[1:20]) # Average geometric growth rate

        K_st_0 = capital_data.inv_st[1] / (g_st + δ_st[1])  # Initial value
        K_st_0 = (isnan(K_st_0)) ? 0 : K_st_0
        K_eq_0 = capital_data.inv_eq[1] / (g_eq + δ_eq[1])  # Initial value
        K_eq_0 = (isnan(K_eq_0)) ? 0 : K_eq_0
        K_ip_0 = capital_data.inv_ip[1] / (g_ip + δ_ip[1])  # Initial value
        K_ip_0 = (isnan(K_ip_0)) ? 0 : K_ip_0

        # Initialize empty vectors for stock levels
        K_st = zeros(length(capital_data.year)); K_st[1] = K_st_0 / (gdpdef.value[1]/100) # Initial value
        K_eq = zeros(length(capital_data.year)); K_eq[1] = K_eq_0 / equip_def[1]    # Initial value
        K_ip = zeros(length(capital_data.year)); K_ip[1] = K_ip_0 / equip_def[1]    # Initial value

        # Iteratively calculate stock levels next period
        for i ∈ 2:length(capital_data.year)
            K_st[i] = K_st[i-1] * (1 - δ_st[i]) + capital_data.inv_st[i] / gdpdef.value[i]
            K_eq[i] = K_eq[i-1] * (1 - δ_eq[i]) + capital_data.inv_eq[i] / equip_def[i]
            K_ip[i] = K_ip[i-1] * (1 - δ_ip[i]) + capital_data.inv_ip[i] / equip_def[i]
        end


        # Save results to file
        final_df = DataFrame(
            [
                :YEAR => capital_data.year,
                :K_STR => K_st,
                :K_EQ => K_eq,
                :REL_P_EQ => peric.value,
                :DPR_ST => δ_st,
                :DPR_EQ => δ_eq
            ]
        )

        CSV.write("./extend_KORV/data/interim/ind_capital/$(ind_).csv", final_df)

    catch
        println(@red @bold "Failed to process capital data for industry: $(ind_)")
    end
end
