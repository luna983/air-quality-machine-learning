# SETUP ----
# clear workspace
rm(list=ls())
# load library
pacman::p_load(dplyr, lubridate, magrittr, ggplot2, lfe, readr, stargazer)
# define root path to be directory of source file
setwd(dirname(rstudioapi::getActiveDocumentContext()$path))
# define relative path
data_dir <- "../../data/output/xgbooster/"
# load data
df <- read_csv(paste0(data_dir, "regression_main.csv"))
# parse dates
df$treat_month <- (df$year - year(df$start_date)) * 12 + (df$month - month(df$start_date))
df %<>% mutate(treat_month_res = treat_month)
df$treat_month_res[df$treat_month_res <= -1] <- -1
df$treat_month_res %<>%
  as.factor() %>%
  relevel(ref="-1")
df %<>% mutate(treat_quarter = floor(treat_month / 3),
               treat_year = floor(treat_month / 12))
df %<>% mutate(treat_quarter_res = treat_quarter,
               treat_year_res = treat_year)
df$treat_quarter_res[df$treat_quarter_res <= -1] <- -1
df$treat_quarter_res %<>%
  as.factor() %>%
  relevel(ref="-1")
df$treat_year_res[df$treat_year_res <= -1] <- -1
df$treat_year_res %<>%
  as.factor() %>%
  relevel(ref="-1")
df$abs_week <- df$year * 53 + df$week
df$pred_CO <- df$pred_CO * 1000

# pre_trend_test ----

# define colors
color <- c("grey40", "firebrick")
names(color) = c("FALSE", "TRUE")

target_names <- c("PM2.5", "PM10", "NO2", "SO2", "CO", "O3")
ref_levels <- c(-8, -8, -8, -8, -8, -8)

for (i in c(1:6)) {
  # loop
  target_name <- target_names[i]
  ref_level <- ref_levels[i]
  
  # regression
  tmp <- df
  tmp$treat_year[tmp$treat_year == ref_level] <- -1
  tmp$treat_year %<>%
    as.factor() %>%
    relevel(ref="-1")
  reg <- felm(as.formula(paste0("pred_", target_name, " ~ C(treat_year) | id + abs_week | 0 | city_cn")),
              data=tmp)
  rss_2 <- sum(reg$residuals ^ 2)
  p_2 <- reg$p
  reg_res <- felm(
    as.formula(paste0("pred_", target_name, " ~ C(treat_year_res) | id + abs_week | 0 | city_cn")),
    data=tmp)
  rss_1 <- sum(reg_res$residuals ^ 2)
  p_1 <- reg_res$p
  n <- reg_res$N
  
  # F-test statistics and p value
  f_stat <- ((rss_1 - rss_2) / (p_2 - p_1)) / (rss_2 / (n - p_2 - 1))
  p_val <- pf(q=f_stat, df1=p_2-p_1, df2=n-p_2, lower.tail=F, log.p=F)
  print(p_val)
  
  # construct results
  results <- matrix(nrow=length(reg$coefficients), ncol=0) %>% tbl_df()
  results$coef <- reg$coefficients %>% as.vector()
  results$se <- reg$cse
  results$treat_year <- reg$coefficients %>%
    rownames() %>%
    gsub("C(treat_year)", "", x=., fixed=T) %>%
    as.integer()
  results$ref <- F
  results <- rbind(results,
                   data.frame(coef = c(0, 0),
                              se = c(0, 0),
                              treat_year = c(ref_level, -1),
                              ref = c(T, T)))
  # annotate
  dep_var_mean <- df %>%
    select(!!quo(paste0("pred_", target_name))) %>%
    as.matrix() %>%
    as.vector() %>%
    mean(na.rm=T) %>%
    round(0)
  
  # plot
  g <- ggplot(results, aes(x=treat_year, y=coef,
                           ymin=coef - 1.96 * se,
                           ymax=coef + 1.96 * se)) +
    geom_abline(intercept=0, slope=0, color="grey10") +
    geom_vline(xintercept=0, color="firebrick") +
    geom_errorbar(color="grey60", width=0.2) +
    geom_line(color="grey60") +
    geom_point(aes(color=ref), shape=18) +
    ylab(paste0("Changes in ", target_name, " Levels (ug/m3)")) +
    xlab("Year Relative To Treatment") +
    scale_x_continuous(breaks=seq(-10, 4, 1)) +
    scale_y_continuous(expand=c(0.5, 0.5)) +
    scale_color_manual(values=color) +
    annotate("text", x=-5, y=max(results$coef) * 2, color="grey20",
             label=paste0("Dependent Variable Mean: ", dep_var_mean)) +
    theme(legend.position="none",
          panel.background=element_blank(),
          panel.border=element_blank(),
          panel.grid.major=element_line(color="grey90"),
          panel.grid.minor=element_blank(),
          axis.ticks=element_blank(),
          axis.title.x=element_text(margin=margin(t=15), color="grey20", size=10),
          axis.title.y=element_text(margin=margin(r=10), color="grey20", size=10))
  ggsave(paste0("../../draft/pre_trend_test_", gsub(".", "", target_name, fixed=T), ".pdf"),
         g, width=8, height=5)
}
