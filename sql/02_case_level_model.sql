-- ============================================================
-- 02_case_level_model.sql
-- Project: Purchase-to-Pay Process Mining & Exception Intelligence
-- Database: MySQL 8.0+
-- Purpose:
--   Convert the validated event log into one row per P2P case.
--
-- Source: p2p_events_raw
-- Output: p2p_case_level
-- ============================================================

USE p2p;

-- Process variants can contain long activity sequences.
SET SESSION group_concat_max_len = 1048576;

DROP TABLE IF EXISTS p2p_case_level;

CREATE TABLE p2p_case_level AS
WITH ordered_events AS (
    SELECT
        e.*,
        ROW_NUMBER() OVER (
            PARTITION BY case_id
            ORDER BY event_timestamp, event_id
        ) AS event_sequence,

        LAG(activity) OVER (
            PARTITION BY case_id
            ORDER BY event_timestamp, event_id
        ) AS previous_activity,

        LAG(org_resource) OVER (
            PARTITION BY case_id
            ORDER BY event_timestamp, event_id
        ) AS previous_resource
    FROM p2p_events_raw e
),

event_flags AS (
    SELECT
        *,

        CASE
            WHEN previous_resource IS NOT NULL
             AND org_resource IS NOT NULL
             AND previous_resource <> org_resource
            THEN 1 ELSE 0
        END AS resource_handoff_flag,

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
            THEN 1 ELSE 0
        END AS po_modification_event,

        CASE
            WHEN activity IN (
                'Delete Purchase Order Item',
                'Block Purchase Order Item',
                'Reactivate Purchase Order Item'
            )
            THEN 1 ELSE 0
        END AS po_intervention_event,

        CASE WHEN activity = 'Cancel Invoice Receipt' THEN 1 ELSE 0 END
            AS invoice_reversal_event,

        CASE WHEN activity = 'Cancel Goods Receipt' THEN 1 ELSE 0 END
            AS gr_reversal_event,

        CASE WHEN activity = 'Set Payment Block' THEN 1 ELSE 0 END
            AS payment_block_set_event,

        CASE WHEN activity = 'Remove Payment Block' THEN 1 ELSE 0 END
            AS payment_block_remove_event,

        CASE WHEN activity = 'Clear Invoice' THEN 1 ELSE 0 END
            AS invoice_clear_event,

        CASE
            WHEN event_timestamp < '2016-01-01'
            THEN 1 ELSE 0
        END AS historical_timestamp_event
    FROM ordered_events
),

variant_sequences AS (
    SELECT
        case_id,
        GROUP_CONCAT(
            activity
            ORDER BY event_timestamp, event_id
            SEPARATOR ' -> '
        ) AS process_variant
    FROM event_flags
    GROUP BY case_id
),

