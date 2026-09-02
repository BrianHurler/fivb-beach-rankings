# Ranking System Investigation

This document tracks what the archived VIS ranking products appear to represent, how they differ, and how we plan to validate them against historical FIVB language and public ranking tables.

## Why this investigation matters

The VIS API exposes multiple beach-volleyball ranking products that coexist on the same dates. Their names alone are not enough to assume they correspond to the public ranking terminology used by FIVB in every historical era.

The archive currently contains:

- Type 6 / SubType 1 — FIVB Athlete / Player
- Type 9 / SubType 3 — FIVB World / Team
- Type 10 / SubType 2 — FIVB Team / PlayerSum

The archive spans 2008 onward for Types 6 and 10, while Type 9 begins in late 2014.

## What VIS itself tells us

### Ranking types

The VIS SDK identifies:

- Type 6 as `FivbPlayer` — FIVB Athlete
- Type 9 as `FivbWorld` — FIVB World
- Type 10 as `FivbTeam` — FIVB Team

Source:

https://www.fivb.org/VisSDK/Fivb.Vis.Model/Fivb.Vis.Model~Fivb.Vis.Beach.BeachRankingType.html

### Ranking subtypes

VIS describes the subtype as the unit used for ranking points:

- SubType 1 `Player` — player ranking
- SubType 2 `PlayerSum` — team ranked by the sum of both players' points
- SubType 3 `Team` — team ranked by points earned together

Source:

https://www.fivb.org/VisSDK/Fivb.Vis.Model/Fivb.Vis.Model~Fivb.Vis.Beach.BeachRankingSubType.html

This means Type 9 and Type 10 are structurally different ranking concepts even when the same pair appears in both.

## Important 2016 terminology

The 2016 FIVB Beach Volleyball Sports Regulations describe several different ranking/points systems operating simultaneously.

### Athlete Entry Points

The best six of the last eight eligible FIVB results in the relevant 365-day window were used for athlete entry points.

### FIVB Seeding Points

FIVB Seeding Points were the sum of the two individual athletes' Entry Points.

### Individual Technical Ranking

The Individual Technical Ranking ranked individual players using the total FIVB Ranking points earned in recognized events over a 365-day period.

### FIVB Season's Ranking

The season ranking ranked teams using their ten best results during the season and determined the Team of the Year.

### Olympic Ranking

The Rio Olympic Ranking used the 12 best performances achieved together as a team during the fixed Olympic qualification window.

Source:

https://www.fivb.org/EN/BeachVolleyball/Document/FIVB_BVB_2016-Sport-Regulations_v10.pdf

This is strong evidence that historical FIVB beach volleyball had multiple legitimate ranking constructs at the same time. Therefore, a VIS ranking should not be identified solely from its generic word `Team` or `World` without empirical validation.

## Important 2017-2018 transition clue

A Volleyball Canada report from FIVB Beach Volleyball Commission discussions stated that beginning with the updated system there would be:

> only one ranking – the World Ranking: the best 8 results in the past 365 days

and noted that other rankings would still be obtainable through VIS.

Source:

https://volleyball.ca/uploads/About/Governance/Annual_reports/VC_Annual_Report2017-18_EN.pdf

This is especially important for our archive. It suggests that from roughly the 2018 rules transition onward, the public-facing `World Ranking` became a single clearly defined product, while other technical/entry/team products continued to exist internally in VIS.

## VIS ranking infrastructure history

VIS release notes show that the modern beach-ranking infrastructure was introduced around February 2017. The release notes record new `BeachRanking`, `BeachRankingEntry`, ranking calculation classes and ranking types, with `FivbPlayer` and `FivbTeam` values added in February 2017.

Source:

https://www.fivb.org/VisSDK/Release%20Notes%20%2810xx%29.html

This raises an important historical interpretation question:

**Are the 2008-2016 Type 6 and Type 10 objects native historical ranking products, or were older ranking snapshots imported/backfilled into the newer VIS ranking schema?**

The data can still be completely valid even if the modern type labels were assigned retrospectively. We should therefore distinguish:

1. what the numbers mathematically represent;
2. what FIVB called that calculation at the time; and
3. what label the modern VIS API now gives the archived object.

## Public-history clues to validate against

### 2015 World Tour / season history

FIVB historical material identifies Aleksandrs Samoilovs / Janis Smedins as the 2013 and 2014 men's World Tour champions and Alison / Bruno Schmidt as the 2015 men's champion. Barbara / Agatha are listed as the 2015 women's champion.

