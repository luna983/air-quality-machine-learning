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

# event_study_main ----
output_file <- "event_study_main_output"
target_names <- c("PM2.5", "PM10", "NO2", "SO2", "CO", "O3")
results <- list()
dep_var_means <- rep(NA, 6)

for (i in c(1:6)) {
  # loop
  target_name <- target_names[i]

  # regression
  args <- list(
    formula=as.formula(paste0("pred_", target_name, " ~ C(treat_year_res) | id + abs_week | 0 | city_cn")),
    data=df)
  reg_res <- do.call(felm, args)
  results[[i]] <- reg_res
    
  # dep var mean for comparisons
  dep_var_means[i] <- df %>%
    select(!!quo(paste0("pred_", target_name))) %>%
    as.matrix() %>%
    as.vector() %>%
    mean(na.rm=T) %>%
    round(0)
}

# format
row_label <- c("Year of Treatment", "1 Year Post Treatment",
               "2 Year Post Treatment", "3 Year Post Treatment", "4 Year Post Treatment")
col_label <- c("PM$_{2.5}$", "PM$_{10}$", "NO$_2$", "SO$_2$", "CO", "O$_3$")
latex_title <- "Impacts of PM$_{2.5}$ Reporting on Air Quality: Event Study Estimates"

# format results with stargazer
output <- stargazer(results,
                    digits=2,
                    title=latex_title,
                    covariate.labels=row_label,
                    add.lines=list(c("Monitoring Station FE", rep("Yes", 6)),
                                   c("Week FE", rep("Yes", 6)),
                                   c("Dependent Variable Mean", dep_var_means)),
                    dep.var.caption="Dependent Variable: Level",
                    dep.var.labels=col_label,
                    keep.stat=c("n", "rsq"),
                    omit.table.layout="n")

# clean up files
for (file in list.files("../../draft/")) {
  if (grepl(output_file, file)) file.remove(paste0("../../draft/", file))
}
# cat output
cat(paste0(unlist(output[c(9:28, 30:34)]), "\n"),
    file=paste0("../../draft/", output_file, ".tex"))