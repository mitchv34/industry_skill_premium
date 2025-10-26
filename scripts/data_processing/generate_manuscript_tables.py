"""
Generate all LaTeX tables for manuscript Data Description section.

This script creates publication-ready LaTeX tables from processed data:
1. Aggregate summary statistics by decade
2. Industry-level trend correlations
3. Labor share heterogeneity groups
4. Slope distribution figure

Inputs:
- data/Data_KORV.csv: Aggregate time series
- data/proc/ind/*.csv: Industry-level data
- data/results/labor_share_by_industry.csv: Labor share statistics
- data/cross_walk.csv: Industry name mappings

Outputs:
- documents/tables/*.tex: LaTeX table files
- documents/images/slope_distribution.pdf: Slope distribution figure
- data/results/*.csv: Summary statistics CSVs
"""

import pandas as pd
import numpy as np
import matplotlib.pyplot as plt
import seaborn as sns
from pathlib import Path
from scipy.stats import linregress
import warnings
warnings.filterwarnings('ignore')

# Set seaborn style for sleek plots
sns.set_style("whitegrid")
sns.set_context("paper", font_scale=1.2)

# Setup paths
ROOT = Path(__file__).resolve().parents[2]
DATA_DIR = ROOT / 'data'
DATA_IND = DATA_DIR / 'proc' / 'ind'
RESULTS_DIR = DATA_DIR / 'results'
TABLES_DIR = ROOT / 'documents' / 'tables'
IMAGES_DIR = ROOT / 'documents' / 'images'

# Create output directories
RESULTS_DIR.mkdir(exist_ok=True, parents=True)
TABLES_DIR.mkdir(exist_ok=True, parents=True)
IMAGES_DIR.mkdir(exist_ok=True, parents=True)

print("="*100)
print("GENERATING MANUSCRIPT TABLES FOR DATA DESCRIPTION SECTION")
print("="*100)
print(f"\nRoot directory: {ROOT}")
print(f"Data directory: {DATA_DIR}")
print(f"Output directories created")


# ============================================================================
# TABLE 1: AGGREGATE SUMMARY STATISTICS BY DECADE
# ============================================================================
print("\n" + "="*100)
print("TABLE 1: AGGREGATE SUMMARY STATISTICS BY DECADE")
print("="*100)

# Load aggregate data
korv_data = pd.read_csv(DATA_DIR / 'Data_KORV.csv', skipinitialspace=True)

# Add year column (KORV data covers 1963-1992, but file might be extended)
korv_data['YEAR'] = range(1963, 1963 + len(korv_data))

# Calculate derived variables
korv_data['SKILL_PREMIUM'] = korv_data['W_S'] / korv_data['W_U']
korv_data['LABOR_INPUT_RATIO'] = korv_data['L_S'] / korv_data['L_U']
korv_data['CAPITAL_RATIO'] = korv_data['K_EQ'] / korv_data['K_STR']
korv_data['TOTAL_CAPITAL'] = korv_data['K_EQ'] + korv_data['K_STR']

print(f"Loaded aggregate data: {korv_data['YEAR'].min()}-{korv_data['YEAR'].max()} ({len(korv_data)} years)")

