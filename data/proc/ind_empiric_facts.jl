using CSV
using DataFrames
using Plots
using Plots.PlotMeasures
using StatsPlots
using GLM



theme(:default) 
default(fontfamily="Computer Modern", framestyle=:box) # LaTex-style



file_list = [f for f in readdir("./proc/ind") if occursin("csv", f)]

data_total =  CSV.read("proc/data_updated.csv", DataFrame)

# I want to know the trend of some varia(bles

data = DataFrame()
reg_li_info = Dict()
reg_ls_info = Dict()
reg_sp_info = Dict()
reg_summary = Dict(:IND => [], :LI => [], :SP => [], :LS => [])

for file in file_list
    df = CSV.read("./proc/ind/" * file, DataFrame)
    df[:, :ind] .= file[1: end-4]
    df = df[2:end, :]
    df.t = 1:length(df.YEAR)
    reg_li = lm(@formula(LABOR_INPUT_RATIO ~ 1 + t), df)
    reg_ls = lm(@formula(L_SHARE ~ 1 + t), df)
    reg_sp = lm(@formula(SKILL_PREMIUM ~ 1 + t), df)
    reg_li_info[file[1:end-4]] = Dict("coef" => coef(reg_li)[2], "std_err" => stderror(reg_li)[2] )
    reg_ls_info[file[1:end-4]] = Dict("coef" => coef(reg_ls)[2], "std_err" => stderror(reg_ls)[2] )
    reg_sp_info[file[1:end-4]] = Dict("coef" => coef(reg_sp)[2], "std_err" => stderror(reg_sp)[2] )
    push!(reg_summary[:IND], file[1:end-4])
    push!(reg_summary[:LI], coef(reg_li)[2])
    push!(reg_summary[:LS], coef(reg_ls)[2])
    push!(reg_summary[:SP], coef(reg_sp)[2])
    df.LABOR_INPUT_RATIO_TREND = predict(reg_li, df)
    df.L_SHARE_TREND = predict(reg_ls, df)
    df.SKILL_PREMIUM_TREND = predict(reg_sp, df)
    data = vcat(data, df)
end

reg_summary = DataFrame(reg_summary)

reg_summary.LI = Float64.(reg_summary.LI)
reg_summary.LS = Float64.(reg_summary.LS)
reg_summary.SP = Float64.(reg_summary.SP)

function plot_correlations(df::DataFrame, variables::Array{Symbol}; title = "", xlabel = "", ylabel = "", level =  0.95)

    reg_formula = Term(variables[1]) ~ sum( term.(vcat([1], variables[2:end]) ) )

    reg_ = lm(reg_formula, df)
    @show reg_
    pred = predict(reg_, reg_summary, interval = :confidence, level = level)

    pred.x = reg_summary[:, variables[2]]

    sort!(pred, :x)

    # Set default title
    title = ( title == "" ) ? "$(variables[1]) vs $(variables[2]) " : title
    # Set default xlabel
    xlabel = ( xlabel == "" ) ? "$(variables[1])" : xlabel
    # Set default ylabel
    ylabel = ( ylabel == "" ) ? "$(variables[2])" : ylabel

    # p = @df df scatter(variables[1], variables[2],
    p = scatter( df[:, variables[2]], df[:, variables[1]], smooth = true,
    alpha = 0.5, xlabel = xlabel, ylabel = ylabel, title = title, label = "",
        markerstrokealpha = 1.0, markerstrokewidth=3, markercolor = :black, markersize = 6.5, framestyle = :zerolines)
    
        plot!(pred.x , pred.prediction, color = :red, linewidth = 2,  label = "",
        ribbon = (pred.prediction .- pred.lower, pred.upper .- pred.prediction),  fillalpha=.2)

    return p

end # plot_correlations


p1 = plot_correlations(reg_summary, [:LS, :LI], title = "", xlabel = "", ylabel = "", level =  0.95)
p2 = plot_correlations(reg_summary, [:LS, :SP]) #; title = "", xlabel = "", ylabel = "", level =  0.95)
p3 = plot_correlations(reg_summary, [:SP, :LI]) #; title = "", xlabel = "", ylabel = "", level =  0.95)


cwalk = CSV.read("./cross_walk.csv", DataFrame)

data


# Plot the Labor input ratio whole economy
@df data_total plot(:LABOR_INPUT_RATIO_TREND, lw = 2, label = "")

# @df data plot(:YEAR, :LABOR_INPUT_RATIO_G , group =:ind, :lw = 2, label = "")


