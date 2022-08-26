from curses.ascii import isdigit
import pandas as pd 
from os import listdir
from rich import print

# Path to data
path_raw_data = "./data/raw/gdi.csv" # To read
path_proc_data = "./data/interim/" # To write

print("[bold blue]Loading data...")
data_dict = {}

data = pd.read_csv(path_raw_data, sep=";")
data.drop(columns=['TableName', 'LineNumber', 'METRIC_NAME', 'CL_UNIT', 'UNIT_MULT', "LineDescription"], inplace=True)
data.rename(columns=lambda x: x.split("_")[-1], inplace=True)
data.set_index("SeriesCode", inplace=True)
UCI = data.loc[["W272RC", "A048RC", "A445RC"]].sum()
CI = UCI + data.loc["A262RC"]
Y = data.loc["A261RC"]
PI = data.loc["A041RC"]
labor_share_ingredients = pd.DataFrame({"UCI": UCI, "CI": CI, "Y": Y, "PI": PI})
labor_share_ingredients.to_csv(path_proc_data + "labor_share.csv")

print(labor_share_ingredients)

