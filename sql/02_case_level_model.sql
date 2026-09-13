-- ============================================================
-- 02_case_level_model.sql
-- Project: Purchase-to-Pay Process Mining & Exception Intelligence
-- Database: PostgreSQL
-- Purpose:
--   Transform the validated raw event log into one row per P2P case.
--
-- Source:
--   p2p.p2p_events_raw
--
-- Output:
--   p2p.p2p_case_level
--
-- IMPORTANT:
--   This script does not modify the raw source table.
-- ============================================================


-- ============================================================
-- 1. DROP / REBUILD CASE-LEVEL TABLE
-- ============================================================

DROP TABLE IF EXISTS p2p.p2p_case_level;


-- ============================================================
-- 2. BUILD EVENT ORDER AND EVENT-LEVEL FLAGS
-- ============================================================

CREATE TABLE p2p.p2p_case_level AS

WITH ordered_events AS (

    SELECT
        e.*,

        ROW_NUMBER() OVER (
            PARTITION BY case_id
            ORDER BY event_timestamp, ctid
        ) AS event_sequence,

        LAG(activity) OVER (
            PARTITION BY case_id
            ORDER BY event_timestamp, ctid
        ) AS previous_activity,

        LAG(org_resource) OVER (
            PARTITION BY case_id
            ORDER BY event_timestamp, ctid
        ) AS previous_resource

    FROM p2p.p2p_events_raw e
),

event_flags AS (

    SELECT
        *,

        -- ----------------------------------------------------
        -- Resource handoff
        -- ----------------------------------------------------
        CASE
            WHEN previous_resource IS NOT NULL
             AND org_resource IS NOT NULL
             AND previous_resource <> org_resource
            THEN 1
            ELSE 0
        END AS resource_handoff_flag,


        -- ----------------------------------------------------
        -- Purchase Order modification
        -- ----------------------------------------------------
        CASE
            WHEN activity IN (
                'Change Quantity',
                'Change Price',
                'Change Approval for Purchase Order',
                'Change Delivery Indicator',
                'Change Storage Location',
                'Change Currency',
                'Change payment term'
            )
            THEN 1
            ELSE 0
        END AS po_modification_event,


        -- ----------------------------------------------------
        -- Purchase Order intervention
        -- ----------------------------------------------------
        CASE
            WHEN activity IN (
                'Delete Purchase Order Item',
                'Block Purchase Order Item',
                'Reactivate Purchase Order Item'
            )
            THEN 1
            ELSE 0
        END AS po_intervention_event,


        -- ----------------------------------------------------
        -- Invoice reversal
        -- ----------------------------------------------------
        CASE
            WHEN activity = 'Cancel Invoice Receipt'
            THEN 1
            ELSE 0
        END AS invoice_reversal_event,


        -- ----------------------------------------------------
        -- Goods Receipt reversal
        -- ----------------------------------------------------
        CASE
            WHEN activity = 'Cancel Goods Receipt'
            THEN 1
            ELSE 0
        END AS gr_reversal_event,


        -- ----------------------------------------------------
        -- Payment block handling
        -- ----------------------------------------------------
        CASE
            WHEN activity = 'Set Payment Block'
            THEN 1
            ELSE 0
        END AS payment_block_set_event,

        CASE
            WHEN activity = 'Remove Payment Block'
            THEN 1
            ELSE 0
        END AS payment_block_remove_event,


        -- ----------------------------------------------------
        -- Invoice clearing
        -- ----------------------------------------------------
        CASE
            WHEN activity = 'Clear Invoice'
            THEN 1
            ELSE 0
        END AS invoice_clear_event,


        -- ----------------------------------------------------
        -- Historical timestamp review flag
        -- ----------------------------------------------------
        CASE
            WHEN event_timestamp < TIMESTAMPTZ '2016-01-01'
            THEN 1
            ELSE 0
        END AS historical_timestamp_event

    FROM ordered_events
),


-- ============================================================
-- 3. PROCESS VARIANT STRING PER CASE
-- ============================================================

