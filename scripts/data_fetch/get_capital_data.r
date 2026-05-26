# Fetches BEA Fixed Assets + NIPA + FRED time series needed for the chapter.
#
# Setup:
#   - install.packages(c("pacman")); pacman::p_load(bea.R, fredr)
#   - Set BEA_API_KEY and FRED_API_KEY environment variables, OR put them in
#     `pass` under api/bea and api/fred (then export from your shell).
#
# Output layout (defined in config.py, kept in sync here):
#   data/raw/bea/   — BEA Fixed Assets + NIPA tables
#   data/raw/fred/  — FRED series
#
# Sample window: SAMPLE_START_YEAR .. SAMPLE_END_YEAR below. Override via env
# vars SAMPLE_START_YEAR / SAMPLE_END_YEAR if needed.

library(pacman)
p_load(bea.R, fredr)

# ---------------------------------------------------------------------------
# Setup: working directory, API keys, sample window.
# ---------------------------------------------------------------------------

script_dir <- dirname(normalizePath(sys.frame(1)$ofile))
repo_root  <- dirname(dirname(script_dir))
setwd(repo_root)

# Read keys from env vars (Mitchell's `pass`-based convention exports these in
# shell init). Refuse to run with empty keys rather than silently failing.
beaKey  <- Sys.getenv("BEA_API_KEY")
fredKey <- Sys.getenv("FRED_API_KEY")
if (nchar(beaKey)  == 0) stop("BEA_API_KEY not set (try: export BEA_API_KEY=$(pass show api/bea))")
if (nchar(fredKey) == 0) stop("FRED_API_KEY not set (try: export FRED_API_KEY=$(pass show api/fred))")

sample_start <- as.integer(Sys.getenv("SAMPLE_START_YEAR", "1947"))
sample_end   <- as.integer(Sys.getenv("SAMPLE_END_YEAR",   "2025"))
obs_start    <- as.Date(sprintf("%d-01-01", sample_start))
obs_end      <- as.Date(sprintf("%d-12-31", sample_end))

# Output directories (kept in sync with config.py).
out_bea  <- file.path(repo_root, "data", "raw", "bea")
out_fred <- file.path(repo_root, "data", "raw", "fred")
dir.create(out_bea,  showWarnings = FALSE, recursive = TRUE)
dir.create(out_fred, showWarnings = FALSE, recursive = TRUE)

# ---------------------------------------------------------------------------
# BEA Fixed Assets — capital stocks, investment, depreciation by industry.
#
# As of 2023, BEA Fixed Assets are published on NAICS 2022. Historical series
# 1947+ have been restated. See:
#   https://www.bea.gov/news/2023/gross-domestic-product-third-quarter-2023-second-estimate
#
# Definitions: https://www.bea.gov/resources/learning-center/definitions-and-introduction-fixed-assets
#
# Equipment  / Structures  / Intellectual Property
# Stock:     FAAt301E / FAAt301S / FAAt301I
# Investment:FAAt307E / FAAt307S / FAAt307I  <-- Table 3.7E is also the input
#                                                for the industry-specific
#                                                Tornqvist deflator (Q1).
# Depreciation: FAAt304E / FAAt304S / FAAt304I
# ---------------------------------------------------------------------------

data_stk <- c("FAAt301E", "FAAt301S", "FAAt301I")
data_inv <- c("FAAt307E", "FAAt307S", "FAAt307I")
data_dpr <- c("FAAt304E", "FAAt304S", "FAAt304I")

create_query <- function(table_name, dataset = "FixedAssets") {
    list(
        'UserID'      = beaKey,
        'Method'      = 'GetData',
        'datasetname' = dataset,
        'TableName'   = table_name,
        'Frequency'   = 'A',
        'Year'        = 'X',          # all available years
        'ResultFormat'= 'json'
    )
}

message("Fetching BEA Fixed Assets ...")
stock_eq <- beaGet(create_query(data_stk[1]))
stock_st <- beaGet(create_query(data_stk[2]))
stock_ip <- beaGet(create_query(data_stk[3]))
inv_eq   <- beaGet(create_query(data_inv[1]))
inv_st   <- beaGet(create_query(data_inv[2]))
inv_ip   <- beaGet(create_query(data_inv[3]))
dpr_eq   <- beaGet(create_query(data_dpr[1]))
dpr_st   <- beaGet(create_query(data_dpr[2]))
dpr_ip   <- beaGet(create_query(data_dpr[3]))

