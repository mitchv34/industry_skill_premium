import pandas as pd
from rich import print

# Load data
comp_college = pd.read_csv("./extend_KORV/data/raw/BEA-BLS-industry-level-production-account-1987-2020/Labor_Col Compensation.csv",
                        header=1, usecols= range(35)).set_index("Industry Description")

comp_no_college = pd.read_csv("./extend_KORV/data/raw/BEA-BLS-industry-level-production-account-1987-2020/Labor_NoCol Compensation.csv",
                        header=1, usecols= range(35)).set_index("Industry Description")
comp_VA = pd.read_csv("./extend_KORV/data/raw/BEA-BLS-industry-level-production-account-1987-2020/Value Added.csv",
                        header=1, usecols= range(35)).set_index("Industry Description")
output = pd.read_csv("./extend_KORV/data/raw/BEA-BLS-industry-level-production-account-1987-2020/Gross Output.csv",
                        header=1, usecols= range(35)).set_index("Industry Description")

codes = pd.read_csv("./extend_KORV/data/raw/BEA-BLS-industry-level-production-account-1987-2020/NAICS codes.csv",
                    header=2, usecols= range(3)).set_index("Descriptions")
codes.dropna(inplace=True)


# Merge data

L_SHARE = (comp_college + comp_no_college) / comp_VA
L_SHARE.loc[:, "Production Account Codes"] = codes.loc[:, "Production Account Codes"].apply(lambda x: x.strip())
L_SHARE.loc[:, "2007 NAICS codes"] = codes.loc[:, "2007 NAICS codes"]
L_SHARE.dropna(inplace=True)

output.loc[:, "Production Account Codes"] = codes.loc[:, "Production Account Codes"].apply(lambda x: x.strip())
output.loc[:, "2007 NAICS codes"] = codes.loc[:, "2007 NAICS codes"]
output.dropna(inplace=True)


print(L_SHARE.head())
print(output.head())



# Save data
L_SHARE.to_csv("./extend_KORV/data/interim/labor_share.csv")
output.to_csv("./extend_KORV/data/interim/output.csv")