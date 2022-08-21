# install.packages('pacman')
library(pacman)
p_load(bea.R, fredr)

# definitions are here: 
#     https://www.bea.gov/resources/learning-center/definitions-and-introduction-fixed-assets

beaKey 	<- 'A22A56FA-4B7B-4EB3-8A78-304D00AF56F4'

# I will also be pulling data from the FRED API
fredKey <- '485a8a81f782ca06921bd2620a64b301'

# I know the identifiers of the following series
# Current-Cost Net Capital Stock of Private Nonresidential Fixed Assets (Equipment): K1N110C1EQ00
# Current-Cost Depreciation of Private Nonresidential Fixed Assets (Equipment): M1N110C1EQ00
# Investment in Private Nonresidential Fixed Assets (Equipment): I3N110C1EQ00

# Let's do a search on the first one and see what we get
beaSearch("by industry", beaKey, asHtml = TRUE)

# There are two tables that contains this series both in the FixedAssets dataset:
# 1.(FAAt301E) Table 3.1E. Current-Cost Net Stock of Private Equipment by Industry
# 2.(FAAt401) Table 4.1. Current-Cost Net Stock of Private Nonresidential Fixed Assets by Industry Group and Legal Form of Organization
# After a quick search I determined that I want the first one

# Repeat the search for the second and third series and I get:
# (FAAt304E) Table 3.4E. Current-Cost Depreciation of Private Equipment by Industry
# (FAAt307E) Table 3.7E. Investment in Private Equipment by Industry

# After looking up the same for Structures and Intelectual Property I get:
    # * Stock of Capital:
    #     - (FAAt301S) Table 3.1S. Current-Cost net Stock of Private Structures by Industry
    #     - (FAAt301I) Table 3.1I. Current-Cost Net Stock of Intellectual Property Products by Industry
    # * Investment:
    #     - (FAAt307S) Table 3.7S. Investment in Private Structures by Industry
    #     - (FAAt307I) Table 3.7I. Investment in Private Intellectual Property Products by Industry
    # * Depreciation:
    #     - (FAAt304S) Table 3.4S. Current-Cost Depreciation of Private Structures by Industry
    #     - (FAAt304I) Table 3.4I. Current-Cost Depreciation of Private Intellectual Property Products by Industry

# Putting all toghter I get:
# List        Equipment   Structures        IP
data_stk <- c("FAAt301E", "FAAt301S", "FAAt301I")   # Stock of Capital
data_inv <- c("FAAt307E", "FAAt307S", "FAAt307I")   # Investment
data_dpr <- c("FAAt304E", "FAAt304S", "FAAt304I")   # Depreciation


# Get the data
create_query <- function(table_name){
    query <-  list(
        'UserID' = beaKey, 
        'Method' = 'GetData',
        'datasetname' = "FixedAssets", # Data set name
        'TableName' = table_name, 
        'Frequency' = 'A', # annual
        'Year' = 'X', # 'X' is a placeholder for all years
        'ResultFormat' = 'json'
    )
    return(query)
}

# Get the data for each series
## Stock of Capital
stock_eq <- beaGet(create_query(data_stk[1]))
stock_st <- beaGet(create_query(data_stk[2]))
stock_ip <- beaGet(create_query(data_stk[3]))
## Investment
inv_eq <- beaGet(create_query(data_inv[1]))
inv_st <- beaGet(create_query(data_inv[2]))
inv_ip <- beaGet(create_query(data_inv[3]))
## Depreciation
dpr_eq <- beaGet(create_query(data_dpr[1]))
dpr_st <- beaGet(create_query(data_dpr[2]))
dpr_ip <- beaGet(create_query(data_dpr[3]))


# FRED DATA
fredr_set_key(fredKey)

# GDP
gdp <- gdpdef <- fredr(
    series_id = "GDPC1",
    observation_start = as.Date("1947-01-01"),
    observation_end = as.Date("2020-01-01"),
    frequency = "a"
)


# Implicit price Deflator GDPDEF
gdpdef <- fredr(
    series_id = "GDPDEF",
    observation_start = as.Date("1947-01-01"),
    observation_end = as.Date("2020-01-01"),
    frequency = "a"
)

# Consumption Deflator CONSDEF
consdef <- fredr(
    series_id = "CONSDEF",
    observation_start = as.Date("1947-01-01"),
    observation_end = as.Date("2020-01-01"),
    frequency = "a"
)

# Relative Price of Equipment PERIC
peric <- fredr(
    series_id = "PERIC",
    observation_start = as.Date("1947-01-01"),
    observation_end = as.Date("2020-01-01"),
    frequency = "a"
)


# Save the data
## From BEA
write.csv2(stock_eq, "./extend_KORV/data/raw/stock_eq.csv", row.names=FALSE, quote=FALSE)
write.csv2(stock_st, "./extend_KORV/data/raw/stock_st.csv", row.names=FALSE, quote=FALSE)
write.csv2(stock_ip, "./extend_KORV/data/raw/stock_ip.csv", row.names=FALSE, quote=FALSE)
write.csv2(inv_eq, "./extend_KORV/data/raw/inv_eq.csv", row.names=FALSE, quote=FALSE)
write.csv2(inv_st, "./extend_KORV/data/raw/inv_st.csv", row.names=FALSE, quote=FALSE)
write.csv2(inv_ip, "./extend_KORV/data/raw/inv_ip.csv", row.names=FALSE, quote=FALSE)
write.csv2(dpr_eq, "./extend_KORV/data/raw/dpr_eq.csv", row.names=FALSE, quote=FALSE)
write.csv2(dpr_st, "./extend_KORV/data/raw/dpr_st.csv", row.names=FALSE, quote=FALSE)
write.csv2(dpr_ip, "./extend_KORV/data/raw/dpr_ip.csv", row.names=FALSE, quote=FALSE)
## From FRED
write.csv(gdp, "./extend_KORV/data/raw/gdp.csv", row.names=FALSE, quote=FALSE)
write.csv(gdpdef, "./extend_KORV/data/raw/gdpdef.csv", row.names=FALSE, quote=FALSE)
write.csv(consdef, "./extend_KORV/data/raw/consdef.csv", row.names=FALSE, quote=FALSE)
write.csv(peric, "./extend_KORV/data/raw/peric.csv", row.names=FALSE, quote=FALSE)


## Data for estimating the Labor Share of the economy
gdi <- beaGet(list(
    'UserID' = beaKey, 
    'Method' = 'GetData',
    'datasetname' = "NIPA", # Data set name
    'TableName' = "T11000", 
    'Frequency' = 'A', # annual
    'Year' = 'X', # 'X' is a placeholder for all years
    'ResultFormat' = 'json'
)
)

write.csv2(gdi, "./extend_KORV/data/raw/gdi.csv", row.names=FALSE, quote=FALSE)

## Data for estimating the Labor Share of the economy
gdi <- beaGet(list(
    'UserID' = beaKey, 
    'Method' = 'GetData',
    'datasetname' = "NIPA", # Data set name
    'TableName' = "T11000", 
    'Frequency' = 'A', # annual
    'Year' = 'X', # 'X' is a placeholder for all years
    'ResultFormat' = 'json'
)
)

gdi <- beaGet(list(
    'UserID' = beaKey, 
    'Method' = 'GetData',
    'datasetname' = "GDPbyIndustry", # Data set name
    'TableID' = "All", 
    'Industry' = "A",
    'Frequency' = 'A', # annual
    'Year' = 'X', # 'X' is a placeholder for all years
    'ResultFormat' = 'json')
)
