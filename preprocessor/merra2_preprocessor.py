# usage:
# nohup python3 merra2_preprocessor.py PBLH RH T2M V2M U2M PS COSC AODANA TO3 &

# load libraries
import os
import numpy as np
import pandas as pd
from netCDF4 import Dataset
import matplotlib.pyplot as plt
# import gdal, osr
import osr
import mpl_toolkits
# import pprint
from scipy.interpolate import RegularGridInterpolator

from sys import argv
from datetime import datetime
from osgeo import gdal_array
from osgeo import gdal
from pyhdf.SD import SD, SDC
from tqdm import tqdm

def array2raster(array, geotiffFile=None, path=".", varName=None, date=None, date_format="%Y%j",
                 rasterOrigin=(56, 72), pixelLatWidth=0.1, pixelLonWidth=0.1):
    """ This function converts array to a raster and saves it to a GeoTIFF file.
    
    :params
        array:
            2-dimensional float ndarray, lat-long (x should be lat), the lower left (south-western) corner
            should be coded as the first element in the array
        geotiffFile:
            string, path and file name for the GeoTIFF file, this option overrides path, varName and date
        path:
            string, instead of passing in the geotiffFile argument, let the function automatically generate
            file names within this path
        varName:
            string, instead of passing in the geotiffFile argument, let the function automatically generate
            file names with this variable name
        date:
            string, instead of passing in the geotiffFile argument, let the function automatically generate
            file names with this date, date could be like "2005-01-01" or "2005001" (day of year)
        date_format:
            string, specify format for date if date is provided, defaults to day of year (e.g. "2005001")
            see: https://docs.python.org/3/library/datetime.html#datetime.datetime.strptime
        rasterOrigin:
            float tuple, the lat-lon coordinate of the origin of the raster
            (the largest lat / smallest lon coordinates, i.e. upper left corner)
            defaults to the origin of the bounding box in this project
        pixelLatWidth, pixelLonWidth:
            float, how many degrees latitude or longitude each element in the array reprensents
            this is spatial resolution for the array
            defaults to 0.1 degree by 0.1 degree
    """
    
    from datetime import datetime
    import gdal, osr
    import os
    
    if geotiffFile is None:
        if varName is None or date is None:
            raise Exception("Please supply either the geotiffFile argument " +
                            "or both arguments of varName and date")
        else:
            # automatically convert dates
            geotiffFile = os.path.abspath(os.path.join(
                    path, datetime.strptime(date, date_format).strftime("%Y-%m-%d") + "_" + varName + ".tif"))
    
    # extract bounding box
    try:
        rows, cols = array.shape
    except:
        print("array needs to be two dimensional")
    originLat, originLon = rasterOrigin
    
    # write files
    driver = gdal.GetDriverByName('GTiff')
    outRaster = driver.Create(geotiffFile, cols, rows, 1, gdal.GDT_Float32) # order of arguments is important
    outRaster.SetGeoTransform((originLon, pixelLonWidth, 0,
                               originLat, 0, - pixelLatWidth)) # set bounding box
    outband = outRaster.GetRasterBand(1)
    outband.WriteArray(array)
    
    # georeference
    outRasterSRS = osr.SpatialReference()
    outRasterSRS.ImportFromProj4('+proj=longlat +datum=WGS84 +no_defs +ellps=WGS84 +towgs84=0,0,0')
    outRaster.SetProjection(outRasterSRS.ExportToWkt())
    outband.FlushCache()
    
    # close files
    outRaster = None
    
if __name__ == '__main__':
    
    # create the grid for the MERRA-2 data

    # according to the MERRA-2 documentation, (i=1, j=1)
    # (or i=0, j=0 in python) refers to the grid point located @ (180W, 90S)
    # number of observations along each axis
    nlat, nlon = (361, 576) 
    # grid width along each axis
    wlat, wlon = (0.5, 0.625)
    # bottom, top, left, right, bounding box for the original dataset
    blat, tlat, llon, rlon = (-90, 90, -180, 179.375) 
    lat = np.linspace(blat, tlat, nlat)
    lon = np.linspace(llon, rlon, nlon)

    # print(lat[:40])
    # print(lon[:40])

    # create the grid for China
    # number of observations along each axis
    nlat_cn, nlon_cn = (400, 650) 
    # grid width along each axis
    wlat_cn, wlon_cn = (0.1, 0.1) 

    # specify bounding box for China
    # bottom, top, left, right
    blat_cn, tlat_cn, llon_cn, rlon_cn = (16, 56, 72, 137) 
    lat_cn = np.linspace(blat_cn + wlat_cn/2, tlat_cn - wlat_cn/2, nlat_cn)
    lon_cn = np.linspace(llon_cn + wlon_cn/2, rlon_cn - wlon_cn/2, nlon_cn)

    # print(lat_cn[:10])
    # print(lon_cn[:10])

    points = []
    for lat_i in range(nlat_cn):
        for lon_i in range(nlon_cn):
            points.append([lat_cn[lat_i], lon_cn[lon_i]])

    # parse command line arguments
    input_vars = argv[1:]
    tqdm.write(str(input_vars))

    for input_var in input_vars:
        
        # define paths
        input_root = os.path.join("../../data/raw/", input_var)
        output_root = os.path.join("../../data/processed/", input_var)
        var_name = "MERRA2_" + input_var
        tqdm.write("processing: {}".format(var_name))

        file_names = [f for f in os.listdir(input_root) if f.endswith(".nc")]

        # # test
        # file_names = file_names[0:5]
        # print(file_names)

        for file_name in tqdm(file_names):
            # extract date from file names
            _, _, date, _, _ = file_name.split(".")
            try:
                # open ncdf file
                f = Dataset(os.path.join(input_root, file_name), 'r')
                # main data
                X = f.variables[input_var]
                X_array = np.squeeze(np.asarray(f.variables[input_var][:]))
                X_array[X_array == X._FillValue] = np.nan
                # Use RegularGridInterpolator to interpolate
                rgi = RegularGridInterpolator((lat, lon), X_array)
                output = rgi(points)
                output = output.reshape(nlat_cn, nlon_cn)
                array2raster(array=output.T, varName=var_name,
                             date=date, date_format="%Y%m%d", path=output_root)
            except:
                tqdm.write("Error with {}".format(file_name))
