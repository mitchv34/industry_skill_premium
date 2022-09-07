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
using PrettyTables

theme(:default) 
default(fontfamily="Computer Modern", framestyle=:box) # LaTex-style

cwalk = CSV.read("./data/cross_walk.csv", DataFrame)

file_list = [f for f in readdir("./data/proc/ind") if occursin("csv", f)]

data_total =  CSV.read("./data/proc/data_updated.csv", DataFrame)

# I want to know the trend of some varia(bles

data = DataFrame()
reg_li_info = Dict()
reg_ls_info = Dict()
reg_sp_info = Dict()
reg_kr_info = Dict()
reg_summary = Dict(:IND => [], :LI => [], :SP => [], :LS => [], :KR => [])
reg_objects = [[], [], [], []]
ls_dec = []
for file in file_list
    df = CSV.read("./data/proc/ind/" * file, DataFrame)
    df[:, :ind] .= file[1: end-4]
    df = df[2:end, :]
    df.K_RATIO = df.K_EQ ./ df.K_STR
    df.t = 1:length(df.YEAR)
    reg_li = lm(@formula(LABOR_INPUT_RATIO ~ 1 + t), df)
    reg_ls = lm(@formula(L_SHARE ~ 1 + t), df)
    reg_sp = lm(@formula(SKILL_PREMIUM ~ 1 + t), df)
    reg_kr = lm(@formula(K_RATIO ~ 1 + t), df)
    # TEsting something
    df.LABOR_INPUT_RATIO = df.L_S ./ df.L_U
    df.SKILL_PREMIUM = df.W_S ./ df.W_U
    if df.L_SHARE[end] <= df.L_SHARE[1]
        push!(ls_dec, (df.L_SHARE[end] - df.L_SHARE[1] ) /  df.L_SHARE[1])
    end
    reg_li_info[file[1:end-4]] = Dict("coef" => coef(reg_li)[2], "std_err" => stderror(reg_li)[2] )
    reg_ls_info[file[1:end-4]] = Dict("coef" => coef(reg_ls)[2], "std_err" => stderror(reg_ls)[2] )
    reg_sp_info[file[1:end-4]] = Dict("coef" => coef(reg_sp)[2], "std_err" => stderror(reg_sp)[2] )
    reg_kr_info[file[1:end-4]] = Dict("coef" => coef(reg_kr)[2], "std_err" => stderror(reg_kr)[2] )
    push!(reg_summary[:IND], file[1:end-4])
    push!(reg_summary[:LI], coef(reg_li)[2])
    push!(reg_summary[:LS], coef(reg_ls)[2])
    push!(reg_summary[:SP], coef(reg_sp)[2])
    push!(reg_summary[:KR], coef(reg_kr)[2])
    push!(reg_objects[1], reg_li)
    push!(reg_objects[2], reg_ls)
    push!(reg_objects[3], reg_sp)
    push!(reg_objects[4], reg_kr)
    df.LABOR_INPUT_RATIO_TREND = predict(reg_li, df)
    df.L_SHARE_TREND = predict(reg_ls, df)
    df.SKILL_PREMIUM_TREND = predict(reg_sp, df)
    df.K_RATIO_TREND = predict(reg_kr, df)
    data = vcat(data, df)
end


reg_summary = DataFrame(reg_summary)

reg_summary.LI = Float64.(reg_summary.LI)
reg_summary.LS = Float64.(reg_summary.LS)
reg_summary.SP = Float64.(reg_summary.SP)
reg_summary.KR = Float64.(reg_summary.KR)


# file = open("../documents/tables/industry_trends_summary.tex", "w")

# write(file, latex_table)

# close(file)

# # Table Eslasticities
# table =  hcat(	[L"\sigma_s", L"\sigma_u"],
# 					[1 / (1 -(-0.495)), 1 / (1-0.401)],
# 					hcat(
# 						[1 / (1-sim_korv.x.ρ), 1 / (1-sim_korv.x.σ)],
# 						[1 / (1-sim_updated.x.ρ), 1 / (1-sim_updated.x.σ)],
# 						[1 / (1-sim_updated_ind.x.ρ), 1 / (1-sim_updated_ind.x.σ)]
# 					)
# 					)

