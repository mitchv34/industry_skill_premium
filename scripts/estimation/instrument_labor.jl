using CSV
using DataFrames
using GLM


# Load data

poly(x, n) = x^n


path_data = "./data/proc/ind"

file_list = [f for f in readdir(path_data) if occursin(".csv", f)]

formula_W_S = @formula( W_S ~ trend  + K_EQ + K_STR + K_EQ_lagged + K_STR_lagged + Q_lagged)
formula_W_U = @formula( W_U ~ trend  + K_EQ + K_STR + K_EQ_lagged + K_STR_lagged + Q_lagged)
formula_L_S = @formula( L_S ~ trend  + K_EQ + K_STR + K_EQ_lagged + K_STR_lagged + Q_lagged)
formula_L_U = @formula( L_U ~ trend  + K_EQ + K_STR + K_EQ_lagged + K_STR_lagged + Q_lagged)

# data_dict = Dict()

for file in file_list
    data = CSV.read(path_data * "/" * file, DataFrame)
    # @show data

    ## Instrument L_S and L_U ######
    data_for_reg = DataFrame(
        [
            :W_S => data.W_S[2:end],
            :W_U => data.W_U[2:end],
            :L_S => data.L_S[2:end],
            :L_U => data.L_U[2:end],
            :trend => 1:length(data.L_S[2:end]),
            :K_EQ => data.K_EQ[2:end],
            :K_STR => data.K_STR[2:end],
            :K_EQ_lagged => data.K_EQ[1:end-1],
            :K_STR_lagged => data.K_STR[1:end-1],
            :Q_lagged => data.REL_P_EQ[1:end-1],
        ]
    )

    ## Run regression  first stage for L_S and L_U ######
    reg_L_S = lm(formula_L_S,  data_for_reg)
    reg_L_U = lm(formula_L_U,  data_for_reg)
    reg_W_S = lm(formula_W_S,  data_for_reg)
    reg_W_U = lm(formula_W_U,  data_for_reg)
    
    L_S_hat = predict(reg_L_S, data_for_reg)
    L_U_hat = predict(reg_L_U, data_for_reg)
    W_S_hat = predict(reg_W_S, data_for_reg)
    W_U_hat = predict(reg_W_U, data_for_reg)
    

    # L_S_hat = ( L_S_hat./L_S_hat[1] ) *  data_for_reg.L_S[1]
    # L_U_hat = ( L_U_hat./L_U_hat[1] ) *  data_for_reg.L_U[1]

    data.L_S = vcat([0], L_S_hat)
    data.L_U = vcat([0], L_U_hat)
    data.W_S = vcat([0], W_S_hat)
    data.W_U = vcat([0], W_U_hat)

    # data_dict[file[1:end-4]] = data
    print(path_data * "/" * file )
    CSV.write(path_data * "/" * file, data)
end



##  Sanity check plots ###### Must uncomment data_dict lines above
# begin
#     i = "5415"
#     p1 = plot(data_dict[i].YEAR[2:end], data_dict[i].L_S[2:end], lw = 2, label = "L_S", legend=:top)
#     plot!(data_dict[i].YEAR[2:end], data_dict[i].L_S_hat[2:end], lw = 2, label = "L_S_hat")

#     p2 = plot(data_dict[i].YEAR[2:end], data_dict[i].L_U[2:end], lw = 2, label = "L_U", legend=:top)
#     plot!(data_dict[i].YEAR[2:end],     data_dict[i].L_U_hat[2:end], lw = 2, label = "L_U_hat")

#     p3 = plot(data_dict[i].YEAR[2:end], data_dict[i].W_S[2:end], lw = 2, label = "W_S", legend=:topleft)
#     plot!(data_dict[i].YEAR[2:end], data_dict[i].W_S_hat[2:end], lw = 2, label = "W_S_hat")
    
#     p4 = plot(data_dict[i].YEAR[2:end], data_dict[i].W_U[2:end], lw = 2, label = "W_U", legend=:topleft)
#     plot!(data_dict[i].YEAR[2:end], data_dict[i].W_U_hat[2:end], lw = 2, label = "W_U_hat")

#     plot(p1, p2, p3, p4)
# end

# begin
#     sp_original = data_dict[i].W_S[2:end] ./ data_dict[i].W_U[2:end]
#     sp_hat = data_dict[i].W_S_hat[2:end] ./ data_dict[i].W_U_hat[2:end]
    
#     wbr_original = (data_dict[i].W_S .* data_dict[i].L_S)[2:end] ./ (data_dict[i].W_U .* data_dict[i].L_U)[2:end]
#     wbr_hat      = (data_dict[i].W_S_hat .* data_dict[i].L_S_hat)[2:end] ./ (data_dict[i].W_U_hat .* data_dict[i].L_U_hat)[2:end]
    

#     p1 = plot(data_dict[i].YEAR[2:end], sp_original, lw = 2, label = "SP", legend=:topleft)
#     plot!(data_dict[i].YEAR[2:end], sp_hat, lw = 2, label = "SP hat")

#     p2 = plot(data_dict[i].YEAR[2:end], wbr_original, lw = 2, label = "WBR", legend=:topleft)
#     plot!(data_dict[i].YEAR[2:end],    wbr_hat, lw = 2, label = "WBR hat")

#     plot(p1, p2)
# end
