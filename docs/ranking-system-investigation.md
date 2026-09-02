# Ranking System Investigation

This document tracks what the archived VIS ranking products represent, how they differ, and how they should be used in historical analysis.

## Project-wide interpretation

The archive contains three recurring VIS ranking products:

| VIS product | Unit | Interpretation |
| --- | --- | --- |
| Type 6 / SubType 1 | Player | FIVB Athlete / individual-player ranking value |
| Type 10 / SubType 2 | PlayerSum | Team / entry-style ranking made from the sum of two player values |
| Type 9 / SubType 3 | Team | Team-results ranking; becomes the validated modern FIVB World Ranking on 2017-02-13 |

The key historical nuance is that the modern VIS label `FivbWorld` should **not** be applied retrospectively as though the same World Ranking formula existed throughout the entire Type 9 archive.

## Operational analysis convention

Use the following rule in future analyses.

### Before 2017-02-13

- Type 10 is the preferred historical team-ranking measure when a ranking covariate or team ordering is needed.
- Type 9 observations from 2014-2016 should be retained for historical research, but should be labeled as the historical team-results / Season Ranking era rather than as the modern World Ranking.
- Do not use those early Type 9 values to answer questions such as `Who was #1 in the modern World Ranking?`.

### On or after 2017-02-13

- Type 9 is the validated FIVB World Ranking: best eight performances achieved together as a team over a rolling 365-day period.
- Type 10 remains available and should be retained alongside World when useful because it is a distinct PlayerSum / entry-style ranking.
- Analyses may therefore use both `world_rank` and `team_rank` from this date onward.

### Olympic Ranking

Olympic Ranking is a fourth, separate qualification product. It uses Olympic-cycle-specific windows and result-count rules and should not be substituted with either Type 9 or Type 10.

See [Type 9 Transition: Season Ranking to Modern World Ranking](type9-transition-investigation.md) for the detailed cutoff evidence and [Olympic Ranking History](olympic-ranking-history.md) for Olympic-cycle rules.

## What VIS itself tells us

The VIS SDK identifies:

- Type 6 as `FivbPlayer` — FIVB Athlete;
- Type 9 as `FivbWorld` — FIVB World;
- Type 10 as `FivbTeam` — FIVB Team.

Source:

https://www.fivb.org/VisSDK/Fivb.Vis.Model/Fivb.Vis.Model~Fivb.Vis.Beach.BeachRankingType.html

VIS also defines the ranking subtype:

- SubType 1 `Player` — player ranking;
- SubType 2 `PlayerSum` — team ranked by the sum of both players' points;
- SubType 3 `Team` — team ranked by points earned together.

Source:

https://www.fivb.org/VisSDK/Fivb.Vis.Model/Fivb.Vis.Model~Fivb.Vis.Beach.BeachRankingSubType.html

These definitions establish that Type 9 and Type 10 are structurally different calculations even when the same pair appears in both.

## Archive-wide empirical findings

### Type 10 arithmetic is exact

Across all 1,844,305 archived Type 10 rows:

```text
Type 10 Points = PointsPlayer1 + PointsPlayer2
```

The equality holds for 100% of rows with both components populated.

This confirms that Type 10 is a PlayerSum ranking rather than an independent partnership-results ranking.

### Type 10 is overwhelmingly linked to Type 6 player values

Matching each Type 10 player component to that player's Type 6 value on the same date produces near-exact agreement throughout the archive and essentially exact agreement in the modern era. Historical deviations, especially around 2017, are preserved as diagnostics rather than silently removed.

### World and Team are not interchangeable

On dates where Type 9 and Type 10 coexist, they usually contain nearly the same universe of pairs but order those pairs differently.

The audit shows:

- pair overlap is usually very high;
- rank correlation is high but not perfect;
- exact positions are rare;
- exact points are uncommon;
- top-10 composition and the #1 pair often differ.

This is consistent with the two systems using the same athlete population but different calculations.

Run:

```r
source("scripts/06_audit_ranking_systems.R")
```

for the current archive-wide diagnostics.

## Why the 2015 Type 9 ranking looked strange

A March 23, 2015 Type 9 snapshot is headed by several Venezuelan, Argentine, and Chilean teams rather than the partnerships one would expect from a rolling global World Ranking.

That snapshot should **not** be interpreted as evidence that the archive is wrong.

The 2016-era FIVB regulations explicitly define a **Season's Ranking** based on a team's ten best results during the season at FIVB-recognized events. Because recognized continental events could award ranking points, an early-season table could favor teams that had already accumulated several continental results while many elite global teams had barely started their international season.

Source:

https://www.fivb.org/EN/BeachVolleyball/Document/FIVB_BVB_2016-Sport-Regulations_v10.pdf

This behavior is one of the strongest empirical reasons not to apply the later best-8 / rolling-365 World Ranking interpretation to Type 9 before 2017.

## The 2016-2017 transition

### 2016 system

The 2016 regulations define the FIVB Season's Ranking as the ten best team results over the season.

### Archive boundary

The final pre-transition Type 9 snapshots occur on 2016-12-31. There are no January 2017 Type 9 snapshots. The series resumes for both genders on 2017-02-13 and then continues weekly.

### VIS infrastructure change

VIS release notes document a substantial new beach-ranking engine in January-February 2017, including new ranking parameters, best-result calculation classes, generic `BeachRanking` objects, and the `GetBeachRanking` / `GetBeachRankingList` requests.

Source:

https://www.fivb.org/VisSDK/Release%20Notes%20%2810xx%29.html

The old VIS data model separately contained `BeachTeamSeasonRanking`, supporting the interpretation that older team-season data were represented differently before the modern generic ranking framework.

### 2017 system

The 2017 FIVB regulations define the FIVB World Ranking as the ranking points earned at the **eight best performances as a team over a 365-day period**.

Source:

https://www.fivb.org/EN/BeachVolleyball/Document/2017FIVB_BVB_Sports_Regulations_Final_20170822.pdf

### External validation on 2017-02-13

A contemporaneous February 15, 2017 article reproduced the official February 13 FIVB World Rankings and separately linked World, Individual Entry, and Team Entry rankings.

Source:

https://volleymob.com/fivb-updates-beach-world-rankings-ft-lauderdale-major/

Our archived Type 9 snapshot reproduces that published World Ranking subject only to tie-display and historical name-format differences. This directly validates Type 9 as the public modern World Ranking by 2017-02-13.

Run:

```r
source("scripts/07_validate_feb2017_world_ranking.R")
```

for the reproducible comparison.

## Historical terminology matters

The archive is valuable precisely because modern VIS type names do not necessarily describe what FIVB publicly called the same underlying calculation in every historical era.

For each ranking observation, keep three concepts separate:

1. **VIS representation** — the current Type/SubType used by the API;
2. **mathematical calculation** — player, PlayerSum, team-together, season-based, rolling window, etc.;
3. **historical public name and purpose** — World Ranking, Team Entry Ranking, Season's Ranking, Olympic Ranking, seeding, or another technical product.

The repository should prefer validated historical interpretation over the modern API label whenever those differ.

## Remaining historical questions

The main unresolved question is not the modern World Ranking cutoff; that is sufficiently validated for project use.

The remaining work is to classify the exact public terminology and formulas of pre-2017 sub-eras, especially the 2014-2016 Type 9 series. Those observations remain useful historical data, but they should not be treated as modern World Ranking observations unless a specific date is independently validated.