# latex_table_2 = pretty_table(String,
# table_2,  backend = Val(:latex), header = header, label = "tab:estimation_korv", wrap_table = false)

# file = open("../documents/tables/estimation_elasticities_korv.tex", "w")

# write(file, latex_table_2)

# close(file)


# Remove industry Rental and leasing services and lessors of intangible assets,532RL,

filter!(:IND => x-> x != "532RL", reg_summary)

function plot_correlations(df::DataFrame, variables::Array{Symbol}; title = "", xlabel = "", ylabel = "", level =  0.95, scale_font = 1)


    Plots.theme(:vibrant); # :dark, :light, :plain, :grid, :tufte, :presentation, :none
    if scale_font != 1 
        default(fontfamily="Helvetica", framestyle=:box ); # LaTex-style1
    else
        default(fontfamily="Computer Modern", framestyle=:box ); # LaTex-style1
    end
    Plots.scalefontsizes(scale_font)

    reg_formula = Term(variables[1]) ~ sum( term.(vcat([1], variables[2:end]) ) )

    reg_ = lm(reg_formula, df)
    @show reg_
    pred = predict(reg_, df, interval = :confidence, level = level)

    pred.x = df[:, variables[2]]


    # Set default title
    title = ( title == "" ) ? "$(variables[2]) vs $(variables[1]) " : title
    # Set default xlabel
    xlabel = ( xlabel == "" ) ? "$(variables[2])" : xlabel
    # Set default ylabel
    ylabel = ( ylabel == "" ) ? "$(variables[1])" : ylabel

    # p = @df df scatter(variables[1], variables[2],
    p = scatter( df[:, variables[2]], df[:, variables[1]], smooth = false,
    alpha = 0.5, xlabel = xlabel, ylabel = ylabel, title = title, label = "",
        markerstrokealpha = 1.0, markerstrokewidth=3, markercolor = :black, markersize = 6.5, framestyle = :zerolines)
    
        plot!(pred.x , pred.prediction, color = :red, linewidth = 2,  label = "",
        ribbon = (pred.prediction .- pred.lower, pred.upper .- pred.prediction),  fillalpha=.2)
        
    # ylims!(-0.02, 0.037)
    # xlims!(-0.03, 0.11)
    return p, reg_

end # plot_correlations


# . = plot_correlations(reg_summary, [:LS, :LI], title = "", xlabel = "Labor Share", ylabel   = "Labor Input Ratio", level =  0.)
# p2 = plot_correlations(reg_summary, [:LS, :SP], title = "", xlabel = "Labor Share", ylabel   = "Skill Premium", level =  0.)


function plot_correlations(data::DataFrame, years::Array{Int64}, variables::Array{Symbol}; title = "", xlabel = "", ylabel = "", scale_font = 1)


    colors = [:red, :green, :orange, :purple, :yellow, :pink, :brown, :gray, :magenta, :cyan]
    Plots.theme(:vibrant); # :dark, :light, :plain, :grid, :tufte, :presentation, :none
    if scale_font != 1 
        default(fontfamily="Helvetica", framestyle=:box ); # LaTex-style1
    else
        default(fontfamily="Computer Modern", framestyle=:box ); # LaTex-style1
    end
    Plots.scalefontsizes(scale_font)
    
    reg_formula = Term(variables[1]) ~ sum( term.(vcat([1], variables[2:end]) ) )

    # Set default title
    # title = ( title == "" ) ? "$(variables[2]) vs $(variables[1]) " : title
    # Set default xlabel
    xlabel = ( xlabel == "" ) ? "$(variables[2])" : xlabel
    # Set default ylabel
    ylabel = ( ylabel == "" ) ? "$(variables[1])" : ylabel

    p = plot( xlabel = xlabel, ylabel = ylabel, title = title, legend = :topleft)
    for i ∈ eachindex(years)
        year = years[i]
        df = subset(data, :YEAR =>  ByRow(==(year)))
        reg_ = lm(reg_formula, df)
        @show reg_
        pred = predict(reg_, df,  interval = :confidence, level = 0)
        pred.x = df[:, variables[2]]

        sort!(pred, :x)


    # p = @df df scatter(variables[1], variables[2],
        scatter!( df[:, variables[2]], df[:, variables[1]], smooth = false, alpha = 0.5, label = "$(year)", markerstrokecolor = colors[i],
            markerstrokealpha = 0.0, markerstrokewidth=3, markercolor = colors[i], markersize = 6.5, framestyle = :box)
    
        plot!(pred.x , pred.prediction, color = colors[i], linewidth = 2,  label = "",
        ribbon = (pred.prediction .- pred.lower, pred.upper .- pred.prediction),  fillalpha=.2)
    end
    return p