case_aggregation AS (
    SELECT
        case_id,

        -- Validated case-level attributes
        MIN(vendor) AS vendor,
        MIN(company) AS company,
        MIN(spend_area) AS spend_area,
        MIN(sub_spend_area) AS sub_spend_area,
        MIN(spend_classification) AS spend_classification,
        MIN(purchasing_document) AS purchasing_document,
        MIN(document_type) AS document_type,
        MIN(item_type) AS item_type,
        MIN(item_category) AS item_category,
        MIN(gr_based_invoice_verification) AS gr_based_invoice_verification,
        MIN(goods_receipt) AS goods_receipt,

        MIN(event_timestamp) AS case_start,
        MAX(event_timestamp) AS case_end,

        COUNT(*) AS event_count,
        COUNT(DISTINCT activity) AS unique_activity_count,
        COUNT(DISTINCT org_resource) AS unique_resource_count,
        SUM(resource_handoff_flag) AS resource_handoff_count,

        SUM(po_modification_event) AS po_modification_count,
        SUM(po_intervention_event) AS po_intervention_count,
        SUM(invoice_reversal_event) AS invoice_reversal_count,
        SUM(gr_reversal_event) AS gr_reversal_count,
        SUM(payment_block_set_event) AS payment_block_set_count,
        SUM(payment_block_remove_event) AS payment_block_remove_count,
        SUM(invoice_clear_event) AS invoice_clear_count,

        MAX(historical_timestamp_event) AS timestamp_anomaly_flag
    FROM event_flags
    GROUP BY case_id
),

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
        COUNT(*) AS variant_case_count,
        DENSE_RANK() OVER (
            ORDER BY SHA2(process_variant, 256), process_variant
        ) AS variant_id
    FROM case_with_variant
    GROUP BY process_variant
)

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

    TIMESTAMPDIFF(
        SECOND,
        c.case_start,
        c.case_end
    ) / 86400.0 AS cycle_time_days_raw,

    c.event_count,
    c.unique_activity_count,
    c.unique_resource_count,
    c.resource_handoff_count,

    (c.event_count - c.unique_activity_count)
        AS repeated_activity_count,

    CASE
        WHEN c.event_count > c.unique_activity_count
        THEN 1 ELSE 0
    END AS repeated_activity_flag,

    c.po_modification_count,
    CASE WHEN c.po_modification_count > 0 THEN 1 ELSE 0 END
        AS po_modification_flag,

    c.po_intervention_count,
    CASE WHEN c.po_intervention_count > 0 THEN 1 ELSE 0 END
        AS po_intervention_flag,

    c.invoice_reversal_count,
    CASE WHEN c.invoice_reversal_count > 0 THEN 1 ELSE 0 END
        AS invoice_reversal_flag,

    c.gr_reversal_count,
    CASE WHEN c.gr_reversal_count > 0 THEN 1 ELSE 0 END
        AS gr_reversal_flag,

    c.payment_block_set_count,
    CASE WHEN c.payment_block_set_count > 0 THEN 1 ELSE 0 END
        AS payment_block_set_flag,

    c.payment_block_remove_count,
    CASE WHEN c.payment_block_remove_count > 0 THEN 1 ELSE 0 END
        AS payment_block_remove_flag,

    CASE
        WHEN c.payment_block_set_count > 0
          OR c.payment_block_remove_count > 0
        THEN 1 ELSE 0
    END AS payment_block_handling_flag,

    c.invoice_clear_count,
    CASE WHEN c.invoice_clear_count > 0 THEN 1 ELSE 0 END
        AS invoice_cleared_flag,

    vf.variant_id,
    c.process_variant,
    vf.variant_case_count,

    ROUND(
        100.0 * vf.variant_case_count /
        (SELECT COUNT(*) FROM case_with_variant),
        4
    ) AS variant_case_share_pct,

    c.timestamp_anomaly_flag

FROM case_with_variant c
LEFT JOIN variant_frequency vf
    ON c.process_variant = vf.process_variant;


-- ============================================================
-- INDEXES
-- ============================================================

ALTER TABLE p2p_case_level
    ADD PRIMARY KEY (case_id),
    ADD INDEX idx_case_vendor (vendor),
    ADD INDEX idx_case_item_category (item_category),
    ADD INDEX idx_case_document_type (document_type),
    ADD INDEX idx_case_spend_area (spend_area),
    ADD INDEX idx_case_variant_id (variant_id),
    ADD INDEX idx_case_timestamp_anomaly (timestamp_anomaly_flag);


-- ============================================================
-- MODEL VALIDATION
-- ============================================================

SELECT
    (SELECT COUNT(DISTINCT case_id) FROM p2p_events_raw)
        AS source_unique_cases,
    COUNT(*) AS case_model_rows,
    COUNT(DISTINCT case_id) AS case_model_unique_cases
FROM p2p_case_level;

SELECT
    case_id,
    COUNT(*) AS row_count
FROM p2p_case_level
GROUP BY case_id
HAVING COUNT(*) > 1;


-- ============================================================
-- EXACT CONTINUOUS MEDIAN / P90 FOR CYCLE TIME
-- MySQL has no native PERCENTILE_CONT, so linear interpolation
-- is implemented with row numbers.
-- ============================================================

WITH ranked AS (
    SELECT
        cycle_time_days_raw,
        ROW_NUMBER() OVER (ORDER BY cycle_time_days_raw) AS rn,
        COUNT(*) OVER () AS n
    FROM p2p_case_level
    WHERE timestamp_anomaly_flag = 0
),
positions AS (
    SELECT
        1 + (MAX(n) - 1) * 0.50 AS p50_pos,
        1 + (MAX(n) - 1) * 0.90 AS p90_pos
    FROM ranked
),
values_at_positions AS (
    SELECT
        MAX(CASE WHEN rn = FLOOR(p.p50_pos) THEN cycle_time_days_raw END) AS p50_low,
        MAX(CASE WHEN rn = CEIL(p.p50_pos)  THEN cycle_time_days_raw END) AS p50_high,
        MAX(CASE WHEN rn = FLOOR(p.p90_pos) THEN cycle_time_days_raw END) AS p90_low,
        MAX(CASE WHEN rn = CEIL(p.p90_pos)  THEN cycle_time_days_raw END) AS p90_high,
        MAX(p.p50_pos) AS p50_pos,
        MAX(p.p90_pos) AS p90_pos
    FROM ranked
    CROSS JOIN positions p
)
SELECT
    ROUND(
        p50_low + (p50_pos - FLOOR(p50_pos)) * (p50_high - p50_low),
        2
    ) AS median_cycle_days,
    ROUND(
        p90_low + (p90_pos - FLOOR(p90_pos)) * (p90_high - p90_low),
        2
    ) AS p90_cycle_days
