using CSV
using DataFrames
using StatsBase
using Plots
using StatsPlots


function recode_education99(x)
    if ismissing(x)
        return nothing
    elseif (x <= 1)
        return nothing
    elseif (x > 1) & (x < 9)
        return "BH"
    elseif (x == 10)
        return "HS"
    elseif (x > 10) & (x < 15) # 12 is assocated degree 15 is bachelors 
        return "SC"
    elseif (x >= 15) 
        return "CG"
    end
end

function recode_educationHG(x)
    if ismissing(x)
        return nothing
    elseif (x < 31) | (x == 999)
        return nothing
    elseif (x >= 31) & (x < 150)
        return "BH"
    elseif (x == 150)
        return "HS"
    elseif (x > 150) & (x < 190) # 190 is fninished 4th year college 181 is some 4th year college didnt finish 
        return "SC"
    elseif (x >= 190) & (x < 999)
        return "CG"
    end
end

function recode_age(x)
    if ismissing(x)
        return nothing
    elseif (x <= 20)
        return "01"
    elseif (x > 20) & (x <= 25)
        return "02"
    elseif (x > 25) & (x <= 30)
        return "03"
    elseif (x > 30) & (x <= 35)
        return "04"
    elseif (x > 35) & (x <= 40)
        return "05"
    elseif (x > 40) & (x <= 45)
        return "06"
    elseif (x > 45) & (x <= 50)
        return "07"
    elseif (x > 50) & (x <= 55)
        return "08"
    elseif (x > 55) & (x <= 60)
        return "09"
    elseif (x > 60) & (x <= 65)
        return "10"
    elseif (x > 65) & (x <= 70)
        return "11"
    elseif (x > 70)
        return nothing
    end
end

function recode_race(x)
    if ismissing(x)
        return nothing
    elseif x == 100
        return "W"
    elseif x == 200
        return "B"
    else 
        return "O"
    end
end 

# labor_data = CSV.read("extend_KORV/data/raw/cps_00014.csv", DataFrame)
labor_data = CSV.read("./data/raw/cps_00022.csv", DataFrame)

# Track sample selection for reporting
println("="^70)
println("CPS SAMPLE SELECTION")
println("="^70)
println("Raw CPS extract: ", nrow(labor_data), " observations")
initial_n = nrow(labor_data)

subset!(labor_data, :ASECWT => ByRow(x -> ~ismissing(x)))
println("After valid weights filter: ", nrow(labor_data), " (", round(100*nrow(labor_data)/initial_n, digits=1), "%)")

# Fix weights for the 2014 sample (CPS redesign adjustment)
# Following IPUMS guidance for 2014 split-sample design:
# https://cps.ipums.org/cps/2014_redesign.shtml
sample2014 = subset( labor_data, :YEAR => ByRow(==(2014)) )
new_ASECWT = sample2014.ASECWT .* (5/8 * (1 .- sample2014.HFLAG) + 3/8 *sample2014.HFLAG)
labor_data[labor_data.YEAR .== 2014, :ASECWT] = new_ASECWT

# Keep only employted individials (excluiding self-employed and unpaid family workers) 
filter!( :CLASSWLY => x -> ~ismissing(x), labor_data)
filter!( :CLASSWLY => ∈([20 ,22 ,24 ,25 ,27 ,28]), labor_data)
println("After employment class filter: ", nrow(labor_data), " (", round(100*nrow(labor_data)/initial_n, digits=1), "%)")

# Remove workers employed in the military and those with missing data
subset!(labor_data, :IND1990 => ByRow(x -> ~ismissing(x)))
filter!(:IND1990 => x -> ~(x  ∈ [940,941,942,950,951,952,960,998] ), labor_data)
println("After military exclusion: ", nrow(labor_data), " (", round(100*nrow(labor_data)/initial_n, digits=1), "%)")

# Remove observations with missing data weeks worked data
filter!(:WKSWORK2 => !=(0), labor_data)
println("After weeks worked filter (WKSWORK2≥5 applied later): ", nrow(labor_data), " (", round(100*nrow(labor_data)/initial_n, digits=1), "%)")
# Recode education
# labor_data.EDUCAT = recode_education.(labor_data.EDUC) # TODO: CHECK EDUCATION VARIABLE 
labor_data.EDUCAT_1 = recode_educationHG.(labor_data.HIGRADE) # TODO: CHECK EDUCATION VARIABLE 
labor_data.EDUCAT_2 = recode_education99.(labor_data.EDUC99) # TODO: CHECK EDUCATION VARIABLE 
labor_data.EDUCAT = [ (isnothing(labor_data.EDUCAT_1[i])) ? labor_data.EDUCAT_2[i] : labor_data.EDUCAT_1[i] for i in 1:length(labor_data.EDUCAT_1)]


