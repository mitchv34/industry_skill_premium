from importlib.resources import path
import pandas as pd
from rich import print
import json

path_data = '/Users/mitchv34/my_work/field_paper_clean/extend_KORV/data/raw/industry_definitions.tsv'
    
df = pd.read_csv(path_data, sep='\t', usecols=[0,1,2])
# df.dropna(inplace=True)
bea_ind = df.loc[:, "BEA CODE"]
naisc_ind = df.loc[:, "2012 NAICS Codes"]


equiv_dict = {}

for i in range(len(bea_ind)):
    equiv_dict[bea_ind[i]] = [s.strip() for s in naisc_ind[i].split(",")]


with open("./extend_KORV/data/interim/equi_bea_naics.json", "w") as outfile:
    json.dump(equiv_dict, outfile)