FROM values_at_positions;


-- ============================================================
-- CASE-LEVEL EXCEPTION PREVALENCE
-- ============================================================

SELECT
    COUNT(*) AS total_cases,

    SUM(po_modification_flag) AS po_modification_cases,
    ROUND(100.0 * AVG(po_modification_flag), 2)
        AS po_modification_rate_pct,

    SUM(invoice_reversal_flag) AS invoice_reversal_cases,
    ROUND(100.0 * AVG(invoice_reversal_flag), 2)
        AS invoice_reversal_rate_pct,

    SUM(gr_reversal_flag) AS gr_reversal_cases,
    ROUND(100.0 * AVG(gr_reversal_flag), 2)
        AS gr_reversal_rate_pct,

    SUM(payment_block_handling_flag) AS payment_block_handling_cases,
    ROUND(100.0 * AVG(payment_block_handling_flag), 2)
        AS payment_block_handling_rate_pct,

    SUM(repeated_activity_flag) AS repeated_activity_cases,
    ROUND(100.0 * AVG(repeated_activity_flag), 2)
        AS repeated_activity_rate_pct,

    SUM(invoice_cleared_flag) AS invoice_cleared_cases,
    ROUND(100.0 * AVG(invoice_cleared_flag), 2)
        AS invoice_cleared_rate_pct
FROM p2p_case_level;


-- ============================================================
-- PROCESS VARIANT SUMMARY
-- ============================================================

SELECT
    COUNT(DISTINCT variant_id) AS unique_process_variants,
    MAX(variant_case_count) AS largest_variant_cases
FROM p2p_case_level;

SELECT DISTINCT
    variant_id,
    process_variant,
    variant_case_count,
    variant_case_share_pct
FROM p2p_case_level
ORDER BY variant_case_count DESC
LIMIT 20;


-- ============================================================
-- PROCESS CATEGORY SUMMARY WITH MEDIAN
-- ============================================================

WITH ranked AS (
    SELECT
        item_category,
        cycle_time_days_raw,
        ROW_NUMBER() OVER (
            PARTITION BY item_category
            ORDER BY cycle_time_days_raw
        ) AS rn,
        COUNT(*) OVER (
            PARTITION BY item_category
        ) AS n
    FROM p2p_case_level
    WHERE timestamp_anomaly_flag = 0
),
medians AS (
    SELECT
        item_category,
        AVG(
            CASE
                WHEN rn IN (
                    FLOOR((n + 1) / 2),
                    CEIL((n + 1) / 2)
                )
                THEN cycle_time_days_raw
            END
        ) AS median_cycle_days
    FROM ranked
    GROUP BY item_category
),
flags AS (
    SELECT
        item_category,
        COUNT(*) AS cases,
        AVG(po_modification_flag) AS po_modification_rate,
        AVG(invoice_reversal_flag) AS invoice_reversal_rate,
        AVG(gr_reversal_flag) AS gr_reversal_rate,
        AVG(payment_block_handling_flag) AS payment_block_handling_rate
    FROM p2p_case_level
    WHERE timestamp_anomaly_flag = 0
    GROUP BY item_category
)
SELECT
    f.item_category,
    f.cases,
    ROUND(m.median_cycle_days, 2) AS median_cycle_days,
    ROUND(100.0 * f.po_modification_rate, 2) AS po_modification_rate_pct,
    ROUND(100.0 * f.invoice_reversal_rate, 2) AS invoice_reversal_rate_pct,
    ROUND(100.0 * f.gr_reversal_rate, 2) AS gr_reversal_rate_pct,
    ROUND(100.0 * f.payment_block_handling_rate, 2)
        AS payment_block_handling_rate_pct
FROM flags f
JOIN medians m
    ON f.item_category <=> m.item_category
ORDER BY f.cases DESC;


-- ============================================================
-- END OF CASE MODEL
-- Next: 03_exception_analysis.sql
-- ============================================================