variant_sequences AS (

    SELECT
        case_id,

        STRING_AGG(
            activity,
            ' -> '
            ORDER BY event_timestamp, event_sequence
        ) AS process_variant

    FROM event_flags

    GROUP BY case_id
),


-- ============================================================
-- 4. AGGREGATE TO ONE ROW PER CASE
-- ============================================================

case_aggregation AS (

    SELECT
        case_id,

        -- ----------------------------------------------------
        -- Case attributes
        -- ----------------------------------------------------
        MIN(vendor) AS vendor,
        MIN(company) AS company,
        MIN(spend_area) AS spend_area,
        MIN(sub_spend_area) AS sub_spend_area,
        MIN(spend_classification) AS spend_classification,
        MIN(purchasing_document) AS purchasing_document,
        MIN(document_type) AS document_type,
        MIN(item_type) AS item_type,
        MIN(item_category) AS item_category,
        MIN(gr_based_invoice_verification)
            AS gr_based_invoice_verification,
        MIN(goods_receipt) AS goods_receipt,


        -- ----------------------------------------------------
        -- Case timestamps
        -- ----------------------------------------------------
        MIN(event_timestamp) AS case_start,
        MAX(event_timestamp) AS case_end,


        -- ----------------------------------------------------
        -- Event / complexity metrics
        -- ----------------------------------------------------
        COUNT(*) AS event_count,

        COUNT(DISTINCT activity)
            AS unique_activity_count,

        COUNT(DISTINCT org_resource)
            AS unique_resource_count,

        SUM(resource_handoff_flag)
            AS resource_handoff_count,


        -- ----------------------------------------------------
        -- Explicit exception / intervention event counts
        -- ----------------------------------------------------
        SUM(po_modification_event)
            AS po_modification_count,

        SUM(po_intervention_event)
            AS po_intervention_count,

        SUM(invoice_reversal_event)
            AS invoice_reversal_count,

        SUM(gr_reversal_event)
            AS gr_reversal_count,

        SUM(payment_block_set_event)
            AS payment_block_set_count,

        SUM(payment_block_remove_event)
            AS payment_block_remove_count,

        SUM(invoice_clear_event)
            AS invoice_clear_count,


        -- ----------------------------------------------------
        -- Historical timestamp flag
        -- ----------------------------------------------------
        MAX(historical_timestamp_event)
            AS timestamp_anomaly_flag

    FROM event_flags

    GROUP BY case_id
),


-- ============================================================
-- 5. ATTACH VARIANT FREQUENCY
-- ============================================================

case_with_variant AS (

    SELECT
        c.*,
        v.process_variant

    FROM case_aggregation c

    LEFT JOIN variant_sequences v
        ON c.case_id = v.case_id
),

variant_frequency AS (

    SELECT
        process_variant,
        COUNT(*) AS variant_case_count

    FROM case_with_variant

    GROUP BY process_variant
),


-- ============================================================
-- 6. FINAL CASE MODEL
-- ============================================================