# Create decade groupings
korv_data['DECADE'] = (korv_data['YEAR'] // 10) * 10

def decade_growth(group, var):
    """Calculate annualized growth rate for a decade"""
    if len(group) < 2:
        return np.nan
    initial = group[var].iloc[0]
    final = group[var].iloc[-1]
    years = len(group) - 1
    if initial > 0 and years > 0:
        return ((final / initial) ** (1/years) - 1) * 100
    return np.nan

# Calculate decade statistics
decade_stats = []

for decade in sorted(korv_data['DECADE'].unique()):
    decade_data = korv_data[korv_data['DECADE'] == decade]
    
    stats = {
        'Decade': f"{decade}s",
        'Years': f"{decade_data['YEAR'].min()}-{decade_data['YEAR'].max()}",
        'N': len(decade_data),
        
        # Means
        'SP_mean': decade_data['SKILL_PREMIUM'].mean(),
        'LIR_mean': decade_data['LABOR_INPUT_RATIO'].mean(),
        'K_EQ_mean': decade_data['K_EQ'].mean(),
        'K_STR_mean': decade_data['K_STR'].mean(),
        'K_RATIO_mean': decade_data['CAPITAL_RATIO'].mean(),
        'L_SHARE_mean': decade_data['L_SHARE'].mean(),
        'OUTPUT_mean': decade_data['OUTPUT'].mean(),
        
        # Growth rates (annualized %)
        'SP_growth': decade_growth(decade_data, 'SKILL_PREMIUM'),
        'LIR_growth': decade_growth(decade_data, 'LABOR_INPUT_RATIO'),
        'K_EQ_growth': decade_growth(decade_data, 'K_EQ'),
        'K_STR_growth': decade_growth(decade_data, 'K_STR'),
        'K_RATIO_growth': decade_growth(decade_data, 'CAPITAL_RATIO'),
        'L_SHARE_growth': decade_growth(decade_data, 'L_SHARE'),
        'OUTPUT_growth': decade_growth(decade_data, 'OUTPUT'),
    }
    decade_stats.append(stats)

decade_summary = pd.DataFrame(decade_stats)

print(f"\nComputed statistics for {len(decade_summary)} decades")
print("\nMeans:")
print(decade_summary[['Decade', 'SP_mean', 'LIR_mean', 'K_RATIO_mean', 'L_SHARE_mean']].to_string(index=False))

# Generate LaTeX table with two-row structure
latex_agg = r"""\begin{table}[H]
\centering
\caption{Aggregate Summary Statistics by Decade}
\label{tab:aggregate_summary_stats}
\small
\begin{tabular}{lccc}
\toprule
\multicolumn{4}{c}{\textbf{Panel A: Prices and Technology}} \\
\midrule
Decade & Skill Premium & Labor Input Ratio & Capital Ratio \\
\midrule
"""

for _, row in decade_summary.iterrows():
    latex_agg += f"{row['Decade']} & "
    latex_agg += f"{row['SP_mean']:.3f} ({row['SP_growth']:+.2f}\\%) & "
    latex_agg += f"{row['LIR_mean']:.3f} ({row['LIR_growth']:+.2f}\\%) & "
    latex_agg += f"{row['K_RATIO_mean']:.3f} ({row['K_RATIO_growth']:+.2f}\\%) \\\\\n"

latex_agg += r"""\midrule
\multicolumn{4}{c}{\textbf{Panel B: Labor and Output}} \\
\midrule
Decade & Labor Share & Output Growth & \\
\midrule
"""

for _, row in decade_summary.iterrows():
    latex_agg += f"{row['Decade']} & "
    latex_agg += f"{row['L_SHARE_mean']:.3f} ({row['L_SHARE_growth']:+.2f}\\%) & "
    latex_agg += f"{row['OUTPUT_growth']:+.2f}\\% & \\\\\n"

latex_agg += r"""\bottomrule
\end{tabular}
\begin{minipage}{\textwidth}
\vspace{0.2cm}
\footnotesize
\textit{Notes:} Table shows mean levels and annualized growth rates (in parentheses) by decade.
Skill Premium = W\_S/W\_U. Labor Input Ratio = L\_S/L\_U. Capital Ratio = K\_EQ/K\_STR.
Labor Share is labor's share of national income. Growth rates are annualized percentage changes within each decade.
\end{minipage}
\end{table}"""

# Save
output_file = TABLES_DIR / 'aggregate_summary_stats.tex'
with open(output_file, 'w') as f:
    f.write(latex_agg)

# Save CSV
decade_summary.to_csv(RESULTS_DIR / 'aggregate_decade_summary.csv', index=False)

print(f"✅ LaTeX table: {output_file.relative_to(ROOT)}")
print(f"✅ CSV data: {(RESULTS_DIR / 'aggregate_decade_summary.csv').relative_to(ROOT)}")


# ============================================================================
# TABLE 2: INDUSTRY-LEVEL TREND ANALYSIS
# ============================================================================
print("\n" + "="*100)
print("TABLE 2: INDUSTRY-LEVEL TREND ANALYSIS")
print("="*100)

# Load crosswalk for industry names
crosswalk = pd.read_csv(DATA_DIR / 'cross_walk.csv')
# Map KLEMS codes to BEA codes and industry names
klems_to_bea = dict(zip(crosswalk['code_klems'].str.upper(), crosswalk['code_bea'].str.upper()))
code_to_name = dict(zip(crosswalk['code_bea'].str.upper(), crosswalk['ind_desc']))

print(f"Loaded crosswalk with {len(crosswalk)} industries")

# Process each industry to calculate trend slopes
industry_trends = []

for file in sorted(DATA_IND.glob('*.csv')):
    try:
        klems_code = file.stem.upper()  # File uses KLEMS code
        ind_code = klems_to_bea.get(klems_code, klems_code)  # Convert to BEA code
        df = pd.read_csv(file)
        
        if len(df) < 5:  # Need sufficient data for trend
            continue
        
        df = df.sort_values('YEAR')
        years = df['YEAR'].values
        
        # Calculate slopes using linear regression
        slopes = {}
        
        # Skill premium slope (prefer pre-computed column, else compute safely)
        if 'SKILL_PREMIUM' in df.columns:
            skill_prem = df['SKILL_PREMIUM'].values
        elif 'W_S' in df.columns and 'W_U' in df.columns:
            # avoid division by zero
            denom = df['W_U'].replace(0, np.nan)
            skill_prem = (df['W_S'] / denom).values
        else:
            skill_prem = np.array([])

        if len(skill_prem) > 0 and not np.all(np.isnan(skill_prem)):
            try:
                slope, _, _, _, _ = linregress(years, skill_prem)
                slopes['SP_slope'] = slope
            except Exception:
                pass

        # Labor input ratio slope (prefer pre-computed column, else compute safely)
        if 'LABOR_INPUT_RATIO' in df.columns:
            labor_ratio = df['LABOR_INPUT_RATIO'].values
        elif 'L_S' in df.columns and 'L_U' in df.columns:
            denom = df['L_U'].replace(0, np.nan)
            labor_ratio = (df['L_S'] / denom).values
        else:
            labor_ratio = np.array([])

        if len(labor_ratio) > 0 and not np.all(np.isnan(labor_ratio)):
            try:
                slope, _, _, _, _ = linregress(years, labor_ratio)
                slopes['LIR_slope'] = slope
            except Exception:
                pass
        
        # Capital ratio slope
        if 'K_EQ' in df.columns and 'K_STR' in df.columns:
            capital_ratio = (df['K_EQ'] / df['K_STR']).values
            if len(capital_ratio) > 0 and not np.all(np.isnan(capital_ratio)):
                slope, _, _, _, _ = linregress(years, capital_ratio)
                slopes['KR_slope'] = slope
        
        # Labor share slope
        if 'L_SHARE' in df.columns:
            l_share = df['L_SHARE'].values
            if len(l_share) > 0 and not np.all(np.isnan(l_share)):
                slope, _, _, _, _ = linregress(years, l_share)
                slopes['LS_slope'] = slope
        
        if slopes:  # Only add if we calculated at least one slope
            slopes['Industry'] = code_to_name.get(ind_code, ind_code)
            slopes['Code'] = ind_code
            industry_trends.append(slopes)
            
    except Exception as e:
        print(f"Warning: Error processing {file.name}: {e}")

trends_df = pd.DataFrame(industry_trends)

print(f"✅ Calculated trends for {len(trends_df)} industries")

# Print distribution statistics
print("\nDistribution Statistics:")
for var in ['SP_slope', 'LIR_slope', 'KR_slope', 'LS_slope']:
    if var in trends_df.columns:
        data = trends_df[var].dropna()
        n_positive = (data > 0).sum()
        pct_positive = (n_positive / len(data)) * 100
        
        print(f"\n  {var.replace('_slope', '')}:")
        print(f"    N industries: {len(data)}")
        print(f"    Increasing: {n_positive} ({pct_positive:.1f}%)")
        print(f"    Median: {data.median():.6f}")
        print(f"    IQR: [{data.quantile(0.25):.6f}, {data.quantile(0.75):.6f}]")

# Save industry trends
trends_df.to_csv(RESULTS_DIR / 'industry_trends.csv', index=False)
print(f"\n✅ CSV data: {(RESULTS_DIR / 'industry_trends.csv').relative_to(ROOT)}")


# ============================================================================
# TABLE 3: CORRELATION MATRIX
# ============================================================================
print("\n" + "="*100)
print("TABLE 3: CORRELATION MATRIX OF INDUSTRY TRENDS")
print("="*100)

corr_data = trends_df[['SP_slope', 'LIR_slope', 'KR_slope', 'LS_slope']].dropna()

if len(corr_data) > 0:
    corr_matrix = corr_data.corr()
    
    print(f"Computing correlations for {len(corr_data)} industries with complete data")
    print("\nPearson correlations:")
    print(corr_matrix.to_string())
    
    # Generate LaTeX correlation matrix
    latex_corr = r"""\begin{table}[H]
\centering
\caption{Correlation Matrix of Industry-Level Trends}
\label{tab:correlations_matrix}
\small
\begin{tabular}{lcccc}
\toprule
 & Skill Premium & Labor Input Ratio & Capital Ratio & Labor Share \\
\midrule
"""
    
    var_names = {
        'SP_slope': 'Skill Premium',
        'LIR_slope': 'Labor Input Ratio',
        'KR_slope': 'Capital Ratio',
        'LS_slope': 'Labor Share'
    }
    
    for var in ['SP_slope', 'LIR_slope', 'KR_slope', 'LS_slope']:
        latex_corr += var_names[var]
        for var2 in ['SP_slope', 'LIR_slope', 'KR_slope', 'LS_slope']:
            corr_val = corr_matrix.loc[var, var2]
            if var == var2:
                latex_corr += " & 1.00"
            else:
                latex_corr += f" & {corr_val:.2f}"
        latex_corr += " \\\\\n"
    
    latex_corr += r"""\bottomrule
\end{tabular}
\begin{minipage}{\textwidth}
\vspace{0.2cm}
\footnotesize
\textit{Notes:} Pearson correlation coefficients between industry-level trend slopes.
Each slope is estimated via OLS regression of the variable on year for each industry.
Based on """ + str(len(corr_data)) + r""" industries with complete data.
Skill Premium = W\_S/W\_U, Labor Input Ratio = L\_S/L\_U, Capital Ratio = K\_EQ/K\_STR.
\end{minipage}
\end{table}"""
    
    # Save
    output_file = TABLES_DIR / 'correlations_matrix.tex'
    with open(output_file, 'w') as f:
        f.write(latex_corr)
    
    corr_matrix.to_csv(RESULTS_DIR / 'trend_correlations.csv')
    
    print(f"✅ LaTeX table: {output_file.relative_to(ROOT)}")
    print(f"✅ CSV data: {(RESULTS_DIR / 'trend_correlations.csv').relative_to(ROOT)}")
else:
    print("⚠️ Not enough data for correlation matrix")


# ============================================================================
# TABLE 4: LABOR SHARE HETEROGENEITY
# ============================================================================
print("\n" + "="*100)
print("TABLE 4: LABOR SHARE HETEROGENEITY BY TREND GROUP")
print("="*100)

# Load already computed labor share data
labor_share_table = pd.read_csv(RESULTS_DIR / 'labor_share_by_industry.csv')

print(f"Loaded labor share data for {len(labor_share_table)} industries")

# Categorize industries by labor share change
def categorize_ls_trend(change):
    if change < -0.15:
        return 'Fast Declining'
    elif change < 0:
        return 'Slow Declining'
    else:
        return 'Stable/Increasing'

labor_share_table['Category'] = labor_share_table['Change'].apply(categorize_ls_trend)

# Group statistics
ls_groups = labor_share_table.groupby('Category').agg({
    'Industry': 'count',
    'Initial LS': 'mean',
    'Final LS': 'mean',
    'Change': 'mean',
    'Annual Growth (%)': 'mean'
}).rename(columns={'Industry': 'N Industries'})

print("\nGroup Statistics:")
print(ls_groups.to_string())

# Generate LaTeX table
latex_ls_het = r"""\begin{table}[H]
\centering
\caption{Industries Grouped by Labor Share Trends}
\label{tab:labor_share_heterogeneity}
\small
\begin{tabular}{lccccc}
\toprule
Group & N & Initial LS & Final LS & Change & Growth (\%/yr) \\
\midrule
"""

for cat in ['Fast Declining', 'Slow Declining', 'Stable/Increasing']:
    if cat in ls_groups.index:
        row = ls_groups.loc[cat]
        latex_ls_het += f"{cat} & "
        latex_ls_het += f"{int(row['N Industries'])} & "
        latex_ls_het += f"{row['Initial LS']:.3f} & "
        latex_ls_het += f"{row['Final LS']:.3f} & "
        latex_ls_het += f"{row['Change']:.3f} & "
        latex_ls_het += f"{row['Annual Growth (%)']:.2f} \\\\\n"

latex_ls_het += r"""\bottomrule
\end{tabular}
\begin{minipage}{\textwidth}
\vspace{0.2cm}
\footnotesize
\textit{Notes:} Industries grouped by labor share change over 1987-2018 period.
Fast Declining: change < -15 pp. Slow Declining: -15 pp $\leq$ change < 0. 
Stable/Increasing: change $\geq$ 0.
Initial LS and Final LS are mean values within each group.
Growth is mean annualized percentage change.
\end{minipage}
\end{table}"""

# Save
output_file = TABLES_DIR / 'labor_share_heterogeneity.tex'
with open(output_file, 'w') as f:
    f.write(latex_ls_het)

ls_groups.to_csv(RESULTS_DIR / 'labor_share_groups.csv')

print(f"✅ LaTeX table: {output_file.relative_to(ROOT)}")
print(f"✅ CSV data: {(RESULTS_DIR / 'labor_share_groups.csv').relative_to(ROOT)}")


# ============================================================================
# FIGURE: SLOPE DISTRIBUTION
# ============================================================================
print("\n" + "="*100)
print("FIGURE: DISTRIBUTION OF INDUSTRY TREND SLOPES")
print("="*100)

# Create figure with seaborn style
fig, axes = plt.subplots(2, 2, figsize=(14, 11))
fig.suptitle('Distribution of Industry-Level Trend Slopes (1987-2018)', 
             fontsize=16, fontweight='bold', y=0.995)

variables = [
    ('SP_slope', 'Skill Premium Slope', axes[0, 0]),
    ('LIR_slope', 'Labor Input Ratio Slope', axes[0, 1]),
    ('KR_slope', 'Capital Ratio Slope', axes[1, 0]),
    ('LS_slope', 'Labor Share Slope', axes[1, 1])
]

for var, title, ax in variables:
    if var in trends_df.columns:
        data = trends_df[var].dropna()
        
        # Create histogram with seaborn
        sns.histplot(data, bins=15, color='#2E86AB', alpha=0.75, 
                    edgecolor='white', linewidth=0.5, ax=ax, kde=False)
        
        # Add vertical line at zero
        ax.axvline(0, color='#A23B72', linestyle='--', linewidth=2, 
                  label='Zero', alpha=0.8)
        
        # Add median line
        median_val = data.median()
        ax.axvline(median_val, color='#F18F01', linestyle='-', linewidth=2, 
                  label=f'Median: {median_val:.4f}', alpha=0.8)
        
        # Labels and formatting
        ax.set_xlabel('Slope (units per year)', fontsize=11, fontweight='semibold')
        ax.set_ylabel('Number of Industries', fontsize=11, fontweight='semibold')
        ax.set_title(title, fontsize=12, fontweight='bold', pad=10)
        
        # Legend with better styling
        ax.legend(fontsize=10, frameon=True, fancybox=True, shadow=True, 
                 loc='upper right')
        
        # Despine - remove top and right spines
        sns.despine(ax=ax, top=True, right=True)
        
        # Add subtle grid
        ax.grid(alpha=0.2, linestyle=':', linewidth=0.5)
        ax.set_axisbelow(True)
        
        # Add stats text box with better styling
        n_positive = (data > 0).sum()
        pct_positive = (n_positive / len(data)) * 100
        stats_text = f'N = {len(data)}\n{pct_positive:.0f}% increasing'
        ax.text(0.05, 0.95, stats_text, transform=ax.transAxes,
                verticalalignment='top', horizontalalignment='left',
                bbox=dict(boxstyle='round,pad=0.5', facecolor='#FFF8DC', 
                         edgecolor='gray', alpha=0.8, linewidth=1),
                fontsize=10, fontweight='semibold')

plt.tight_layout()

# Save figure
output_fig = IMAGES_DIR / 'slope_distribution.pdf'
plt.savefig(output_fig, dpi=300, bbox_inches='tight')
plt.close()

print(f"✅ Figure saved: {output_fig.relative_to(ROOT)}")


# ============================================================================
# SUMMARY
# ============================================================================
print("\n" + "="*100)
print("SUMMARY OF GENERATED FILES")
print("="*100)

print("\n📊 LaTeX Tables:")
print(f"  1. {(TABLES_DIR / 'aggregate_summary_stats.tex').relative_to(ROOT)}")
print(f"  2. {(TABLES_DIR / 'correlations_matrix.tex').relative_to(ROOT)}")
print(f"  3. {(TABLES_DIR / 'labor_share_heterogeneity.tex').relative_to(ROOT)}")
print(f"  4. {(TABLES_DIR / 'labor_share_by_industry.tex').relative_to(ROOT)} (already created)")

print("\n📈 Figures:")
print(f"  1. {(IMAGES_DIR / 'slope_distribution.pdf').relative_to(ROOT)}")

print("\n💾 Data Files:")
print(f"  1. {(RESULTS_DIR / 'aggregate_decade_summary.csv').relative_to(ROOT)}")
print(f"  2. {(RESULTS_DIR / 'industry_trends.csv').relative_to(ROOT)}")
print(f"  3. {(RESULTS_DIR / 'trend_correlations.csv').relative_to(ROOT)}")
print(f"  4. {(RESULTS_DIR / 'labor_share_groups.csv').relative_to(ROOT)}")
print(f"  5. {(RESULTS_DIR / 'labor_share_by_industry.csv').relative_to(ROOT)}")

print("\n" + "="*100)
print("✅ ALL TABLES AND FIGURES GENERATED SUCCESSFULLY")
print("="*100)
print("\nThese files are ready to \\input{} into your manuscript!")
