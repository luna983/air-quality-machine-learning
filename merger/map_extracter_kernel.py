import os, sys
import numpy as np
import pandas as pd
import scipy as sp
from datetime import datetime
import matplotlib.pyplot as plt
import gdal, osr
from scipy.interpolate import RegularGridInterpolator
from tqdm import tqdm, tqdm_notebook

from map_extracter_utils import Raster

assert sys.version_info[0] >= 3, "Python 3 or a more recent version is required."

# construct kernel
x = np.arange(0, 30)
y = np.arange(0, 30)
xx, yy = np.meshgrid(x, y)
kernel = (14.5 ** 2 - ((xx - 14.5)**2 + (yy - 14.5)**2))
kernel[kernel < 0] = 0

# define paths
monitor_coords_file = "../../data/processed/monitor/monitor_coords.csv"
# extract coords
monitor_coords = pd.read_csv(monitor_coords_file)
output = monitor_coords[['id']].copy()
points = monitor_coords[['long', 'lat']].values

# define path, loop through variables
raster_roots = ["../../data/MODAOD/",
                "../../data/MYDAOD/",
                "../../data/omi_no2/",
                "../../data/omi_so2/",
                "../../data/processed/o3/"]
output_roots = ["../../data/processed/modaod_kernel_csv/",
                "../../data/processed/mydaod_kernel_csv/",
                "../../data/processed/no2_kernel_csv/",
                "../../data/processed/so2_kernel_csv/",
                "../../data/processed/o3_kernel_csv/"]

for raster_root, output_root in zip(raster_roots, output_roots):

    # list files
    raster_files = [f for f in os.listdir(raster_root) if f.endswith('.tif')]

    raster_parent = Raster()
    for raster_file in tqdm(raster_files):
        # parse file name
        raster_info = raster_file.split('.')[0]
        date, dataset, variable = raster_info.split('_')
        # variable renaming
        variable = variable + '_kernel'
        # read in array
        raster = gdal.Open(os.path.join(raster_root, raster_file)).ReadAsArray()
        # censor
        raster[raster < -1e+10] = np.nan
        # check dimension
        if raster.shape == (400, 650):
            raster_parent.fill(raster.T)
        elif raster.shape == (650, 400):
            raster_parent.fill(raster)
        else:
            assert False
        # generate output
        raster_output = raster_parent.find_weighted_mean(kernel=kernel, points=points).astype(np.float16)
        # reduce float bytes
        kwargs = {variable: raster_output, 'date': date}
        output.assign(**kwargs).to_csv(os.path.join(output_root, raster_info + '-kernel.csv'), index=False)