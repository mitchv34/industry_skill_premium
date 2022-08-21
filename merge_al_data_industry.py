# %%
import pandas as pd
from rich import print

xwalk = pd.read_csv("./extend_KORV/data/interim/cross_walk.csv")
klems_code = xwalk["code_klems"].values.tolist()
bea_code = xwalk["code_bea"].values.tolist()

gdp_def = pd.read_csv("./extend_KORV/data/raw/gdpdef.csv")

gdp_def.value = gdp_def.value / 100
gdp_def.date = gdp_def.date.apply(lambda x : int(x[:4]))
gdp_def = gdp_def.loc[ gdp_def.date >= 1987 , :]
gdp_def = gdp_def.loc[ gdp_def.date <= 2018 , :]
gdp_def.date = gdp_def.date.apply(lambda x : str(x))
gdp_def.set_index("date", inplace=True)

# Read labor share and output data 
labor_share = pd.read_csv("/Users/mitchv34/my_work/field_paper_clean/extend_KORV/data/interim/labor_share.csv")
output = pd.read_csv("/Users/mitchv34/my_work/field_paper_clean/extend_KORV/data/interim/output.csv")



for (ind_bea, ind_klems) in zip(bea_code, klems_code):
    # Select labor share data and output for the industry
    labor_share_ind = labor_share.loc[labor_share["Production Account Codes"] == ind_klems]
    output_ind = output.loc[output["Production Account Codes"] == ind_klems]

    years = [y for y in labor_share_ind.columns if y.isdigit()]

    labor_share_ind = labor_share_ind.T.loc[years]
    output_ind = output_ind.T.loc[years]

    labor_share_ind.rename(columns={labor_share_ind.columns[0] : "L_SHARE"}, inplace=True)
    output_ind.rename(columns={output_ind.columns[0] : "OUTPUT"}, inplace=True)


    # Merge both dataframes
    merged = pd.merge(labor_share_ind, output_ind, left_index=True, right_index=True)
    # Deflate output
    merged.OUTPUT = merged.OUTPUT.astype(float) /gdp_def.value

    # Read Capital Data
    code_list = ind_bea.split(",")
    capital_data = pd.DataFrame({   "YEAR" : map(str , range(1947, 2021)), 
                                    "K_STR" : [0]*len(range(1947, 2021)),
                                    "K_EQ" :[0]*len(range(1947, 2021)),
                                    "REL_P_EQ" : [0]*len(range(1947, 2021)),
                                    "DPR_ST": [0]*len(range(1947, 2021)),
                                    "DPR_EQ": [0]*len(range(1947, 2021))}).set_index("YEAR")

    for ind_ in code_list:
        capital_data_temp = pd.read_csv(f"./extend_KORV/data/interim/ind_capital/{ind_.strip()}.csv")
        capital_data_temp.YEAR = capital_data_temp.YEAR.astype(int).astype(str)
        capital_data_temp.set_index("YEAR", inplace=True)
        capital_data.K_STR += capital_data_temp.K_STR * 1000
        capital_data.K_EQ += capital_data_temp.K_EQ * 1000
        capital_data.REL_P_EQ += capital_data_temp.REL_P_EQ
    
    capital_data.REL_P_EQ /= len(code_list)

    # Merge (again) both dataframes
    merged = pd.merge(merged, capital_data, left_index=True, right_index=True)

    labor = pd.read_csv(f"./extend_KORV/data/interim/ind_labor/{ind_klems}.csv")
    if len(labor) == 0:
        continue
    labor.YEAR = labor.YEAR.astype(int).astype(str)
    labor.set_index("YEAR", inplace=True)

    # Merge (again) both dataframes
    merged = pd.merge(merged, labor, left_index=True, right_index=True)

    merged.reset_index(inplace=True)
    merged.rename(columns={"index": "YEAR"}, inplace=True)

    merged.loc[:,["L_U", "L_S"]] = merged.loc[:,["L_U", "L_S"]] / 1000
    merged.loc[:,["K_STR", "K_EQ"]] = merged.loc[:,["K_STR", "K_EQ"]] / 10
    merged.loc[:, ["OUTPUT"]] = merged.loc[:, ["OUTPUT"]] / 1000
    merged.loc[:, ["REL_P_EQ"]] = merged.loc[:, ["REL_P_EQ"]] / merged.loc[0, ["REL_P_EQ"]]

    # print(ind_bea, ind_klems)
    print(merged.head())
    merged.to_csv("./extend_KORV/data/proc/ind/{}.csv".format(ind_klems), index=False)


# %%
