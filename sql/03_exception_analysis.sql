-- ============================================================
-- 03_exception_analysis.sql
-- Project: Purchase-to-Pay Process Mining & Exception Intelligence
-- Database: PostgreSQL
-- Purpose:
--   Analyze explicit P2P exception / complexity patterns from
--   p2p.p2p_case_level.
--
-- Focus:
--   - PO modification
--   - PO intervention
--   - Invoice reversal
--   - Goods receipt reversal
--   - Payment-block handling
--   - Repeated activity
--   - Long-cycle cases
--   - Resource handoffs
--   - Process variants
--
-- IMPORTANT:
--   These are investigation signals.
--   They are NOT automatically fraud, non-compliance, supplier
--   failure, employee fault, or financial loss.
-- ============================================================


-- ============================================================
-- 1. OVERALL EXCEPTION / COMPLEXITY SUMMARY
-- ============================================================

SELECT
    COUNT(*) AS total_cases,

    SUM(po_modification_flag) AS po_modification_cases,
    ROUND(100.0 * AVG(po_modification_flag), 2)
        AS po_modification_rate_pct,

    SUM(po_intervention_flag) AS po_intervention_cases,
    ROUND(100.0 * AVG(po_intervention_flag), 2)
        AS po_intervention_rate_pct,

    SUM(invoice_reversal_flag) AS invoice_reversal_cases,
    ROUND(100.0 * AVG(invoice_reversal_flag), 2)
        AS invoice_reversal_rate_pct,

    SUM(gr_reversal_flag) AS gr_reversal_cases,
    ROUND(100.0 * AVG(gr_reversal_flag), 2)
        AS gr_reversal_rate_pct,

    SUM(payment_block_set_flag) AS payment_block_set_cases,
    ROUND(100.0 * AVG(payment_block_set_flag), 4)
        AS payment_block_set_rate_pct,

    SUM(payment_block_remove_flag) AS payment_block_remove_cases,
    ROUND(100.0 * AVG(payment_block_remove_flag), 2)
        AS payment_block_remove_rate_pct,

    SUM(payment_block_handling_flag) AS payment_block_handling_cases,
    ROUND(100.0 * AVG(payment_block_handling_flag), 2)
        AS payment_block_handling_rate_pct,

    SUM(repeated_activity_flag) AS repeated_activity_cases,
    ROUND(100.0 * AVG(repeated_activity_flag), 2)
        AS repeated_activity_rate_pct,

    SUM(invoice_cleared_flag) AS invoice_cleared_cases,
    ROUND(100.0 * AVG(invoice_cleared_flag), 2)
        AS invoice_cleared_rate_pct

FROM p2p.p2p_case_level;


-- ============================================================
-- 2. PO MODIFICATION DETAIL
-- ============================================================

SELECT
    po_modification_flag,
    COUNT(*) AS cases,

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

    ROUND(AVG(event_count), 2) AS avg_events,

    ROUND(AVG(resource_handoff_count), 2)
        AS avg_resource_handoffs

FROM p2p.p2p_case_level

WHERE timestamp_anomaly_flag = 0

GROUP BY po_modification_flag

ORDER BY po_modification_flag;


-- ============================================================
-- 3. PO MODIFICATION TYPES
-- ============================================================

SELECT
    activity AS po_change_activity,
    COUNT(*) AS event_count,
    COUNT(DISTINCT case_id) AS case_count,

    ROUND(
        100.0 * COUNT(DISTINCT case_id)
        / (SELECT COUNT(*) FROM p2p.p2p_case_level),
        2
    ) AS case_rate_pct

FROM p2p.p2p_events_raw

WHERE activity IN (
    'Change Quantity',
    'Change Price',
    'Change Approval for Purchase Order',
    'Change Delivery Indicator',
    'Change Storage Location',
    'Change Currency',
    'Change payment term'
)

GROUP BY activity

ORDER BY case_count DESC;


-- ============================================================
-- 4. PO INTERVENTION DETAIL
-- ============================================================

SELECT
    activity AS po_intervention_activity,
    COUNT(*) AS event_count,
    COUNT(DISTINCT case_id) AS case_count

FROM p2p.p2p_events_raw

