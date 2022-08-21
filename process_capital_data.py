from curses.ascii import isdigit
import pandas as pd 
from os import listdir
from rich import print

# Path to data
path_raw_data = "./extend_KORV/data/raw/" # To read
path_proc_data = "./extend_KORV/data/interim/" # To write

print("[bold blue]Loading data...")
file_list = [f for f in listdir(path_raw_data) if ".csv" in f]
file_names = [f.split(".")[0] for f in file_list]
data_dict = {}
# Load all datafiles
for i in range(len(file_list)):
    try:
        file = file_list[i]
        file_name = file_names[i]
        data = pd.read_csv(path_raw_data + file, sep=";") 
        data.drop(columns=['TableName', 'LineNumber', 'METRIC_NAME', 'CL_UNIT', 'UNIT_MULT', "LineDescription"], inplace=True)
        data.rename(columns=lambda x: x.split("_")[-1], inplace=True)
        data["BEAIND"] = data.SeriesCode.apply(lambda x: x[3:7] )
        data.drop(columns=['SeriesCode'], inplace=True)
        print("[bold green] Loaded [bold white] {}".format(file))
        data_dict[file_name] = data
    except:
        print("[bold red]Error loading {}".format(file))
        continue
print("[bold green] Data loaded.")

# Get list of years
years = data_dict[list(data_dict.keys())[0]].columns.to_list()[0:-1]
years.sort()
print("Data Available for {} years".format(len(years)))
# print(years)
# Get list of BEAINDs
beainds = list(data_dict[list(data_dict.keys())[0]].BEAIND)
# Create list of file names
file_names = ["capital_" + bi + ".csv" for bi in beainds]

print("[bold blue] Creating dataframes...")
dict_ind = {
    bi : {
        "year" : years,
    }
    for bi in beainds
}

# Create dataframes for each BEAIND
for (name, data) in data_dict.items():
    for bi in beainds:
        data_name = bi
        col = data[data.BEAIND == bi][years].iloc[0].to_list()
        col_name = name
        dict_ind[bi][col_name] = list( map( lambda x : x.replace(",", "."), col ) )

print("[bold green] Dataframes created.")

# Save dataframes to csv
print("[bold blue] Saving dataframes...")
for (name, file_name) in zip(beainds, file_names):
    try:
        df = pd.DataFrame(dict_ind[name])
        df.to_csv(path_proc_data + file_name, sep=";", index=False)
        print("[bold green] Saved {}".format(file_name))
    except:
        print("[bold red]Error saving {}".format(file_name))
        continue
print("[bold green] Dataframes saved.")