final_model AS (

    SELECT
        c.case_id,

        c.vendor,
        c.company,
        c.spend_area,
        c.sub_spend_area,
        c.spend_classification,
        c.purchasing_document,
        c.document_type,
        c.item_type,
        c.item_category,
        c.gr_based_invoice_verification,
        c.goods_receipt,

        c.case_start,
        c.case_end,

        EXTRACT(
            EPOCH FROM (c.case_end - c.case_start)
        ) / 86400.0
            AS cycle_time_days_raw,

        c.event_count,
        c.unique_activity_count,
        c.unique_resource_count,
        c.resource_handoff_count,

        (c.event_count - c.unique_activity_count)
            AS repeated_activity_count,

        CASE
            WHEN c.event_count > c.unique_activity_count
            THEN 1
            ELSE 0
        END AS repeated_activity_flag,


        -- ----------------------------------------------------
        -- PO modification
        -- ----------------------------------------------------
        c.po_modification_count,

        CASE
            WHEN c.po_modification_count > 0
            THEN 1
            ELSE 0
        END AS po_modification_flag,


        -- ----------------------------------------------------
        -- PO intervention
        -- ----------------------------------------------------
        c.po_intervention_count,

        CASE
            WHEN c.po_intervention_count > 0
            THEN 1
            ELSE 0
        END AS po_intervention_flag,


        -- ----------------------------------------------------
        -- Invoice reversal
        -- ----------------------------------------------------
        c.invoice_reversal_count,

        CASE
            WHEN c.invoice_reversal_count > 0
            THEN 1
            ELSE 0
        END AS invoice_reversal_flag,


        -- ----------------------------------------------------
        -- GR reversal
        -- ----------------------------------------------------
        c.gr_reversal_count,

        CASE
            WHEN c.gr_reversal_count > 0
            THEN 1
            ELSE 0
        END AS gr_reversal_flag,


        -- ----------------------------------------------------
        -- Payment block handling
        -- ----------------------------------------------------
        c.payment_block_set_count,

        CASE
            WHEN c.payment_block_set_count > 0
            THEN 1
            ELSE 0
        END AS payment_block_set_flag,

        c.payment_block_remove_count,

        CASE
            WHEN c.payment_block_remove_count > 0
            THEN 1
            ELSE 0
        END AS payment_block_remove_flag,

        CASE
            WHEN c.payment_block_set_count > 0
              OR c.payment_block_remove_count > 0
            THEN 1
            ELSE 0
        END AS payment_block_handling_flag,


        -- ----------------------------------------------------
        -- Invoice clearing
        -- ----------------------------------------------------
        c.invoice_clear_count,

        CASE
            WHEN c.invoice_clear_count > 0
            THEN 1
            ELSE 0
        END AS invoice_cleared_flag,


        -- ----------------------------------------------------
        -- Process variant
        -- ----------------------------------------------------
        c.process_variant,

        vf.variant_case_count,

        ROUND(
            100.0 * vf.variant_case_count
            / SUM(vf.variant_case_count) OVER (),
            4
        ) AS variant_case_share_pct,


        -- ----------------------------------------------------
        -- Timestamp anomaly
        -- ----------------------------------------------------
        c.timestamp_anomaly_flag

    FROM case_with_variant c

    LEFT JOIN variant_frequency vf
        ON c.process_variant = vf.process_variant
)

SELECT *
FROM final_model;



-- ============================================================
-- 7. CREATE INDEXES
-- ============================================================

CREATE UNIQUE INDEX IF NOT EXISTS idx_p2p_case_id
ON p2p.p2p_case_level(case_id);

CREATE INDEX IF NOT EXISTS idx_p2p_case_vendor
ON p2p.p2p_case_level(vendor);

CREATE INDEX IF NOT EXISTS idx_p2p_case_item_category
ON p2p.p2p_case_level(item_category);

CREATE INDEX IF NOT EXISTS idx_p2p_case_document_type
ON p2p.p2p_case_level(document_type);

CREATE INDEX IF NOT EXISTS idx_p2p_case_spend_area
ON p2p.p2p_case_level(spend_area);

CREATE INDEX IF NOT EXISTS idx_p2p_case_variant
ON p2p.p2p_case_level(process_variant);



-- ============================================================
-- 8. MODEL VALIDATION
-- ============================================================

-- Expected:
-- source_unique_cases = model_rows = model_unique_cases
-- approximately 251,734.

SELECT
    (SELECT COUNT(DISTINCT case_id)
     FROM p2p.p2p_events_raw)
        AS source_unique_cases,

    COUNT(*)
        AS case_model_rows,

    COUNT(DISTINCT case_id)
        AS case_model_unique_cases

FROM p2p.p2p_case_level;



-- Duplicate case IDs should be zero.

SELECT
    case_id,
    COUNT(*) AS row_count
FROM p2p.p2p_case_level
GROUP BY case_id
HAVING COUNT(*) > 1;



-- ============================================================
-- 9. HIGH-LEVEL CASE MODEL PROFILE
-- ============================================================

