-- =====================================================================
-- World Economic Classifications: GDP analysis (DuckDB)
-- Question: Which country groups should an exporter or investor prioritise?
-- Source: World_Economic_Classifications_v2.csv (205 countries, 2022 GDP)
-- Notes:
--   * Flag columns in the file are 'Yes'/'No' (not 'true'/'false').
--   * 'N/A' strings are converted to NULL; $ and , are stripped from GDP.
--   * 176 countries have GDP per capita, 175 have PPP. Others are NULL.
-- =====================================================================


-- 0. CLEAN VIEW ------------------------------------------------------
CREATE OR REPLACE VIEW econ_clean AS
SELECT
    country_name,
    NULLIF(un_class_2014, 'N/A')  AS un_class_2014,
    NULLIF(imf_class_2023, 'N/A') AS imf_class_2023,
    (g7 = 'Yes')                  AS g7,
    (eu_member = 'Yes')           AS eu_member,
    (fuel_exp_country = 'Yes')    AS fuel_exp_country,
    TRY_CAST(NULLIF(wealth_rank, 'N/A') AS INTEGER) AS wealth_rank,
    TRY_CAST(REPLACE(REPLACE(NULLIF(gdp_ppp_2022, 'N/A'), '$', ''), ',', '') AS DOUBLE) AS gdp_ppp_2022,
    TRY_CAST(REPLACE(REPLACE(NULLIF(gdp_pc_2022,  'N/A'), '$', ''), ',', '') AS DOUBLE) AS gdp_pc_2022
FROM read_csv('World_Economic_Classifications_v2.csv', header = true, all_varchar = true);


-- 0b. DATA QUALITY CHECK ---------------------------------------------
-- Expected: 205 rows, 205 distinct countries, 176 with GDP pc, 175 with PPP
SELECT COUNT(*)                     AS total_rows,
       COUNT(DISTINCT country_name) AS distinct_countries,
       COUNT(gdp_pc_2022)           AS with_gdp_pc,
       COUNT(gdp_ppp_2022)          AS with_gdp_ppp
FROM econ_clean;


-- 1. TOP 7 COUNTRIES BY GDP PER CAPITA (2022) ------------------------
SELECT country_name, gdp_pc_2022
FROM econ_clean
WHERE gdp_pc_2022 IS NOT NULL
ORDER BY gdp_pc_2022 DESC
LIMIT 7;


-- 2. GDP PER CAPITA BY IMF CLASSIFICATION (2023) ---------------------
-- Note: 'Developing' has only 1 country, so its average is not meaningful.
SELECT imf_class_2023,
       ROUND(AVG(gdp_pc_2022), 2)    AS avg_gdp_pc,
       ROUND(MEDIAN(gdp_pc_2022), 2) AS median_gdp_pc,
       COUNT(gdp_pc_2022)            AS num_of_countries
FROM econ_clean
WHERE imf_class_2023 IS NOT NULL
GROUP BY imf_class_2023
ORDER BY avg_gdp_pc DESC;


-- 3. GDP (PPP) BY IMF CLASSIFICATION (2023) --------------------------
SELECT imf_class_2023,
       ROUND(AVG(gdp_ppp_2022), 2)    AS avg_gdp_ppp,
       ROUND(MEDIAN(gdp_ppp_2022), 2) AS median_gdp_ppp,
       COUNT(gdp_ppp_2022)            AS num_of_countries
FROM econ_clean
WHERE imf_class_2023 IS NOT NULL
GROUP BY imf_class_2023
ORDER BY avg_gdp_ppp DESC;


-- 4. DO EU MEMBERS HAVE A STRONGER ECONOMY THAN NON-EU? (PPP) --------
-- Correlation != explanation: rich countries were more likely to join
-- the EU, so this gap is selection, not proof the EU causes wealth.
SELECT CASE WHEN eu_member THEN 'EU member' ELSE 'Non-EU' END AS eu_status,
       ROUND(AVG(gdp_ppp_2022), 2)    AS avg_gdp_ppp,
       ROUND(MEDIAN(gdp_ppp_2022), 2) AS median_gdp_ppp,
       ROUND(MAX(gdp_ppp_2022), 2)    AS max_gdp_ppp,
       ROUND(MIN(gdp_ppp_2022), 2)    AS min_gdp_ppp,
       COUNT(gdp_ppp_2022)            AS num_of_countries
FROM econ_clean
GROUP BY eu_member
ORDER BY avg_gdp_ppp DESC;


