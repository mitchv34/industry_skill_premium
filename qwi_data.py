# Import packages
from os import listdir
import pandas as pd 
import requests
import json
from rich import print

class CensusAPI:
    """_summary_
    """
    def __init__(self, api_key, states, industry_code):
        """_summary_
        """
        self.api_key = api_key
        self.time_init = '2000'
        self.time_final = '2030'
        self.base_url = "https://api.census.gov/data/timeseries/qwi/"
        apiself.endpoint = "se"
        self.variables = {  "EmpS" : "Full-Quarter Employment (Stable): Counts",
                            "EarnS": "Full Quarter Employment (Stable): Average Monthly Earnings"}
        self.sex = [1,2]
        self.education = [1,2,3,4]
        self.states = states
        self.county = "" 
        self.industry = industry_code
        self.request_url = ""
        self.data_frame =  False # This could also be empty dataframe
        self.data = False # This could also be empty list

    def contruct_url(self):
        """_summary_
        """

        education = "&education=E" + "&education=E".join(map(str, self.education))
        variables = ",".join(self.variables.keys())
        states =  ",".join(map(str, self.states))
        self.request_url = self.base_url + f"{self.endpoint}?get={variables}&for=state:{states}&time=from{self.time_init}to{self.time_final}{education}&industry={self.industry}&key="+self.api_key

    def get_data(self):
        """_summary_
        """
        if self.request_url == "":
            self.contruct_url()
        response = requests.get(self.request_url)
        self.data = response.json()

    def get_dataframe(self, return_dataframe=False):
        """_summary_

        Args:
            return_dataframe (bool, optional): _description_. Defaults to True.

        Returns:
            _type_: _description_
        """        
        self.get_data()
        df = pd.DataFrame(self.data[1:], columns=self.data[0])

        if return_dataframe:
            return df
        else:
            self.data_frame = df

    def save_dataframe(self, filename):
        if self.data_frame:
            self.data_frame.to_csv(filename, index=False)
        else:
            if self.data:
                self.data_frame = pd.DataFrame(self.data[1:], columns=self.data[0])
            else:
                self.get_dataframe()
                self.data_frame.to_csv(filename, index=False)
        

if __name__ == "__main__":
    # Read the api key from a file
    api_keys_path = "/Users/mitchv34/my_work/census_data_api/api_key/"
    api_keys = [f for f in listdir(api_keys_path) if "key" in f]

    with open(api_keys_path + '/' + api_keys[0], 'r') as f:
        api_key = f.read()
    ind_code = "1121"
    a = CensusAPI(api_key, ind_code)
    a.contruct_url()
    # print(a.request_url)
    print(a.get_dataframe())