end # plot_correlations

# savefig(., "/Users/mitchv34/Work/industry_skill_premium/documents/images/fig_correlations_guide.pdf")

# . = plot_correlations(reg_summary, [:SP, :LI], title = L"$1988$ - $2018$", xlabel = "(slope) Skill Premium", ylabel = "(slope) Labor Input Ratio", level = 0.)
# p2 = plot_correlations(reg_summary, [:SP, :LI], title = "1988 - 2018", xlabel = "(slope) Skill Premium", ylabel = "(slope) Labor Input Ratio", level = 0., scale_font = 1.5)

# savefig(., "/Users/mitchv34/Work/industry_skill_premium/documents/images/trend_correlation_doc.pdf")
# savefig(p2, "/Users/mitchv34/Work/industry_skill_premium/documents/images/trend_correlation_slides.pdf")

# p3 = plot_correlations(data, [1993, 2018], [:LABOR_INPUT_RATIO, :SKILL_PREMIUM]; title = "", xlabel = "Skill Premium", ylabel = "Labor Input Ratio", scale_font = 1)
# p4 = plot_correlations(data, [1993, 2018], [:LABOR_INPUT_RATIO, :SKILL_PREMIUM]; title = "", xlabel = "Skill Premium", ylabel = "Labor Input Ratio", scale_font = 1.5)

# savefig(p3, "/Users/mitchv34/Work/industry_skill_premium/documents/images/correlation_lisp_doc.pdf")
# savefig(p4, "/Users/mitchv34/Work/industry_skill_premium/documents/images/correlation_lisp_slides.pdf")

# # data

p1 = plot_correlations(reg_summary, [:KR, :SP],  title = "1988 - 2018", xlabel = "(slope) Skill Premium", ylabel   = "Capital Input Ratio", level = 0.)
p2 = plot_correlations(reg_summary, [:KR, :LI], title = L"$1988$ - $2018$", level = 0.)

savefig(p1, "/Users/mitchv34/Work/industry_skill_premium/documents/images/trend_correlation_2_doc.pdf")

@df reg_summary scatter(:LI, :KR, smooth = true, alpha = 0.5, xlabel = "LI", ylabel = "KR", title = "1988 - 2018", label = "",
    markerstrokealpha = 1.0, markerstrokewidth=3, markercolor = :black, markersize = 6.5, framestyle = :zerolines)
