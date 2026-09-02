# Olympic Ranking History and Relationship to VIS Rankings

This note documents how FIVB Beach Volleyball Olympic qualification rankings have been constructed across recent Olympic cycles, and how they relate to the ranking products exposed by the VIS API.

## Main conclusion

The **Olympic Ranking is a separate ranking product** from the ordinary FIVB World, Team, and Athlete rankings.

It generally uses the same underlying FIVB ranking points earned at eligible tournaments, but applies Olympic-specific rules such as:

- a fixed Olympic qualification window;
- a fixed number of best results counted;
- team-based eligibility requirements;
- event-eligibility rules;
- NOC/NF quota limits;
- Olympic-specific qualification cutoffs.

This is strongly reinforced by VIS itself, which exposes a separate request:

`GetBeachOlympicSelectionRanking`

rather than treating Olympic qualification as a subtype of `GetBeachRanking`.

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

This is direct evidence that the Olympic Ranking was not simply the ordinary World Ranking under a different name.

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

The key phrase is that the Olympic Ranking used **FIVB World Ranking points**, not that it was the FIVB World Ranking itself.

Conceptually:

```text
Tournament results
      ↓
FIVB ranking points
      ↓
      ├── ordinary FIVB ranking formula(s)
      └── Olympic Ranking formula
            - fixed Olympic window
            - best 12 team results
            - Olympic eligibility rules
```

This strongly suggests that the same point currency could feed multiple ranking products.

### Sources

- FIVB 2016 Beach Volleyball Sport Regulations: https://www.fivb.org/EN/BeachVolleyball/Document/FIVB_BVB_2016-Sport-Regulations_v10.pdf
- Rio 2016 qualification system: https://www.fivb.org/EN/BeachVolleyball/Document/FIVB_OG2016_Qualification_System_BVB_ENG.pdf

---

## Tokyo 2020 / held in 2021

### Olympic Ranking composition

The Tokyo qualification system again used each team's **12 best performances** during the Olympic qualification period.

Eligible results included major FIVB events such as the World Championships, World Tour events, and recognized Continental Tour Finals.

Because of the COVID-19 postponement, FIVB extended the Olympic Ranking qualification period through **June 13, 2021**, with the final ranking published on **June 14, 2021**.

The best-12-results structure remained unchanged.

### Olympic field pathways

Tokyo's Olympic field combined multiple qualification pathways, including:

- Olympic Ranking qualifiers;
- the Olympic Qualification Tournament;
- the 2019 World Champions;
- Continental Cup qualification;
- host allocation.

Again, this confirms that the Olympic Ranking was one component of the Olympic qualification architecture rather than a synonym for the general World Ranking.

### Sources

- Tokyo 2020 qualification system: https://www.fivb.org/EN/BeachVolleyball/Forms/Olympic_Qualification/Tokyo2020-Qualification-System-Beach-Volleyball_31.01.2019.pdf
- FIVB adaptation of Olympic qualification following the postponement: https://www.fivb.com/fivb-announces-adaptation-of-beach-volleyball-olympic-qualification/
- Tokyo draw / qualification pathways: https://www.fivb.com/draw-reveals-pools-for-tokyo-2020-beach-volleyball-tournament/

---

## Paris 2024

### Olympic Ranking composition

For Paris 2024, the Olympic Ranking was based on each team's **12 best performances as a team** from **January 1, 2023 through June 10, 2024**.

Seventeen teams per gender qualified through the Olympic Ranking pathway.

The rest of the 24-team Olympic field came through other qualification routes, including the World Championships, continental qualification, and the host quota.

### Contrast with the ordinary World Ranking

By this era, the distinction is especially clear.

The ordinary modern FIVB World Ranking is based on a **rolling 365-day period** and uses a smaller fixed number of best results.

The Olympic Ranking instead used:

```text
12 best team results
fixed Jan 1, 2023 → Jun 10, 2024 window
Olympic-specific eligibility and quota rules
```

