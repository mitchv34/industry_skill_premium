# Scripts Directory

This folder contains all data processing and estimation scripts, organized by function.

## Organization

### 📥 `data_fetch/` - Data Acquisition
**R Scripts:**
- `get_capital_data.r` - Fetches BEA capital stock data and FRED macroeconomic indicators

**Python Scripts:**
- `qwi_data.py` - Census QWI (Quarterly Workforce Indicators) data fetching and processing
- `get_bea_industries_definitions.py` - BEA industry code mappings and definitions

### 🔄 `data_processing/` - ETL & Transformation
- `process_capital_data.py` - Main ETL script: transforms raw BEA/FRED CSVs into per-industry datasets
- `get_labor_share.py` - Computes labor share metrics
- `labor_share_and_output_by_ind.py` - Industry-level labor share calculations
- `merge_al_data_industry.py` - Merges multiple data sources by industry

### 📊 `estimation/` - Julia Analysis Scripts
- `gmm_test_plots.jl` - GMM estimation diagnostics and plots
- `instrument_labor.jl` - Labor market instrument construction
- `proc_capital_data_bulk.jl` - Bulk capital data processing
- `proc_capital_data_example.jl` - Example capital data workflow
- `proc_labor_data.jl` - Labor data processing pipeline
- `proc_labor_data_bulk.jl` - Bulk labor data processing
- `result_analisys.jl` - Results analysis and aggregation
- `segment_labor_data_by ind.jl` - Industry segmentation of labor data

## Usage

### 1. Fetch Data
```bash
cd scripts/data_fetch
Rscript get_capital_data.r
```
**Note**: Update `beaKey` and `fredKey` at the top of the file with your API keys.

```bash
python qwi_data.py
```
**Note**: Update API key path in the script.

### 2. Process Data
```bash
cd scripts/data_processing
python process_capital_data.py
```
Reads from `extend_KORV/data/raw/` and writes to `data/proc/ind/`.

### 3. Run Estimation
The main estimation scripts remain in the root-level `estimation/` directory:
```bash
cd estimation
julia --project=.. do_estimation.jl
```

## Configuration

All paths are centralized in `config.py` at the repository root. Scripts automatically add the repository root to their import path.