WHERE activity IN (
    'Delete Purchase Order Item',
    'Block Purchase Order Item',
    'Reactivate Purchase Order Item'
)

GROUP BY activity

ORDER BY case_count DESC;


-- ============================================================
-- 5. INVOICE REVERSAL ANALYSIS
-- ============================================================

SELECT
    invoice_reversal_flag,
    COUNT(*) AS cases,

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

    ROUND(AVG(event_count), 2) AS avg_events,

    ROUND(AVG(resource_handoff_count), 2)
        AS avg_resource_handoffs

FROM p2p.p2p_case_level

WHERE timestamp_anomaly_flag = 0

GROUP BY invoice_reversal_flag

ORDER BY invoice_reversal_flag;


-- ============================================================
-- 6. GOODS RECEIPT REVERSAL ANALYSIS
-- ============================================================

SELECT
    gr_reversal_flag,
    COUNT(*) AS cases,

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

    ROUND(AVG(event_count), 2) AS avg_events,

    ROUND(AVG(resource_handoff_count), 2)
        AS avg_resource_handoffs

FROM p2p.p2p_case_level

WHERE timestamp_anomaly_flag = 0

GROUP BY gr_reversal_flag

ORDER BY gr_reversal_flag;


-- ============================================================
-- 7. PAYMENT-BLOCK HANDLING
-- ============================================================

-- Keep Set / Remove / Any handling separate because the source
-- frequencies are highly asymmetric.

SELECT
    payment_block_set_flag,
    payment_block_remove_flag,
    payment_block_handling_flag,
    COUNT(*) AS cases

FROM p2p.p2p_case_level

GROUP BY
    payment_block_set_flag,
    payment_block_remove_flag,
    payment_block_handling_flag

ORDER BY cases DESC;


-- ============================================================
-- 8. REMOVE PAYMENT BLOCK -> CLEAR INVOICE DURATION
-- ============================================================
-- For cases containing both events, calculate the elapsed time
-- from the final Remove Payment Block event to the first Clear
-- Invoice event occurring after that removal.

WITH remove_events AS (
    SELECT
        case_id,
        MAX(event_timestamp) AS last_remove_payment_block_ts
    FROM p2p.p2p_events_raw
    WHERE activity = 'Remove Payment Block'
    GROUP BY case_id
),

clear_after_remove AS (
    SELECT
        r.case_id,
        r.last_remove_payment_block_ts,
        MIN(e.event_timestamp) AS first_clear_after_remove_ts
    FROM remove_events r
    JOIN p2p.p2p_events_raw e
      ON e.case_id = r.case_id
     AND e.activity = 'Clear Invoice'
     AND e.event_timestamp >= r.last_remove_payment_block_ts
    GROUP BY
        r.case_id,
        r.last_remove_payment_block_ts
),

durations AS (
    SELECT
        case_id,
        EXTRACT(
            EPOCH FROM (
                first_clear_after_remove_ts
                - last_remove_payment_block_ts
            )
        ) / 86400.0 AS days_remove_to_clear
    FROM clear_after_remove
)

SELECT
    COUNT(*) AS cases_with_remove_then_clear,

    ROUND(
        PERCENTILE_CONT(0.50)
        WITHIN GROUP (ORDER BY days_remove_to_clear)::NUMERIC,
        2
    ) AS median_days_remove_to_clear,

    ROUND(
        PERCENTILE_CONT(0.90)
        WITHIN GROUP (ORDER BY days_remove_to_clear)::NUMERIC,
        2
    ) AS p90_days_remove_to_clear,

    ROUND(AVG(days_remove_to_clear), 2)
        AS avg_days_remove_to_clear

FROM durations;


-- ============================================================
-- 9. REPEATED ACTIVITY ANALYSIS
-- ============================================================

SELECT
    repeated_activity_flag,
    COUNT(*) AS cases,

    ROUND(
        PERCENTILE_CONT(0.50)
        WITHIN GROUP (ORDER BY repeated_activity_count)::NUMERIC,
        2
    ) AS median_repeated_activity_count,

    ROUND(
        PERCENTILE_CONT(0.50)
        WITHIN GROUP (ORDER BY cycle_time_days_raw)::NUMERIC,
        2
    ) AS median_cycle_days,

    ROUND(
        PERCENTILE_CONT(0.90)
        WITHIN GROUP (ORDER BY cycle_time_days_raw)::NUMERIC,
        2
    ) AS p90_cycle_days

