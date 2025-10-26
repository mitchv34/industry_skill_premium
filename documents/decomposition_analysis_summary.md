# Decomposition Analysis Summary

## Overview
This document summarizes the decomposition of skill premium growth across 28 industries using equation (11) from the manuscript.

## Key Findings

### 1. CSC Effect Dominance
- **22 out of 28 industries (78.6%)** show that the Capital-Skill Complementarity (CSC) effect dominates the supply effect
- This provides strong industry-level evidence for CSC as the primary driver of skill premium changes

### 2. Parameter Evidence
- **Mean σ - ρ = 0.861** across industries (positive indicates CSC)
- **Median σ - ρ = 1.077** (confirming positive CSC is the norm)
- Only 3 industries show negative σ - ρ (311FT, 3361MV, 44RT)

### 3. Decomposition Results by Channel

#### Supply Effect (H_s/H_u changes)
- Median contribution: **-685.0%** (note: percentages sum to 100% within each industry)
- In most industries, increased relative skill supply would have *reduced* the skill premium
- But this was offset by other factors

#### CSC Effect (K_eq/K_str changes)
- Median contribution: **1261.0%**
- Strong positive contribution in most industries
- Industries with highest CSC: Wholesale Trade (42), Utilities (22), Computer/Electronic (335)

#### Efficiency Effect (A_s/A_u changes)
- Median contribution: **-530.2%**
- This residual captures productivity changes not explained by observables
- Often counteracts the CSC effect

### 4. Industries Where CSC Dominates Most Strongly
Top 5 industries by CSC percentage contribution:
1. **Wholesale Trade (42)**: 541,216% CSC contribution
2. **Utilities (22)**: 39,458% CSC contribution  
3. **Electrical Equipment (335)**: 10,630% CSC contribution
4. **Furniture (337)**: 5,370% CSC contribution
5. **Machinery (333)**: 4,863% CSC contribution

### 5. Industries Where Supply Effect Dominates
Only 6 industries show supply effect > CSC effect (21.4%):
- Mining (211, 212, 213)
- Food Manufacturing (311FT, 313TT)  
- Motor Vehicles (3361MV)
- Retail Trade (44RT)
- Warehousing (485)
- Chemical Manufacturing (326)
- Agriculture (111CA)
- Textile Mills (313TT)

## Interpretation

### Why Are Percentages So Large?
The percentage contributions can exceed ±100% because:
1. Multiple effects work in opposite directions
2. When the total change is small, percentage contributions become very large
3. The three effects must sum to 100%, but individually can be >100% if they partially offset each other

### More Meaningful Metrics
Looking at the **absolute contributions (log points)**:
- Median total change: 0.127 log points (~13.5% skill premium change)
- Typical CSC effect size: 1-10 log points (industries 322, 323, 332, 483)
- Typical supply effect: -1 to -5 log points (offsetting CSC)

### Economic Interpretation
1. **Equipment investment complementary to skilled labor**: The positive σ - ρ in most industries confirms that equipment capital and skilled labor are complements

2. **Supply would have reduced premiums**: In isolation, the growth in college graduates would have reduced skill premiums substantially

3. **Technology-driven demand shift**: The CSC effect (equipment growth) more than offset supply increases, driving up skill premiums

4. **Industry heterogeneity matters**: Different industries show very different decomposition patterns, suggesting industry-specific analysis is valuable

## Data Quality Notes
- **28 of 32 industries** successfully decomposed (87.5% success rate)
- **4 industries failed** due to numerical issues with estimated parameters
- All successful industries had stable parameter estimates with finite elasticities

## Files Generated
1. `data/results/decomposition_by_industry.csv` - Full results with all parameters
2. `documents/tables/decomposition_by_industry.tex` - Detailed LaTeX table
3. `documents/tables/decomposition_summary.tex` - Summary statistics table

## Next Steps for Manuscript
1. Add the decomposition tables to the results section
2. Discuss industries where CSC dominates vs. doesn't
3. Link to parameter estimates (σ, ρ, σ-ρ) from Table 1
4. Add discussion of magnitude vs. percentage contributions
5. Consider industry groupings (manufacturing vs. services, high-tech vs. traditional)