-- 5. DOES EXPORTING FUEL MAKE A COUNTRY RICHER PER PERSON? -----------
SELECT CASE WHEN fuel_exp_country THEN 'Fuel exporter' ELSE 'Other' END AS fuel_status,
       ROUND(AVG(gdp_pc_2022), 2)    AS avg_gdp_pc,
       ROUND(MEDIAN(gdp_pc_2022), 2) AS median_gdp_pc,
       COUNT(gdp_pc_2022)            AS num_of_countries
FROM econ_clean
GROUP BY fuel_exp_country
ORDER BY avg_gdp_pc DESC;


-- 6. PPP vs NOMINAL GAP: 10 LARGEST POSITIVE AND 10 LARGEST NEGATIVE --
-- Large positive gap = low local prices (typical of lower-income economies).
-- Negative gap = expensive economy.
WITH gap AS (
    SELECT country_name,
           gdp_ppp_2022,
           gdp_pc_2022,
           ROUND((gdp_ppp_2022 - gdp_pc_2022) / gdp_pc_2022 * 100, 2) AS gap_pct
    FROM econ_clean
    WHERE gdp_ppp_2022 IS NOT NULL
      AND gdp_pc_2022 > 0
)
SELECT 'Largest positive gap' AS group_label, * FROM (SELECT * FROM gap ORDER BY gap_pct DESC LIMIT 10)
UNION ALL
SELECT 'Largest negative gap' AS group_label, * FROM (SELECT * FROM gap ORDER BY gap_pct ASC LIMIT 10);


-- 7. ARE G7 COUNTRIES ACTUALLY THE RICHEST PER CAPITA? ---------------
WITH ranked AS (
    SELECT country_name,
           g7,
           gdp_pc_2022,
           RANK() OVER (ORDER BY gdp_pc_2022 DESC) AS world_rank
    FROM econ_clean
    WHERE gdp_pc_2022 IS NOT NULL
)
SELECT country_name, gdp_pc_2022, world_rank
FROM ranked
WHERE g7
ORDER BY world_rank;


-- 8. SIDE BY SIDE: TOP 7 RICHEST vs OFFICIAL G7 ----------------------
WITH ranked AS (
    SELECT country_name, g7,
           ROW_NUMBER() OVER (ORDER BY gdp_pc_2022 DESC) AS rn
    FROM econ_clean
    WHERE gdp_pc_2022 IS NOT NULL
),
top7 AS (SELECT country_name, rn FROM ranked WHERE rn <= 7),
g7s  AS (
    SELECT country_name, ROW_NUMBER() OVER (ORDER BY gdp_pc_2022 DESC) AS rn
    FROM econ_clean
    WHERE g7 AND gdp_pc_2022 IS NOT NULL
)
SELECT t.rn AS position,
       t.country_name AS top_7_wealthiest,
       g.country_name AS official_g7_by_wealth
FROM top7 t
LEFT JOIN g7s g ON g.rn = t.rn
ORDER BY t.rn;


-- 9. CHECK: IS wealth_rank JUST PPP RANKED? --------------------------
-- A value near -1 means wealth_rank adds no independent information.
WITH r AS (
    SELECT wealth_rank,
           RANK() OVER (ORDER BY gdp_ppp_2022 DESC) AS ppp_rank
    FROM econ_clean
    WHERE wealth_rank IS NOT NULL AND gdp_ppp_2022 IS NOT NULL
)
SELECT ROUND(CORR(wealth_rank, ppp_rank), 3) AS rank_correlation FROM r;
-- Expected: close to 1 (both are ranks of the same measure).


-- 10. COUNTRY SPOT CHECK (edit the name) -----------------------------
SELECT country_name, wealth_rank, gdp_ppp_2022, gdp_pc_2022,
       ROUND((gdp_ppp_2022 - gdp_pc_2022) / gdp_pc_2022 * 100, 1) AS gap_pct
FROM econ_clean
WHERE country_name ILIKE '%ethiopia%';


-- =====================================================================
-- ROOT CAUSE ANALYSIS: WHY DOES THE PPP-TO-NOMINAL GAP VARY?
-- Problem: the gap ranges from about -14% to +387% across 175 countries.
-- gap = (PPP - nominal) / nominal. A large positive gap = low local prices.
-- Hypotheses: H1 income level, H2 fuel exporter, H3 EU membership, H4 IMF class.
-- =====================================================================

