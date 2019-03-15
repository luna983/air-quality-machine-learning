import os, sys
import numpy as np
import pandas as pd
import scipy as sp
from datetime import datetime
from glob import glob
import matplotlib.pyplot as plt
from tqdm import tqdm, tqdm_notebook

# define paths
main_root = "../../data/main/"
new_roots = glob("../../data/csv/*_csv/")
monitor_root = "../../data/csv/monitor/"

# load coordinates
monitor_coords = pd.read_csv(os.path.join(monitor_root, "monitor_coords.csv"))

for year in tqdm(range(2005, 2017)):
    
    # create empty main files or load existing main files
    if not os.path.isfile(os.path.join(main_root, "main_" + str(year) + ".csv")):
        dates = pd.date_range(start=str(year) + "-01-01", end=str(year) + "-12-31")
        main = pd.concat([monitor_coords.assign(date = date) for date in dates],
                         ignore_index=True)
        main.to_csv(os.path.join(main_root, "main_" + str(year) + ".csv"), index=False)
    else:
        main = pd.read_csv(os.path.join(main_root, "main_" + str(year) + ".csv"))
    
    # prepare to merge
    main['date'] = pd.to_datetime(main['date'])
    main.set_index(['id', 'date'], inplace=True)
    
    for new_root in tqdm(new_roots):
        if ("aqi_csv" not in new_root) or (year >= 2015):
            # load all csvs in a particular year
            files = [f for f in os.listdir(new_root) if f.endswith(".csv") and f.startswith(str(year))]
            # stack csv files to be merged
            new = pd.concat([pd.read_csv(os.path.join(new_root, file), engine='python') for file in files],
                            ignore_index=True)
            # convert date to datetime type to be merged with main
            new['date'] = pd.to_datetime(new['date'])
            # prepare to merge
            new.set_index(['id', 'date'], inplace=True)
            # merge
            main = main.join(new)
    
    # save
    main.to_csv(os.path.join(main_root, "main_" + str(year) + ".csv"))