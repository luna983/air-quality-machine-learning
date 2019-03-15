import os, sys
import numpy as np
import pandas as pd
import scipy as sp
from datetime import datetime
import matplotlib.pyplot as plt

import gdal, osr

from scipy.interpolate import RegularGridInterpolator

from tqdm import tqdm, tqdm_notebook

class Raster:
    
    import numpy as np
    from scipy.interpolate import RegularGridInterpolator
    
    def __init__(self,
                 latUpper=56 - 0.1/2, longLower=72 + 0.1/2,
                 latStep=0.1, longStep=0.1,
                 latN=400, longN=650):
        """ Record latitude and longitude information on the uniform grid.
        Default to our bounding box in China.
        
        :param
            latUpper, longLower:
                float, the upper left corner of the bounding box
            latStep, longStep:
                float, the spatial resolution in degrees, both should be positive
            latN, longN:
                int, total number of observations in each dimension
        """
        
        # initialized values
        self.latUpper = latUpper
        self.longLower = longLower
        self.latStep = latStep
        self.longStep = longStep
        self.latN = latN
        self.longN = longN
        self.latLower = latUpper - latStep * (latN - 1)
        self.longUpper = longLower + longStep * (longN - 1)
        # compute coordinates
        self.lat = np.linspace(self.latLower, self.latUpper, self.latN)
        self.long = np.linspace(self.longLower, self.longUpper, self.longN)
        # initialize empty array
        self.values = np.empty((self.longN, self.latN))
        self.values.fill(np.nan)
        
    def fill(self, array):
        """ Fill in the raster with the array.
        
        :param
            array:
                2 dimensional ndarray, the first element of the array should be
                the lower left corner of the map (smallest long and lat)
                the array is long (dimension 0) by lat (dimension 1)
        """
        
        # check dimension
        assert array.shape == (self.longN, self.latN), "Dimension Mismatch."
        # copy array
        self.values = array.copy()
    
    def find_neighbor_mean(self, points):
        """ Impute the closest observation contained in self raster.
        
        :param
            points:
                a two-dimensional ndarray with a pair of long, lat in each row
                interpolation will be based on self, output will be returned
        :return
            a one-dimensional ndarray with the interpolated points
        """
        
        # initialize output
        output = np.empty((points.shape[0]))
        output.fill(np.nan)
        
        # extract values from self array via direct indexing
        for i, point in enumerate(points):
            # find source index
            selfLongIndex = int(np.floor(
                (point[0] - self.longLower) / self.longStep))
            selfLatIndex = int(np.floor(
                (point[1] - self.latLower) / self.latStep))
            # impute value
            output[i] = np.nanmean(
                self.values[selfLongIndex:(selfLongIndex + 2), selfLatIndex:(selfLatIndex + 2)])
        return output
    
    def find_interpolated(self, points):
        """ Impute the interpolated values contained in self raster.
        
        :param
            points:
                a two-dimensional ndarray with a pair of long, lat in each row
                interpolation will be based on self, output will be returned
        :return
            a one-dimensional ndarray with the interpolated points
        """
        
        # extract values
        rgi = RegularGridInterpolator((self.long, self.lat), self.values)
        output = rgi(points)
        return output

# EVI

# define paths
monitor_coords_file = "../../data/processed/monitor/monitor_coords.csv"
raster_root = "../../data/processed/evi/"
output_root = "../../data/processed/evi_csv/"

monitor_coords = pd.read_csv(monitor_coords_file)
output = monitor_coords[['id']].copy()

points = monitor_coords[['long', 'lat']].values

raster_files = [f for f in os.listdir(raster_root) if f.endswith('.tif')]

raster_parent = Raster()
for raster_file in tqdm(raster_files):
    # parse file name
    raster_info = raster_file.split('.')[0]
    date, dataset, variable = raster_info.split('_')
    # read in array
    raster = gdal.Open(os.path.join(raster_root, raster_file)).ReadAsArray()
    raster_parent.fill(raster)
    # generate output
    raster_output = raster_parent.find_interpolated(points).astype(np.float16)
    # reduce float bytes
    kwargs = {variable: raster_output, 'date': date}
    output.assign(**kwargs).to_csv(os.path.join(output_root, raster_info + '.csv'), index=False)

# Ozone

# define paths
monitor_coords_file = "../../data/processed/monitor/monitor_coords.csv"
raster_root = "../../data/processed/o3/"
output_root = "../../data/processed/o3_csv/"
# extract coords
monitor_coords = pd.read_csv(monitor_coords_file)
output = monitor_coords[['id']].copy()
points = monitor_coords[['long', 'lat']].values
# list files
raster_files = [f for f in os.listdir(raster_root) if f.endswith('.tif')]

raster_parent = Raster()
for raster_file in tqdm(raster_files):
    # parse file name
    raster_info = raster_file.split('.')[0]
    date, dataset, variable = raster_info.split('_')
    # read in array
    raster = gdal.Open(os.path.join(raster_root, raster_file)).ReadAsArray()
    raster_parent.fill(raster)
    # generate output
    raster_output = raster_parent.find_interpolated(points).astype(np.float16)
    # reduce float bytes
    kwargs = {variable: raster_output, 'date': date}
    output.assign(**kwargs).to_csv(os.path.join(output_root, raster_info + '.csv'), index=False)
    
# SO2

# define paths
monitor_coords_file = "../../data/processed/monitor/monitor_coords.csv"
raster_root = "../../data/omi_so2/"
output_root = "../../data/processed/so2_csv/"
# extract coords
monitor_coords = pd.read_csv(monitor_coords_file)
output = monitor_coords[['id']].copy()
points = monitor_coords[['long', 'lat']].values
# list files
raster_files = [f for f in os.listdir(raster_root) if f.endswith('.tif')]

raster_parent = Raster()
for raster_file in tqdm(raster_files):
    # parse file name
    raster_info = raster_file.split('.')[0]
    date, dataset, variable = raster_info.split('_')
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
    raster_output = raster_parent.find_interpolated(points).astype(np.float16)
    # reduce float bytes
    kwargs = {variable: raster_output, 'date': date}
    output.assign(**kwargs).to_csv(os.path.join(output_root, raster_info + '.csv'), index=False)