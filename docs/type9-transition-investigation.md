# Type 9 Transition: Season Ranking to Modern World Ranking

This note documents the evidence for when VIS Type 9 / SubType 3 changed from the historical season-based team-results ranking into the modern FIVB World Ranking based on the best eight performances together over a rolling 365-day period.

## Operational conclusion

For this project, use **2017-02-13** as the first validated Type 9 snapshot representing the modern FIVB World Ranking.

Analysis convention:

- **Type 9 before 2017-02-13:** historical team-results / Season Ranking era. Do not label it as the modern World Ranking.
- **Type 9 on or after 2017-02-13:** FIVB World Ranking, based on the best eight performances together over a rolling 365-day period.

The precise administrative effective date of the new formula may precede the first published ranking by a small amount, but 2017-02-13 is the first Type 9 snapshot in the archive for which the modern calculation and public identity are directly validated.

### Project-wide usage rule

For future historical analyses, the repository should apply the cutoff explicitly rather than simply filtering `ranking_type == 9`.

Recommended interpretation:

```text
2008-03-31 through 2017-02-12
  Use Type 10 Team / PlayerSum when a historical team-ranking measure is required.
  Keep any Type 9 observations available for historical research, but do not label them
  as the modern World Ranking.

2017-02-13 onward
  Use Type 9 as FIVB World Ranking.
  Retain Type 10 Team / PlayerSum alongside it when useful because the two rankings
  are mathematically and empirically distinct.
```

In other words, the presence of a Type 9 object before 2017-02-13 does **not** mean a modern World Ranking is available for that date. This distinction is essential for longitudinal analyses, rank-history plots, historical #1 queries, and any model using ranking position as a covariate.

## Evidence

### 1. 2016-era system: Season's Ranking

The 2016 FIVB Beach Volleyball Sports Regulations explicitly define the **FIVB Season's Ranking** as a team ranking based on the **ten best results at all FIVB-recognized events over the season**. It was updated every Monday after an eligible event.

Source:

https://www.fivb.org/EN/BeachVolleyball/Document/FIVB_BVB_2016-Sport-Regulations_v10.pdf

Historical references preserve official FIVB pages titled `2015 FIVB Season Ranking` and `2015/2016 FIVB Season Ranking`. The unusual early-season Type 9 snapshots in 2015 are consistent with this formula: a season-to-date ranking could be dominated by teams already accumulating results on continental circuits even when many elite global teams had not yet begun their season.

### 2. The old VIS data model explicitly contained a team Season Ranking

The VIS data-type enumeration includes a distinct historical `BeachTeamSeasonRanking` data type, separate from World Tour, Olympic, player, technical, and later generic `BeachRanking` objects.

Source:

https://www.fivb.org/VisSDK/VisWebService/DataType.html

VIS release notes show `BeachTeamsSeasonRanking` being added to the exposed data types in November 2016.

Source:

https://www.fivb.org/VisSDK/Release%20Notes%20%2810xx%29.html

This is consistent with the interpretation that the pre-2017 Type 9 records were historical team season-ranking data later represented inside the newer generic ranking archive.

### 3. A new generic ranking engine was built immediately before the 2017 season

VIS release notes document a substantial beach-ranking rewrite in January-February 2017:

- January 31: new `BeachRankingParameters`, `BeachRankingResultsBest`, and `BeachRankingResultsBestOfLast` classes;
- February 10: new `CalculateBeachRanking` request and a new `BeachRanking` class;
- February 14: new `BeachRankingEntry` infrastructure;
- February 16: new `GetBeachRanking` and `GetBeachRankingList` requests;
- February 17: additional ranking types and ranking-method support.

Source:

https://www.fivb.org/VisSDK/Release%20Notes%20%2810xx%29.html

This timing aligns closely with the start of the 2017 World Tour season and the first modern World Ranking snapshot in our archive.

### 4. Archive change point

The final Type 9 snapshots before the transition window occur on **2016-12-31**.

There are no January 2017 Type 9 snapshots in the archive.

The next Type 9 snapshot is:

- **2017-02-13 — Men**
- **2017-02-13 — Women**

Subsequent Type 9 snapshots resume weekly on February 20, February 27, March 6, March 13, March 20, March 27, etc.

This makes February 13 a natural first published snapshot for the new 2017 ranking era.

### 5. 2017 regulations explicitly define the modern formula

The 2017 FIVB Beach Volleyball Sports Regulations define the **FIVB World Ranking** as FIVB ranking points earned at the **eight best performances as a team** in sanctioned or homologated events over a **365-day period**. It is updated every Monday after an eligible event.

Source:

https://www.fivb.org/EN/BeachVolleyball/Document/2017FIVB_BVB_Sports_Regulations_Final_20170822.pdf

### 6. February 13, 2017 Type 9 directly matches the published World Ranking

A contemporaneous February 15, 2017 article reproduces the official FIVB World Rankings as of February 13, 2017 and separately links:

- Men's and Women's World Ranking;
- Individual Entry Ranking;
- Team Entry Ranking.

It explains that World Rankings are based on actual pairs and their points earned together, while the entry products are based on individual-athlete ranking values.

Source:

https://volleymob.com/fivb-updates-beach-world-rankings-ft-lauderdale-major/

Our archived Type 9 snapshot on February 13, 2017 reproduces that published table, subject only to tie-display and historical-name-format differences. This directly identifies Type 9 as the public FIVB World Ranking by this date.

### 7. Later documentary confirmation

A Volleyball Canada report from FIVB Beach Volleyball Commission discussions states:

> There will be only one ranking - The World Ranking: the best 8 results in the past 365 days. The other rankings are obtained through VIS only.

Source:

https://volleyball.ca/uploads/About/Governance/Annual_reports/VC_Annual_Report2017-18_EN.pdf

This confirms the conceptual distinction between the public World Ranking and other technical / entry products retained in VIS.

## Result-count fields did not identify the switch

`scripts/08_audit_type9_world_transition.R` tested the Type 9 entry fields:

- `NbTakenResultsTeam`
- `NbTotalResultsTeam`

Across the archive, `NbTakenResultsTeam` is not populated, so these fields cannot be used to distinguish a best-10 from best-8 calculation directly.

The transition audit was still useful because it established the exact sequence of Type 9 dates around the 2016-2017 boundary.

## Confidence statement

**High confidence:** Type 9 on and after 2017-02-13 is the modern FIVB World Ranking (best 8 performances together / rolling 365 days).

**High confidence:** the 2014-2016 Type 9 archive should not be treated as that modern World Ranking formula.

**Still worth historical validation:** precisely which public legacy label applies to every pre-2017 Type 9 sub-era (Season Ranking, World Tour Season Ranking, or closely related team-results product). That question does not affect the operational 2017 boundary for future analyses.