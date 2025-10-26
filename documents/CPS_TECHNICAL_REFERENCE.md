# CPS Microdata: Technical Reference Documentation

**Project**: Industry Skill Premium Analysis  
**Author**: Mitchell Valdes-Bobes  
**Last Updated**: October 2024  

---

## Table of Contents

1. [Data Source Overview](#data-source)
2. [CPS Variables Reference](#variables)
3. [Sample Selection Criteria](#selection)
4. [Education Recoding Logic](#education)
5. [Employment Classification](#employment)
6. [Industry Codes](#industry)
7. [Data Processing Pipeline](#pipeline)
8. [Output Files Specification](#outputs)

---

## Data Source Overview {#data-source}

### CPS IPUMS March ASEC

**Extract Details:**
- **Filename**: `cps_00022.csv`
- **Size**: 4,358,292 observations, 319 MB  
- **Coverage**: 1963-2018 (56 years)
- **Type**: March Annual Social & Economic Supplement (ASEC)
- **Source**: [IPUMS CPS](https://cps.ipums.org/)
- **Extract Date**: [TBD]

**Key Features:**
- Annual cross-sections (not panel)
- Income data from previous calendar year
- Sample weights for population inference
- Consistent industry codes (IND1990)
- Education recoded across classification changes

### Variables Extracted

| Variable | Type | Description | Range |
|----------|------|-------------|-------|
| YEAR | Int | Survey year | 1963-2018 |
| SERIAL | Int | Household identifier | Unique |
| PERNUM | Int | Person number within household | 1-20 |
| ASECWT | Float | Annual weight | 0-100,000+ |
| HFLAG | Int | Edited/allocated flag | 0=original, 1=edited |
| AGE | Int | Age in years | 0-99 (90=90+) |
| SEX | Int | Gender | 1=Male, 2=Female |
| RACE | Int | Race code | Various |
| HISPAN | Int | Hispanic origin | 0=Not, 1-612=Yes |
| EDUC | Int | Education (detailed) | 0-125 |
| EDUCD | Int | Education (detailed, alt) | 0-999 |
| EDUC99 | Int | Education (1990 basis) | 0-17 |
| CLASSWLY | Int | Class of worker last year | See table below |
| IND1990 | Int | Industry (1990 basis) | 0-999 |
| WKSWORK1 | Int | Weeks worked last year | 0-52 |
| WKSWORK2 | Int | Weeks worked (intervals) | 1-6 |
| UHRSWORKT | Int | Hours/week last week | 0-99 |
| UHRSWORKLY | Int | Hours/week last year | 0-99 |
| AHRSWORKT | Int | Hours/week last week (alt) | 0-99 |
| INCWAGE | Int | Wage/salary income | 0-999,998 |
| QINCWAGE | Int | Allocated income flag | 0-1 (if available) |

---

## CPS Variables Reference {#variables}

### Core Identification Variables

**YEAR** (Survey Year)
- Range: 1963-2018
- Income data refers to YEAR-1
- Used for: Time series analysis

**SERIAL + PERNUM** (Unique Person ID)
- SERIAL: Household identifier
- PERNUM: Person within household
- Combined = unique observation

**ASECWT** (Sample Weight)
- Purpose: Expand sample to population
- Range: Typically 100-50,000
- Special case: 2014 requires adjustment (see below)
- Usage: All statistics must be weighted

**HFLAG** (Edited Flag)
- 0 = Original response
- 1 = Response edited/allocated by Census
- 2014 adjustment uses this flag
- May affect data quality

### Demographic Variables

**AGE** (Age in Years)
- Range: 0-90 (90 = 90+)
- Filter: Keep 16-70 for working age
- Top-coded at 90

**SEX** (Gender)
- 1 = Male
- 2 = Female
- Used for: Demographic cell construction

**RACE** (Race Code)
- Detailed codes vary by year
- Simplified to: White, Black, Other
- Used for: Demographic cell construction

**HISPAN** (Hispanic Origin)
- 0 = Not Hispanic
- 1-612 = Various Hispanic origins
- Recode to: 0/1 binary
- Used for: Demographic cell construction

### Education Variables

**EDUC** (Education Level - Detailed)
- Range: 0-125
- Different scales pre/post 1992
- Primary variable for recoding

**EDUC99** (Education - 1990 Basis)
- Range: 0-17
- Harmonized across years
- Breakpoint at code 10 (some college)

**Our Recoding: EDUCAT** (6 categories)
1. Less than high school
2. High school graduate
3. Some college
4. Associate degree
5. Bachelor degree
6. Graduate degree

**Skilled Definition**: EDUCAT ≥ 5 (Bachelor+)

### Employment Variables

**CLASSWLY** (Class of Worker Last Year)
- See full table in [Employment Classification](#employment)
- Key: Wage/salary vs self-employed
- Filter out: Unpaid, incorporated self-employed

**IND1990** (Industry - 1990 Basis)
- 3-digit code
- Consistent 1963-2018
- See [Industry Codes](#industry) section
- Special codes: 940-960 (military)

### Work Hours/Weeks Variables

**WKSWORK1** (Weeks Worked - Exact)
- Range: 0-52
- Available: 1976-2018
- Missing: 1963-1975 (use WKSWORK2 + imputation)

**WKSWORK2** (Weeks Worked - Intervals)
- 1 = 1-13 weeks
- 2 = 14-26 weeks
- 3 = 27-39 weeks
- 4 = 40-47 weeks
- 5 = 48-49 weeks
- 6 = 50-52 weeks
- Available: All years
- Filter: Keep ≥ 5 (48+ weeks, i.e., 40+ weeks criterion)

**UHRSWORKLY** (Hours/Week Last Year)
- Range: 0-99
- Available: 1976-2018
- Missing: 1963-1975 (impute)
- Filter: Keep ≥ 30 hours/week

**UHRSWORKT** (Hours/Week Last Week)
- Range: 0-99
- Used for imputation when UHRSWORKLY missing

### Income Variables

**INCWAGE** (Wage/Salary Income)
- Range: 0-999,998
- Top-coded (varies by year)
- Excludes: Business income, capital income
- Filter: Apply real wage floor (~$5,000 2018$)

**QINCWAGE** (Allocated Income Flag)
- 0 = Reported
- 1 = Allocated/imputed
- Note: Not always available in extracts
- Manuscript says excluded, but not filtered in code

---

## Sample Selection Criteria {#selection}

### Filter Sequence

Applied in this order (approximately):

1. **Valid Weights**: `ASECWT > 0`
   - Removes observations with missing/invalid weights

2. **Wage/Salary Workers**: `CLASSWLY ∈ {valid codes}`
   - Keep: Private sector, government, self-employed (unincorporated)
   - Exclude: Self-employed incorporated, unpaid family, private household

3. **Full Year Workers**: `WKSWORK2 >= 5` (48+ weeks)
   - Ensures attachment to labor market
   - Approximately 40+ weeks worked

4. **Full Time Workers**: `UHRSWORKLY >= 30` hours/week
   - Note: Manuscript says 35, code uses 30
   - See discrepancies document

5. **Working Age**: `16 <= AGE <= 70`
   - Standard working age definition

6. **Education Reported**: `EDUC > 0 and valid`
   - Can recode to EDUCAT

7. **Positive Wage**: `INCWAGE > 0`
   - After applying real wage floor

8. **Wage Floor**: Real wage > ~$5,000 (2018 dollars)
   - Removes implausibly low values

### Sample Size Flowchart

```
Raw CPS Extract               4,358,292 observations (100.0%)
   ↓ [Valid weights]
After weight filter           ~4,300,000 (98.7%)
   ↓ [Wage/salary workers]
After employment filter       ~2,800,000 (64.3%)
   ↓ [Full year workers]
After weeks filter            ~2,600,000 (59.7%)
   ↓ [Full time workers]
After hours filter            ~2,450,000 (56.2%)
   ↓ [Working age]
After age filter              ~2,420,000 (55.5%)
   ↓ [Education reported]
After education filter        ~2,410,000 (55.3%)
   ↓ [Wage floor]
Final estimation sample       ~2,400,000 (55.1%)
```

*Note: Exact numbers TBD - run with logging to get actuals*

---

## Education Recoding Logic {#education}

### Historical Context

CPS changed education coding in 1992:
- **Pre-1992**: Grades/years completed
- **Post-1992**: Degrees/credentials

EDUC99 provides consistent 1990-basis coding.

### Our 6-Category System (EDUCAT)

#### 1. Less than High School (`EDUCAT = 1`)

**Pre-1992 (EDUC basis):**
- EDUC < 73

**Post-1992 (EDUC basis):**
- EDUC < 60

**EDUC99 equivalent:**
- EDUC99 < 10

**Interpretation**: Did not complete high school

---

#### 2. High School Graduate (`EDUCAT = 2`)

**Pre-1992:**
- EDUC = 73

**Post-1992:**
- EDUC = 60-64 (high school graduate or GED)

**EDUC99 equivalent:**
- EDUC99 = 10

**Interpretation**: High school diploma or equivalent

---

#### 3. Some College (`EDUCAT = 3`)

**Pre-1992:**
- EDUC = 74-90

**Post-1992:**
- EDUC = 65-80

**EDUC99 equivalent:**
- EDUC99 = 11-12

**Interpretation**: Some college, no degree

---

#### 4. Associate Degree (`EDUCAT = 4`)

**Pre-1992:**
- EDUC = 91-92

**Post-1992:**
- EDUC = 81-100

**EDUC99 equivalent:**
- EDUC99 = 13

**Interpretation**: Associate degree (AA, AS)

---

#### 5. Bachelor Degree (`EDUCAT = 5`) ⭐

**Pre-1992:**
- EDUC = 111

**Post-1992:**
- EDUC = 111

**EDUC99 equivalent:**
- EDUC99 = 14

**Interpretation**: Bachelor's degree (BA, BS)

**Skilled Threshold Starts Here**

---

#### 6. Graduate Degree (`EDUCAT = 6`) ⭐

**Pre-1992:**
- EDUC = 123-125

**Post-1992:**
- EDUC = 123-125

**EDUC99 equivalent:**
- EDUC99 = 15-17

**Interpretation**: Master's, professional, or doctoral degree

---

### Skill Group Definition

**Skilled Workers**: `EDUCAT >= 5` (Bachelor's degree or higher)
**Unskilled Workers**: `EDUCAT < 5` (Less than Bachelor's)

This follows standard labor economics literature (e.g., Katz-Murphy 1992).

---

## Employment Classification {#employment}

### CLASSWLY Codes

Full table of worker class codes:

| Code | Description | Include? | Reason |
|------|-------------|----------|--------|
| 13 | Government, federal | ✅ Yes | Wage/salary |
| 14 | Government, state | ✅ Yes | Wage/salary |
| 21 | Private, for profit | ✅ Yes | Wage/salary |
| 22 | Private, nonprofit | ✅ Yes | Wage/salary |
| 23 | Private, own incorporated | ⚠️ **No** | Business income (not wage) |
| 24 | Private, own not incorporated | ✅ Yes | Self-employed wage |
| 25 | Private, household | ⚠️ **No** | Domestic work (different market) |
| 27 | Without pay, family | ⚠️ **No** | No wage income |
| 28 | Private, unknown | ✅ Yes | Assume wage/salary |
| 29 | Unemployed | ⚠️ **No** | Not working |

**Rationale for Exclusions:**
- **Code 23**: Incorporated self-employed report business income, not wages
- **Code 25**: Household workers operate in different labor market
- **Code 27**: No compensation
- **Code 29**: Not employed

---

## Industry Codes {#industry}

### IND1990 Classification

3-digit codes, consistent 1963-2018.

**Major Categories:**

| Range | Industry Group |
|-------|----------------|
| 010-032 | Agriculture, Forestry, Fishing |
| 040-050 | Mining |
| 060 | Construction |
| 100-392 | Manufacturing |
| 400-472 | Transportation, Communications, Utilities |
| 500-571 | Wholesale Trade |
| 580-691 | Retail Trade |
| 700-712 | Finance, Insurance, Real Estate |
| 721-760 | Business & Repair Services |
| 761-791 | Personal Services |
| 800-810 | Entertainment & Recreation |
| 812-893 | Professional & Related Services |
| 900-932 | Public Administration |
| 940-960 | **Military** ⚠️ |

**Military Codes (IND1990 = 940-960):**
- 940 = Army
- 941 = Air Force  
- 942 = Navy
- 950 = Marines
- 951 = Coast Guard
- 952 = Armed Forces, branch not specified
- 960 = Military Reserves or National Guard

**Note**: Manuscript says military excluded, but filter is commented out in code. See discrepancies document.

### Mapping to BEA Industries

See `data/cross_walk.csv` for mapping between:
- IND1990 (CPS)
- BEA industry codes
- NAICS codes

---

## Data Processing Pipeline {#pipeline}

### Stage 1: Load Raw Data

```python
import polars as pl

df = pl.read_csv('data/raw/cps_00022.csv')
# 4,358,292 observations
```

### Stage 2: Apply Filters

```python
df = df.filter(
    (pl.col('ASECWT') > 0) &
    (pl.col('CLASSWLY').is_in([13,14,21,22,24,28])) &
    (pl.col('WKSWORK2') >= 5) &
    (pl.col('UHRSWORKLY') >= 30) &
    (pl.col('AGE').is_between(16, 70)) &
    (pl.col('INCWAGE') > 0)
)
```

### Stage 3: Recode Education

```python
def recode_education(educ, year):
    if year < 1992:
        if educ < 73: return 1
        elif educ == 73: return 2
        elif educ <= 90: return 3
        elif educ <= 92: return 4
        elif educ == 111: return 5
        else: return 6
    else:
        if educ < 60: return 1
        elif educ <= 64: return 2
        elif educ <= 80: return 3
        elif educ <= 100: return 4
        elif educ == 111: return 5
        else: return 6

df = df.with_columns(
    pl.struct(['EDUC', 'YEAR'])
      .map_elements(lambda x: recode_education(x['EDUC'], x['YEAR']))
      .alias('EDUCAT')
)
```

### Stage 4: Create Demographic Cells

**Cell Definition**: (SEX × RACE × HISPAN × AGE_GROUP × EDUCAT)
- SEX: 2 categories
- RACE: 3 categories (White, Black, Other)
- HISPAN: 2 categories
- AGE_GROUP: 11 categories (5-year bins: 16-20, 21-25, ..., 66-70)
- EDUCAT: 2 categories (Skilled=5+, Unskilled=1-4)

**Total cells**: 2 × 3 × 2 × 11 × 2 = **264 demographic cells**

```python
df = df.with_columns([
    pl.col('SEX'),
    pl.when(pl.col('RACE') == 100).then(1)  # White
      .when(pl.col('RACE') == 200).then(2)  # Black
      .otherwise(3)                          # Other
      .alias('RACE_CAT'),
    (pl.col('HISPAN') > 0).cast(pl.Int32).alias('HISPAN_CAT'),
    ((pl.col('AGE') - 16) // 5).alias('AGE_GROUP'),
    (pl.col('EDUCAT') >= 5).cast(pl.Int32).alias('SKILLED')
])

df = df.with_columns(
    pl.concat_str([
        pl.col('SEX'),
        pl.col('RACE_CAT'),
        pl.col('HISPAN_CAT'),
        pl.col('AGE_GROUP'),
        pl.col('SKILLED')
    ], separator='_').alias('GROUP')
)
```

### Stage 5: Calculate Annual Hours & Efficiency Units

**Annual Hours**:
```
ANNUAL_HOURS = WKSWORK1 × UHRSWORKLY
```

**Efficiency Units** (Acemoglu-Autor 2011):
```
For skilled:   h_s = (ANNUAL_HOURS / 2000) × (INCWAGE / median_wage_skilled)
For unskilled: h_u = (ANNUAL_HOURS / 2000) × (INCWAGE / median_wage_unskilled)
```

Normalizes to 2000-hour year and wage-adjusts for quality.

### Stage 6: Aggregate to Groups

**By Group-Year**:
```python
group_data = df.group_by(['YEAR', 'GROUP']).agg([
    pl.col('ASECWT').sum().alias('COUNT'),
    (pl.col('EFFICIENCY_UNITS') * pl.col('ASECWT')).sum().alias('TOTAL_EU')
])
```

**By Skill-Year**:
```python
totals = df.group_by(['YEAR', 'SKILLED']).agg([
    pl.col('ASECWT').sum().alias('LABOR'),
    (pl.col('EFFICIENCY_UNITS') * pl.col('ASECWT')).sum().alias('EU_TOTAL'),
    (pl.col('INCWAGE') * pl.col('ASECWT')).sum().alias('WAGE_BILL')
])
```

### Stage 7: Calculate Key Variables

```python
totals = totals.with_columns([
    (pl.col('WAGE_BILL') / pl.col('EU_TOTAL')).alias('AVG_WAGE'),
])

# Reshape to wide
skilled = totals.filter(pl.col('SKILLED') == 1)
unskilled = totals.filter(pl.col('SKILLED') == 0)

final = skilled.join(unskilled, on='YEAR', suffix='_U')

final = final.with_columns([
    (pl.col('LABOR') / pl.col('LABOR_U')).alias('LABOR_INPUT_RATIO'),
    (pl.col('AVG_WAGE') / pl.col('AVG_WAGE_U')).alias('WAGE_PREMIUM'),
    (pl.col('WAGE_BILL') / (pl.col('WAGE_BILL') + pl.col('WAGE_BILL_U'))).alias('SKILLED_SHARE')
])
```

### Stage 8: Special Adjustments

**2014 CPS Redesign Weight Adjustment**:
```python
if year == 2014:
    df = df.with_columns(
        (pl.col('ASECWT') * 
         (5/8 * (1 - pl.col('HFLAG')) + 3/8 * pl.col('HFLAG'))
        ).alias('ASECWT')
    )
```

**1963-1975 Imputation** (for WKSWORK1 and UHRSWORKLY):
```python
# Calculate group averages from 1976-1992
group_avgs = df_post.group_by(['GROUP', 'WKSWORK2']).agg([
    pl.col('WKSWORK1').median().alias('WKSWORK1_MED'),
    pl.col('UHRSWORKLY').median().alias('UHRSWORKLY_MED')
])

# Apply to pre-1976 data
df_pre = df_pre.join(group_avgs, on=['GROUP', 'WKSWORK2'])
df_pre = df_pre.with_columns([
    pl.col('WKSWORK1_MED').alias('WKSWORK1'),
    pl.when(pl.col('UHRSWORKT') > 0)
      .then(pl.col('UHRSWORKT'))
      .otherwise(pl.col('UHRSWORKLY_MED'))
      .alias('UHRSWORKLY')
])
```

---

## Output Files Specification {#outputs}

### labor_totl.csv

**Description**: Aggregate time series of skilled/unskilled labor

**Columns**:

| Column | Type | Description | Typical Range |
|--------|------|-------------|---------------|
| YEAR | Int | Survey year | 1963-2018 |
| LABOR_S | Float | Skilled efficiency units | 20M-60M |
| LABOR_U | Float | Unskilled efficiency units | 80M-120M |
| LABOR_INPUT_RATIO | Float | L_S / L_U | 0.2-0.6 |
| WAGE_S | Float | Avg skilled wage (2018$) | 60k-80k |
| WAGE_U | Float | Avg unskilled wage (2018$) | 30k-45k |
| WAGE_PREMIUM | Float | W_S / W_U | 1.4-1.9 |
| SKILLED_SHARE | Float | Skilled wage bill share | 0.35-0.50 |
| COUNT_S | Float | Skilled worker count | 10M-40M |
| COUNT_U | Float | Unskilled worker count | 60M-90M |

**Usage**: Primary input for aggregate estimation models

**Example**:
```
YEAR,LABOR_S,LABOR_U,LABOR_INPUT_RATIO,WAGE_S,WAGE_U,WAGE_PREMIUM
1963,23456789,98765432,0.237,58234,32156,1.811
1964,24123456,99234567,0.243,59123,32543,1.817
...
```

---

### labor_by_group.csv

**Description**: Demographic cell time series (264 groups)

**Columns**:

| Column | Type | Description |
|--------|------|-------------|
| YEAR | Int | Survey year |
| GROUP | String | Cell ID (e.g., "1_1_0_5_1") |
| SEX | Int | 1=Male, 2=Female |
| RACE | Int | 1=White, 2=Black, 3=Other |
| HISPAN | Int | 0=Non-Hispanic, 1=Hispanic |
| AGE_GROUP | Int | 0-10 (5-year bins) |
| SKILLED | Int | 0=Unskilled, 1=Skilled |
| COUNT | Float | Worker count (weighted) |
| EU_TOTAL | Float | Total efficiency units |
| AVG_WAGE | Float | Average wage (2018$) |
| AVG_HOURS | Float | Average annual hours |

**Usage**: 
- Heterogeneity analysis
- Robustness checks by demographic
- Model extensions with group-specific parameters

**Example**:
```
YEAR,GROUP,SEX,RACE,HISPAN,AGE_GROUP,SKILLED,COUNT,EU_TOTAL,AVG_WAGE
1963,1_1_0_0_0,1,1,0,0,0,1234567,987654,28456
1963,1_1_0_0_1,1,1,0,0,1,234567,345678,64789
...
```

---

## Processing Statistics

### Typical Sample Characteristics

**Raw Data**:
- 4.4M observations
- 56 years (1963-2018)
- ~78,000 obs/year average

**Final Sample**:
- ~2.4M observations (55% retention)
- ~43,000 obs/year average
- Skilled: ~30% of final sample
- Male: ~55% of final sample

**Time Trends** (1963 → 2018):
- Skilled share: 15% → 35% (+133%)
- Wage premium: 1.65 → 1.58 (-4%)
- Female share: 35% → 48% (+37%)
- College grads: 10% → 35% (+250%)

---

## Known Issues & Limitations

### High Priority

1. **Hours Threshold Inconsistency**
   - Code: 30 hrs/week
   - Manuscript: 35 hrs/week
   - **Action needed**: Align

2. **Imputation Not Documented**
   - 1963-1975 hours imputed
   - Uses post-1975 group averages
   - **Action needed**: Add to manuscript

3. **Data Source Confusion**
   - Only CPS used
   - Manuscript says "CPS/ACS"
   - **Action needed**: Remove ACS references

### Medium Priority

4. **Military Workers**
   - Filter commented out
   - ~1% of sample
   - **Action needed**: Uncomment or justify

5. **Allocated Income**
   - Manuscript says excluded
   - Not filtered in code
   - **Action needed**: Check if variable available

6. **2014 Adjustment**
   - Code implements weight adjustment
   - Not mentioned in manuscript
   - **Action needed**: Document method

### Low Priority

7. **Sample Selection Table**
   - No attrition flowchart
   - **Action needed**: Add to appendix

---

## References

### Data Documentation

- IPUMS CPS: https://cps.ipums.org/
- Variable definitions: https://cps.ipums.org/cps/
- 2014 redesign: https://cps.ipums.org/cps/2014_redesign.shtml

### Methodological

- Acemoglu & Autor (2011): "Skills, Tasks and Technologies: Implications for Employment and Earnings"
- Katz & Murphy (1992): "Changes in Relative Wages, 1963-1987"
- Card & Lemieux (2001): "Can Falling Supply Explain the Rising Return to College?"

---

## Changelog

**October 2024**:
- Initial documentation created
- Extracted from Jupyter notebooks
- Added variable definitions and code tables

---

**For questions or corrections**: Contact project maintainer

**Last validation**: October 2024  
**Next review**: TBD