Therefore, even when the same tournament points feed both rankings, the Olympic Ranking and World Ranking should not generally be expected to match numerically.

### Sources

- FIVB Paris 2024 qualification information: https://www.fivb.com/?p=66667
- FIVB teams qualified for Paris 2024: https://www.fivb.com/beach-volleyball-teams-qualified-for-paris-2024/
- FIVB Beach Volleyball Sport Operations Manual: https://www.fivb.com/wp-content/uploads/2024/05/2025_FIVB_BVB_Sport-Operations-Manual-Clean-March-11-2025.pdf

---

## VIS ranking products relevant to this project

The current VIS ranking archive we are collecting contains several distinct ranking products:

- **Type 6 / SubType 1 — FIVB Athlete**
- **Type 9 / SubType 3 — FIVB World**
- **Type 10 / SubType 2 — FIVB Team**

VIS also exposes a separate Olympic-specific request:

`GetBeachOlympicSelectionRanking`

The request supports fields including Olympic Games year, gender, and historical reference date.

This is the strongest technical evidence that Olympic qualification rankings should be treated as a separate archive rather than inferred from Type 6, Type 9, or Type 10.

### VIS sources

- Olympic Selection Ranking request: https://www.fivb.org/VisSDK/VisWebService/GetBeachOlympicSelectionRanking.html
- Beach ranking types: https://www.fivb.org/VisSDK/Fivb.Vis.Model/Fivb.Vis.Model~Fivb.Vis.Beach.BeachRankingType.html
- Beach ranking subtypes: https://www.fivb.org/VisSDK/Fivb.Vis.Model/Fivb.Vis.Model~Fivb.Vis.Beach.BeachRankingSubType.html
- VIS data types: https://www.fivb.org/VisSDK/VisWebService/DataType.html

---

## Working hypotheses for empirical validation

Our archive should treat the following as separate historical series until proven otherwise:

1. FIVB Athlete Ranking
2. FIVB Team Ranking
3. FIVB World Ranking
4. Olympic Selection Ranking

The Olympic Ranking may be highly correlated with Type 9 FIVB World rankings, especially near Olympic qualification cutoffs, but official qualification rules indicate that it should not automatically be assumed to be identical.

Type 10 is particularly unlikely to be identical to the Olympic Ranking because its subtype represents teams ranked from the sum of the two players' points, whereas Olympic qualification rules consistently emphasize results earned **as a team**.

---

## Proposed Olympic archive work

After the general ranking archive is complete, add a dedicated Olympic Selection Ranking archive for at least:

- London 2012
- Rio 2016
- Tokyo 2020
- Paris 2024

Initial final-snapshot dates to test:

| Games | VIS GamesYear | Final/reference date to test |
|---|---:|---|
| London 2012 | 2012 | 2012-06-18 |
| Rio 2016 | 2016 | 2016-06-13 |
| Tokyo 2020 | 2020 | 2021-06-14 |
| Paris 2024 | 2024 | 2024-06-10 |

For Tokyo, use `GamesYear="2020"` even though the Games were held in 2021.

If historical Olympic Selection snapshots are available, archive every distinct available reference date rather than only the final ranking.

---

## Comparison analyses to run once both archives exist

For matched dates, compare Olympic Selection Ranking against Types 6, 9, and 10 by player/team identifiers.

Useful diagnostics include:

- rank differences;
- points differences;
- Spearman rank correlation;
- teams appearing in one ranking but not another;
- effect of NOC quota limits;
- effect of fixed Olympic qualification windows;
- effect of best-12 rules versus the ordinary rolling World Ranking rules;
- whether World and Olympic rankings converge near qualification deadlines;
- whether historical changes in World Ranking methodology explain changes in Olympic Ranking behavior.

The goal is to empirically document exactly how the FIVB ranking ecosystem evolved across Olympic cycles rather than assuming that similarly named rankings were interchangeable.
