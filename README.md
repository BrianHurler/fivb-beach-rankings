# FIVB Beach Rankings Archive

R tooling to inventory, download, preserve, and parse historical FIVB Beach Volleyball rankings from the VIS web service.

## Current scope

The initial archive targets rankings from `2008-01-01` onward for:

- Type 6 / SubType 1 — FIVB Athlete
- Type 9 / SubType 3 — FIVB World
- Type 10 / SubType 2 — FIVB Team

The VIS ranking inventory currently exposes thousands of historical ranking snapshots, including pre-2017 records.

A validated `GetBeachRanking` response has:

- `<BeachRanking>` as the XML root
- ranking metadata (`No`, `Date`, `Gender`, `Type`, `SubType`, `Version`) on the root
- one child `<Entry>` element per ranking row

For example, men's FIVB World ranking No. 774 (2015-03-23) returns 68 `<Entry>` rows.

## Project structure

```text
R/
  vis_request.R          # low-level VIS requests
  ranking_inventory.R    # inventory + archive queue
  ranking_download.R     # validated single-ranking and resumable downloads
  ranking_parse.R        # raw XML validation/inspection/parsing helpers
scripts/
  01_build_inventory.R
  02_inspect_ranking_774.R
  02b_validate_archive_samples.R
  03_download_archive.R
  04_parse_archive.R
  05_query_world_ranking.R
data/
  inventory/             # generated inventory files (ignored)
  raw/                   # raw ranking XML (ignored)
  parsed/                # parsed datasets (ignored)
  logs/                  # preflight + download logs (ignored)
```

## Setup

```r
install.packages(c("httr2", "xml2", "dplyr", "purrr", "tibble"))
```

## Workflow

1. Build the VIS ranking inventory and the 2008+ archive queue:

```r
source("scripts/01_build_inventory.R")
```

2. Inspect the known men's FIVB World ranking for 2015-03-23 (`No = 774`):

```r
source("scripts/02_inspect_ranking_774.R")
```

3. Validate one historical example for every ranking shape in the archive (men/women x Types 6, 9, 10):

```r
source("scripts/02b_validate_archive_samples.R")
```

The bulk archive script will not run unless all six representative rankings pass.

4. Download the complete archive:

```r
source("scripts/03_download_archive.R")
```

Each HTTP-200 response is validated as the requested `<BeachRanking>` with at least one `<Entry>` before it is saved. Existing XML is revalidated when a download is resumed.

5. Parse the local raw XML archive:

```r
source("scripts/04_parse_archive.R")
```

6. Query the parsed FIVB World series:

```r
source("scripts/05_query_world_ranking.R")
```

## Design principle

Raw VIS XML is treated as the archival source of truth. Parsing is intentionally separate from acquisition so the archive can be reprocessed later without repeatedly querying VIS.