Useful source:

https://www.fivb.org/EN/BeachVolleyball/Competitions/WorldTour/2016/Handbook_2016/FIVB-BVB-Handbook2016-CH01_v02.pdf

This gives us end-of-season validation targets, though a season ranking should not automatically be assumed to equal a rolling World Ranking.

### Modern World Ranking formula

Modern Volleyball World material explicitly defines the FIVB Beach Volleyball World Ranking as the eight best performances as a team over the prior 365 days.

Example source:

https://en.volleyballworld.com/news/world-champs-top-world-rankings-ahead-of-new-season

### Modern entry / technical points remain separate

Current Volleyball World tournament entry lists still expose distinct columns such as Entry Points, Entry Technical Points, Seed Points and Seed Technical Points. That reinforces the fact that public World Ranking position is not the only points construct in the system.

Example:

https://en.volleyballworld.com/beachvolleyball/competitions/beach-pro-tour/2026/elite16/hamburg-ger/teams/men/main-draw

## Empirical audit plan

Run:

```r
source("scripts/06_audit_ranking_systems.R")
```

The script produces local files in `data/audit/`.

### Test 1 — Type 10 arithmetic

Check whether:

```text
Type 10 Points = PointsPlayer1 + PointsPlayer2
```

If true across the archive, that directly confirms the `PlayerSum` interpretation.

### Test 2 — Type 6 to Type 10 linkage

For each player in a Type 10 team, match the player ID to the Type 6 ranking on the same date and test whether:

```text
Type 10 PointsPlayer1 = that athlete's Type 6 Points
Type 10 PointsPlayer2 = that athlete's Type 6 Points
```

If this is nearly or exactly 100%, then Type 10 is mechanically derived from Type 6.

This would be an extremely important finding because it would tell us that Type 10 is not an independent results-based team ranking at all; it is a pairing of two individual ranking values.

### Test 3 — Type 9 vs Type 10

On every date where both rankings exist, compare pairs using stable VIS player IDs.

Metrics:

- percentage of Type 9 pairs appearing in Type 10;
- top-10 overlap;
- whether the #1 pair is the same;
- Spearman correlation of pair positions;
- percentage of overlapping pairs with exactly the same position;
- percentage with exactly the same points.

This will show whether the two products are sometimes similar, highly correlated, or genuinely divergent.

### Test 4 — Historical sample snapshots

The audit automatically selects the closest common Type 9 / Type 10 snapshots to:

- 2015-03-23
- 2016-06-13
- 2018-01-01
- 2021-06-14
- 2024-06-10
- 2026-08-31

For each gender it exports the top 20 from both rankings side by side.

These dates are intended to sample different regulatory eras and Olympic-cycle landmarks.

## External validation strategy

For selected snapshots, locate a contemporaneous posted ranking or authoritative description from:

1. FIVB / Volleyball World pages and PDFs;
2. Olympic qualification documents;
3. World Tour handbooks and sports regulations;
4. national federation material that reproduces FIVB rankings;
5. archived pages or the Internet Archive when original FIVB pages are no longer live.

For every external validation, record:

- published date;
- what the source calls the ranking;
- ranking formula stated by the source, if any;
- top teams and points;
- which VIS product matches it;
- whether the match is exact or approximate.

## Working hypotheses

These are deliberately hypotheses, not conclusions.

### Type 6 — FIVB Athlete

Likely represents an individual-player ranking/technical points construct. The exact historical formula may change by era.

### Type 10 — FIVB Team / PlayerSum

Expected to be a team ordering created by adding two individual-player point totals. It may correspond closely to entry/seeding/technical-team concepts used historically rather than to the public World Ranking.

### Type 9 — FIVB World / Team

The best candidate for the public team-based World Ranking, particularly after the 2017-2018 ranking-system simplification. However, the 2014-2017 portion requires careful historical validation before we assume the current label maps perfectly onto the public terminology used at the time.

### Olympic Ranking

Separate from all three products above and should eventually be archived through `GetBeachOlympicSelectionRanking`.

## Goal

The end product should be a year-by-year ranking dictionary that answers:

- What rankings existed?
- What was each one called publicly?
- What was its formula?
- What was it used for: entry, seeding, technical ranking, World Ranking, season championship or Olympic qualification?
- Which modern VIS Type/SubType contains it?
- Was the historical data native or retrospectively represented in the newer VIS schema?

The archive is valuable precisely because it gives us enough historical snapshots to answer these questions empirically rather than relying only on current naming conventions.
