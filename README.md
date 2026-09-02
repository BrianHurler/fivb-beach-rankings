# FIVB Beach Rankings Archive

R tooling to inventory, download, preserve, and parse historical FIVB Beach Volleyball rankings from the VIS web service.

## Current scope

The initial archive targets rankings from `2008-01-01` onward for:

- Type 6 / SubType 1 — FIVB Athlete
- Type 9 / SubType 3 — FIVB World
- Type 10 / SubType 2 — FIVB Team

The VIS ranking inventory currently exposes thousands of historical ranking snapshots, including pre-2017 records.

## Project structure

```text
R/
  vis_request.R          # low-level VIS requests
  ranking_inventory.R    # inventory + archive queue
  ranking_download.R     # single-ranking and resumable archive downloads
  ranking_parse.R        # raw XML inspection/parsing helpers
scripts/
  01_build_inventory.R
  02_inspect_ranking_774.R
  03_download_archive.R
  04_parse_archive.R
data/
  inventory/             # generated inventory files (ignored)
  raw/                   # raw ranking XML (ignored)
  parsed/                # parsed datasets (ignored)
  logs/                  # download logs (ignored)
```

## Setup

```r
install.packages(c("httr2", "xml2", "dplyr", "purrr", "tibble"))
```

## Workflow

1. Build the VIS ranking inventory:

```r
source("scripts/01_build_inventory.R")
```

2. Inspect the known men's FIVB World ranking for 2015-03-23 (`No = 774`) before bulk downloading:

```r
source("scripts/02_inspect_ranking_774.R")
```

3. Once the response structure is validated, download the archive:

```r
source("scripts/03_download_archive.R")
```

4. Parse the local raw XML archive:

```r
source("scripts/04_parse_archive.R")
```

## Design principle

Raw VIS XML is treated as the archival source of truth. Parsing is intentionally separate from acquisition so the archive can be reprocessed later without repeatedly querying VIS.
