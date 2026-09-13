-- ============================================================
-- 01_data_validation.sql
-- Project: Purchase-to-Pay Process Mining & Exception Intelligence
-- Database: PostgreSQL
-- Purpose:
--   1. Define a raw staging table for the converted BPI 2019 CSV
--   2. Validate row counts, case grain, activities, nulls, dates
--   3. Identify potential duplicate-looking events
--
-- IMPORTANT:
--   Do not delete, deduplicate, or correct source records in this file.
--   This script is for source validation only.
-- ============================================================

CREATE SCHEMA IF NOT EXISTS p2p;

DROP TABLE IF EXISTS p2p.p2p_events_raw;

CREATE TABLE p2p.p2p_events_raw (
    user_id                         TEXT,
    org_resource                    TEXT,
    activity                        TEXT,
    cumulative_net_worth_eur        NUMERIC,
    event_timestamp                 TIMESTAMPTZ,
    spend_area                      TEXT,
    company                         TEXT,
    document_type                   TEXT,
    sub_spend_area                  TEXT,
    purchasing_document             TEXT,
    purchasing_document_category    TEXT,
    vendor                          TEXT,
    item_type                       TEXT,
    item_category                   TEXT,
    spend_classification            TEXT,
    source_system                   TEXT,
    case_name                       TEXT,
    gr_based_invoice_verification   TEXT,
    item                            TEXT,
    case_id                         TEXT,
    goods_receipt                   TEXT
);

-- ============================================================
-- LOAD NOTE
-- ============================================================
-- Load output.csv into p2p.p2p_events_raw using pgAdmin Import/Export
-- or PostgreSQL COPY.
--
-- CSV column order must match the CREATE TABLE order above.
--
-- Expected source baseline:
--   Event rows              : 1,595,923
--   Unique cases            :   251,734
--   Purchasing documents    :    76,349
--   Vendors                 :     1,975
--   Activities              :        42
--   Companies               :         4
-- ============================================================


-- ============================================================
-- 1. SOURCE BASELINE
-- ============================================================

SELECT
    COUNT(*) AS event_rows,
    COUNT(DISTINCT case_id) AS unique_cases,
    COUNT(DISTINCT purchasing_document) AS purchasing_documents,
    COUNT(DISTINCT vendor) AS vendors,
    COUNT(DISTINCT activity) AS activities,
    COUNT(DISTINCT company) AS companies
FROM p2p.p2p_events_raw;


-- ============================================================
-- 2. EVENT-LEVEL VS CASE-LEVEL GRAIN
-- ============================================================

SELECT
    case_id,
    COUNT(*) AS event_count
FROM p2p.p2p_events_raw
GROUP BY case_id
ORDER BY event_count DESC
LIMIT 20;


-- Distribution of events per case.
WITH events_per_case AS (
    SELECT
        case_id,
        COUNT(*) AS event_count
    FROM p2p.p2p_events_raw
    GROUP BY case_id
)
SELECT
    MIN(event_count) AS min_events,
    ROUND(AVG(event_count), 2) AS avg_events,
    PERCENTILE_CONT(0.50) WITHIN GROUP (ORDER BY event_count) AS median_events,
    PERCENTILE_CONT(0.90) WITHIN GROUP (ORDER BY event_count) AS p90_events,
    PERCENTILE_CONT(0.95) WITHIN GROUP (ORDER BY event_count) AS p95_events,
    PERCENTILE_CONT(0.99) WITHIN GROUP (ORDER BY event_count) AS p99_events,
    MAX(event_count) AS max_events
FROM events_per_case;


-- ============================================================
-- 3. ACTIVITY INVENTORY
-- ============================================================

SELECT
    activity,
    COUNT(*) AS event_count,
    COUNT(DISTINCT case_id) AS case_count,
    ROUND(
        100.0 * COUNT(*) / SUM(COUNT(*)) OVER (),
        2
    ) AS event_share_pct,
    ROUND(
        100.0 * COUNT(DISTINCT case_id)
        / (SELECT COUNT(DISTINCT case_id) FROM p2p.p2p_events_raw),
        2
    ) AS case_share_pct
FROM p2p.p2p_events_raw
GROUP BY activity
ORDER BY event_count DESC;


-- ============================================================
-- 4. NULL PROFILE
-- ============================================================

