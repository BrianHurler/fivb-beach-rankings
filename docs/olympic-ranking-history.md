# Olympic Ranking History and Relationship to VIS Rankings

This note documents how FIVB Beach Volleyball Olympic qualification rankings have been constructed across recent Olympic cycles, how they differ from ordinary FIVB rankings, and what the VIS API appears to preserve.

## Main conclusion

The **Olympic Ranking is a separate ranking product** from the ordinary FIVB World, Team, and Athlete rankings.

It generally uses the same underlying FIVB ranking points earned at eligible tournaments, but applies Olympic-specific rules such as:

- a fixed Olympic qualification window;
- a fixed number of best results counted;
- team-based eligibility requirements;
- event-eligibility rules;
- NOC/NF quota limits;
- Olympic-specific qualification cutoffs.

VIS reinforces this distinction by exposing a dedicated public request:

`GetBeachOlympicSelectionRanking`

rather than treating Olympic qualification as a subtype of `GetBeachRanking`.

---

## Beijing 2008

### Olympic Ranking composition

The Beijing 2008 qualification system used a fixed qualification window from **January 1, 2007 through July 20, 2008**.

Only the points from each team's **eight best performances together** in nominated Olympic Qualification Tournaments counted toward the Olympic Ranking.

Eligible events included World Championships, World Tour events, and recognized Continental Championship Finals.

The qualification system stated that the FIVB would issue the Olympic Ranking no later than **July 21, 2008**.

This is useful for the project because our general ranking archive begins in March 2008, so Beijing-era Olympic ranking data may overlap the beginning of our historical series if VIS still retains it.

### Sources

- FIVB Beijing 2008 qualification system: https://www.fivb.org/en/volleyball/competitions/olympics/2008/fivb.og2008.volleyball.olympic.qualification.system_eng.pdf
- FIVB Beijing 2008 media guide: https://www.fivb.org/EN/BeachVolleyball/Competitions/Olympics/2008/W/Press/FIVB_BVB_OG2008_MediaGuide_Part1.pdf

---

## London 2012

### Olympic Ranking composition

For London 2012, the Olympic Ranking was based on the **best 12 results earned as a team** during the Olympic qualification period.

The qualification period ran from **January 1, 2011 through June 17, 2012**.

Eligible competitions included FIVB World Championships, FIVB World Tour events, and recognized Continental Tour Finals.

The top **16 Olympic Ranking quota places** were awarded through this pathway, subject to the Olympic maximum of two teams per NOC/NF.

The Olympic field was completed through other qualification pathways, including Continental Cup qualification, World Cup Olympic Qualification, and the host quota.

### Important distinction from the World Ranking

The official London qualification regulations explicitly discuss both the **Olympic Ranking** and the **World Ranking** as separate concepts.

The Olympic Ranking determined quota places. The World Ranking had a separate role in determining which eligible teams an NOC could nominate once it had earned quota places.

### Sources

- FIVB London 2012 qualification system: https://www.fivb.org/en/BeachVolleyball/Document/FIVB_OG2012_Qualification_System_BVB_ENG.PDF
- FIVB beach volleyball history: https://www.fivb.com/beach-volleyball/the-game/history/

---

## Rio 2016

### Olympic Ranking composition

For Rio 2016, FIVB described the Olympic Ranking as being established from **FIVB World Ranking points earned at the 12 best performances as a team**.

The qualification period ran from **January 1, 2015 through June 12, 2016**.

The final Olympic Ranking list was published on **June 13, 2016**.

Eligible events included the FIVB World Championships, FIVB World Tour events, and recognized Continental Tour Finals.

Fifteen teams per gender qualified through the Olympic Ranking pathway, with the remaining Olympic places coming from other qualification routes.

### Interpretation

The Olympic Ranking used FIVB ranking-point currency, but applied its own fixed Olympic window and best-12 team-results rule. It should therefore not be assumed to equal either the ordinary Team Entry ranking or the general team-results ranking used outside Olympic qualification.

### Sources

- FIVB 2016 Beach Volleyball Sport Regulations: https://www.fivb.org/EN/BeachVolleyball/Document/FIVB_BVB_2016-Sport-Regulations_v10.pdf
- Rio 2016 qualification system: https://www.fivb.org/EN/BeachVolleyball/Document/FIVB_OG2016_Qualification_System_BVB_ENG.pdf

---

## Tokyo 2020 / held in 2021

### Olympic Ranking composition

The Tokyo qualification system again used each team's **12 best performances** during the Olympic qualification period.

Because of the COVID-19 postponement, FIVB extended the Olympic Ranking qualification period through **June 13, 2021**, with the final ranking published on **June 14, 2021**.

The Games remained officially Tokyo 2020, so the VIS `GamesYear` should be `2020` even when querying a 2021 reference date.

### Sources

- Tokyo 2020 qualification system: https://www.fivb.org/EN/BeachVolleyball/Forms/Olympic_Qualification/Tokyo2020-Qualification-System-Beach-Volleyball_31.01.2019.pdf
- FIVB adaptation of Olympic qualification: https://www.fivb.com/fivb-announces-adaptation-of-beach-volleyball-olympic-qualification/
- Tokyo draw / qualification pathways: https://www.fivb.com/draw-reveals-pools-for-tokyo-2020-beach-volleyball-tournament/

---

## Paris 2024

### Olympic Ranking composition

For Paris 2024, the Olympic Ranking was based on each team's **12 best performances as a team** from **January 1, 2023 through June 10, 2024**.

Seventeen teams per gender qualified through the Olympic Ranking pathway.

By this era the contrast with the ordinary World Ranking is especially clear: the modern World Ranking uses a rolling 365-day window and best eight performances, whereas the Olympic Ranking used best 12 across a fixed Olympic qualification window.

