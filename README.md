# Industry Skill Premium Analysis

[![Python](https://img.shields.io/badge/python-3.8+-blue.svg)](https://www.python.org/downloads/)
[![R](https://img.shields.io/badge/R-4.0+-276DC3.svg)](https://www.r-project.org/)
[![Julia](https://img.shields.io/badge/julia-1.6+-9558B2.svg)](https://julialang.org/)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

A comprehensive empirical analysis of industry-level skill premiums, capital accumulation, and labor market dynamics using U.S. macroeconomic data from the Bureau of Economic Analysis (BEA), Federal Reserve Economic Data (FRED), and Census Quarterly Workforce Indicators (QWI).

## 📊 Project Overview

This project investigates the relationship between:
- **Capital equipment and structures** accumulation by industry
- **Skill premiums** (skilled vs. unskilled labor wages)
- **Labor share** of output across industries
- **Technology shocks** and their impact on labor markets

The analysis combines:
- Multi-language data pipeline (R → Python → Julia)
- Structural economic modeling with GMM estimation
- Industry-level heterogeneity analysis across 60+ U.S. industries

## 🎯 Key Features

- **Automated data ingestion** from BEA, FRED, and Census APIs
- **Robust ETL pipeline** handling industry-specific time series
- **Structural estimation** using Nelder-Mead optimization
- **Rich visualizations** of model fit and industry dynamics
- **Reproducible workflow** with centralized configuration

## 📁 Repository Structure

```
industry_skill_premium/
├── notebooks/              # Jupyter notebooks for exploration and presentation
│   ├── 01_data_pipeline.ipynb
│   ├── 02_industry_analysis.ipynb
│   └── 03_model_estimation.ipynb
├── scripts/                # Core data processing and estimation scripts
│   ├── data_fetch/         # R scripts for API data fetching
│   ├── data_processing/    # Python ETL scripts
│   └── estimation/         # Julia model estimation scripts
├── data/                   # Data directory (raw data not committed)
│   ├── proc/ind/           # Processed per-industry CSVs (for estimation)
│   └── results/            # Estimation results
├── results_examples/       # Sample outputs and visualizations
├── config.py               # Centralized path configuration
├── requirements.txt        # Python dependencies
└── .github/copilot-instructions.md  # AI agent guidance
```

## 🚀 Quick Start

### Prerequisites

- **Python** 3.8+ with pandas, rich, requests
- **R** 4.0+ with bea.R, fredr, pacman
- **Julia** 1.6+ with DataFrames, CSV, Optim, Plots, ModelingToolkit

### Installation

1. **Clone the repository**
   ```bash
   git clone https://github.com/mitchv34/industry_skill_premium.git
   cd industry_skill_premium
   ```

2. **Install Python dependencies**
   ```bash
   pip install -r requirements.txt
   ```

3. **Install R packages** (in R console)
   ```r
   install.packages('pacman')
   library(pacman)
   p_load(bea.R, fredr)
   ```

4. **Set up Julia environment**
   ```bash
   julia --project=. -e 'using Pkg; Pkg.instantiate()'
   ```

5. **Configure API keys**
   
   Update the following in your scripts or set environment variables:
   - **BEA API Key**: Register at [BEA](https://apps.bea.gov/API/signup/)
   - **FRED API Key**: Register at [FRED](https://fred.stlouisfed.org/docs/api/api_key.html)
   - **Census API Key**: Register at [Census](https://www.census.gov/data/developers/guidance/api-user-guide.html)
   
   Either edit `scripts/get_capital_data.r` and `config.py` or set:
   ```bash
   export CENSUS_API_KEYS_PATH=/path/to/your/api_keys/
   ```

### Running the Pipeline

The analysis follows a three-stage workflow:

#### 1. Data Fetching (R)
```bash
cd scripts/data_fetch
Rscript get_capital_data.r
```
Fetches BEA capital stock data and FRED macroeconomic indicators.

#### 2. Data Processing (Python)
```bash
cd scripts/data_processing
python process_capital_data.py
```
Transforms raw CSVs into per-industry analysis-ready datasets.

#### 3. Model Estimation (Julia)
```bash
julia --project=. estimation/do_estimation.jl
```
Estimates structural parameters for each industry using GMM.

## 📓 Notebooks

Explore the analysis interactively:

1. **[Data Pipeline](notebooks/01_data_pipeline.ipynb)** - Complete data flow from APIs to processed datasets
2. **[Industry Analysis](notebooks/02_industry_analysis.ipynb)** - Deep dive into selected industries with visualizations
3. **[Model Estimation](notebooks/03_model_estimation.ipynb)** - Walkthrough of the estimation methodology and results

## 📈 Sample Results

See [`results_examples/`](results_examples/) for:
- Industry-specific skill premium trends
- Model fit diagnostics
- Capital accumulation patterns
- Labor share dynamics

## 🔬 Methodology

The project employs a structural approach following Krusell et al. (2000) and extensions:

- **Production Function**: Nested CES with capital-skill complementarity
- **Estimation**: Generalized Method of Moments (GMM)
- **Data**: Annual observations 1947-2020 across 60+ industries
- **Identification**: Industry-level variation in technology shocks and factor inputs

## 📊 Data Sources

- **BEA Fixed Assets**: Industry-level capital stocks (equipment, structures, IP)
- **FRED**: Aggregate price deflators and macroeconomic indicators
- **Census QWI**: Industry-level employment and earnings by education

## 🤝 Contributing

This is a research project. If you find issues or have suggestions:
1. Open an issue describing the problem
2. Fork and submit a pull request with improvements

## 📄 License

This project is licensed under the MIT License - see [LICENSE](LICENSE) file for details.

## 📚 Citation

If you use this code or methodology in your research, please cite:

```bibtex
@misc{industry_skill_premium_2025,
  author = {Mitchell Valdes},
  title = {Industry Skill Premium Analysis},
  year = {2025},
  url = {https://github.com/mitchv34/industry_skill_premium}
}
```

## ✉️ Contact

**Mitchell Valdes**  
GitHub: [@mitchv34](https://github.com/mitchv34)

---

*This project showcases end-to-end data science skills: API integration, multi-language pipelines, econometric modeling, and reproducible research practices.*
