# clear workspace
rm(list=ls())

# load library
pacman::p_load(dplyr, readr, reshape2, magrittr, lubridate, ggplot2, ggmap, RColorBrewer)

# set absolute directory to be source file directory
working_dir <- rstudioapi::getActiveDocumentContext()$path %>%
  dirname()
setwd(working_dir)
getwd()

# functions
"%&%" <- function(x, y) paste0(x, y)

# define target and standard
target_name <- "PM2.5"
ref_50 <- 35
ref_100 <- 75
target_unit <- "(ug/m3)"

# target_name <- "PM10"
# ref_50 <- 50
# ref_100 <- 150
# target_unit <- "(ug/m3)"
# 
# target_name <- "O3"
# ref_50 <- 100 # this is 8-h moving average
# ref_100 <- 160 # this is 8-h moving average
# target_unit <- "(ug/m3)"
# 
# target_name <- "SO2"
# ref_50 <- 50
# ref_100 <- 150
# target_unit <- "(ug/m3)"
# 
# target_name <- "NO2"
# ref_50 <- 40
# ref_100 <- 80
# target_unit <- "(ug/m3)"
# 
# target_name <- "CO"
# ref_50 <- 2
# ref_100 <- 4
# target_unit <- "(mg/m3)"

# define colors
pal = brewer.pal(6, "RdGy")
color <- c(pal[1], pal[6], pal[2])
names(color) <- c("Predictions", "Training Data", "Test Data")

# load data
df <- read_csv("../../data/output/xgbooster/" %&% target_name %&% "/prediction_output.csv")
tmp <- read_csv("../../data/output/xgbooster/" %&% target_name %&% "/train_output.csv")
names(tmp) <- c("id", "date", "pred", "train")
df <- left_join(df, tmp %>% select(-pred), by=c("id", "date"))
tmp <- read_csv("../../data/output/xgbooster/" %&% target_name %&% "/test_output.csv")
names(tmp) <- c("id", "date", "pred", "test")
df <- left_join(df, tmp %>% select(-pred), by=c("id", "date"))

# parse dates
df$date <- ymd(df$date)
df$year <- year(df$date)
df$week <- week(df$date)

# take weekly mean
df <- df %>% group_by(id, year, week) %>%
  summarise(date=median(date),
            pred=mean(pred, na.rm=T),
            train=mean(train, na.rm=T),
            test=mean(test, na.rm=T))

# take mean of all stations
df_mean <- df %>% group_by(date) %>%
  summarise(pred=mean(pred, na.rm=T), train=mean(train, na.rm=T), test=NA) %>%
  ungroup()
df_mean$id <- "Mean"

# subsample
ids <- df$id %>% unique() %>% sample(5, replace=F)
df_sub <- df %>% ungroup() %>% select(-year, -week) %>% filter(id %in% ids)

# merge into dataframe
df_sub <- rbind(df_mean, df_sub)
df_sub$id %<>% factor(levels=c("Mean", ids))

# pred_trend ----
g <- ggplot(df_sub) +
  geom_hline(yintercept=ref_100, color="grey60") +
  geom_line(aes(x=date, y=pred, color=names(color)[1])) +
  geom_line(aes(x=date, y=train, color=names(color)[2])) +
  geom_line(aes(x=date, y=test, color=names(color)[3])) +
  facet_grid(id ~ .) +
  scale_y_continuous(breaks=c(0, ref_100), expand=c(0, 0)) +
  scale_x_date(date_breaks = "1 year", date_labels = "%Y", expand=c(0, 0)) +
  scale_color_manual(values=color, name="", guide=guide_legend(nrow=1)) +
  xlab("") +
  ylab("Weekly " %&% target_name %&% " Mean " %&% target_unit) +
  theme(legend.position=c(0.03, 1),
        legend.justification=c("left", "top"),
        legend.title=element_blank(),
        legend.text=element_text(size=9, color="grey30"),
        legend.key=element_blank(),
        legend.background=element_blank(),
        panel.background=element_rect(fill=NA),
        panel.border=element_rect(fill=NA, color="grey50"),
        axis.title.x=element_text(margin=margin(t=10), color="grey30", size=10),
        axis.title.y=element_text(margin=margin(r=10), color="grey30", size=10),
        axis.ticks=element_blank())

ggsave("../../draft/" %&% gsub(".", "", target_name, fixed=T) %&% "_pred_trend.pdf", g, width=6, height=7)
