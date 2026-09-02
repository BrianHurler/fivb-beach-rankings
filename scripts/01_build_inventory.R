library(httr2)
library(xml2)
library(dplyr)
library(purrr)
library(tibble)

source("R/vis_request.R")
source("R/ranking_inventory.R")

inventory_dir <- file.path("data", "inventory")
dir.create(inventory_dir, recursive = TRUE, showWarnings = FALSE)

ranking_inventory <- get_beach_ranking_inventory(
  save_raw_path = file.path(inventory_dir, "ranking_inventory_raw.xml")
)

archive_inventory <- build_archive_inventory(
  ranking_inventory,
  start_date = as.Date("2008-01-01"),
  archive_types = c(6L, 9L, 10L)
)

saveRDS(ranking_inventory, file.path(inventory_dir, "ranking_inventory.rds"))
utils::write.csv(ranking_inventory, file.path(inventory_dir, "ranking_inventory.csv"), row.names = FALSE)

saveRDS(archive_inventory, file.path(inventory_dir, "archive_inventory.rds"))
utils::write.csv(archive_inventory, file.path(inventory_dir, "archive_inventory.csv"), row.names = FALSE)

print(
  archive_inventory |>
    group_by(Type, type_name, SubType, subtype_name, Gender, gender_name) |>
    summarise(
      n_rankings = n(),
      first_date = min(Date),
      last_date = max(Date),
      .groups = "drop"
    ),
  n = Inf
)

message("Archive queue contains ", format(nrow(archive_inventory), big.mark = ","), " rankings.")
