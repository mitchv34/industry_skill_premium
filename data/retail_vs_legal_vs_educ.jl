using CSV
using DataFrames
using Plots
using Plots.PlotMeasures
using StatsPlots
using GLM
using TexTables
using LaTeXStrings
using Statistics
using StatsPlots


theme(:default) 
default(fontfamily="Computer Modern", framestyle=:box) # LaTex-style

cwalk = CSV.read("./data/cross_walk.csv", DataFrame)
cwalk_dict = Dict(zip(cwalk.code_klems, cwalk.ind_desc))

code_retail = "44RT"
data_retail = CSV.read("./data/proc/ind/$(code_retail).csv", DataFrame)
data_retail = data_retail[2:end, :]
code_legal = "525"
data_legal = CSV.read("./data/proc/ind/$(code_legal).csv", DataFrame)
data_legal = data_legal[2:end, :]
educ_code = "213"
data_educ = CSV.read("./data/proc/ind/$(educ_code).csv", DataFrame)
data_educ = data_educ[2:end, :]

LI_retail = data_retail.L_S ./ data_retail.L_U
LI_legal = data_legal.L_S ./ data_legal.L_U
LI_educ = data_educ.L_S ./ data_educ.L_U

p1 = plot(data_retail.YEAR, (LI_retail .- LI_retail[1]) / LI_retail[1] , label="$(cwalk_dict[code_retail])", color=:black, lw=2, legend = :topleft)
plot!(data_legal.YEAR, (LI_legal .- LI_legal[1]) / LI_legal[1] , label="$(cwalk_dict[code_legal])", color=:red, lw=2)
plot!(data_educ.YEAR, (LI_educ .- LI_educ[1]) / LI_educ[1] , label="$(cwalk_dict[educ_code])", color=:blue, lw=2)

SP_retail = data_retail.W_S ./ data_retail.W_U
SP_legal = data_legal.W_S ./ data_legal.W_U
SP_educ = data_educ.W_S ./ data_educ.W_U

p2 = plot(data_retail.YEAR, (SP_retail .- SP_retail[1]) / SP_retail[1] , label="$(cwalk_dict[code_retail])", color=:black, lw=2, legend = :topleft)
plot!(data_legal.YEAR, (SP_legal .- SP_legal[1]) / SP_legal[1] , label="$(cwalk_dict[code_legal])", color=:red, lw=2)
plot!(data_educ.YEAR, (SP_educ .- SP_educ[1]) / SP_educ[1] , label="$(cwalk_dict[educ_code])", color=:blue, lw=2)

plot(p1, p2, size =(800, 400) )