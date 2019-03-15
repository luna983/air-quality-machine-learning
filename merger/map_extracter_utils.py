import os, sys
import numpy as np
import pandas as pd
import scipy as sp
from datetime import datetime
import matplotlib.pyplot as plt

import gdal, osr

from scipy.interpolate import RegularGridInterpolator

from tqdm import tqdm, tqdm_notebook

assert sys.version_info[0] >= 3, "Python 3 or a more recent version is required."

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
    
    def find_weighted_mean(self, kernel, points):
        """ Impute weighted mean contained in self raster.
        
        :param
            kernel:
                a two-dimensional ndarray, the spatial kernel
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
            longBand, latBand = kernel.shape
            longBand, latBand = int(longBand / 2), int(latBand / 2)
            cell = self.values[(selfLongIndex + 1 - longBand):(selfLongIndex + 1 + longBand),
                               (selfLatIndex + 1 - latBand):(selfLatIndex + 1 + latBand)]
            # impute value
            if np.isnan(cell[kernel != 0]).all():
                output[i] = np.nan
            else:
                kernel[np.isnan(cell)] = 0
                kernel = kernel / np.sum(kernel)
                output[i] = np.nansum(cell * kernel)
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