-- Base table for the RCA queries
CREATE OR REPLACE VIEW gap_base AS
SELECT country_name, imf_class_2023, eu_member, fuel_exp_country,
       gdp_pc_2022, gdp_ppp_2022,
       (gdp_ppp_2022 - gdp_pc_2022) / gdp_pc_2022 * 100 AS gap_pct,
       NTILE(4) OVER (ORDER BY gdp_pc_2022)            AS income_quartile
FROM econ_clean
WHERE gdp_ppp_2022 IS NOT NULL AND gdp_pc_2022 > 0;


-- 11. H1 INCOME: gap by income quartile (1 = poorest, 4 = richest) ----
-- Expected: median gap falls from about +182% (Q1) to about +34% (Q4).
SELECT income_quartile,
       ROUND(MEDIAN(gap_pct), 1) AS median_gap_pct,
       COUNT(*)                  AS n
FROM gap_base
GROUP BY income_quartile
ORDER BY income_quartile;


-- 12. H1 INCOME: strength of the relationship -------------------------
-- Expected: correlation about -0.67, R-squared about 0.455, slope about -40.5
-- (each doubling of income cuts the gap by about 28 percentage points: -40.5 * ln 2).
SELECT ROUND(CORR(LN(gdp_pc_2022), gap_pct), 3)      AS corr_logincome_gap,
       ROUND(REGR_R2(gap_pct, LN(gdp_pc_2022)), 3)   AS r_squared,
       ROUND(REGR_SLOPE(gap_pct, LN(gdp_pc_2022)), 2) AS slope_per_log_unit
FROM gap_base;


-- 13. H2 / H3 / H4 RAW COMPARISONS (before controlling for income) ----
SELECT 'Fuel exporter' AS factor,
       CASE WHEN fuel_exp_country THEN 'Yes' ELSE 'No' END AS category,
       ROUND(MEDIAN(gap_pct), 1) AS median_gap_pct, COUNT(*) AS n
FROM gap_base GROUP BY fuel_exp_country
UNION ALL
SELECT 'EU member',
       CASE WHEN eu_member THEN 'Yes' ELSE 'No' END,
       ROUND(MEDIAN(gap_pct), 1), COUNT(*)
FROM gap_base GROUP BY eu_member
UNION ALL
SELECT 'IMF class', imf_class_2023,
       ROUND(MEDIAN(gap_pct), 1), COUNT(*)
FROM gap_base WHERE imf_class_2023 IS NOT NULL GROUP BY imf_class_2023
ORDER BY factor, category;
-- Expected: EU looks much lower (+68% vs +136%), but see query 14.


-- 14. CAUSE vs CORRELATION: EU effect WITHIN the same income quartile -
-- If the EU truly lowered the gap, EU members should be lower in every quartile.
-- Expected: EU members are NOT lower (Q3: +142% vs +114%, Q4: +52% vs +34%),
-- so the raw EU difference in query 13 is an income effect, not an EU effect.
-- (No EU members are in Q1 or Q2.)
SELECT income_quartile,
       CASE WHEN eu_member THEN 'EU' ELSE 'Non-EU' END AS eu_status,
       ROUND(MEDIAN(gap_pct), 1) AS median_gap_pct,
       COUNT(*)                  AS n
FROM gap_base
GROUP BY income_quartile, eu_member
ORDER BY income_quartile, eu_status;


-- 15. SAME CHECK FOR FUEL EXPORTERS ----------------------------------
-- Expected: no consistent pattern across quartiles, so fuel is not a driver.
SELECT income_quartile,
       CASE WHEN fuel_exp_country THEN 'Fuel exporter' ELSE 'Other' END AS fuel_status,
       ROUND(MEDIAN(gap_pct), 1) AS median_gap_pct,
       COUNT(*)                  AS n
FROM gap_base
GROUP BY income_quartile, fuel_exp_country
ORDER BY income_quartile, fuel_status;


-- 16. EXCEPTIONS: income above $15,000 but gap above 60% -------------
-- Income does not explain these. They need price, wage or exchange-rate data.
SELECT country_name, gdp_pc_2022, ROUND(gap_pct, 1) AS gap_pct
FROM gap_base
WHERE gdp_pc_2022 > 15000 AND gap_pct > 60
ORDER BY gap_pct DESC;


-- ROOT CAUSE (from the results above):
-- The PPP gap is mainly a price-level effect linked to income. Poorer countries
-- have cheaper local goods and services. Income alone explains about 45% of the
-- variation. Fuel exports and EU membership add almost nothing once income is
-- controlled. About half of the variation is unexplained; the dataset has no
-- price, wage or exchange-rate data.
