# FIVB Beach Rankings Archive

R tooling to inventory, download, preserve, parse, and investigate historical FIVB Beach Volleyball rankings from the VIS web service.

## Current scope

The archive targets rankings from `2008-01-01` onward for:

- Type 6 / SubType 1 — FIVB Athlete / Player
- Type 9 / SubType 3 — FIVB World / Team
- Type 10 / SubType 2 — FIVB Team / PlayerSum

The completed general-ranking archive contains 3,663 ranking snapshots and more than 6 million ranking-entry rows from 2008-03-31 through 2026-08-31.

A separate Olympic Selection Ranking archive is being built for:

- London 2012
- Rio 2016
- Tokyo 2020 / held in 2021
- Paris 2024

The live VIS API has been confirmed to retain Olympic Selection Rankings for all four cycles.

A validated `GetBeachRanking` response has:

- `<BeachRanking>` as the XML root
- ranking metadata (`No`, `Date`, `Gender`, `Type`, `SubType`, `Version`) on the root
- one child `<Entry>` element per ranking row

## Important analysis convention

**Do not treat every VIS Type 9 object as the modern FIVB World Ranking.**

Our historical validation supports the following operational rule:

- **Before 2017-02-13:** Type 9 belongs to the historical team-results / Season Ranking era and should not be labeled as the modern World Ranking.
- **On or after 2017-02-13:** Type 9 is the validated FIVB World Ranking: the best eight performances achieved together as a team over a rolling 365-day period.
- **Type 10:** Team / PlayerSum ranking. Its points equal `PointsPlayer1 + PointsPlayer2`; it is distinct from Type 9.
- **Olympic Selection Ranking:** a temporary, quad-specific ranking with its own fixed qualification window, result-count rule, eligibility statuses, and Olympic quota logic.

For future analyses:

- when a validated modern World Ranking is available (`ranking_date >= 2017-02-13`), retain **both World (Type 9) and Team (Type 10)** because they measure different ranking constructs;
- before that cutoff, use **Team (Type 10)** as the historical ranking measure when needed, clearly labeled as Team rather than World;
- during an Olympic qualification window, retain the **Olympic Selection Ranking as an additional separate measure** rather than substituting World or Team ranking for it;
- Olympic ranking `Position`, `SelectionRank`, and `Status` should be preserved separately because teams already qualified through another pathway can remain high in the points table without consuming an Olympic-Ranking quota.

Why the Type 9 cutoff matters: an apparently strange Type 9 table from 2015 is consistent with the historical Season Ranking system rather than the later rolling-365 World Ranking. The archive stops its pre-2017 Type 9 sequence on 2016-12-31, has no January 2017 Type 9 snapshots, and resumes on 2017-02-13. That February 13 snapshot has been directly validated against a contemporaneously published FIVB World Ranking.

See [Type 9 Transition: Season Ranking to Modern World Ranking](docs/type9-transition-investigation.md) for the full evidence, [Ranking System Investigation](docs/ranking-system-investigation.md) for the broader ranking taxonomy, and [Olympic Ranking History and Relationship to VIS Rankings](docs/olympic-ranking-history.md) for Olympic-specific rules and VIS findings.

## Research notes

- [Type 9 Transition: Season Ranking to Modern World Ranking](docs/type9-transition-investigation.md) — documents the validated `2017-02-13` operational cutoff and the evidence for the change from the historical season-based team ranking to the modern best-8 / rolling-365 World Ranking.
- [Ranking System Investigation](docs/ranking-system-investigation.md) — documents the relationship among Type 6, Type 9, and Type 10 and the empirical audit results.
- [Olympic Ranking History and Relationship to VIS Rankings](docs/olympic-ranking-history.md) — documents London 2012, Rio 2016, Tokyo 2020/21, and Paris 2024 Olympic Ranking rules, retained VIS data, selection statuses, and the Olympic archive workflow.
- [Empirical Ranking Findings](docs/empirical-ranking-findings.md) — records archive-wide numerical findings from the ranking audits.

## Project structure

```text
R/
  vis_request.R          # low-level VIS requests
  ranking_inventory.R    # inventory + archive queue
  ranking_download.R     # validated single-ranking and resumable downloads
  ranking_parse.R        # raw XML validation/inspection/parsing helpers
  olympic_ranking.R      # Olympic Selection Ranking request + parser helpers
scripts/
  01_build_inventory.R
  02_inspect_ranking_774.R
  02b_validate_archive_samples.R
  03_download_archive.R
  04_parse_archive.R
  05_query_world_ranking.R
  06_audit_ranking_systems.R
  07_validate_feb2017_world_ranking.R
  08_audit_type9_world_transition.R
  09_probe_olympic_rankings.R
  10_discover_olympic_reference_dates.R
docs/
  ranking-system-investigation.md
  empirical-ranking-findings.md
  type9-transition-investigation.md
  olympic-ranking-history.md
data/
  inventory/             # generated inventory files (ignored)
  raw/                   # raw general-ranking XML (ignored)
  parsed/                # parsed general-ranking datasets (ignored)
  audit/                 # generated audit outputs (ignored)
  validation/            # generated validation outputs (ignored)
  olympic_probe/         # generated Olympic probe outputs (ignored)
  olympic_discovery/     # generated Olympic reference-date discovery (ignored)
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

2. Inspect a known historical Type 9 ranking (`No = 774`, 2015-03-23):

```r
source("scripts/02_inspect_ranking_774.R")
```

This object is useful for validating XML structure, but because it predates `2017-02-13`, it should not be interpreted as the modern best-8 / 365-day World Ranking.

3. Validate one historical example for every ranking shape in the archive (men/women x Types 6, 9, 10):

```r
source("scripts/02b_validate_archive_samples.R")
```

4. Download the complete general-ranking archive:

```r
source("scripts/03_download_archive.R")
```

Each HTTP-200 response is validated as the requested `<BeachRanking>` with at least one `<Entry>` before it is saved. Existing XML is revalidated when a download is resumed.

5. Parse the local raw XML archive:

```r
source("scripts/04_parse_archive.R")
```

6. Audit the relationships among Athlete, Team, and World products:

```r
source("scripts/06_audit_ranking_systems.R")
```

7. Validate the February 13, 2017 Type 9 snapshot against a contemporaneously published FIVB World Ranking:

```r
source("scripts/07_validate_feb2017_world_ranking.R")
```

8. Audit the Type 9 transition around the 2016-2017 boundary:

```r
source("scripts/08_audit_type9_world_transition.R")
```

9. Probe the retained Olympic Selection Rankings and known final snapshots:

```r
source("scripts/09_probe_olympic_rankings.R")
```

10. Discover every exact Olympic `ReferenceDate` retained by VIS across the four qualification windows:

```r
source("scripts/10_discover_olympic_reference_dates.R")
```

Script 10 is checkpointed and resumable because VIS does not expose an Olympic-ranking list endpoint; it must probe exact calendar dates to discover stored snapshots.

## Design principle

Raw VIS XML is treated as the archival source of truth. Parsing is intentionally separate from acquisition so the archive can be reprocessed later without repeatedly querying VIS.

Historical naming is treated separately from modern VIS type labels. A current VIS label does not automatically imply that the same public ranking formula or terminology applied to every archived year.
