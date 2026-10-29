# Which Countries Should an Exporter or Investor Prioritise? A SQL Analysis of World Economic Classifications

**Business question:** Which country groups offer the strongest market size and purchasing power, and which common assumptions (G7 = richest, EU = richer because of the EU, fuel exports = wealth) do not hold up in the data?

## Key findings

| # | Finding | Evidence (2022 data) |
|---|---|---|
| 1 | Income is highly concentrated. | Top 7 by GDP per capita: Luxembourg ($127,046), Norway, Ireland, Switzerland, Qatar, Singapore, United States. |
| 2 | The "Advanced" vs "Emerging" gap is large, and the median is the better measure. | Advanced: avg $44,734, median $41,993 (45 countries). Emerging: avg $7,371, median $4,104 (126 countries). |
| 3 | EU members are far richer in PPP terms, but this is selection, not proof the EU causes wealth. | EU median $49,946 vs non-EU median $13,334 (PPP). Even the poorest EU member ($33,582) is above the non-EU median. |
| 4 | G7 is not the richest group per person. | Only the US is in the top 10 by GDP per capita (7th). Canada 13th, Germany 19th, UK 22nd, France 24th, Japan 27th, Italy 28th. |
| 5 | Fuel exports alone do not make a country richer per person. | Fuel exporters: median $6,510. Others: median $6,938. |
| 6 | PPP and nominal GDP can tell very different stories, and income explains most of the difference (see the root cause analysis below). | Largest positive gaps: Micronesia (+387%), Tajikistan (+364%), Laos (+349%). Negative: Israel (-14%), Barbados (-11%), Switzerland (-9.5%). |

## Root cause analysis: why does the PPP gap vary?

**Problem:** The gap between PPP and nominal GDP per capita ranges from -14% to +387% across 175 countries. A large positive gap means low local prices. What drives it?

| Hypothesis | Test | Result | Verdict |
|---|---|---|---|
| **H1 Income level** | Median gap by income quartile; correlation of log income with the gap | Poorest quartile +182%, then +166%, +126%, richest +34%. Correlation -0.67, R-squared 0.455 | **Supported.** Main driver. |
| **H2 Fuel exporter** | Median gap, then repeated within each income quartile | +134% vs +126% overall; no consistent pattern within quartiles | **Not a driver** |
| **H3 EU membership** | Median gap, then repeated within each income quartile | Looks lower overall (+68% vs +136%), but within Q3 and Q4 EU members are *higher* (+142% vs +114%, +52% vs +34%) | **Rejected.** The raw difference is an income effect. |

**Cause vs correlation:** EU membership appears linked to a low gap only because EU members are rich. Comparing countries *within the same income quartile* removes this confounder, and the EU effect disappears.

**Exceptions:** Countries with income above $15,000 and a gap above 60% (for example Poland, Hungary, Romania, Saudi Arabia, Bahrain, Russia) are not explained by income.

**Root cause:** The PPP gap is mainly a **price-level effect linked to income**. Lower-income countries have cheaper local goods and services. Income explains about 45% of the variation. Fuel exports and EU membership add almost nothing once income is controlled.

**Recommendation:** Use PPP to judge local-cost and price-sensitive markets, and nominal GDP to judge import value and revenue in dollars. Do not read a high PPP as high demand in dollars.

## Recommendation

1. **Use two measures, not one.** Nominal GDP per capita shows market size in dollars (import value, pricing power). PPP shows what local incomes can buy (locally produced and priced goods).
2. **Target by group, with the median.** Averages are pulled up by small rich economies such as Luxembourg and Ireland.
3. **Do not use G7, EU or fuel-exporter status as a shortcut for wealth.** Check the GDP figures directly.
4. **Treat large PPP gaps as low-price economies.** They suit local-cost production and price-sensitive goods, not premium positioning.

## Data

- **File:** `World_Economic_Classifications_v2.csv`, 205 countries, one row per country.
- **Columns:** country_name, un_class_2014, imf_class_2023, g7, eu_member, fuel_exp_country, wealth_rank, gdp_ppp_2022, gdp_pc_2022.
- **Cleaning (done in the SQL view `econ_clean`):**
  - `'N/A'` strings converted to NULL
  - `$` and `,` removed from GDP columns and cast to numbers
  - `Yes`/`No` flags converted to booleans
- **Coverage:** 176 countries have GDP per capita and 175 have PPP. Territories and some states (e.g. Taiwan, Cuba, Venezuela, Somalia) have no value and are excluded from GDP calculations.

## Limitations

- **Snapshot, not a trend:** one year (2022). It cannot show growth or causes.
- **Correlation is not explanation:** EU membership, G7 status, and fuel export status are associated with income but are not shown to cause it.
- **Small groups:** the IMF "Developing" class has 1 country, so its average is not meaningful.
- **`wealth_rank`** is a ranking of the same PPP measure, so it adds no independent information.
- **Mixed time labels:** the UN class is 2014 and the IMF class is 2023, so groupings may not match the 2022 GDP year exactly.

## How to run

1. Install [DuckDB](https://duckdb.org/) (CLI or the local UI).
2. Put `World_Economic_Classifications_v2.csv` in the same folder as `query1.sql`.
3. Run `query1.sql`. The first statement creates the `econ_clean` view and the rest are the analysis queries.

```bash
duckdb < query1.sql
```

## Folder structure

```
.
├── README.md
├── query1.sql
└── World_Economic_Classifications_v2.csv
```

## Query index

| Query | Purpose |
|---|---|
| 0 | Create the clean view and check data quality |
| 1 | Top 7 countries by GDP per capita |
| 2-3 | GDP per capita and PPP by IMF class |
| 4 | EU vs non-EU |
| 5 | Fuel exporters vs others |
| 6 | PPP vs nominal gap, largest and smallest |
| 7-8 | G7 vs the richest countries |
| 9 | Is `wealth_rank` just ranked PPP? |
| 10 | Country spot check |
| 11-16 | Root cause analysis of the PPP gap: income quartiles, correlation, EU and fuel checks within income groups, exceptions |

## Tools

SQL (DuckDB): CTEs, window functions (`RANK`, `ROW_NUMBER`), conditional aggregation, `MEDIAN`, `TRY_CAST`, views.
