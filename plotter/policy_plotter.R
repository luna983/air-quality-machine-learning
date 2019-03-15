# clear workspace
rm(list=ls())

# load library
pacman::p_load(dplyr, magrittr, lubridate, ggplot2, ggmap)

# set absolute directory to be source file directory
working_dir <- rstudioapi::getActiveDocumentContext()$path %>%
  dirname()
setwd(working_dir)
getwd()

# load data
df <- readr::read_csv("../../data/policy/all_prefecture_cities.csv")
date <- readr::read_csv("../../data/policy/PM2.5_reporting_date.csv")
names(df) <- c("city_id", "city", "city_cn")

df <- left_join(df, date, by="city_cn")
df$start_date[is.na(df$start_date)] <- "2015-01-01"
df$start_date %<>% ymd() %>% strftime(format="%Y-%m")
names(df)[1] <- "id"
df$id %<>% as.character()

# load shape files
shp <- rgdal::readOGR("../../data/raw/adm/", "CHN_adm2")
shp_df <- fortify(shp, region="ID_2")
shp_df <- left_join(shp_df, select(df, id, start_date), by = "id")

# policy ----
g <- ggplot(shp_df,
            aes(x=long, y=lat, group=group, fill=factor(start_date))) +
  geom_polygon()  +
  geom_path(color="white") +
  scale_fill_brewer(palette="RdYlBu",
                    name="Time of Treatment",
                    guide=guide_legend(title.position="top", ncol=1)) +
  # scale_x_continuous(breaks=c(80, 90, 100, 110, 120, 130),
  #                    labels=c("80E", "90E", "100E", "110E", "120E", "130E")) +
  # scale_y_continuous(breaks=c(20, 30, 40, 50),
  #                    labels=c("20N", "30N", "40N", "50N")) +
  coord_equal() +
  theme(legend.position=c(.88, .32),
        legend.title=element_text(angle=0, size=9, color="grey20"),
        legend.text=element_text(size=9, color="grey20"),
        panel.background=element_rect(fill="white"),
        # panel.grid.major=element_line(color="grey80"),
        title=element_blank(),
        axis.ticks=element_blank(),
        axis.text=element_blank())

ggsave("../../draft/policy.pdf", g, width=9, height=6)