FROM p2p.p2p_case_level

WHERE timestamp_anomaly_flag = 0

GROUP BY repeated_activity_flag

ORDER BY repeated_activity_flag;


-- ============================================================
-- 10. MOST REPEATED ACTIVITIES
-- ============================================================

WITH activity_case_counts AS (
    SELECT
        case_id,
        activity,
        COUNT(*) AS activity_occurrences
    FROM p2p.p2p_events_raw
    GROUP BY
        case_id,
        activity
),

repeated_only AS (
    SELECT *
    FROM activity_case_counts
    WHERE activity_occurrences > 1
)

SELECT
    activity,

    COUNT(*) AS cases_with_repetition,

    SUM(activity_occurrences - 1)
        AS extra_repeated_events,

    ROUND(
        AVG(activity_occurrences),
        2
    ) AS avg_occurrences_when_repeated

FROM repeated_only

GROUP BY activity

ORDER BY extra_repeated_events DESC;


-- ============================================================
-- 11. LONG-CYCLE THRESHOLD
-- ============================================================
-- Use the actual case distribution (excluding timestamp-anomaly
-- cases) rather than an arbitrary external threshold.

WITH threshold AS (
    SELECT
        PERCENTILE_CONT(0.90)
        WITHIN GROUP (ORDER BY cycle_time_days_raw)
            AS p90_cycle_days
    FROM p2p.p2p_case_level
    WHERE timestamp_anomaly_flag = 0
)

SELECT
    ROUND(p90_cycle_days::NUMERIC, 2)
        AS p90_cycle_days
FROM threshold;


-- ============================================================
-- 12. LONG-CYCLE CASES
-- ============================================================

WITH threshold AS (
    SELECT
        PERCENTILE_CONT(0.90)
        WITHIN GROUP (ORDER BY cycle_time_days_raw)
            AS p90_cycle_days
    FROM p2p.p2p_case_level
    WHERE timestamp_anomaly_flag = 0
)

SELECT
    c.case_id,
    c.vendor,
    c.spend_area,
    c.document_type,
    c.item_category,
    ROUND(c.cycle_time_days_raw::NUMERIC, 2)
        AS cycle_time_days,
    c.event_count,
    c.resource_handoff_count,
    c.po_modification_flag,
    c.invoice_reversal_flag,
    c.gr_reversal_flag,
    c.payment_block_handling_flag,
    c.repeated_activity_flag,
    c.process_variant

FROM p2p.p2p_case_level c
CROSS JOIN threshold t

WHERE c.timestamp_anomaly_flag = 0
  AND c.cycle_time_days_raw >= t.p90_cycle_days

ORDER BY
    c.cycle_time_days_raw DESC;


-- ============================================================
-- 13. RESOURCE HANDOFF THRESHOLD
-- ============================================================

WITH handoff_threshold AS (
    SELECT
        PERCENTILE_CONT(0.90)
        WITHIN GROUP (ORDER BY resource_handoff_count)
            AS p90_handoffs
    FROM p2p.p2p_case_level
    WHERE timestamp_anomaly_flag = 0
)

SELECT
    p90_handoffs
FROM handoff_threshold;


-- ============================================================
-- 14. HANDOFF BAND ANALYSIS
-- ============================================================

WITH handoff_bands AS (
    SELECT
        CASE
            WHEN resource_handoff_count = 0
                THEN '0'
            WHEN resource_handoff_count BETWEEN 1 AND 2
                THEN '1-2'
            WHEN resource_handoff_count BETWEEN 3 AND 5
                THEN '3-5'
            WHEN resource_handoff_count BETWEEN 6 AND 10
                THEN '6-10'
            ELSE '11+'
        END AS handoff_band,

        cycle_time_days_raw,
        event_count

    FROM p2p.p2p_case_level

    WHERE timestamp_anomaly_flag = 0
)

