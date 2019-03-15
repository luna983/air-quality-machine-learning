# This script provides support for automatic downloads
# of MODIS satellite images
# from the LAADS DAAC HTTP server
# Python version 3.5.2
# Author: Yue 'Luna' Huang
# yuehuang@berkeley.edu

import os
import numpy as np
import pandas as pd
import urllib.request
from tqdm import tqdm


class RemoteFileDoesntExist(Exception):
    """ Exception to be used when the remote file does not exist, this will not raise an error """
    pass


class InternetConnectionIssue(Exception):
    """ Exception for when the user is having Internet connection issues """
    pass


class LocalDirectoryDoesntExist(Exception):
    """ Exception for when local (root) directory does not exist """
    pass


class NoFileListProvided(Exception):
    """ Exception for when downloading is initiated when file list is not yet parsed """
    pass


class UnknownError(Exception):
    """ Unknown Error """
    pass


class Downloader(object):
    """
    The object for downloading MODIS remote sensing data

    :param download_dir:
        Provide a download directory, ideally not in the current working directory
        An error will be raised if the directory is not provided
    :type download_dir:
        String

    Attributes:
        download_dir: records the absolute path of downloaded files
        file_num: records the number of file to be downloaded
        file_list: maintains a record of the list of file names, urls, local file paths and downloading status

    """

    def __init__(self, download_dir=None):
        if download_dir is None:
            raise LocalDirectoryDoesntExist('No Directory Specified')
        elif not os.path.isdir(download_dir):
            raise LocalDirectoryDoesntExist()
        else:
            self.download_dir = download_dir if download_dir[-1] is '/' else download_dir + '/'
            self.file_num = 0
            self.file_list = None

    def parse_file_list(self, file_path=None, file_name_id='Producer Granule ID', url_id='Online Access URLs'):
        """
        Parse the list of files to be downloaded, and store the parsed list in file_list

        :param file_path:
            Provide a csv file listing all the file names
            An error will be raised if the csv file is not provided
        :type file_path:
            String
        :param file_name_id:
            Column identifier for extracting file names
        :type file_name_id:
            String
        :param url_id:
            Column identifier for extracting urls
        :type url_id:
            String

        """

        # read in and maintain the raw csv file as df
        df = pd.read_csv(file_path)

        # record the number of files
        self.file_num = df.__len__()

        # initiate the data frame
        self.file_list = pd.DataFrame()
        self.file_list['download_dir'] = np.NaN
        self.file_list['file_name'] = df[file_name_id]
        self.file_list['online_url'] = df[url_id]
        self.file_list['status'] = 0
        self.file_list['year'] = 0
        self.file_list['day'] = 0
        self.file_list = self.file_list.reset_index(drop=True)

        # clean up the variables for a file list downloaded from Reverb
        # extract http urls from the file list
        print("Extracting http urls from the file list...")
        self.file_list['online_url'] = self.file_list['online_url'].str.rstrip("\'").str.split(',').str[1]
        self.file_list['year'] = self.file_list['online_url'].str.split('/', expand=True).iloc[:, 7]
        self.file_list['day'] = self.file_list['online_url'].str.split('/', expand=True).iloc[:, 8]
        self.file_list['download_dir'] = self.download_dir + self.file_list['year'] + '/' + self.file_list['day'] + '/'

    def download_file_list(self, limit=None, test_page='https://www.google.com'):
        """
        Download the list of files, given that the csv list of files have been parsed

        :param limit:
            The number of files that the user wants to download
        :type limit:
            Integer
        :param test_page:
            The page for Internet connection testing
        :type test_page:
            String

        """
        # test csv file parsing
        if self.file_list is None:
            raise NoFileListProvided()

        # test Internet connection
        try:
            urllib.request.urlopen(test_page, timeout=2)
        except urllib.request.URLError:
            raise InternetConnectionIssue()
        except:
            raise UnknownError()

        # determine whether the number of file to be downloaded is capped for test purposes
        if limit is None:
            total_file_num = self.file_num
        else:
            total_file_num = limit
        print('Total number of files to be downloaded: ' + str(total_file_num))

        # perform downloading
        print("Downloading MODIS data...")
        for row in tqdm(range(total_file_num)):
            download_dir = self.file_list['download_dir'].iloc[row]
            file_name = self.file_list['file_name'].iloc[row]
            online_url = self.file_list['online_url'].iloc[row]

            # create local sub-directories
            if not os.path.isdir(download_dir):
                os.makedirs(download_dir)

            # check local file existence
            # CAUTION: the existence of local files, even incomplete, will preemptively stop the downloading process
            if os.path.isfile(os.path.join(download_dir, file_name)):
                self.file_list.set_value(index=row, col='status', value=1)
            else:
                try:
                    HTTPresponse = urllib.request.urlretrieve(online_url, os.path.join(download_dir, file_name))
                    # check remote file existence
                    if 'Content-Type: application/x-hdf' in HTTPresponse[1].__str__():
                        self.file_list.set_value(index=row, col='status', value=1)
                    elif 'Content-Type: text/html' in HTTPresponse[1].__str__():
                        os.remove(os.path.join(download_dir, file_name))
                        raise RemoteFileDoesntExist()
                    else:
                        os.remove(os.path.join(download_dir, file_name))
                        raise UnknownError()
                except RemoteFileDoesntExist:
                    self.file_list.set_value(index=row, col='status', value=0)
                except:
                    os.remove(os.path.join(download_dir, file_name))
                    self.file_list.set_value(index=row, col='status', value=0)
                    raise UnknownError()


if __name__ == '__main__':
    # all paths are absolute
    d = Downloader(download_dir='/Users/Yue/Google Drive/Luna/research/research projects/' +
                                'city-air-quality-ranking/repo/storage/modis/')
    d.parse_file_list(file_path='/Users/Yue/Google Drive/Luna/research/research projects/' +
                                'city-air-quality-ranking/repo/china-city-air-quality-ranking/modis/' +
                                '_MYD04_L2_list.csv')
    # test 12 images from 2012-01-01
    d.download_file_list(limit=12)
    # save downloading log
    d.file_list.to_csv('/Users/Yue/Downloads/_MYD04_L2_log.csv')