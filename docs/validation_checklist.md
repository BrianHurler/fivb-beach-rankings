# Ranking response validation checklist

Before bulk downloading, validate one ranking from each target family:

- [ ] Type 9 / SubType 3 — FIVB World (`No = 774`, 2015-03-23 men)
- [ ] Type 6 / SubType 1 — FIVB Athlete
- [ ] Type 10 / SubType 2 — FIVB Team

For each response, confirm:

- root element and ranking-level attributes
- entry element structure
- presence of `Position`, `Rank`, player/team identifiers, federation, and points
- requested `EntriesFields` are accepted by VIS
- parser returns a non-empty tibble
- raw XML is preserved before any transformation
