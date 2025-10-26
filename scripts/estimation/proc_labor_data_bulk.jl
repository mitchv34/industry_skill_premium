using CSV
using DataFrames
using StatsBase
using Plots
using StatsPlots
using Term

# read data
path = "./data/raw/labor_raw/"
ind_code_list = [split(f, ".")[1] for f in readdir(path)]

for ind_code ∈ ind_code_list
    println(@green @bold "Processing labor data for industry: $(ind_code)")
    labor_data = CSV.read(path * "$ind_code" * ".csv", DataFrame)


    # Process Data
    # ------------
    ## Post 1975
    labor_data_full = filter(:YEAR => x -> x >  1975, labor_data)

    # Yearly Weights
    weights = combine(
            groupby(labor_data_full, :YEAR),
                [:ASECWT] => sum => :ASECWT)

    weights = Dict(
        zip(
            weights.YEAR, 
            weights.:ASECWT
        )
    )


    labor_data_full.:ASECWT = [w / weights[y] for (w, y) in zip(labor_data_full.:ASECWT, labor_data_full.YEAR)] 

    #labor_data_full.INCWAGE = labor_data_full.INCWAGE .* labor_data_full.CPI99

    # # Drop observations with less than 35 weeks worked
    filter!(:WKSWORK1 => >=(40), labor_data_full) # TODO: Check if this is correct
    # # Drop observations with less than 30 hours worked
    filter!(:UHRSWORKLY => >=(35), labor_data_full) # TODO: Check if this is correct

    # Construct hours worked variable
    labor_data_full.HOURS_WORKED = labor_data_full.WKSWORK1 .* labor_data_full.UHRSWORKLY;
    # Construct hourly wages variable
    labor_data_full.WAGE = labor_data_full.INCWAGE ./ labor_data_full.HOURS_WORKED
    # Removing workers earning less than half the minimum wage (using 1999 min wage )
    labor_data_full = labor_data_full[(labor_data_full.WAGE .* labor_data_full.CPI99 .>= (5.65 / 2)), :]


    labor_data_full.W_HOURS_WORKED = labor_data_full.HOURS_WORKED .* labor_data_full.ASECWT
    labor_data_full.W_WAGE = labor_data_full.WAGE .* labor_data_full.ASECWT


    grouped_data = combine( 
        groupby(labor_data_full, [:YEAR, :GROUP]),
        [
            :W_HOURS_WORKED => sum => :L,
            :W_WAGE => sum => :W,
            :ASECWT => sum => :μ
        ]
    )

    grouped_data.W = grouped_data.W ./ grouped_data.μ  # Average wage
    grouped_data.L = grouped_data.L ./ grouped_data.μ # Average hours worked

    grouped_data.SKILL = [(g[1:2] ∈ ["CG"]) ? "S" : "U" for g in grouped_data.GROUP] #! REMEBER CHECK BOTH SPECIFICATIONS 

    # Sin incluirlo
    grouped_data.W_L = grouped_data.L  .* grouped_data.μ
    # grouped_data_post.W_W = grouped_data_post.W  .* grouped_data_post.μ 

    # Incluirlo
    g1980 = subset( grouped_data, :YEAR => ByRow(==(1980) ) )[:, [:GROUP, :W, :SKILL]]
    g = unique(g1980.GROUP)
    filter!(:GROUP =>  ∈(g), grouped_data)

    dict1980 = Dict(zip(g1980.GROUP, g1980.W))
    try
    CPI9980 = unique(labor_data_full[labor_data_full.YEAR .== 1980, :].CPI99)[1]

    grouped_data.W_L_80 = [h * dict1980[g] * CPI9980 for (h, g) ∈ zip(grouped_data.W_L, grouped_data.GROUP)]
    scale =1
    grouped_skill = combine(
        groupby(grouped_data, [:YEAR, :SKILL]),
        [
            :W_L => (x -> sum(x) /  scale) => :hours,
            :W_L_80 => (x -> sum(x) / scale)  => :hours_80,
            [:W, :W_L] => ( (x,y) -> sum(x.*y) / scale) => :wage
        ]
    )

    filter!(:YEAR => x -> 1964 <= x <= 2019, grouped_skill)

    ## HOURS_80######################################################################

    grouped_skill.wage = grouped_skill.wage ./ grouped_skill.hours_80
    grouped_skill.YEAR .-= 1
    # @df subset(
    #     grouped_skill, 
    #     :SKILL => ByRow(==("S")), :YEAR => ByRow(>(1963))) plot(:YEAR .- 1, :hours_80 ./ :hours_80[1], group=:SKILL)

    # @df subset(
    #     grouped_skill, 
    #     :SKILL => ByRow(==("U")), :YEAR => ByRow(>(1963))) plot(:YEAR .- 1, :wage, group=:SKILL)


    final = innerjoin( 
        rename( 
                unstack(grouped_skill, :YEAR, :SKILL, :hours_80) , 
                    [:S => :L_S, :U => :L_U]
                ),
        rename(unstack(grouped_skill, :YEAR, :SKILL, :wage) ,
                    [:S => :W_S, :U => :W_U]
                    ),
                on = :YEAR)

    final.SKILL_PREMIUM = final.W_S ./ final.W_U
    final.LABOR_INPUT_RATIO = final.L_S ./ final.L_U    

    CSV.write("./data/interim/ind_labor/$(ind_code).csv", final)
    catch   
        final = DataFrame( [
                            :YEAR => [], 
                            :L_S => [], :L_U => [], 
                            :W_S => [], :W_U => [], 
                            :SKILL_PREMIUM => [], 
                            :LABOR_INPUT_RATIO => []
                        ])
        println(@red @bold "Error Processing labor data for industry: $(ind_code)")
        CSV.write("./data/interim/ind_labor/$(ind_code).csv", final)
    end
end # for ind_code ∈ ind_code_list

# p4 = plot(final.YEAR, final.SKILL_PREMIUM / final.SKILL_PREMIUM[1], legend=:topleft, label="Updated", lw = 2, linestyle = :dash)

# p5 = plot(final.YEAR, final.LABOR_INPUT_RATIO / final.LABOR_INPUT_RATIO[1], legend=:topleft, label="Update", lw = 2, linestyle = :dash)


# wbr = (final.W_S  .* final.L_S) ./ (final.W_U .* final.L_U)

# p3 = plot(final.YEAR, wbr / wbr[1], legend=:topleft, label="Update", lw = 2, linestyle = :dash)

# p2 = plot(final.YEAR, final.L_U / final.L_U[1], label="Update", lw = 2, linestyle = :dash)

# p1 = plot(final.YEAR, final.L_S / final.L_S[1], legend=:topleft, label="Update", lw = 2, linestyle = :dash)


# plot(p1, p2, p3, p4)

