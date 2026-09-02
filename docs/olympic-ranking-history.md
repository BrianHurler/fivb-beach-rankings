# Olympic Ranking History and Relationship to VIS Rankings

This note documents how FIVB Beach Volleyball Olympic qualification rankings have been constructed across the Olympic cycles in scope for this project, how they differ from ordinary FIVB rankings, and what the VIS API preserves.

## Main conclusion

The **Olympic Ranking is a separate ranking product** from the ordinary FIVB World, Team, and Athlete rankings.

It generally uses the same underlying FIVB ranking points earned at eligible tournaments, but applies Olympic-specific rules such as:

- a fixed Olympic qualification window;
- a fixed number of best results counted;
- team-based eligibility requirements;
- event-eligibility rules;
- NOC/NF quota limits;
- Olympic-specific qualification cutoffs and other qualification pathways.

VIS reinforces this distinction by exposing a dedicated public request:

`GetBeachOlympicSelectionRanking`

rather than treating Olympic qualification as a subtype of `GetBeachRanking`.

The live VIS API has now been empirically confirmed to retain Olympic Selection Rankings for **London 2012, Rio 2016, Tokyo 2020, and Paris 2024**.

---

## London 2012

For London 2012, the Olympic Ranking was based on the **best 12 results earned as a team** during the Olympic qualification period.

The qualification period ran from **January 1, 2011 through June 17, 2012**, with the final Olympic Ranking dated **June 18, 2012**.

The top **16 Olympic Ranking quota places** were awarded through this pathway, subject to the Olympic maximum of two teams per NOC/NF.

The Olympic field was completed through other qualification pathways, including Continental Cup qualification, World Cup Olympic Qualification, and the host quota.

The official London qualification regulations explicitly discuss both the **Olympic Ranking** and the **World Ranking** as separate concepts.

### VIS validation

`ReferenceDate="2012-06-18"` returns the retained final ranking:

- Men: 288 teams, 16 selected through the relevant selection statuses
- Women: 237 teams, 16 selected

Omitting `ReferenceDate` returns the same row counts and same leaders, indicating that the final London ranking is also the latest retained London snapshot.

Examples from the final ranking:

- Men: Emanuel/Alison 8,360; Rogers/Dalhausser 7,560; Brink/Reckermann 6,760
- Women: Larissa/Juliana 8,380; Zhang Xi/Xue 7,880; May-Treanor/Walsh Jennings 7,560

### Sources

- FIVB London 2012 qualification system: https://www.fivb.org/en/BeachVolleyball/Document/FIVB_OG2012_Qualification_System_BVB_ENG.PDF
- FIVB beach volleyball history: https://www.fivb.com/beach-volleyball/the-game/history/

---

## Rio 2016

For Rio 2016, FIVB described the Olympic Ranking as being established from **FIVB World Ranking points earned at the 12 best performances as a team**.

The qualification period ran from **January 1, 2015 through June 12, 2016**. FIVB's qualification timeline says the final Olympic Ranking was **published June 13, 2016**.

This creates an important VIS distinction:

- public publication date: `2016-06-13`
- ranking reference/calculation date: expected to be `2016-06-12`

Our initial VIS probe using `ReferenceDate="2016-06-13"` correctly returned an empty ranking because no ranking was calculated on that exact date. Omitting `ReferenceDate` returns the retained final Rio ranking:

- Men: 370 teams
- Women: 305 teams

The repo now treats **2016-06-12** as the expected final VIS `ReferenceDate`, while retaining June 13 as the public publication date.

Examples from the retained final ranking:

- Men: Alison/Bruno Schmidt 7,740; Brouwer/Meeuwsen 6,470; Lucena/Dalhausser 6,280
- Women: Larissa/Talita 7,700; Agatha/Barbara 7,230; Walsh Jennings/April 6,670

### Sources

