# SETUP ----
# clear workspace
rm(list=ls())
gc()
# load library
pacman::p_load(dplyr, lubridate, magrittr, data.table,
               ggplot2, lfe, readr, stargazer, progress)
# define root path to be directory of source file
setwd(dirname(rstudioapi::getActiveDocumentContext()$path))
# define relative path
data_dir <- "../../data/"

# load data
df <- read_csv(paste0(data_dir, "main/pred.csv")) %>%
  select(id, date, AODANA, COSC, TO3,
         MODAOD_kernel, MYDAOD_kernel, Ozone_kernel,
         NO2_kernel, SO2_kernel) %>% as.data.table()
setkeyv(df, c("id", "date"))

policy <- read_csv(paste0(data_dir, "csv/monitor/monitor_treatment.csv")) %>%
  select(id, city_cn, start_date) %>% as.data.table()
setkeyv(policy, "id")

# merge data
df <- merge(df, policy, by="id")

# parse dates
df[, year := year(date)]
df[, week := week(date)]
df[, abs_week := (year - 2005) * 53 + week]
df[, treat_week := abs_week -
     ((year(start_date) - 2005) * 53 + week(start_date))]
df <- df[, list(AODANA = mean(AODANA, na.rm=T),
                COSC = mean(COSC, na.rm=T),
                TO3 = mean(TO3, na.rm=T),
                MODAOD_kernel = mean(MODAOD_kernel, na.rm=T),
                MYDAOD_kernel = mean(MYDAOD_kernel, na.rm=T),
                Ozone_kernel = mean(Ozone_kernel, na.rm=T),
                NO2_kernel = mean(NO2_kernel, na.rm=T),
                SO2_kernel = mean(SO2_kernel, na.rm=T),
                treat_week = median(treat_week)),
         by=list(id, abs_week, city_cn)]
df[, treat_year := floor(treat_week / 53)]
df[, treat_year_res := treat_year]
df[treat_year_res <= -1, treat_year_res := -1]
df$treat_year_res %<>%
  as.factor() %>%
  relevel(ref="-1")

# event_study_raw_satellite ----
output_file <- "event_study_raw_satellite_output"
target_names <- c(
  "AODANA", "TO3", "COSC",
  "MODAOD_kernel", "MYDAOD_kernel", "Ozone_kernel", "NO2_kernel", "SO2_kernel")
results <- list()
dep_var_means <- rep(NA, length(target_names))

pb <- progress_bar$new(total=length(target_names))

for (i in c(1:length(target_names))) {
  
  pb$tick()
  # loop
  target_name <- target_names[i]
  
  # regression
  args <- list(
    formula=as.formula(paste0(target_name, " ~ C(treat_year_res) | id + abs_week | 0 | city_cn")),
    data=df,
    keepX=F, keepCX=F)
  reg_res <- do.call(felm, args)
  results[[i]] <- reg_res
  
  # dep var mean for comparisons
  dep_var_means[i] <- df %>%
    select(!!quo(target_name)) %>%
    as.matrix() %>%
    as.vector() %>%
    mean(na.rm=T) %>%
    round(2)
}

# format
row_label <- c("Year of Treatment", "1 Year Post Treatment",
               "2 Year Post Treatment", "3 Year Post Treatment", "4 Year Post Treatment")
col_label <- c(
  "AOD", "O$_3$", "CO",
  "AOD Terra", "AOD Aqua", "O$_3$", "NO$_2$", "SO$_2$")
latex_title <- "Impacts of PM$_{2.5}$ Reporting on Air Quality: Raw Satellite Measurements"

# format results with stargazer
output <- stargazer(results,
                    digits=2,
                    title=latex_title,
                    covariate.labels=row_label,
                    add.lines=list(c("Monitoring Station FE", rep("Yes", length(target_names))),
                                   c("Year by Week FE", rep("Yes", length(target_names))),
                                   c("Dependent Variable Mean", dep_var_means)),
                    dep.var.caption="Dependent Variable: Raw Satellite Measurements",
                    dep.var.labels=col_label,
                    keep.stat=c("n", "rsq"),
                    omit.table.layout="n")

# clean up files
for (file in list.files("../../draft/")) {
  if (grepl(output_file, file)) file.remove(paste0("../../draft/", file))
}
# cat output
cat(paste0(unlist(output[c(11:28, 30:34)]), "\n"),
    file=paste0("../../draft/", output_file, ".tex"))
