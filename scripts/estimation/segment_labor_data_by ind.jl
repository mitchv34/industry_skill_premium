using CSV
using DataFrames
using StatsBase
using JSON
using Term
using StatFiles

## AUX FUNCTIONS ########################################################################

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


## MAIN  ########################################################################

xwalk = CSV.read("./data/cross_walk.csv", DataFrame)

code_census = xwalk.code_census
code_klems = xwalk.code_klems

# Read in big CPS data
labor_data = CSV.read("./data/raw/cps_00022.csv", DataFrame)
subset!(labor_data, :ASECWT => ByRow(x -> ~ismissing(x)))

# Drop observations with missing industry data
filter!(:IND1990 => x -> ~ismissing(x), labor_data)

code_census_list = collect(Iterators.flatten([split(code_census[i], ",") for i in 1:length(code_census)]))

subdata_not = subset(labor_data, :IND1990 => ByRow( x -> ~(string(x)  ∈ code_census_list)))

# Fix weights for the 2014 sample
sample2014 = subset( labor_data, :YEAR => ByRow(==(2014)) )
new_ASECWT = sample2014.ASECWT .* (5/8 * (1 .- sample2014.HFLAG) + 3/8 *sample2014.HFLAG)
labor_data[labor_data.YEAR .== 2014, :ASECWT] = new_ASECWT

# Keep only employted individials (excluiding self-employed and unpaid family workers) 
filter!( :CLASSWLY => x -> ~ismissing(x), labor_data)
filter!( :CLASSWLY => ∈([20 ,22 ,24 ,25 ,27 ,28]), labor_data)

# Remove workers employed in the military and those with missing data
# subset!(labor_data, :IND1990 => ByRow(x -> ~ismissing(x)))
# filter!(:IND1990 => x -> ~(x  ∈ [940,941,942,950,951,952,960,998] ), labor_data)

# Remove observations with missing data weeks worked data
filter!(:WKSWORK2 => !=(0), labor_data)
# Recode education
# labor_data.EDUCAT = recode_education.(labor_data.EDUC) # TODO: CHECK EDUCATION VARIABLE 
labor_data.EDUCAT_1 = recode_educationHG.(labor_data.HIGRADE) # TODO: CHECK EDUCATION VARIABLE 
labor_data.EDUCAT_2 = recode_education99.(labor_data.EDUC99) # TODO: CHECK EDUCATION VARIABLE 
labor_data.EDUCAT = [ (isnothing(labor_data.EDUCAT_1[i])) ? labor_data.EDUCAT_2[i] : labor_data.EDUCAT_1[i] for i in 1:length(labor_data.EDUCAT_1)]


# Drop observations based on not reported education level
filter!(:EDUCAT => x -> ~isnothing(x), labor_data)
# Create groups
age_groups = [20 + i * 5 for i in 0:10]
labor_data.AGEGROUP = recode_age.(labor_data.AGE)
# Drop observations based on not reported age group
filter!(:AGEGROUP => x -> ~isnothing(x), labor_data)
labor_data.RACEGROUP = recode_race.(labor_data.RACE)
labor_data.GROUP =  string.(labor_data.EDUCAT) .* labor_data.AGEGROUP .* labor_data.RACEGROUP .* string.(labor_data.SEX)



i = 1
cols = [:YEAR, :ASECWT, :UHRSWORKLY, :WKSWORK1, :INCWAGE, :CPI99, :GROUP]
for (klems, census) in zip(code_klems, code_census)
    print(@red "$klems  -> " )
    print(@green "$census \n")

    subdata = subset(labor_data, :IND1990 => ByRow( x -> string(x) ∈ split(census, ",")))[:,cols]
    CSV.write("./extend_KORV/data/raw/labor_raw/$(klems).csv", subdata)
    s = size(subdata)
    println(@blue "size = $s")
    # if i > 4
    #     break
    # end
    i += 1
end