SELECT
    COUNT(*) AS total_rows,

    COUNT(*) FILTER (WHERE user_id IS NULL) AS user_id_nulls,
    COUNT(*) FILTER (WHERE org_resource IS NULL) AS org_resource_nulls,
    COUNT(*) FILTER (WHERE activity IS NULL) AS activity_nulls,
    COUNT(*) FILTER (WHERE cumulative_net_worth_eur IS NULL) AS value_nulls,
    COUNT(*) FILTER (WHERE event_timestamp IS NULL) AS timestamp_nulls,
    COUNT(*) FILTER (WHERE spend_area IS NULL) AS spend_area_nulls,
    COUNT(*) FILTER (WHERE company IS NULL) AS company_nulls,
    COUNT(*) FILTER (WHERE document_type IS NULL) AS document_type_nulls,
    COUNT(*) FILTER (WHERE sub_spend_area IS NULL) AS sub_spend_area_nulls,
    COUNT(*) FILTER (WHERE purchasing_document IS NULL) AS purchasing_document_nulls,
    COUNT(*) FILTER (WHERE purchasing_document_category IS NULL) AS purchasing_category_nulls,
    COUNT(*) FILTER (WHERE vendor IS NULL) AS vendor_nulls,
    COUNT(*) FILTER (WHERE item_type IS NULL) AS item_type_nulls,
    COUNT(*) FILTER (WHERE item_category IS NULL) AS item_category_nulls,
    COUNT(*) FILTER (WHERE spend_classification IS NULL) AS spend_classification_nulls,
    COUNT(*) FILTER (WHERE source_system IS NULL) AS source_system_nulls,
    COUNT(*) FILTER (WHERE case_name IS NULL) AS case_name_nulls,
    COUNT(*) FILTER (WHERE gr_based_invoice_verification IS NULL) AS gr_based_inv_nulls,
    COUNT(*) FILTER (WHERE item IS NULL) AS item_nulls,
    COUNT(*) FILTER (WHERE case_id IS NULL) AS case_id_nulls,
    COUNT(*) FILTER (WHERE goods_receipt IS NULL) AS goods_receipt_nulls
FROM p2p.p2p_events_raw;


-- ============================================================
-- 5. TIMESTAMP VALIDATION
-- ============================================================

SELECT
    MIN(event_timestamp) AS min_timestamp,
    MAX(event_timestamp) AS max_timestamp
FROM p2p.p2p_events_raw;


SELECT
    EXTRACT(YEAR FROM event_timestamp)::INT AS event_year,
    COUNT(*) AS event_count,
    COUNT(DISTINCT case_id) AS case_count
FROM p2p.p2p_events_raw
GROUP BY EXTRACT(YEAR FROM event_timestamp)
ORDER BY event_year;


-- Historical timestamp review.
SELECT
    case_id,
    activity,
    event_timestamp,
    vendor,
    purchasing_document
FROM p2p.p2p_events_raw
WHERE event_timestamp < TIMESTAMPTZ '2016-01-01'
ORDER BY event_timestamp
LIMIT 200;


-- ============================================================
-- 6. DUPLICATE-LOOKING ROWS
-- ============================================================
-- These rows are NOT automatically removed.
-- Repeated business events can legitimately have identical
-- visible attributes.

WITH duplicate_groups AS (
    SELECT
        user_id,
        org_resource,
        activity,
        cumulative_net_worth_eur,
        event_timestamp,
        spend_area,
        company,
        document_type,
        sub_spend_area,
        purchasing_document,
        purchasing_document_category,
        vendor,
        item_type,
        item_category,
        spend_classification,
        source_system,
        case_name,
        gr_based_invoice_verification,
        item,
        case_id,
        goods_receipt,
        COUNT(*) AS duplicate_count
    FROM p2p.p2p_events_raw
    GROUP BY
        user_id,
        org_resource,
        activity,
        cumulative_net_worth_eur,
        event_timestamp,
        spend_area,
        company,
        document_type,
        sub_spend_area,
        purchasing_document,
        purchasing_document_category,
        vendor,
        item_type,
        item_category,
        spend_classification,
        source_system,
        case_name,
        gr_based_invoice_verification,
        item,
        case_id,
        goods_receipt
    HAVING COUNT(*) > 1
)
SELECT
    COUNT(*) AS duplicate_groups,
    SUM(duplicate_count - 1) AS extra_duplicate_looking_rows
FROM duplicate_groups;


-- Activities most represented among duplicate-looking groups.
WITH duplicate_groups AS (
    SELECT
        activity,
        case_id,
        event_timestamp,
        org_resource,
        purchasing_document,
        item,
        COUNT(*) AS duplicate_count
    FROM p2p.p2p_events_raw
    GROUP BY
        activity,
        case_id,
        event_timestamp,
        org_resource,
        purchasing_document,
        item
    HAVING COUNT(*) > 1
)
SELECT
    activity,
    COUNT(*) AS duplicate_groups,
    SUM(duplicate_count - 1) AS extra_rows
FROM duplicate_groups
GROUP BY activity
ORDER BY extra_rows DESC;


-- ============================================================
-- 7. USER VS RESOURCE VALIDATION
-- ============================================================

SELECT
    COUNT(*) AS total_rows,
    COUNT(*) FILTER (WHERE user_id = org_resource) AS matching_rows,
    COUNT(*) FILTER (
        WHERE user_id IS DISTINCT FROM org_resource
    ) AS non_matching_rows,
    ROUND(
        100.0 * COUNT(*) FILTER (WHERE user_id = org_resource)
        / NULLIF(COUNT(*), 0),
        4
    ) AS matching_pct
FROM p2p.p2p_events_raw;


