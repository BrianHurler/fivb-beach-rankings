# Olympic Archive Final QA and Source Quirks

This note records the final integrity checks for the historical FIVB Beach Volleyball Olympic Selection Ranking archive and distinguishes archive-quality issues from quirks present in the VIS source itself.

## Archive status

**The Olympic ranking archive is complete for the four project cycles and has passed all hard QA checks.**

Coverage:

| GamesYear | Gender | Snapshots | Rows | First retained date | Final retained date |
|---:|:---:|---:|---:|---|---|
| 2012 | M | 25 | 4,687 | 2011-05-08 | 2012-06-18 |
| 2012 | W | 24 | 3,923 | 2011-05-08 | 2012-06-18 |
| 2016 | M | 38 | 10,139 | 2015-07-20 | 2016-06-12 |
| 2016 | W | 38 | 8,879 | 2015-07-20 | 2016-06-12 |
| 2020 | M | 81 | 34,148 | 2018-09-17 | 2021-06-14 |
| 2020 | W | 81 | 28,287 | 2018-09-17 | 2021-06-14 |
| 2024 | M | 65 | 23,593 | 2023-02-06 | 2024-06-10 |
| 2024 | W | 65 | 20,838 | 2023-02-06 | 2024-06-10 |

Overall:

- **134,494 ranking-entry rows**
- **417 gender-specific snapshots**
- **211 distinct GamesYear/reference-date combinations**
- raw XML preserved for all 417 discovered snapshots
- zero download failures

## Hard QA results

`scripts/13_validate_olympic_archive.R` compares the parsed archive against the exhaustive reference-date discovery output and independently validated final Olympic snapshots.

All hard checks passed:

- parsed snapshots: 417
- discovered snapshots: 417
- discovered snapshots missing from parsed archive: 0
- extra parsed snapshots: 0
- snapshot row-count mismatches: 0
- snapshots with duplicate `Position`: 0
- rows missing `NoPlayer1`: 0
- rows missing `NoPlayer2`: 0
- rows missing `Points`: 0
- rows with negative points: 0
- final snapshot row-count checks: PASS
- final selected-count checks: PASS

The archive is therefore suitable for analysis. The remaining diagnostics below describe behavior present in VIS itself rather than acquisition or parsing failures.

## Final Olympic snapshot validation

| GamesYear | Gender | Final VIS reference date | Rows | #1 team | #1 points | Selected statuses 1-3 |
|---:|:---:|---|---:|---|---:|---:|
| 2012 | M | 2012-06-18 | 288 | Emanuel/Alison | 8,360 | 16 |
| 2012 | W | 2012-06-18 | 237 | Larissa/Juliana | 8,380 | 16 |
| 2016 | M | 2016-06-12 | 370 | Alison/Bruno Schmidt | 7,740 | 16 |
| 2016 | W | 2016-06-12 | 305 | Larissa/Talita | 7,700 | 16 |
| 2020 | M | 2021-06-14 | 751 | Mol/Sørum | 10,960 | 16 |
| 2020 | W | 2021-06-14 | 616 | Pavan/Melissa | 9,400 | 16 |
| 2024 | M | 2024-06-10 | 673 | Åhman/Hellvig | 13,160 | 17 |
| 2024 | W | 2024-06-10 | 618 | Duda/Ana Patrícia | 13,160 | 17 |

The `selected_status_1_3` values shown by the parser for an entire cycle are cumulative counts across all historical snapshots. They must **not** be interpreted as the number of Olympic qualifiers. Qualification counts should be evaluated within a specific reference-date snapshot, usually the final ranking.

## Olympic status values

The historical public VIS model documents named Olympic-team statuses corresponding to values 1-8. The retained archive also contains values 0, 9 and 10.

### Status 0

`Status = 0` is present throughout the source archive. It should be preserved as a raw/default VIS status and not automatically recoded as selected or excluded.

### Status 9 — strong empirical interpretation

Status 9 occurs in Rio 2016, Tokyo 2020 and Paris 2024. The teams carrying it in the final rankings are teams that already held an Olympic berth through another qualification pathway, particularly the preceding World Championship winners.

The project therefore labels it:

`AlreadyQualifiedOtherPathway_inferred`

This is deliberately marked as an empirical inference rather than an official enum name.

### Status 10 — unresolved Tokyo-era source value

`Status = 10` appears only in the Tokyo 2020 cycle in the completed archive:

- men: 41 rows across the historical series
- women: 62 rows

The public VIS Olympic-team-status documentation inspected during the project does not expose a semantic name for value 10. We therefore **do not guess its meaning**.

The parser preserves it as:

`UndocumentedStatus10`

Use `scripts/14_inspect_olympic_source_quirks.R` to inspect the exact teams, dates, ranks, points, selection ranks and adjacent-snapshot history associated with Status 10.

## Duplicate player-pair keys

Final QA found:

- 0 snapshots with duplicate `Position` values
- **55 snapshots with at least one duplicate unordered player-pair key**

This does not invalidate the archive. The raw VIS rows are preserved exactly, and the same general class of historical duplicate-pair behavior was observed in the ordinary Team/World ranking archive.

Do not silently deduplicate the archival source table.

For pair-level analysis, first inspect the duplicate rows and then apply an explicitly documented canonicalization rule appropriate to the analysis. `scripts/14_inspect_olympic_source_quirks.R` exports:

- `data/olympic/qa/olympic_duplicate_pair_rows.csv`
- `data/olympic/qa/olympic_duplicate_pair_summary.csv`
- `data/olympic/qa/olympic_duplicate_pair_characteristics.csv`

The characteristics output shows whether duplicate entries differ in player order, points, status or `SelectionRank`.

## Source-quirk diagnostic workflow

Run:

```r
source("scripts/14_inspect_olympic_source_quirks.R")
```

It writes diagnostics for:

1. all `Status = 10` rows;
2. complete historical trajectories for pairs that ever receive Status 10;
3. every duplicate pair row;
4. aggregate duplicate-pair behavior by cycle/gender;
5. whether duplicate rows reflect reversed player order or materially different ranking records.

These diagnostics are investigative only. They do not change the archived source data.

## Analysis convention

For future analyses:

1. treat Olympic Selection Ranking as its own temporary quad-specific ranking product;
2. join on stable player IDs whenever possible;
3. preserve `Position`, `SelectionRank`, `Points` and `Status` as separate concepts;
4. preserve unknown/undocumented source statuses rather than coercing them into known categories;
5. do not deduplicate raw Olympic rows in place;
6. when a pair-level unique table is required, derive a separate canonicalized analysis table and document the rule;
7. use the Olympic Ranking only during the retained qualification window for the corresponding GamesYear.

With these conventions, the ranking-data collection phase is considered complete and the project can proceed to substantive historical ranking analyses.

## Relevant scripts

```text
09_probe_olympic_rankings.R
10_discover_olympic_reference_dates.R
11_download_olympic_archive.R
12_parse_olympic_archive.R
13_validate_olympic_archive.R
14_inspect_olympic_source_quirks.R
```

Primary parsed dataset:

```text
data/olympic/parsed/fivb_olympic_ranking_entries.rds
```