SELECT
    handoff_band,
    COUNT(*) AS cases,

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
        PERCENTILE_CONT(0.50)
        WITHIN GROUP (ORDER BY event_count)::NUMERIC,
        2
    ) AS median_events

FROM handoff_bands

GROUP BY handoff_band

ORDER BY
    CASE handoff_band
        WHEN '0' THEN 1
        WHEN '1-2' THEN 2
        WHEN '3-5' THEN 3
        WHEN '6-10' THEN 4
        WHEN '11+' THEN 5
    END;


-- ============================================================
-- 15. PROCESS VARIANTS WITH MEANINGFUL VOLUME
-- ============================================================
-- Avoid overinterpreting one-off or very rare variants.

SELECT
    process_variant,
    COUNT(*) AS cases,

    ROUND(
        100.0 * COUNT(*)
        / SUM(COUNT(*)) OVER (),
        4
    ) AS case_share_pct,

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
        AVG(resource_handoff_count),
        2
    ) AS avg_resource_handoffs

FROM p2p.p2p_case_level

WHERE timestamp_anomaly_flag = 0

GROUP BY process_variant

HAVING COUNT(*) >= 100

ORDER BY
    cases DESC;


-- ============================================================
-- 16. EXCEPTION SIGNAL COUNT
-- ============================================================

WITH scored AS (
    SELECT
        case_id,

        po_modification_flag
        + po_intervention_flag
        + invoice_reversal_flag
        + gr_reversal_flag
        + payment_block_handling_flag
        + repeated_activity_flag
            AS exception_signal_count

    FROM p2p.p2p_case_level
)

SELECT
    exception_signal_count,
    COUNT(*) AS cases,

    ROUND(
        100.0 * COUNT(*)
        / SUM(COUNT(*)) OVER (),
        2
    ) AS case_share_pct

FROM scored

GROUP BY exception_signal_count

ORDER BY exception_signal_count;


-- ============================================================
-- 17. CASES WITH MULTIPLE EXCEPTION SIGNALS
-- ============================================================

SELECT
    case_id,
    vendor,
    spend_area,
    document_type,
    item_category,
    ROUND(cycle_time_days_raw::NUMERIC, 2)
        AS cycle_time_days,
    event_count,
    resource_handoff_count,

    po_modification_flag
    + po_intervention_flag
    + invoice_reversal_flag
    + gr_reversal_flag
    + payment_block_handling_flag
    + repeated_activity_flag
        AS exception_signal_count,

    po_modification_flag,
    po_intervention_flag,
    invoice_reversal_flag,
    gr_reversal_flag,
    payment_block_handling_flag,
    repeated_activity_flag

FROM p2p.p2p_case_level

WHERE (
    po_modification_flag
    + po_intervention_flag
    + invoice_reversal_flag
    + gr_reversal_flag
    + payment_block_handling_flag
    + repeated_activity_flag
) >= 2

ORDER BY
    exception_signal_count DESC,
    cycle_time_days_raw DESC;


-- ============================================================
-- 18. PROCESS CATEGORY EXCEPTION COMPARISON
-- ============================================================

SELECT
    item_category,
    COUNT(*) AS cases,

    ROUND(
        100.0 * AVG(po_modification_flag),
        2
    ) AS po_modification_rate_pct,

    ROUND(
        100.0 * AVG(po_intervention_flag),
        2
    ) AS po_intervention_rate_pct,

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
    ) AS payment_block_handling_rate_pct,

    ROUND(
        100.0 * AVG(repeated_activity_flag),
        2
    ) AS repeated_activity_rate_pct,

    ROUND(
        PERCENTILE_CONT(0.50)
        WITHIN GROUP (ORDER BY cycle_time_days_raw)::NUMERIC,
        2
    ) AS median_cycle_days

FROM p2p.p2p_case_level

WHERE timestamp_anomaly_flag = 0

GROUP BY item_category

ORDER BY cases DESC;


-- ============================================================
-- END OF EXCEPTION ANALYSIS
-- ============================================================
-- Next:
--   04_business_analysis.sql
--
-- That script will answer management questions across:
--   - vendors
--   - spend areas
--   - document types
--   - process categories
--   - Pareto concentration
--   - investigation prioritization
-- ============================================================