-- ============================================================
-- 8. CONSTANT / LOW-CARDINALITY FIELDS
-- ============================================================

SELECT
    COUNT(DISTINCT company) AS company_values,
    COUNT(DISTINCT purchasing_document_category) AS purchasing_category_values,
    COUNT(DISTINCT source_system) AS source_system_values,
    COUNT(DISTINCT item_category) AS item_category_values,
    COUNT(DISTINCT document_type) AS document_type_values,
    COUNT(DISTINCT gr_based_invoice_verification) AS gr_verification_values,
    COUNT(DISTINCT goods_receipt) AS goods_receipt_values
FROM p2p.p2p_events_raw;


-- ============================================================
-- 9. CASE-ATTRIBUTE CONSISTENCY
-- ============================================================

WITH case_checks AS (
    SELECT
        case_id,
        COUNT(DISTINCT vendor) AS vendor_values,
        COUNT(DISTINCT company) AS company_values,
        COUNT(DISTINCT purchasing_document) AS purchasing_document_values,
        COUNT(DISTINCT document_type) AS document_type_values,
        COUNT(DISTINCT item_type) AS item_type_values,
        COUNT(DISTINCT item_category) AS item_category_values,
        COUNT(DISTINCT spend_area) AS spend_area_values,
        COUNT(DISTINCT sub_spend_area) AS sub_spend_area_values,
        COUNT(DISTINCT spend_classification) AS spend_classification_values,
        COUNT(DISTINCT gr_based_invoice_verification) AS gr_verification_values,
        COUNT(DISTINCT goods_receipt) AS goods_receipt_values
    FROM p2p.p2p_events_raw
    GROUP BY case_id
)
SELECT
    COUNT(*) FILTER (WHERE vendor_values > 1) AS cases_with_multiple_vendors,
    COUNT(*) FILTER (WHERE company_values > 1) AS cases_with_multiple_companies,
    COUNT(*) FILTER (WHERE purchasing_document_values > 1) AS cases_with_multiple_documents,
    COUNT(*) FILTER (WHERE document_type_values > 1) AS cases_with_multiple_document_types,
    COUNT(*) FILTER (WHERE item_type_values > 1) AS cases_with_multiple_item_types,
    COUNT(*) FILTER (WHERE item_category_values > 1) AS cases_with_multiple_item_categories,
    COUNT(*) FILTER (WHERE spend_area_values > 1) AS cases_with_multiple_spend_areas,
    COUNT(*) FILTER (WHERE sub_spend_area_values > 1) AS cases_with_multiple_sub_spend_areas,
    COUNT(*) FILTER (WHERE spend_classification_values > 1) AS cases_with_multiple_spend_classes,
    COUNT(*) FILTER (WHERE gr_verification_values > 1) AS cases_with_multiple_gr_flags,
    COUNT(*) FILTER (WHERE goods_receipt_values > 1) AS cases_with_multiple_gr_values
FROM case_checks;


-- ============================================================
-- 10. MONETARY FIELD CONSISTENCY
-- ============================================================

WITH value_check AS (
    SELECT
        case_id,
        COUNT(DISTINCT cumulative_net_worth_eur) AS distinct_values,
        MIN(cumulative_net_worth_eur) AS min_value,
        MAX(cumulative_net_worth_eur) AS max_value
    FROM p2p.p2p_events_raw
    GROUP BY case_id
)
SELECT
    COUNT(*) AS total_cases,
    COUNT(*) FILTER (WHERE distinct_values > 1) AS cases_with_changing_value,
    ROUND(
        100.0 * COUNT(*) FILTER (WHERE distinct_values > 1)
        / NULLIF(COUNT(*), 0),
        2
    ) AS changing_value_case_pct
FROM value_check;


-- Inspect examples where value changes during a case.
WITH changing_cases AS (
    SELECT case_id
    FROM p2p.p2p_events_raw
    GROUP BY case_id
    HAVING COUNT(DISTINCT cumulative_net_worth_eur) > 1
)
SELECT
    e.case_id,
    e.event_timestamp,
    e.activity,
    e.cumulative_net_worth_eur
FROM p2p.p2p_events_raw e
JOIN changing_cases c
    ON e.case_id = c.case_id
ORDER BY e.case_id, e.event_timestamp
LIMIT 200;


-- ============================================================
-- 11. PROCESS-CATEGORY DISTRIBUTION
-- ============================================================

SELECT
    item_category,
    COUNT(DISTINCT case_id) AS cases,
    ROUND(
        100.0 * COUNT(DISTINCT case_id)
        / (SELECT COUNT(DISTINCT case_id) FROM p2p.p2p_events_raw),
        2
    ) AS case_share_pct
FROM p2p.p2p_events_raw
GROUP BY item_category
ORDER BY cases DESC;


-- ============================================================
-- END OF SOURCE VALIDATION
-- ============================================================
-- Do not modify the raw staging table.
-- The next script, 02_case_level_model.sql, will transform this
-- validated event log into one row per P2P case.
-- ============================================================
