# usage: python3 station_xgbooster.py 0.1 PM2.5 PM10 PM2.5 O3 SO2 NO2 CO
# the first argument is the fraction of stations being trained
# the second to last arguments are targets of interests


import os
from sys import argv
import numpy as np
import pandas as pd
import matplotlib.pyplot as plt
from ast import literal_eval
from random import sample

from xgboost import XGBRegressor
from sklearn.utils import shuffle
from sklearn.model_selection import KFold
from multiprocessing import Pool
from tqdm import tqdm

def train(station_id):
    """
    :params
        station_id: station id that uniquely identifies each monitoring station
    """
    
    # select station for train_test, don't shuffle
    df_tt_id = df_tt.loc[station_id, :].copy()
    # sample(frac=1, random_state=0) - this causes CV and TEST R2 to diverge
    df_pred_id = df_pred.loc[station_id, :].copy()
    
    # split into target and features
    X = df_tt_id.loc[:, ~df_tt_id.columns.str.startswith("target_")].drop(['date'], axis=1).values
    y = df_tt_id["target_" + target_name].values
    X_pred = df_pred_id.drop(['date'], axis=1).values
    
    # drop problematic stations
    if X.shape[0] > 100:
        
        # instantiate model and output
        m = XGBRegressor(**params)
        test_out = []
        
        # cross validation
        for train_index, test_index in kf.split(X):
            
            # train-test split
            X_train, X_test = X[train_index], X[test_index]
            y_train, y_test = y[train_index], y[test_index]
            
            # fit regression model
            m.fit(X_train, y_train)

            # test output
            y_test_pred = m.predict(X_test)
            test_out.append(
                pd.DataFrame({
                    'true': y_test,
                    'pred': y_test_pred,
                    'date': df_tt_id.date[test_index],
                    'id': station_id}))
        
        pd.concat(test_out, ignore_index=True).sort_values(by='date').to_csv(
            os.path.join(out_root, target_name, "test/", station_id + ".csv"), index=False)
        
        # prediction output
        m.fit(X, y)
        y_pred = m.predict(X_pred)
        pred_out = pd.DataFrame({
            'pred': y_pred,
            'date': df_pred_id.date,
            'id': station_id})
        pred_out.to_csv(os.path.join(out_root, target_name, "pred/", station_id + ".csv"), index=False)

    
if __name__ == "__main__":
    
    # declare paths
    in_root = "../../data/main/"
    out_root = "../../data/output/xgbooster/"
    
    # import data
    tqdm.write("Loading Data...")
    df_tt_raw = pd.read_csv(os.path.join(in_root, "train_test.csv"))
    df_tt_raw.sort_values(by=['id', 'date'], inplace=True)
    df_tt_raw.set_index(['id'], inplace=True)
    df_pred = pd.read_csv(os.path.join(in_root, "pred.csv"))
    df_pred.sort_values(by=['id', 'date'], inplace=True)
    df_pred.set_index(['id'], inplace=True)
    
    # parse command line arguments, loop over targets
    for target_name in argv[2:]:
        
        # display target variables
        tqdm.write("Target: {}...".format(target_name))
        
        # remove rows missing target
        df_tt = df_tt_raw[~pd.isna(df_tt_raw["target_" + target_name])]
        
        # xgboost hyperparams
        with open(os.path.join(out_root, "params/", "params_" + target_name + ".txt"), 'r') as f:
            params = literal_eval(f.read())
        
        # collect unique station_ids
        station_ids = df_tt.index.unique()
        
        # only process a sub sample
        station_ids = pd.Series(station_ids).sample(
                frac=float(argv[1]), replace=False).tolist()
        
        # initialize k-fold
        kf = KFold(n_splits=5, shuffle=False, random_state=0)
        
        # instantiate parallelization utilities
        p = Pool(8)
        
        # initiate progress bar
        pbar = tqdm(total=len(station_ids))
        
        # training starts
        for _ in p.imap_unordered(train, station_ids):
            pbar.update()
            
        # training ends
        pbar.close()
