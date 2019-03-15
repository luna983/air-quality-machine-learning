rm(list=ls())

# load packages
pacman::p_load(ggplot2, dplyr, magrittr)

# set absolute directory to be source file directory
working_dir <- rstudioapi::getActiveDocumentContext()$path %>%
  dirname()
setwd(working_dir)
getwd()

# load all cities
boundary <- readr::read_csv("../../data/raw/adm/CHN_adm2.csv")
boundary %<>% select(ID_2, NAME_2, NL_NAME_2)

# unicode manipulation
boundary$NL_NAME_2 <- boundary$NL_NAME_2 %>%
  gsub(".*\\|", "", x=.) %>%
  gsub("<U\\+5E02>", "", x=.) %>%
  gsub("<", "", x=.) %>%
  gsub(">", "", x=.) %>%
  gsub("U\\+", "\\\\u", x=.) %>%
  stringi::stri_unescape_unicode()
boundary$NAME_2 <- boundary$NAME_2 %>%
  gsub("\\\u00ea", "e", x=.) %>%
  gsub("\\\u00f6", "o", x=.) %>%
  gsub("\\\u00dc", "U", x=.) %>%
  gsub("\\\u00fc", "u", x=.)

# matching names
boundary$NL_NAME_2 <- boundary$NL_NAME_2 %>%
  gsub("長", "长", x=.) %>%
  gsub("張", "张", x=.) %>%
  gsub("陽", "阳", x=.) %>%
  gsub("懷", "怀", x=.) %>%
  gsub("婁", "娄", x=.) %>%
  gsub("大理白族自治州", "大理州", x=.) %>%
  gsub("湘西土家族苗族自治州", "湘西州", x=.) %>%
  gsub("怒江傈僳族自治州", "怒江州", x=.) %>%
  gsub("西双版纳傣族自治州", "西双版纳州", x=.) %>%
  gsub("红河哈尼族彝族自治州", "红河州", x=.) %>%
  gsub("德宏傣族景颇族自治州", "德宏州", x=.) %>%
  gsub("玉树藏族自治州", "玉树州", x=.) %>%
  gsub("甘南藏族自治州", "甘南州", x=.) %>%
  gsub("临夏回族自治州", "临夏州", x=.) %>%
  gsub("黔东南苗族侗族自治州", "黔东南州", x=.) %>%
  gsub("黔南布依族苗族自治州", "黔南州", x=.) %>%
  gsub("黔西南布依族苗族自治州", "黔西南州", x=.) %>%
  gsub("阿坝藏族羌族自治州", "阿坝州", x=.) %>%
  gsub("凉山彝族自治州", "凉山州", x=.) %>%
  gsub("海北藏族自治州", "海北州", x=.) %>%
  gsub("延边朝鲜族自治州", "延边州", x=.) %>%
  gsub("海南藏族自治州", "海南州", x=.) %>%
  gsub("海北藏族自治州", "海北州", x=.) %>%
  gsub("黄南藏族自治州", "黄南州", x=.) %>%
  gsub("博尔塔拉蒙古自治州", "博州", x=.) %>%
  gsub("文山壮族苗族自治州", "文山州", x=.) %>%
  gsub("迪庆藏族自治州", "迪庆州", x=.) %>%
  gsub("楚雄彝族自治州", "楚雄州", x=.) %>%
  gsub("海西蒙古族藏族自治州", "海西州", x=.) %>%
  gsub("巴音郭愣蒙古自治州", "巴音郭愣州", x=.) %>%
  gsub("昌吉回族自治州", "昌吉州", x=.) %>%
  gsub("果洛藏族自治州", "果洛州", x=.) %>%
  gsub("甘孜藏族自治州", "甘孜州", x=.) %>%
  gsub("伊犁哈萨克自治州", "伊犁哈萨克州", x=.) %>%
  gsub("克孜勒苏柯尔克孜自治州", "克州", x=.) %>%
  gsub("迪庆藏族自治州", "迪庆州", x=.) %>%
  gsub("恩施土家族苗族自治州", "恩施州", x=.) %>%
  gsub("运城县", "运城", x=.)

# drop duplicate
# boundary %<>% filter(NL_NAME_2 != "内江")
  
readr::write_csv(boundary, "../../data/policy/all_prefecture_cities.csv")
