# clear workspace
rm(list=ls())

# load library
pacman::p_load(dplyr, reshape2, magrittr, lubridate, ggplot2, ggmap, RColorBrewer)

# set absolute directory to be source file directory
working_dir <- rstudioapi::getActiveDocumentContext()$path %>%
  dirname()
setwd(working_dir)
getwd()

# functions
"%&%" <- function(x, y) paste0(x, y)

# join treatment status and monitor id
if (F) {
  date <- readr::read_csv("../../data/policy/PM2.5_reporting_date.csv")
  monitor <- readr::read_csv("../../data/csv/monitor/monitor_processed.csv")
  monitor <- monitor %>% left_join(date, by="city_cn")
  monitor %>% readr::write_csv("../../data/csv/monitor/monitor_treatment.csv")
}

# load shape files
shp <- rgdal::readOGR("../../data/raw/adm/", "CHN_adm1")
shp_df <- fortify(shp, region="ID_1")

# load data
target_name <- "O3"
df <- readr::read_csv("../../data/output/xgbooster/" %&% target_name %&% "/day_r2_cv.csv")
ids <- df[df$r2 >= median(df$r2), ]$id
keep <- tibble(id = ids, keep = 1)
monitor <- readr::read_csv("../../data/csv/monitor/monitor_treatment.csv")
monitor %<>% left_join(keep, by="id")
monitor$keep %<>% recode(`1` = "Included Stations",
                         .missing = "Excluded Stations")

# define colors
pal = brewer.pal(8, "RdGy")
color <- c(pal[1], pal[4])
names(color) <- c("Included Stations", "Excluded Stations")

# r2_map ----
g <- ggplot() +
  geom_polygon(data=shp_df, aes(x=long, y=lat, group=group), fill="grey50")  +
  geom_path(data=shp_df, aes(x=long, y=lat, group=group), color="white") +
  geom_point(data=monitor, aes(x=lon, y=lat, color=keep), size=1.8, shape=18) +
  scale_color_manual(values=color, name="", guide=guide_legend(ncol=1, override.aes = list(size=5))) +
  coord_equal() +
  theme(legend.position=c(.86, .25),
        legend.title=element_text(angle=0, size=9, color="grey20"),
        legend.key=element_rect(color="transparent", fill="white"),
        legend.text=element_text(size=9, color="grey20"),
        panel.background=element_rect(fill="white"),
        title=element_blank(),
        axis.ticks=element_blank(),
        axis.text=element_blank())

ggsave("../../draft/" %&% target_name %&% "_r2_map.pdf", g, width=9, height=6)

# timeline ----
timeline <- tibble(
  date = seq(ymd("2012-01-01"), ymd("2016-12-31"), by="weeks")
)
tmp <- lapply(
  X=timeline$date,
  FUN=function(x) {
    monitor %>%
      filter(x >= ymd(monitor$start_date)) %>%
      filter(keep == "Included Stations") %>%
      nrow()
    })
timeline$in_station <- tmp %>% unlist()
tmp <- lapply(
  X=timeline$date,
  FUN=function(x) {
    monitor %>%
      filter(x >= ymd(monitor$start_date)) %>%
      filter(keep == "Excluded Stations") %>%
      nrow()
  })
timeline$ex_station <- tmp %>% unlist()
timeline <- melt(timeline, id.vars="date")
timeline$variable %<>% recode("in_station" = "Included Stations",
                              "ex_station" = "Excluded Stations")

# define colors
# pal = brewer.pal(3, "RdPu")
color <- c("grey30", "grey90")
names(color) <- c("Included Stations", "Excluded Stations")
y_breaks <- timeline %>% filter(variable == "Included Stations") %$% value %>% unique()

g <- ggplot(data=timeline, aes(x=date, y=value)) +
  geom_bar(aes(fill=variable), stat="identity", width=7, position=position_stack(reverse=TRUE)) +
  scale_fill_manual(values=color, name="", guide=guide_legend(nrow=1)) +
  scale_x_date(date_breaks = "1 year", date_labels = "%Y", expand=c(0, 0)) +
  scale_y_continuous(breaks=seq(0, 1500, 300), position="right", expand=c(0, 0)) +
  xlab("Time of Treatment") +
  ylab("No. of Stations") +
  theme(legend.position=c(0.1, 0.95),
        legend.justification=c("left", "top"),
        legend.title=element_blank(),
        legend.text=element_text(size=9, color="grey30"),
        panel.background=element_rect(fill=NA),
        axis.title.x=element_text(margin=margin(t=10), color="grey30", size=10),
        axis.title.y.right=element_text(margin=margin(l=10), color="grey30", size=10),
        axis.line=element_line(color="grey30"),
        axis.ticks=element_blank(),
        plot.margin=unit(c(1, 1, 1, 1), units="in")) +
  annotate("text",
           x=c(ymd("2012-10-01"), ymd("2013-07-01"), ymd("2014-07-01"), ymd("2016-01-01")),
           y=y_breaks[9:12] - 50, label=y_breaks[9:12], color="white")

ggsave("../../draft/" %&% gsub(".", "", target_name, fixed=T) %&% "_timeline.pdf", g, width=9, height=6)
