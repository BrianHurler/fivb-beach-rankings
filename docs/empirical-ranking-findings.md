# Empirical Ranking Findings

This note records findings from the complete historical VIS ranking archive after downloading and parsing all archived FIVB Athlete, FIVB World, and FIVB Team ranking snapshots from 2008 onward.

## Archive scale

The archive contains 3,663 ranking snapshots spanning 2008-03-31 through 2026-08-31 and parses to 6,054,861 ranking-entry rows.

## Type 10 is definitively a PlayerSum ranking

Across all 1,844,305 Type 10 rows with both player components present:

```text
Type 10 Points = PointsPlayer1 + PointsPlayer2
```

The equality holds for 100% of rows and the median difference is exactly zero.

This confirms the VIS `PlayerSum` subtype literally: Type 10 is not an independently accumulated team-performance ranking. It is a ranking of pairings constructed from two player point totals.

## Type 10 player components closely track Type 6 Athlete points

When each Type 10 player component is matched to the same athlete's Type 6 points on the same date, the values are overwhelmingly identical.

The exact-match share is approximately:

- 99.9-100% in 2008-2012;
- 98.9-99.6% in 2013-2016;
- 95.4% in 2017;
- 99.5-99.8% in 2018-2019;
- effectively 100% from 2020 onward, with only tiny isolated mismatches in 2023, 2024, and 2026.

The 2017 discrepancy is large enough to warrant targeted investigation. Possible explanations include rule-transition timing, point-version differences, revised ranking records, or historical backfilling into the newer VIS ranking schema.

## World and Team contain largely the same pairs but are different rankings

After canonicalizing duplicate pair rows within snapshots, Type 9 World and Type 10 Team have extremely high pair overlap on common dates.

From 2016 onward, usually 97-100% of World pairs appear in Team, and from 2020 onward the overlap is effectively complete in both directions.

However, their actual rankings are materially different:

- exact pair positions typically agree for only about 0.2-0.7% of overlapping rows;
- exact point totals generally agree for only about 6-32% of overlapping rows;
- position-order Spearman correlations are commonly around 0.72-0.87;
- top-10 overlap is often roughly 6-8 teams rather than 10;
- the #1 pair frequently differs.

This is exactly what should occur if both products rank a largely common pair universe using different point constructions.

## Historical duplicate pair rows

Duplicate unordered player-pair keys occur in both Type 9 and Type 10 snapshots primarily from 2011 through 2019. They disappear from the audit after 2019.

These rows should not be silently treated as independent pairs when comparing ranking systems. The audit now preserves them in diagnostic exports while using one canonical row per pair for World-vs-Team comparisons.

Their historical cause remains an open question. Possibilities include alternate player order, duplicate/revised registrations, ranking-data migration, or other VIS-era bookkeeping behavior.

## February 13, 2017 external World Ranking validation

A contemporaneous VolleyMob article reproduces FIVB's World Ranking dated February 13, 2017 and separately links the public World Ranking, Individual Entry Ranking, and Team Entry Ranking products.

Source:

https://volleymob.com/fivb-updates-beach-world-rankings-ft-lauderdale-major/

The archived Type 9 men's snapshot matches all ten published teams and all published point totals. The only apparent position discrepancy is the published tie at 3,520 points between Nicolai/Lupo and Gibb/Patterson: VIS stores the tied rows sequentially at positions 9 and 10, while the published table displays rank 9 once and leaves the second tied row blank.

The initial women's validation found 8/10 teams through normalized name matching. The unresolved rows were Walsh Jennings/Ross and Heidrich/Zumkehr. Because the remaining eight rows matched exactly and historical VIS naming can differ from publication naming, the validation script has been updated to use a conservative unique-points fallback and tie-aware positional checks. The revised script also exports the complete Type 9 snapshot for direct inspection.

Run:

```r
source("scripts/07_validate_feb2017_world_ranking.R")
```

## Current working interpretation

The combined documentary and empirical evidence now strongly supports:

| VIS product | Interpretation |
| --- | --- |
| Type 6 / SubType 1 | Athlete / individual entry-style points |
| Type 10 / SubType 2 | Team Entry / PlayerSum construction from two athlete point totals |
| Type 9 / SubType 3 | Pair-based FIVB World Ranking, at least clearly confirmed for the 2017-era system |
| Olympic Selection Ranking | Separate Olympic qualification product, not one of the above |

For analysis, Type 9 and Type 10 should therefore be retained as distinct variables whenever both exist. Prior to Type 9 availability in late 2014, Type 10 can be used as the available historical Team/Entry ranking, but it should not be relabeled as World Ranking.
