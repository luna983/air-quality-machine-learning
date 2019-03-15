# clear workspace
rm(list=ls())

# load library
pacman::p_load(dplyr, readr, reshape2, magrittr, lubridate, ggplot2, ggmap,
               RColorBrewer, grid, gridExtra, egg)

# set absolute directory to be source file directory
working_dir <- rstudioapi::getActiveDocumentContext()$path %>%
  dirname()
setwd(working_dir)
getwd()

# functions
"%&%" <- function(x, y) paste0(x, y)

# define target and standard
target_name <- "API"

# define colors
pal = brewer.pal(6, "RdGy")
color <- c(pal[1], pal[6])
names(color) <- c("Adjusted Predicted API", "Reported API")

# load data
df <- read_csv("../../data/output/xgbooster/" %&% target_name %&% "/api_matched.csv")
names(df)[4] <- "report"

# parse dates
df$date <- ymd(df$date)
df$year <- year(df$date)
df$week <- week(df$date)

# take mean of all stations
df_mean <- df %>% group_by(date, year, week) %>%
  summarise(pred=mean(pred, na.rm=T), report=mean(report, na.rm=T)) %>%
  ungroup()

# select sub station
# city_en_ <- "Mean"
# tmp <- df_mean
city_en_ <- "Shanghai"
tmp <- df %>% filter(city_en == city_en_) %>% select(-city_id, -city_en)

# adjustment
reg <- lm(report ~ pred, tmp)
tmp$pred_adj <- reg$fitted.values

# take weekly mean
tmp_week <- tmp %>% group_by(year, week) %>%
  summarise(date=median(date),
            pred=mean(pred, na.rm=T),
            pred_adj=mean(pred_adj, na.rm=T),
            report=mean(report, na.rm=T))

# API_match ----
gb <- ggplot(data=tmp_week) +
  geom_hline(yintercept=100, color="grey60") +
  geom_line(aes(x=date, y=report, color=names(color)[2])) +
  geom_line(aes(x=date, y=pred_adj, color=names(color)[1])) +
  scale_x_date(date_breaks = "1 year", date_labels = "%Y") +
  scale_color_manual(values=color, name="", guide=guide_legend(ncol=1)) +
  xlab("") +
  ylab("Air Pollution Index") +
  theme(legend.position=c(0.03, 1),
        legend.justification=c("left", "top"),
        legend.title=element_blank(),
        legend.text=element_text(size=9, color="grey30"),
        legend.key=element_blank(),
        legend.background=element_blank(),
        panel.background=element_rect(fill=NA),
        panel.border=element_rect(fill=NA, color="grey50"),
        axis.title.x=element_text(margin=margin(t=10), color="grey30", size=10),
        axis.title.y=element_text(margin=margin(r=12), color="grey30", size=10),
        axis.ticks=element_blank(),
        plot.margin=unit(c(0.1, 0.1, 0.1, 0.77), "in"))

gr <- ggplot(data=tmp) +
  geom_rect(aes(xmin=0, xmax=100, ymin=-Inf, ymax=Inf), fill="grey90") + 
  geom_line(aes(x=pred_adj, color=names(color)[1]), stat="density", bw=0.5) +
  geom_line(aes(x=report, color=names(color)[2]), stat="density", bw=0.5) +
  scale_x_continuous(limits=c(0, 220), expand=c(0, 0)) +
  scale_color_manual(values=color, name="", guide=guide_legend(ncol=1)) +
  xlab("Air Pollution Index") +
  ylab("Density") +
  theme(legend.position=c(0.5, 1),
        legend.justification=c("left", "top"),
        legend.title=element_blank(),
        legend.text=element_text(size=9, color="grey30"),
        legend.key=element_blank(),
        legend.key.size=unit(0.3, "in"),
        text=element_text(size=14),
        legend.background=element_blank(),
        panel.background=element_rect(fill=NA),
        axis.line.y=element_blank(),
        axis.line.x=element_line(color="grey30"),
        axis.title.x=element_text(margin=margin(t=10), color="grey30", size=10),
        axis.title.y=element_text(margin=margin(r=0), color="grey30", size=10),
        axis.ticks=element_blank(),
        axis.text.y=element_blank(),
        axis.text.x=element_text(color="grey30", size=9))

lims <- c(quantile(c(tmp$pred, tmp$report), probs=0.001),
          quantile(c(tmp$pred, tmp$report), probs=0.999))

gl <- ggplot(data=tmp) +
  geom_abline(slope=1, intercept=0, color="grey50") + 
  geom_point(aes(x=pred_adj, y=report), alpha=0.1, size=0.5) +
  xlab(names(color)[1]) +
  ylab(names(color)[2]) +
  coord_equal() +
  scale_x_continuous(limits=lims, expand=c(0.05, 0.05)) +
  scale_y_continuous(limits=lims, expand=c(0.05, 0.05)) +
  theme(legend.position="none",
        panel.background=element_rect(fill=NA),
        axis.title.x=element_text(margin=margin(t=10), color="grey30", size=10),
        axis.title.y=element_text(margin=margin(r=10), color="grey30", size=10),
        axis.line=element_line(color="grey30"),
        axis.ticks=element_blank(),
        axis.text=element_text(color="grey30", size=9))

g <- arrangeGrob(gl, gr, gb, layout_matrix=rbind(c(1, 2), c(3, 3)))

ggsave("../../draft/API_match_" %&% city_en_ %&% ".pdf", g, width=9, height=6)

