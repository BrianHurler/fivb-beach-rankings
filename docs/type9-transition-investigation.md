# Type 9 Transition: Season Ranking to Modern World Ranking

This note tracks the evidence for when VIS Type 9 / SubType 3 changed from the historical season-based team ranking into the modern FIVB World Ranking based on the best eight performances together over a rolling 365-day period.

## What is already established

### 2016-era system: Season's Ranking

The 2016 FIVB Beach Volleyball Sports Regulations explicitly define the **FIVB Season's Ranking** as a team ranking based on the **ten best results at all FIVB-recognized events over the season**. It was updated every Monday after an eligible event.

Source:

https://www.fivb.org/EN/BeachVolleyball/Document/FIVB_BVB_2016-Sport-Regulations_v10.pdf

This formula is consistent with the unusual early-season Type 9 snapshots in 2015. A season-to-date ranking can be dominated by teams that had already accumulated results on continental circuits even when the strongest global teams had not yet played many events in that season.

Historical references also preserve FIVB pages titled `2015 FIVB Season Ranking` and `2015/2016 FIVB Season Ranking`, confirming that this was a distinct public product.

### 2017-era system: rolling World Ranking

The 2017 FIVB Beach Volleyball Sports Regulations explicitly define the **FIVB World Ranking** as the FIVB ranking points earned at the **eight best performances as a team** in FIVB-sanctioned or homologated events over a **365-day period**. The ranking was updated every Monday.

Source:

https://www.fivb.org/EN/BeachVolleyball/Document/2017FIVB_BVB_Sports_Regulations_Final_20170822.pdf

A contemporaneous February 15, 2017 article reproducing the official February 13 FIVB rankings says the World Rankings were based on the last 365 days and, importantly, distinguishes them from separate Individual Entry and Team Entry rankings. It also states that the World Rankings are based on actual pairs and points scored together.

Source:

https://volleymob.com/fivb-updates-beach-world-rankings-ft-lauderdale-major/

Our archived Type 9 snapshot on February 13, 2017 matches that published World Ranking extremely closely, giving direct empirical evidence that Type 9 represented the public World Ranking by that date.

A further 2017 public source describes the beach World Ranking as considering teams' eight best performances over the past year.

Source:

https://en.granma.cu/deportes/2017-04-19/nivaldo-and-sergio-the-cream-of-the-crop

### 2017-2018 confirmation

A Volleyball Canada report from FIVB Beach Volleyball Commission discussions states:

> There will be only one ranking - The World Ranking: the best 8 results in the past 365 days. The other rankings are obtained through VIS only.

Source:

https://volleyball.ca/uploads/About/Governance/Annual_reports/VC_Annual_Report2017-18_EN.pdf

This confirms the modern conceptual split:

- World Ranking = best eight results together over 365 days;
- other entry / technical products remain available through VIS.

## What remains unknown

The documentary evidence gives us a narrow transition interval:

- **2016 system:** season-based best 10 is explicitly documented;
- **February 13, 2017:** Type 9 is empirically validated against the public World Ranking;
- **2017 regulations:** World Ranking is explicitly best 8 together over 365 days.

What we do not yet know is the exact Type 9 snapshot on which the calculation changed.

## Empirical change-point test

Run:

```r
source("scripts/08_audit_type9_world_transition.R")
```

Type 9 entries contain two potentially useful VIS fields:

- `NbTakenResultsTeam`
- `NbTotalResultsTeam`

The audit summarizes those fields for every Type 9 snapshot and tests whether the number of counted results fits:

```text
min(total results, 10)
```

versus:

```text
min(total results, 8)
```

It specifically exports the November 2016 through March 2017 window, where the formula change is most likely to be visible.

Outputs:

```text
data/audit/type9_result_count_by_snapshot.csv
data/audit/type9_result_count_by_year.csv
data/audit/type9_transition_window_2016_2017.csv
```

## Interpretation standard

Until the change-point audit is complete, use the following labels:

- **Type 9 before the validated transition:** historical team-results ranking / Season's Ranking era;
- **Type 9 after the validated transition:** FIVB World Ranking, best eight performances together over rolling 365 days.

Do not apply the modern World Ranking label retrospectively to the 2014-2016 Type 9 archive unless a specific date has been validated.