# Drop observations based on not reported education level
filter!(:EDUCAT => x -> ~isnothing(x), labor_data)
println("After education filter: ", nrow(labor_data), " (", round(100*nrow(labor_data)/initial_n, digits=1), "%)")
# Create groups
age_groups = [20 + i * 5 for i in 0:10]
labor_data.AGEGROUP = recode_age.(labor_data.AGE)
# Drop observations based on not reported age group
filter!(:AGEGROUP => x -> ~isnothing(x), labor_data)
println("After age filter (16-70): ", nrow(labor_data), " (", round(100*nrow(labor_data)/initial_n, digits=1), "%)")
labor_data.RACEGROUP = recode_race.(labor_data.RACE)
labor_data.GROUP =  string.(labor_data.EDUCAT) .* labor_data.AGEGROUP .* labor_data.RACEGROUP .* string.(labor_data.SEX)

# Process Data
# ------------
## Post 1975
labor_data_post = filter(:YEAR => x -> x >  1975, labor_data)

# ------------
## Pre 1975
labor_data_pre  = filter(:YEAR => x -> x <= 1975, labor_data)

### Use post 1975 data to impute missing data in pre 1975 data
# Note: For 1963-1975, WKSWORK1 and UHRSWORKLY are not recorded in CPS
# We impute using demographic group averages from 1976-1992 period

labor_data_post_c = copy(labor_data_post)

filter!(:WKSWORK1 => >(0), labor_data_post_c)
filter!(:UHRSWORKLY => >(0), labor_data_post_c)

## Create a dictionary using post 1975 data (GROUP, WKSWOKR2) =>  (mean(WKSWOKR1), mean(:UHRSWORKLY))
group_hours = combine(
        groupby(labor_data_post[labor_data_post.YEAR .<= 1992, :], [:GROUP, :WKSWORK2]),
            [:WKSWORK1, :ASECWT] => ( (x,y) -> sum(x.*y) ./ sum(y)) => :WKSWORK1,
            [:UHRSWORKLY, :ASECWT] => ( (x,y) -> sum(x.*y) ./ sum(y)) => :UHRSWORKLY)
group_hours = Dict(
                    zip(
                        tuple.(group_hours.GROUP, group_hours.WKSWORK2), 
                        tuple.(group_hours.WKSWORK1, group_hours.UHRSWORKLY)
    )
)
    
# Replace WKSWORK1 with the corresponding WKSWORK2 average for post 1975
# Create new colum WKSWOKR1 using mean WKSWOKR1 for each (GROUP, WKSWOKR2) combination
WKSWORK1_new = zeros(size(labor_data_pre)[1])
for (i, d) ∈ zip(1:size(labor_data_pre)[1], eachrow(labor_data_pre))
    key = ( d.GROUP, d.WKSWORK2)
    if ~( key ∈ keys(group_hours) )
        # @show i, key
        WKSWORK1_new[i] = -1 # Set to -1 if not found
    else 
        WKSWORK1_new[i] = group_hours[key][1]
    end
end   
# Add new column to labor_data_pre
labor_data_pre.WKSWORK1 = WKSWORK1_new

UHRSWORKLY_new = zeros(size(labor_data_pre)[1])
for (i, d) ∈ zip(1:size(labor_data_pre)[1], eachrow(labor_data_pre))
    if (d.AHRSWORKT > 0) & (d.AHRSWORKT < 999)
        UHRSWORKLY_new[i] = d.AHRSWORKT # If possitive or not missing use the value from AHRSWORKT
        continue
    else
        key = ( d.GROUP, d.WKSWORK2 )
        if ~( key ∈ keys(group_hours) )
            UHRSWORKLY_new[i] = -1 # Set to -1 if not found
        else
            UHRSWORKLY_new[i] = group_hours[key][2] # Use the group average UHRSWORKLY
        end
    end
end
labor_data_pre.UHRSWORKLY = UHRSWORKLY_new





# CPI ################################################################################
labor_data_full = vcat(labor_data_pre, labor_data_post)


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

# Drop observations with less than 40 weeks worked (≥48 weeks from WKSWORK2 ≥5)
filter!(:WKSWORK1 => >=(40), labor_data_full)
println("After full-year filter (≥40 weeks): ", nrow(labor_data_full), " (", round(100*nrow(labor_data_full)/initial_n, digits=1), "%)")
# Drop observations with less than 30 hours worked per week
filter!(:UHRSWORKLY => >=(30), labor_data_full)
println("After full-time filter (≥30 hrs/week): ", nrow(labor_data_full), " (", round(100*nrow(labor_data_full)/initial_n, digits=1), "%)")