ylims!(-0.01, 0.2)

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
    y_max = maximum([y for y in sub_df.LABOR_INPUT_RATIO if ~ismissing(y)])
    y_min = minimum([y for y in sub_df.LABOR_INPUT_RATIO if ~ismissing(y)])
    ylims!(y_min * 0.2, y_max * 1.1)
    co_li = ( coef_li > 0.0009 ) ? :red : :blue
    plot!(sub_df.YEAR, sub_df.LABOR_INPUT_RATIO_TREND, lw = 2, color=co_li, linestyle = :dash, label = "")
    p_ls = Plots.plot(sub_df.YEAR, sub_df.L_SHARE, lw = 2, color=:black, linestyle = :solid,
    title="$ind_name", 
    xlabel="Year", ylabel="Ratio", label = "")
    # y_max = maximum([y for y in sub_df.L_SHARE if ~ismissing(y)])
    # y_min = minimum([y for y in sub_df.L_SHARE if ~ismissing(y)])
    # ylims!(y_min * 0.2, y_max * 1.1)
    co_ls = ( coef_ls > 0.0009 ) ? :red : :blue
    plot!(sub_df.YEAR, sub_df.L_SHARE_TREND, lw = 2, color=co_ls, linestyle = :dash, label = "")
    p_sp = Plots.plot(sub_df.YEAR, sub_df.SKILL_PREMIUM, lw = 2, color=:black, linestyle = :solid,
    title="$ind_name", 
    xlabel="Year", ylabel="Ratio", label = "")
    y_max = maximum([y for y in sub_df.SKILL_PREMIUM if ~ismissing(y)])
    y_min = minimum([y for y in sub_df.SKILL_PREMIUM if ~ismissing(y)])
    ylims!(y_min * 0.9, y_max * 1.1)
    co_sp = ( coef_sp > 0.0009 ) ? :red : :blue
    plot!(sub_df.YEAR, sub_df.SKILL_PREMIUM_TREND, lw = 2, color=co_sp, linestyle = :dash, label = "")
    prefix_li = ( co_li == :red ) ? "inc" : "dec"
    prefix_ls = ( co_ls == :red ) ? "inc" : "dec"
    prefix_sp = ( co_sp == :red ) ? "inc" : "dec"
    


    # savefig(p_li, "/Users/mitchv34/Work/industry_skill_premium/documents/images/industries/labor_input_ratio/$prefix_li$(ind_code).pdf")
    # savefig(p_ls, "/Users/mitchv34/Work/industry_skill_premium/documents/images/industries/labor_share/$prefix_ls$(ind_code).pdf")
    # savefig(p_sp, "/Users/mitchv34/Work/industry_skill_premium/documents/images/industries/skill_premium/$prefix_sp$(ind_code).pdf")
end   


for i in eachrow(cwalk)
    ind_code = i.code_klems
    ind_name = i.ind_desc

    sub_df = subset(data, :ind => ByRow(==(ind_code)))

    title = Plots.plot(title = "$(ind_name)", framestyle=nothing,
    showaxis=false,xticks=false,yticks=false,  margin = -1.5mm)
    
    . = Plots.plot(sub_df.YEAR[2:end], sub_df.LABOR_INPUT_RATIO[2:end], lw = 2, color=:black, title="Labor Input Ratio", 
    xlabel="Year", ylabel="Ratio", label = "")
    p2 = Plots.plot(sub_df.YEAR[2:end], sub_df.SKILL_PREMIUM[2:end], lw = 2, color=:black, title="Skill Premium", 
    xlabel="Year", ylabel="Ratio", label = "")
    p = Plots.plot(title, ., p2, layout = @layout([A{0.01h}; [B; C]]))
    # savefig("./documents/images/industries/labor_input_skill_premium/$(ind_code).pdf")
end    

for year in unique(data.YEAR)
    sub_df = subset(data, :YEAR => ByRow(==(year)))
    title = Plots.plot(title = "$(year)", framestyle=nothing,
    showaxis=false,xticks=false,yticks=false,  margin = -1.5mm)
    Plots.scatter(log.(sub_df.LABOR_INPUT_RATIO), log.(sub_df.SKILL_PREMIUM), lw = 2, color=:black)
    ylims!(0, 1.6)
    xlims!(0, 2.1)
    # savefig("./documents/images/industries/labor_input_skill_premium/$(year).pdf")
end

data.K_RATIO = data.K_EQ ./ data.K_STR

ind_list = unique(data.ind)

p = plot()
for  i ∈ ind_list
    sub_data = subset(data, :ind => ByRow(==(i))) 
    if sub_data.DPR_EQ[end] > sub_data.DPR_EQ[1]
        c = :red
    else
        c = :green
    end
    @df sub_data plot!(:YEAR, :DPR_EQ ./ :DPR_ST ,lw = 2, legend = false, c = c)
end


sub_data = subset(data, :ind => ByRow(==("23"))) 

@df sub_data plot(:YEAR, :K_RATIO ,lw = 2, legend = false, c = :red)

sub_data = subset(data, :ind => ByRow(==("5411")))

@df sub_data plot!(:YEAR, :K_RATIO ,lw = 2, legend = false, c = :blue)