for i in eachrow(cwalk)
    ind_code = i.code_klems
    ind_name = i.ind_desc

    sub_df = subset(data, :ind => ByRow(==(ind_code)))

    if size(sub_df)[1] == 0
        continue
    end   

    coef_li = round( reg_li_info[ind_code]["coef"], digits =3 ) 
    coef_ls = round( reg_ls_info[ind_code]["coef"], digits =3 ) 
    coef_sp = round( reg_sp_info[ind_code]["coef"], digits =3 ) 
    p_li = Plots.plot(sub_df.YEAR, sub_df.LABOR_INPUT_RATIO, lw = 2, color=:black, linestyle = :solid,
    title="$ind_name", 
    xlabel="Year", ylabel="Ratio", label = "")
    co_li = ( coef_li > 0.0009 ) ? :red : :blue
    plot!(sub_df.YEAR, sub_df.LABOR_INPUT_RATIO_TREND, lw = 2, color=co_li, linestyle = :dash, label = "")
    p_ls = Plots.plot(sub_df.YEAR, sub_df.L_SHARE, lw = 2, color=:black, linestyle = :solid,
    title="$ind_name", 
    xlabel="Year", ylabel="Ratio", label = "")
    co_ls = ( coef_ls > 0.0009 ) ? :red : :blue
    plot!(sub_df.YEAR, sub_df.L_SHARE_TREND, lw = 2, color=co_ls, linestyle = :dash, label = "")
    p_sp = Plots.plot(sub_df.YEAR, sub_df.SKILL_PREMIUM, lw = 2, color=:black, linestyle = :solid,
    title="$ind_name", 
    xlabel="Year", ylabel="Ratio", label = "")
    co_sp = ( coef_sp > 0.0009 ) ? :red : :blue
    plot!(sub_df.YEAR, sub_df.SKILL_PREMIUM_TREND, lw = 2, color=co_sp, linestyle = :dash, label = "")
    prefix_li = ( co_li == :red ) ? "inc" : "dec"
    prefix_ls = ( co_ls == :red ) ? "inc" : "dec"
    prefix_sp = ( co_sp == :red ) ? "inc" : "dec"
    


    savefig(p_li, "/Users/mitchv34/Work/industry_skill_premium/documents/images/industries/labor_input_ratio/$prefix_li$(ind_code).pdf")
    savefig(p_ls, "/Users/mitchv34/Work/industry_skill_premium/documents/images/industries/labor_share/$prefix_ls$(ind_code).pdf")
    savefig(p_sp, "/Users/mitchv34/Work/industry_skill_premium/documents/images/industries/skill_premium/$prefix_sp$(ind_code).pdf")
end   


    for i in eachrow(cwalk)
    ind_code = i.code_klems
    ind_name = i.ind_desc

    sub_df = subset(data, :ind => ByRow(==(ind_code)))

    title = Plots.plot(title = "$(ind_name)", framestyle=nothing,
    showaxis=false,xticks=false,yticks=false,  margin = -1.5mm)
    
    p1 = Plots.plot(sub_df.YEAR[2:end], sub_df.LABOR_INPUT_RATIO[2:end], lw = 2, color=:black, title="Labor Input Ratio", 
    xlabel="Year", ylabel="Ratio", label = "")
    p2 = Plots.plot(sub_df.YEAR[2:end], sub_df.SKILL_PREMIUM[2:end], lw = 2, color=:black, title="Skill Premium", 
    xlabel="Year", ylabel="Ratio", label = "")
    p = Plots.plot(title, p1, p2, layout = @layout([A{0.01h}; [B; C]]))
    savefig("./documents/images/industries/labor_input_skill_premium/$(ind_code).pdf")
end    

for year in unique(data.YEAR)
    sub_df = subset(data, :YEAR => ByRow(==(year)))
    title = Plots.plot(title = "$(year)", framestyle=nothing,
    showaxis=false,xticks=false,yticks=false,  margin = -1.5mm)
    Plots.scatter(log.(sub_df.LABOR_INPUT_RATIO), log.(sub_df.SKILL_PREMIUM), lw = 2, color=:black)
    ylims!(0, 1.6)
    xlims!(0, 2.1)
    savefig("./documents/images/industries/labor_input_skill_premium/$(year).pdf")
end

dropmissing!(data)

@df subset(data, :YEAR => ByRow(==(2000))) density(:SKILL_PREMIUM)