# ---------------------------------------------------------------------------
# NIPA — equipment price indexes by detail asset type (Table 5.6.4).
# Needed for industry-specific Tornqvist deflator (Q1).
# ---------------------------------------------------------------------------

message("Fetching NIPA Table 5.6.4 (price indexes for equipment by type) ...")
nipa_5_6_4 <- beaGet(list(
    'UserID'      = beaKey,
    'Method'      = 'GetData',
    'datasetname' = "NIPA",
    'TableName'   = "T50604",
    'Frequency'   = 'A',
    'Year'        = 'X',
    'ResultFormat'= 'json'
))

# ---------------------------------------------------------------------------
# NIPA Gross Domestic Income (T11000) — labor share construction input.
# ---------------------------------------------------------------------------

message("Fetching NIPA T11000 (Gross Domestic Income) ...")
gdi <- beaGet(list(
    'UserID'      = beaKey,
    'Method'      = 'GetData',
    'datasetname' = "NIPA",
    'TableName'   = "T11000",
    'Frequency'   = 'A',
    'Year'        = 'X',
    'ResultFormat'= 'json'
))

# ---------------------------------------------------------------------------
# GDP by Industry — for industry-level value added / output.
# ---------------------------------------------------------------------------

message("Fetching GDPbyIndustry (industry-level value added) ...")
gdp_by_industry <- beaGet(list(
    'UserID'      = beaKey,
    'Method'      = 'GetData',
    'datasetname' = "GDPbyIndustry",
    'TableID'     = "All",
    'Industry'    = "A",
    'Frequency'   = 'A',
    'Year'        = 'X',
    'ResultFormat'= 'json'
))

# ---------------------------------------------------------------------------
# FRED — aggregate price/output series.
# ---------------------------------------------------------------------------

fredr_set_key(fredKey)

fred_fetch <- function(series_id) {
    fredr(
        series_id         = series_id,
        observation_start = obs_start,
        observation_end   = obs_end,
        frequency         = "a"
    )
}

message("Fetching FRED series ...")
gdp     <- fred_fetch("GDPC1")     # Real GDP, chained 2017 dollars
gdpdef  <- fred_fetch("GDPDEF")    # GDP implicit deflator
consdef <- fred_fetch("CONSDEF")   # Consumption deflator
peric   <- fred_fetch("PERIC")     # Relative price of equipment (aggregate q_t)

# ---------------------------------------------------------------------------
# Write outputs.
# ---------------------------------------------------------------------------

bea_writer <- function(df, fname) {
    write.csv2(df, file.path(out_bea, fname), row.names = FALSE, quote = FALSE)
}
fred_writer <- function(df, fname) {
    write.csv(df, file.path(out_fred, fname), row.names = FALSE, quote = FALSE)
}

message("Writing BEA outputs to ", out_bea, " ...")
bea_writer(stock_eq,        "stock_eq.csv")
bea_writer(stock_st,        "stock_st.csv")
bea_writer(stock_ip,        "stock_ip.csv")
bea_writer(inv_eq,          "inv_eq.csv")
bea_writer(inv_st,          "inv_st.csv")
bea_writer(inv_ip,          "inv_ip.csv")
bea_writer(dpr_eq,          "dpr_eq.csv")
bea_writer(dpr_st,          "dpr_st.csv")
bea_writer(dpr_ip,          "dpr_ip.csv")
bea_writer(nipa_5_6_4,      "nipa_T50604_equipment_price_by_asset.csv")
bea_writer(gdi,             "gdi.csv")
bea_writer(gdp_by_industry, "gdp_by_industry.csv")

message("Writing FRED outputs to ", out_fred, " ...")
fred_writer(gdp,     "gdp.csv")
fred_writer(gdpdef,  "gdpdef.csv")
fred_writer(consdef, "consdef.csv")
fred_writer(peric,   "peric.csv")

message("Done. Sample: ", sample_start, "-", sample_end,
        " | NAICS 2022 (BEA restatement applies to historical series).")
