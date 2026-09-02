# VIS ranking archive discovery

Initial exploration of `GetBeachRankingList` found a large historical archive in the current VIS ranking store.

## Target series

The initial downloader preserves these FIVB series from 2008 onward:

| Type | SubType | Working label | Historical coverage observed |
|---:|---:|---|---|
| 6 | 1 | FIVB Athlete | 2008 onward |
| 9 | 3 | FIVB World | 2014-11-10 onward |
| 10 | 2 | FIVB Team | 2008 onward |

The combined initial archive queue contains 3,663 ranking snapshots across men and women.

## Known validation record

Ranking `No = 774` is the men's Type 9 / SubType 3 FIVB World ranking dated `2015-03-23`.

This record is used as the first response-shape validation case before the project launches the full resumable archive download.

## Current open question

The first exploratory parser incorrectly assumed a specific child element name for ranking entries. The project now inspects the raw response and identifies candidate entry nodes by their `Position` attribute before bulk acquisition is enabled.