### Sources

- FIVB Paris 2024 qualification information: https://www.fivb.com/?p=66667
- FIVB teams qualified for Paris 2024: https://www.fivb.com/beach-volleyball-teams-qualified-for-paris-2024/
- FIVB Beach Volleyball Sport Operations Manual: https://www.fivb.com/wp-content/uploads/2024/05/2025_FIVB_BVB_Sport-Operations-Manual-Clean-March-11-2025.pdf

---

## What VIS stores for Olympic qualification

VIS has a dedicated public request:

```xml
<Request Type="GetBeachOlympicSelectionRanking"
         Gender="W"
         GamesYear="2024"
         ReferenceDate="2024-06-10"
         Fields="GamesYear Position NoPlayer1 NoPlayer2 TeamName TeamCountryCode NbParticipations SelectionRank Points Status" />
```

The request supports:

- `Gender` — mandatory;
- `GamesYear` — Olympic Games year;
- `ReferenceDate` — exact date on which a ranking was calculated;
- `OnlySelected` — all teams, selected teams only, or non-selected teams only.

If `GamesYear` is omitted, VIS returns the latest Olympic Games for which it has a ranking. If `ReferenceDate` is omitted, VIS returns the latest stored ranking date for that Olympic cycle. If an exact requested reference date was not calculated, VIS returns an empty ranking.

VIS identifies Olympic selection as its own global-ranking category (`BeachOlympicSelection`) and also has a dedicated historical data type (`BeachOlympicRanking`).

### Entry fields

The complete Olympic Selection Ranking entry field set exposed by the current VIS client/documentation is:

- `GamesYear`
- `Position`
- `NoPlayer1`
- `NoPlayer2`
- `TeamName`
- `TeamCountryCode`
- `NbParticipations`
- `SelectionRank`
- `Points`
- `Status`

The stable player IDs are especially useful because Olympic snapshots can be joined directly to our Athlete, Team, and World ranking archives without relying only on historical team-name strings.

### Selection-status information

VIS does not merely store ranking position and points. `Status` records why a team is or is not selected:

| Status | Meaning |
|---:|---|
| 1 | Selected |
| 2 | Selected because of host minimum quota |
| 3 | Selected because of confederation minimum quota |
| 4 | Tied but not selected |
| 5 | Not enough qualifying tournaments |
| 6 | Excluded by country quota |
| 7 | Not registered |
| 8 | Not enough points |

This makes the Olympic endpoint potentially richer than a simple ranking table: it may allow us to reconstruct Olympic eligibility and quota effects directly from VIS snapshots.

### Important limitation: no Olympic-ranking list request

Unlike the generic `GetBeachRankingList`, the public VIS request catalog does **not** expose a `GetBeachOlympicSelectionRankingList` request.

Therefore, historical Olympic snapshot discovery appears to require probing plausible `ReferenceDate` values. A sensible workflow is:

1. test the documented final reference date for each Olympic cycle;
2. query the latest stored ranking for each `GamesYear` with no reference date;
3. if historical snapshots are retained, scan likely ranking dates within each qualification window and archive every non-empty response.

### VIS / client sources

- Olympic Selection Ranking request: https://www.fivb.org/VisSDK/VisWebService/GetBeachOlympicSelectionRanking.html
- VIS request list: https://www.fivb.org/VisSDK/VisWebService/RequestList.html
- VIS data types: https://www.fivb.org/VisSDK/VisWebService/DataType.html
- OpenVolley `fivbvis` Olympic selection wrapper and field definitions: https://rdrr.io/github/openvolley/fivbvis/man/v_get_beach_olympic_selection_ranking.html
- OpenVolley VIS field definitions: https://rdrr.io/github/openvolley/fivbvis/src/R/fields.R
- OpenVolley VIS status mappings: https://rdrr.io/github/openvolley/fivbvis/src/R/data_schema.R

---

## VIS discovery probe in this repository

The repo contains:

```text
R/olympic_ranking.R
scripts/09_probe_olympic_rankings.R
```

The probe tests both the expected final ranking date and the latest stored ranking for men and women in:

- Beijing 2008
- London 2012
- Rio 2016
- Tokyo 2020
- Paris 2024

Expected final dates tested:

| Games | VIS GamesYear | Final/reference date |
|---|---:|---|
| Beijing 2008 | 2008 | 2008-07-21 |
| London 2012 | 2012 | 2012-06-18 |
| Rio 2016 | 2016 | 2016-06-13 |
| Tokyo 2020 | 2020 | 2021-06-14 |
| Paris 2024 | 2024 | 2024-06-10 |

Run:

```r
source("scripts/09_probe_olympic_rankings.R")
```

The probe preserves raw XML under `data/olympic_probe/raw/` and writes summary/entry CSVs under `data/olympic_probe/`.

The first objective is to establish which cycles VIS still retains and whether the expected final snapshots exist exactly. Only after that should we scan each qualification period for every stored historical reference date.

---

## Analysis convention once Olympic data is archived

Treat four ranking products as distinct:

1. FIVB Athlete / Player ranking
2. FIVB Team / PlayerSum ranking
3. FIVB World / team-results ranking, using the validated historical-era rules documented elsewhere in this repo
4. Olympic Selection Ranking

For matched dates, useful comparisons include:

- Olympic rank vs World rank;
- Olympic rank vs Team rank;
- points differences;
- teams appearing in one product but not another;
- country-quota exclusions;
- tournament-participation eligibility;
- selected vs non-selected teams;
- how Olympic and World rankings converge or diverge near qualification deadlines.

The goal is to preserve the Olympic Ranking as the temporary, quad-specific qualification product it actually was rather than substituting another FIVB ranking for it.
