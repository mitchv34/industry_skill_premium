# Industry Codes and Names

## Overview
This repository uses **BEA industry codes** from the Bureau of Economic Analysis (BEA) Fixed Assets tables and BEA-BLS Industry-Level Production Account.

## Industry Names File
**Location**: `data/industry_names.csv`

This file maps BEA industry codes to human-readable descriptions for all 56 industries in our dataset.

### Format
```csv
Description,BEA_Code
Farms,111CA
"Forestry, fishing, and related activities",113FF
...
```

### Usage in Python
```python
import pandas as pd

# Load industry names
industry_names = pd.read_csv('data/industry_names.csv')

# Create a lookup dictionary
ind_dict = dict(zip(industry_names['BEA_Code'], industry_names['Description']))

# Look up an industry
print(ind_dict['334'])  # "Computer and electronic products"
```

### Usage in Julia
```julia
using CSV, DataFrames

# Load industry names
industry_names = CSV.read("data/industry_names.csv", DataFrame)

# Create a lookup
ind_dict = Dict(zip(industry_names.BEA_Code, industry_names.Description))

# Look up an industry
println(ind_dict["334"])  # "Computer and electronic products"
```

## Industries in Dataset (56 total)

### Agriculture, Forestry, and Extraction (5)
- 111CA: Farms
- 113FF: Forestry, fishing, and related activities
- 211: Oil and gas extraction
- 212: Mining, except oil and gas
- 213: Support activities for mining

### Utilities and Construction (2)
- 22: Utilities
- 23: Construction

### Manufacturing (23)
- 311FT: Food and beverage and tobacco products
- 313TT: Textile mills and textile product mills
- 315AL: Apparel and leather and allied products
- 321: Wood products
- 322: Paper products
- 323: Printing and related support activities
- 324: Petroleum and coal products
- 325: Chemical products
- 326: Plastics and rubber products
- 327: Nonmetallic mineral products
- 331: Primary metals
- 332: Fabricated metal products
- 333: Machinery
- 334: Computer and electronic products
- 335: Electrical equipment, appliances, and components
- 3361MV: Motor vehicles, bodies and trailers, and parts
- 3364OT: Other transportation equipment
- 337: Furniture and related products
- 339: Miscellaneous manufacturing

### Trade (2)
- 42: Wholesale trade
- 44RT: Retail trade

### Transportation and Warehousing (8)
- 481: Air transportation
- 482: Rail transportation
- 483: Water transportation
- 484: Truck transportation
- 485: Transit and ground passenger transportation
- 487OS: Other transportation and support activities
- 493: Warehousing and storage

### Information (2)
- 512: Motion picture and sound recording industries
- 513: Broadcasting and telecommunications

### Finance and Insurance (4)
- 521CI: Federal Reserve banks, credit intermediation, and related activities
- 524: Insurance carriers and related activities
- 525: Funds, trusts, and other financial vehicles
- 531: Real estate

### Professional and Business Services (5)
- 532RL: Rental and leasing services and lessors of intangible assets
- 5411: Legal services
- 5412OP: Miscellaneous professional, scientific, and technical services
- 5415: Computer systems design and related services
- 55: Management of companies and enterprises
- 561: Administrative and support services
- 562: Waste management and remediation services

### Education, Health, and Social Services (4)
- 61: Educational services
- 621: Ambulatory health care services
- 622HO: Hospitals and nursing and residential care facilities
- 624: Social assistance

### Arts, Entertainment, and Food Services (4)
- 711AS: Performing arts, spectator sports, museums, and related activities
- 721: Accommodation
- 722: Food services and drinking places

### Other Services (1)
- 81: Other services, except government

## Code Conventions

### BEA Code Suffixes
Some codes have letter suffixes to aggregate related NAICS codes:
- **CA**: Combined agriculture (Crops and Animals)
- **FF**: Forestry, Fishing, and related
- **FT**: Food and Tobacco
- **TT**: Textile and Textile products
- **AL**: Apparel and Leather
- **MV**: Motor Vehicles
- **OT**: Other Transportation equipment
- **RT**: Retail Trade
- **OS**: Other transportation and Support activities
- **CI**: Credit Intermediation
- **RL**: Rental and Leasing
- **OP**: Other Professional services
- **HO**: Hospitals and nursing
- **AS**: Arts and Spectator sports

## Mapping to Other Classifications

The industry codes can be mapped to:
- **NAICS 2007/2012**: See `data/raw/BEA-BLS-industry-level-production-account-1987-2020/NAICS codes.csv`
- **Census codes**: See crosswalks in `data/interim/Acemoglu_Restrepo_SBTC_PP/`

## Data Sources

1. **Primary source**: BEA-BLS Industry-Level Production Account (1987-2020)
   - File: `data/raw/BEA-BLS-industry-level-production-account-1987-2020/NAICS codes.csv`
   
2. **Alternative definitions**: 
   - File: `data/raw/industry_definitions.tsv`

## Notes

- Government industries (Federal, State/Local) are excluded from the analysis
- Some industries were combined by BEA to maintain consistency across years
- Time coverage: 1987-2018 (varies by industry)
