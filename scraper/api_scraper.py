# this script scrapes China's MEP data center for historical API data
# author: Yue 'Luna' Huang at UC Berkeley
# email: yue_huang@berkeley.edu

import requests
from bs4 import BeautifulSoup
import pandas as pd
import re
import os
from tqdm import tqdm

# os.chdir("/Users/Yue/Google Drive/research/china-air-quality-ml")

# Initialization
url = "http://datacenter.mep.gov.cn:8099/ths-report/report!list.action"
post_params = {'page.pageNo': None,
               'page.orderBy': 'CITY',
               'page.order': 'desc',
               'xmlname': 1463473852790,
               'queryflag': 'close',
               'isdesignpatterns': False,
               'gisDataJson': None}
page_number = 12702

# TEST: PLEASE COMMENT OUT
# page_number = 3

# Scrape the first page
url_first = url + "?xmlname=" + str(post_params['xmlname'])
post_response = requests.get(url_first)
page = BeautifulSoup(post_response.text, 'html.parser')
post_params['gisDataJson'] = page.find(id='gisDataJson').get('value')
with open("tmp/api_tmp.txt", 'wb') as f:
    f.write(post_params['gisDataJson'].encode('utf-8'))

# Scrape the rest of the pages
for i in tqdm(range(2, page_number + 1)):
    post_params['page.pageNo'] = i
    post_response = requests.post(url, data=post_params)
    page = BeautifulSoup(post_response.text, 'html.parser')
    post_params['gisDataJson'] = page.find(id='gisDataJson').get('value')
    with open("tmp/api_tmp.txt", 'ab') as f:
        f.write(post_params['gisDataJson'].encode('utf-8'))

# Clean data
with open("tmp/api_tmp.txt", 'r+', encoding='utf-8') as f:
    f_json = re.sub(r"\]\[", ",", f.read())
    f_csv = pd.read_json(f_json, orient='records')
    f_csv.to_csv("data/api/china_api.csv", index=False, encoding='utf-8')