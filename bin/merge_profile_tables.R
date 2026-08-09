#!/usr/bin/env Rscript
args <- commandArgs(trailingOnly = TRUE)
input_dir <- args[1]
out_tsv <- args[2]

suppressPackageStartupMessages({
  library(dplyr)
  library(readr)
  library(purrr)
})

table_files <- list.files(path = input_dir, pattern = "*.tsv", full.names = TRUE)

if(length(table_files) > 0) {
    merged_data <- table_files %>%
        set_names() %>%
        map(read_tsv, show_col_types = FALSE) %>%
        reduce(full_join, by = "ID")
    write_tsv(merged_data, out_tsv)
} else {
    write_tsv(data.frame(ID=character()), out_tsv)
}