rm(list=ls())

# load packages
pacman::p_load(ggplot2, tidyverse, magrittr)

# set absolute directory to be source file directory
working_dir <- rstudioapi::getActiveDocumentContext()$path %>%
  dirname()
setwd(working_dir)
getwd()

monitor <- read_delim("../../data/raw/aqi/china_stations_w_XY.txt", delim="\t") %>%
  select(StationID, CityNM, StationNM, Long, Lat)
names(monitor) <- c("id", "city_cn", "station_cn", "lon", "lat")

# match API reporting status
api <- read_csv("../../data/raw/api/china_api.csv")
api %<>% select(CITY, CTIME, POLLUTION_INDECES)
names(api) <- c("city_cn", "date", "report_API")
api_city <- data.frame(city_cn=unique(api$city_cn))

# match GADM boundary data cities - contains English names and ids
all_cities <- read_csv("../../data/policy/all_prefecture_cities.csv")
names(all_cities) <- c("city_id", "city_en", "city_cn")
api_city <- left_join(api_city, all_cities, by="city_cn")

# save matched API dataset
api <- left_join(api, all_cities, by="city_cn")
write_csv(api, "../../data/csv/api/china_api_processed.csv")

# save matched monitor datset
monitor <- full_join(monitor, api_city, by="city_cn")
write_csv(monitor, "../../data/csv/monitor/monitor_processed.csv")

# # sanitize mismatched cases
# tmp <- monitor[!complete.cases(monitor),]