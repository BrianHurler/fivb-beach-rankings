# Next steps

1. Run `scripts/02_inspect_ranking_774.R` locally and capture the raw VIS response shape.
2. Confirm the correct ranking-entry node structure and valid `EntriesFields` for Type 9 / SubType 3.
3. Update `R/ranking_parse.R` if needed based on the live response.
4. Validate one Type 6 and one Type 10 historical ranking as well.
5. Launch `scripts/03_download_archive.R` only after all three target series are validated.
6. Parse the complete archive and QA ranking counts against `archive_inventory`.
7. Determine the correct analytical predecessor to Type 9 FIVB World for the 2008-2014 era.