SELECT
    COUNT(*) AS total_cases,

    ROUND(
        PERCENTILE_CONT(0.50)
        WITHIN GROUP (ORDER BY cycle_time_days_raw)::NUMERIC,
        2
    ) AS median_cycle_days,

    ROUND(
        PERCENTILE_CONT(0.90)
        WITHIN GROUP (ORDER BY cycle_time_days_raw)::NUMERIC,
        2
    ) AS p90_cycle_days,

    ROUND(
        AVG(event_count),
        2
    ) AS avg_events_per_case,

    ROUND(
        AVG(resource_handoff_count),
        2
    ) AS avg_resource_handoffs

FROM p2p.p2p_case_level

WHERE timestamp_anomaly_flag = 0;



-- ============================================================
-- 10. CASE-LEVEL EXCEPTION PREVALENCE
-- ============================================================

SELECT

    COUNT(*) AS total_cases,


    -- PO modification
    SUM(po_modification_flag)
        AS po_modification_cases,

    ROUND(
        100.0 * SUM(po_modification_flag)
        / COUNT(*),
        2
    ) AS po_modification_rate_pct,


    -- Invoice reversal
    SUM(invoice_reversal_flag)
        AS invoice_reversal_cases,

    ROUND(
        100.0 * SUM(invoice_reversal_flag)
        / COUNT(*),
        2
    ) AS invoice_reversal_rate_pct,


    -- GR reversal
    SUM(gr_reversal_flag)
        AS gr_reversal_cases,

    ROUND(
        100.0 * SUM(gr_reversal_flag)
        / COUNT(*),
        2
    ) AS gr_reversal_rate_pct,


    -- Payment block handling
    SUM(payment_block_handling_flag)
        AS payment_block_handling_cases,

    ROUND(
        100.0 * SUM(payment_block_handling_flag)
        / COUNT(*),
        2
    ) AS payment_block_handling_rate_pct,


    -- Repeated activity
    SUM(repeated_activity_flag)
        AS repeated_activity_cases,

    ROUND(
        100.0 * SUM(repeated_activity_flag)
        / COUNT(*),
        2
    ) AS repeated_activity_rate_pct,


    -- Invoice cleared
    SUM(invoice_cleared_flag)
        AS invoice_cleared_cases,

    ROUND(
        100.0 * SUM(invoice_cleared_flag)
        / COUNT(*),
        2
    ) AS invoice_cleared_rate_pct

FROM p2p.p2p_case_level;



-- ============================================================
-- 11. PROCESS VARIANT SUMMARY
-- ============================================================

SELECT
    COUNT(DISTINCT process_variant)
        AS unique_process_variants,

    MAX(variant_case_count)
        AS largest_variant_cases

FROM p2p.p2p_case_level;



-- Top process variants.

SELECT DISTINCT
    process_variant,
    variant_case_count,
    variant_case_share_pct

FROM p2p.p2p_case_level

ORDER BY variant_case_count DESC

LIMIT 20;



-- ============================================================
-- 12. PROCESS CATEGORY SUMMARY
-- ============================================================

SELECT
    item_category,

    COUNT(*) AS cases,

    ROUND(
        PERCENTILE_CONT(0.50)
        WITHIN GROUP (ORDER BY cycle_time_days_raw)::NUMERIC,
        2
    ) AS median_cycle_days,

    ROUND(
        100.0 * AVG(po_modification_flag),
        2
    ) AS po_modification_rate_pct,

    ROUND(
        100.0 * AVG(invoice_reversal_flag),
        2
    ) AS invoice_reversal_rate_pct,

    ROUND(
        100.0 * AVG(gr_reversal_flag),
        2
    ) AS gr_reversal_rate_pct,

    ROUND(
        100.0 * AVG(payment_block_handling_flag),
        2
    ) AS payment_block_handling_rate_pct

FROM p2p.p2p_case_level

WHERE timestamp_anomaly_flag = 0

GROUP BY item_category

ORDER BY cases DESC;



-- ============================================================
-- END OF CASE MODEL
-- ============================================================
-- The next script:
--
--   03_exception_analysis.sql
--
-- will use this table to analyze:
--   - PO rework
--   - invoice reversal
--   - goods receipt reversal
--   - payment block handling
--   - repeated activities
--   - long-cycle cases
--   - resource handoffs
-- ============================================================