- FIVB 2016 Beach Volleyball Sport Regulations: https://www.fivb.org/EN/BeachVolleyball/Document/FIVB_BVB_2016-Sport-Regulations_v10.pdf
- Rio 2016 qualification system: https://www.fivb.org/EN/BeachVolleyball/Document/FIVB_OG2016_Qualification_System_BVB_ENG.pdf

---

## Tokyo 2020 / held in 2021

The Tokyo qualification system again used each team's **12 best performances** during the Olympic qualification period.

The original Olympic Ranking period began **September 1, 2018**. Because of the COVID-19 postponement, FIVB extended qualification through June 2021, with the final ranking dated **June 14, 2021**.

The Games remained officially Tokyo 2020, so the VIS `GamesYear` is `2020` even for 2021 reference dates.

### VIS validation

`GamesYear="2020" ReferenceDate="2021-06-14"` returns the retained final ranking:

- Men: 751 teams
- Women: 616 teams

Omitting `ReferenceDate` returns the same row counts and leaders.

Examples:

- Men: Mol/Sørum 10,960; Krasilnikov/Stoyanovskiy 9,180; Cherif/Ahmed 7,720
- Women: Pavan/Melissa 9,400; Alix/April 9,400; Agatha/Duda 9,040

### Sources

- Tokyo 2020 qualification system: https://www.fivb.org/EN/BeachVolleyball/Forms/Olympic_Qualification/Tokyo2020-Qualification-System-Beach-Volleyball_31.01.2019.pdf
- FIVB adaptation of Olympic qualification: https://www.fivb.com/fivb-announces-adaptation-of-beach-volleyball-olympic-qualification/
- Tokyo draw / qualification pathways: https://www.fivb.com/draw-reveals-pools-for-tokyo-2020-beach-volleyball-tournament/

---

## Paris 2024

For Paris 2024, the Olympic Ranking was based on each team's **12 best performances as a team** from **January 1, 2023 through June 10, 2024**.

Seventeen teams per gender qualified through the Olympic Ranking pathway.

By this era the contrast with the ordinary World Ranking is especially clear: the modern World Ranking uses a rolling 365-day window and best eight performances, whereas the Olympic Ranking used best 12 across a fixed Olympic qualification window.

### VIS validation

`ReferenceDate="2024-06-10"` returns the retained final ranking:

- Men: 673 teams, 17 selected through the Olympic Ranking statuses
- Women: 618 teams, 17 selected

Omitting `ReferenceDate` returns the same row counts and leaders.

Examples:

- Men: Åhman/Hellvig 13,160; Mol/Sørum 11,360; Ehlers/Wickler 10,500
- Women: Duda/Ana Patrícia 13,160; Cruz/Brasher 11,960; Hughes/Cheng 11,400

FIVB publicly announced the finalized rankings on June 11, 2024, after the June 10 ranking cutoff.

### Sources

- FIVB Paris 2024 qualification information: https://www.fivb.com/?p=66667
- FIVB teams qualified for Paris 2024: https://www.fivb.com/beach-volleyball-teams-qualified-for-paris-2024/
- FIVB Beach Volleyball Sport Operations Manual: https://www.fivb.com/wp-content/uploads/2024/05/2025_FIVB_BVB_Sport-Operations-Manual-Clean-March-11-2025.pdf

---

## What VIS stores for Olympic qualification

VIS has a dedicated public request. Because it is a legacy request, it must be wrapped in `<Requests>`:

```xml
<Requests>
  <Request Type="GetBeachOlympicSelectionRanking"
           Gender="W"
           GamesYear="2024"
           ReferenceDate="2024-06-10"
           Fields="GamesYear Position NoPlayer1 NoPlayer2 TeamName TeamCountryCode NbParticipations SelectionRank Points Status" />
</Requests>
```

The request supports:

- `Gender` — mandatory;
- `GamesYear` — Olympic Games year;
- `ReferenceDate` — exact date on which a ranking was calculated;
- `OnlySelected` — all teams, selected teams only, or non-selected teams only.