# Construct hours worked variable
labor_data_full.HOURS_WORKED = labor_data_full.WKSWORK1 .* labor_data_full.UHRSWORKLY;
# Construct hourly wages variable
labor_data_full.WAGE = labor_data_full.INCWAGE ./ labor_data_full.HOURS_WORKED
# Removing workers earning less than half the minimum wage (using 1999 min wage )
labor_data_full = labor_data_full[(labor_data_full.WAGE .* labor_data_full.CPI99 .>= (5.65 / 4)), :]
println("After wage floor filter: ", nrow(labor_data_full), " (", round(100*nrow(labor_data_full)/initial_n, digits=1), "%)")
println("="^70)
println("Final estimation sample: ", nrow(labor_data_full), " observations")
println("="^70)
println()


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

@df subset(
    grouped_skill, 
    :SKILL => ByRow(==("U")), :YEAR => ByRow(>(1963))) plot(:YEAR .- 1, :hours_80 ./ :hours_80[1], group=:SKILL)

@df subset(
    grouped_skill, 
    :SKILL => ByRow(==("U")), :YEAR => ByRow(>(1963))) plot(:YEAR .- 1, :wage, group=:SKILL)


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


data_korv = CSV.read("./data/Data_KORV.csv", DataFrame)

sp_korv = data_korv.W_S ./ data_korv.W_U
lir_korv = data_korv.L_S ./ data_korv.L_U

theme(:default) 
default(fontfamily="Computer Modern", framestyle=:box) # LaTex-style

p4 = plot(final.YEAR, final.SKILL_PREMIUM /   final.SKILL_PREMIUM[1] , c = :red, legend=:topleft, label="Updated", lw = 2, linestyle = :dash)
plot!(final.YEAR[1:30], sp_korv  / sp_korv[1], label="KORV",  c=:black,lw = 2)

p5 = plot(final.YEAR, final.LABOR_INPUT_RATIO / final.LABOR_INPUT_RATIO[1],  c = :red, legend=:topleft, label="Update", lw = 2, linestyle = :dash)
plot!(final.YEAR[1:30], lir_korv / lir_korv[1], label="KORV",  c=:black,lw = 2)

wbr = (final.W_S  .* final.L_S) ./ (final.W_U .* final.L_U)
wbr_korv = (data_korv.W_S  .* data_korv.L_S) ./ (data_korv.W_U .* data_korv.L_U)

p3 = plot(final.YEAR, wbr / wbr[1], legend=:topleft, label="Update",  c = :red, lw = 2, linestyle = :dash)
plot!(final.YEAR[1:30], wbr_korv / wbr_korv[1], label="KORV",  c=:black,lw = 2)

p2 = plot(final.YEAR, final.L_U / final.L_U[1], label="Update",  c = :red, lw = 2, linestyle = :dash)
plot!(final.YEAR[1:30], data_korv.L_U  / data_korv.L_U[1], label="KORV", c=:black, lw = 2)

p1 = plot(final.YEAR, final.L_S / final.L_S[1], legend=:topleft,  c = :red, label="Update", lw = 2, linestyle = :dash)
plot!(final.YEAR[1:30], data_korv.L_S  / data_korv.L_S[1], label="KORV", c=:black, lw = 2)

plot(p1, p2, p3, p4)


savefig(p1, "./documents/images/labor_input_unskilled_doc.pdf")
savefig(p2, "./documents/images/labor_input_skilled_doc.pdf")
savefig(p3, "./documents/images/sp_doc.pdf")
savefig(p4, "./documents/images/wbr_doc.pdf")


# Re Escale the so that the first value coeincides with the first value of the KORV data
final.W_S = final.W_S ./ final.W_S[1] * data_korv.W_S[1]
final.W_U = final.W_U ./ final.W_U[1] * data_korv.W_U[1]
final.L_S = final.L_S ./ final.L_S[1] * data_korv.L_S[1]
final.L_U = final.L_U ./ final.L_U[1] * data_korv.L_U[1]
#
# Read labor share data # TODO: FIX THIS PART 
labor_share = CSV.read("./data/interim/labor_share.csv", DataFrame)
rename!(labor_share, :Column1 => :YEAR)
capital = CSV.read("./data/interim/capital_totl.csv", DataFrame)
filter!(:YEAR => >=(1947) , labor_share, )
filter!(:YEAR => <=(2020) , labor_share, )

labor_share.L_SHARE = 1 .- ( ( labor_share.CI .- capital.inv_ip ) ./ ( labor_share.Y .- labor_share.PI .- capital.inv_ip  )  )

filter!(:YEAR => >=(1963) , labor_share, )
filter!(:YEAR => <=(2018) , labor_share, )

p6 = plot(labor_share.L_SHARE, legend=:topright, label="Updated", lw = 2, linestyle = :dash)
plot!( data_korv.L_SHARE, label="KORV", lw = 2)


final.L_SHARE = labor_share.L_SHARE

# save final to csv
CSV.write("./data/proc/labor_totl.csv", final)

plot(p1, p2, p3, p4)