If `GamesYear` is omitted, VIS returns the latest Olympic Games for which it has a ranking. If `ReferenceDate` is omitted, VIS returns the latest stored ranking date for that Olympic cycle. If an exact requested reference date was not calculated, VIS returns an empty ranking.

VIS identifies Olympic selection as its own global-ranking category (`BeachOlympicSelection`) and also has a dedicated historical data type (`BeachOlympicRanking`).

### Entry fields

The Olympic Selection Ranking entries expose:

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

The stable player IDs allow Olympic snapshots to be joined directly to our Athlete, Team, and World ranking archives.

### Selection-status information

VIS does not merely store ranking position and points. `Status` records selection/eligibility state.

The historical VIS model documents:

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

### Undocumented Status 9

The retained 2016, 2020, and 2024 rankings also contain `Status="9"`, which is absent from the older public VIS enum documentation.

Its meaning can be inferred very strongly from the teams carrying it:

- Rio 2016: Alison/Bruno Schmidt and Agatha/Barbara — 2015 World Champions
- Tokyo 2020: Krasilnikov/Stoyanovskiy and Pavan/Melissa — 2019 World Champions
- Paris 2024: Perusic/Schweiner and Hughes/Cheng — 2023 World Champions

These teams had already earned Olympic quota places through the World Championship pathway and therefore did not need an Olympic Ranking quota.

The repo labels status 9:

`AlreadyQualifiedOtherPathway_inferred`

This label is explicitly marked as an empirical inference rather than an official current VIS enum name.

### Important limitation: no Olympic-ranking list request

Unlike `GetBeachRankingList`, the public VIS catalog does **not** expose a `GetBeachOlympicSelectionRankingList` request.

Historical Olympic snapshot discovery therefore requires probing exact `ReferenceDate` values. This is feasible because an invalid/non-calculated date returns an empty ranking rather than an error.

---

## Repository workflow

### 09 — validate cycles and final snapshots

```r
source("scripts/09_probe_olympic_rankings.R")
```

This has confirmed retained Olympic ranking data for all four cycles in project scope.

### 10 — discover every retained reference date

```r
source("scripts/10_discover_olympic_reference_dates.R")
```

Because there is no list endpoint, script 10 scans every calendar date in each Olympic Ranking window for both genders using a minimal two-field request. It is checkpointed and resumable.

Scan windows:

| GamesYear | Scan start | Scan end |
|---:|---|---|
| 2012 | 2011-01-01 | 2012-06-18 |
| 2016 | 2015-01-01 | 2016-06-12 |
| 2020 | 2018-09-01 | 2021-06-14 |
| 2024 | 2023-01-01 | 2024-06-10 |

Outputs:

```text
data/olympic_discovery/olympic_reference_date_scan.csv
data/olympic_discovery/olympic_reference_dates.csv
data/olympic_discovery/olympic_reference_date_summary.csv
```

The next step after discovery is to request the full Olympic field set for every discovered date/gender combination and preserve the raw XML plus parsed archive.

---

## Analysis convention once Olympic data is archived

Treat four ranking products as distinct:

1. FIVB Athlete / Player ranking
2. FIVB Team / PlayerSum ranking
3. FIVB World / team-results ranking, using the validated historical-era rules documented elsewhere in this repo
4. Olympic Selection Ranking

The Olympic ranking should be used only within the qualification window for its corresponding GamesYear. It is a temporary quad-specific qualification measure, not a permanent substitute for World or Team ranking.

For matched dates, useful comparisons include:

- Olympic rank vs World rank;
- Olympic rank vs Team rank;
- points differences;
- teams appearing in one product but not another;
- country-quota exclusions;
- tournament-participation eligibility;
- teams already qualified through another pathway;
- how Olympic and World rankings converge or diverge near qualification deadlines.
