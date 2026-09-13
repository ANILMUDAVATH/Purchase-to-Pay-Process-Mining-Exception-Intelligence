-- ============================================================
-- 03_exception_analysis.sql
-- Project: Purchase-to-Pay Process Mining & Exception Intelligence
-- Database: MySQL 8.0+
-- Purpose:
--   Analyze P2P exception and process-complexity patterns.
-- ============================================================

USE p2p;


-- ============================================================
-- 1. CREATE DATA-DERIVED ANALYSIS THRESHOLDS
-- Exact continuous P90 using linear interpolation.
-- ============================================================

DROP TABLE IF EXISTS p2p_analysis_thresholds;

CREATE TABLE p2p_analysis_thresholds AS
WITH cycle_ranked AS (
    SELECT
        cycle_time_days_raw AS value_num,
        ROW_NUMBER() OVER (ORDER BY cycle_time_days_raw) AS rn,
        COUNT(*) OVER () AS n
    FROM p2p_case_level
    WHERE timestamp_anomaly_flag = 0
),
cycle_pos AS (
    SELECT 1 + (MAX(n) - 1) * 0.90 AS pos
    FROM cycle_ranked
),
cycle_values AS (
    SELECT
        MAX(CASE WHEN rn = FLOOR(p.pos) THEN value_num END) AS low_value,
        MAX(CASE WHEN rn = CEIL(p.pos)  THEN value_num END) AS high_value,
        MAX(p.pos) AS pos
    FROM cycle_ranked
    CROSS JOIN cycle_pos p
),
handoff_ranked AS (
    SELECT
        resource_handoff_count AS value_num,
        ROW_NUMBER() OVER (ORDER BY resource_handoff_count) AS rn,
        COUNT(*) OVER () AS n
    FROM p2p_case_level
    WHERE timestamp_anomaly_flag = 0
),
handoff_pos AS (
    SELECT 1 + (MAX(n) - 1) * 0.90 AS pos
    FROM handoff_ranked
),
handoff_values AS (
    SELECT
        MAX(CASE WHEN rn = FLOOR(p.pos) THEN value_num END) AS low_value,
        MAX(CASE WHEN rn = CEIL(p.pos)  THEN value_num END) AS high_value,
        MAX(p.pos) AS pos
    FROM handoff_ranked
    CROSS JOIN handoff_pos p
)
SELECT
    c.low_value
      + (c.pos - FLOOR(c.pos)) * (c.high_value - c.low_value)
        AS p90_cycle_days,

    h.low_value
      + (h.pos - FLOOR(h.pos)) * (h.high_value - h.low_value)
        AS p90_handoffs
FROM cycle_values c
CROSS JOIN handoff_values h;

SELECT * FROM p2p_analysis_thresholds;


-- ============================================================
-- 2. OVERALL EXCEPTION / COMPLEXITY SUMMARY
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
FROM p2p_case_level;


-- ============================================================
-- 3. PO MODIFICATION VS NO PO MODIFICATION
-- Median and P90 are calculated per group.
-- ============================================================

WITH ranked AS (
    SELECT
        po_modification_flag AS grp,
        cycle_time_days_raw,
        event_count,
        resource_handoff_count,
        ROW_NUMBER() OVER (
            PARTITION BY po_modification_flag
            ORDER BY cycle_time_days_raw
        ) AS rn,
        COUNT(*) OVER (
            PARTITION BY po_modification_flag
        ) AS n
    FROM p2p_case_level
    WHERE timestamp_anomaly_flag = 0
),
quantiles AS (
    SELECT
        grp,
        MAX(n) AS n,
        AVG(
            CASE
                WHEN rn IN (
                    FLOOR((n + 1) / 2),
                    CEIL((n + 1) / 2)
                )
                THEN cycle_time_days_raw
            END
        ) AS median_cycle_days,

        MAX(
            CASE
                WHEN rn = FLOOR(1 + (n - 1) * 0.90)
                THEN cycle_time_days_raw
            END
        ) AS p90_low,

        MAX(
            CASE
                WHEN rn = CEIL(1 + (n - 1) * 0.90)
                THEN cycle_time_days_raw
            END
        ) AS p90_high,

        MAX(1 + (n - 1) * 0.90) AS p90_pos
    FROM ranked
    GROUP BY grp
),
aggregates AS (
    SELECT
        po_modification_flag AS grp,
        COUNT(*) AS cases,
        AVG(event_count) AS avg_events,
        AVG(resource_handoff_count) AS avg_resource_handoffs
    FROM p2p_case_level
    WHERE timestamp_anomaly_flag = 0
    GROUP BY po_modification_flag
)
SELECT
    a.grp AS po_modification_flag,
    a.cases,
    ROUND(q.median_cycle_days, 2) AS median_cycle_days,
    ROUND(
        q.p90_low
        + (q.p90_pos - FLOOR(q.p90_pos))
        * (q.p90_high - q.p90_low),
        2
    ) AS p90_cycle_days,
    ROUND(a.avg_events, 2) AS avg_events,
    ROUND(a.avg_resource_handoffs, 2) AS avg_resource_handoffs
FROM aggregates a
JOIN quantiles q
    ON a.grp = q.grp
ORDER BY a.grp;


-- ============================================================
-- 4. PO MODIFICATION TYPES
-- ============================================================

SELECT
    activity AS po_change_activity,
    COUNT(*) AS event_count,
    COUNT(DISTINCT case_id) AS case_count,
    ROUND(
        100.0 * COUNT(DISTINCT case_id) /
        (SELECT COUNT(*) FROM p2p_case_level),
        2
    ) AS case_rate_pct
FROM p2p_events_raw
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
-- 5. PO INTERVENTION DETAIL
-- ============================================================

SELECT
    activity AS po_intervention_activity,
    COUNT(*) AS event_count,
    COUNT(DISTINCT case_id) AS case_count
FROM p2p_events_raw
WHERE activity IN (
    'Delete Purchase Order Item',
    'Block Purchase Order Item',
    'Reactivate Purchase Order Item'
)
GROUP BY activity
ORDER BY case_count DESC;


-- ============================================================
-- 6. INVOICE REVERSAL COMPARISON
-- ============================================================

WITH ranked AS (
    SELECT
        invoice_reversal_flag AS grp,
        cycle_time_days_raw,
        ROW_NUMBER() OVER (
            PARTITION BY invoice_reversal_flag
            ORDER BY cycle_time_days_raw
        ) AS rn,
        COUNT(*) OVER (
            PARTITION BY invoice_reversal_flag
        ) AS n
    FROM p2p_case_level
    WHERE timestamp_anomaly_flag = 0
),
q AS (
    SELECT
        grp,
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
    GROUP BY grp
)
SELECT
    c.invoice_reversal_flag,
    COUNT(*) AS cases,
    ROUND(q.median_cycle_days, 2) AS median_cycle_days,
    ROUND(AVG(c.event_count), 2) AS avg_events,
    ROUND(AVG(c.resource_handoff_count), 2) AS avg_resource_handoffs
FROM p2p_case_level c
JOIN q
    ON c.invoice_reversal_flag = q.grp
WHERE c.timestamp_anomaly_flag = 0
GROUP BY
    c.invoice_reversal_flag,
    q.median_cycle_days
ORDER BY c.invoice_reversal_flag;


-- ============================================================
-- 7. GOODS RECEIPT REVERSAL COMPARISON
-- ============================================================

WITH ranked AS (
    SELECT
        gr_reversal_flag AS grp,
        cycle_time_days_raw,
        ROW_NUMBER() OVER (
            PARTITION BY gr_reversal_flag
            ORDER BY cycle_time_days_raw
        ) AS rn,
        COUNT(*) OVER (
            PARTITION BY gr_reversal_flag
        ) AS n
    FROM p2p_case_level
    WHERE timestamp_anomaly_flag = 0
),
q AS (
    SELECT
        grp,
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
    GROUP BY grp
)
SELECT
    c.gr_reversal_flag,
    COUNT(*) AS cases,
    ROUND(q.median_cycle_days, 2) AS median_cycle_days,
    ROUND(AVG(c.event_count), 2) AS avg_events,
    ROUND(AVG(c.resource_handoff_count), 2) AS avg_resource_handoffs
FROM p2p_case_level c
JOIN q
    ON c.gr_reversal_flag = q.grp
WHERE c.timestamp_anomaly_flag = 0
GROUP BY
    c.gr_reversal_flag,
    q.median_cycle_days
ORDER BY c.gr_reversal_flag;


-- ============================================================
-- 8. PAYMENT-BLOCK HANDLING
-- ============================================================

SELECT
    payment_block_set_flag,
    payment_block_remove_flag,
    payment_block_handling_flag,
    COUNT(*) AS cases
FROM p2p_case_level
GROUP BY
    payment_block_set_flag,
    payment_block_remove_flag,
    payment_block_handling_flag
ORDER BY cases DESC;


-- ============================================================
-- 9. REMOVE PAYMENT BLOCK -> CLEAR INVOICE DURATION
-- ============================================================

WITH remove_events AS (
    SELECT
        case_id,
        MAX(event_timestamp) AS last_remove_payment_block_ts
    FROM p2p_events_raw
    WHERE activity = 'Remove Payment Block'
    GROUP BY case_id
),
clear_after_remove AS (
    SELECT
        r.case_id,
        r.last_remove_payment_block_ts,
        MIN(e.event_timestamp) AS first_clear_after_remove_ts
    FROM remove_events r
    JOIN p2p_events_raw e
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
        TIMESTAMPDIFF(
            SECOND,
            last_remove_payment_block_ts,
            first_clear_after_remove_ts
        ) / 86400.0 AS days_remove_to_clear
    FROM clear_after_remove
),
ranked AS (
    SELECT
        days_remove_to_clear,
        ROW_NUMBER() OVER (ORDER BY days_remove_to_clear) AS rn,
        COUNT(*) OVER () AS n
    FROM durations
)
SELECT
    COUNT(*) AS cases_with_remove_then_clear,
    ROUND(
        AVG(
            CASE
                WHEN rn IN (
                    FLOOR((n + 1) / 2),
                    CEIL((n + 1) / 2)
                )
                THEN days_remove_to_clear
            END
        ),
        2
    ) AS median_days_remove_to_clear,
    ROUND(AVG(days_remove_to_clear), 2) AS avg_days_remove_to_clear
FROM ranked;


-- ============================================================
-- 10. REPEATED ACTIVITY
-- ============================================================

SELECT
    repeated_activity_flag,
    COUNT(*) AS cases,
    ROUND(AVG(repeated_activity_count), 2) AS avg_repeated_activity_count,
    ROUND(AVG(cycle_time_days_raw), 2) AS avg_cycle_days
FROM p2p_case_level
WHERE timestamp_anomaly_flag = 0
GROUP BY repeated_activity_flag
ORDER BY repeated_activity_flag;

WITH activity_case_counts AS (
    SELECT
        case_id,
        activity,
        COUNT(*) AS activity_occurrences
    FROM p2p_events_raw
    GROUP BY case_id, activity
),
repeated_only AS (
    SELECT *
    FROM activity_case_counts
    WHERE activity_occurrences > 1
)
SELECT
    activity,
    COUNT(*) AS cases_with_repetition,
    SUM(activity_occurrences - 1) AS extra_repeated_events,
    ROUND(AVG(activity_occurrences), 2)
        AS avg_occurrences_when_repeated
FROM repeated_only
GROUP BY activity
ORDER BY extra_repeated_events DESC;


-- ============================================================
-- 11. LONG-CYCLE CASES
-- ============================================================

SELECT
    ROUND(p90_cycle_days, 2) AS p90_cycle_days,
    p90_handoffs
FROM p2p_analysis_thresholds;

SELECT
    c.case_id,
    c.vendor,
    c.spend_area,
    c.document_type,
    c.item_category,
    ROUND(c.cycle_time_days_raw, 2) AS cycle_time_days,
    c.event_count,
    c.resource_handoff_count,
    c.po_modification_flag,
    c.invoice_reversal_flag,
    c.gr_reversal_flag,
    c.payment_block_handling_flag,
    c.repeated_activity_flag,
    c.variant_id
FROM p2p_case_level c
CROSS JOIN p2p_analysis_thresholds t
WHERE c.timestamp_anomaly_flag = 0
  AND c.cycle_time_days_raw >= t.p90_cycle_days
ORDER BY c.cycle_time_days_raw DESC;


-- ============================================================
-- 12. HANDOFF BAND ANALYSIS
-- ============================================================

WITH banded AS (
    SELECT
        CASE
            WHEN resource_handoff_count = 0 THEN '0'
            WHEN resource_handoff_count BETWEEN 1 AND 2 THEN '1-2'
            WHEN resource_handoff_count BETWEEN 3 AND 5 THEN '3-5'
            WHEN resource_handoff_count BETWEEN 6 AND 10 THEN '6-10'
            ELSE '11+'
        END AS handoff_band,
        cycle_time_days_raw,
        event_count
    FROM p2p_case_level
    WHERE timestamp_anomaly_flag = 0
),
ranked AS (
    SELECT
        *,
        ROW_NUMBER() OVER (
            PARTITION BY handoff_band
            ORDER BY cycle_time_days_raw
        ) AS rn,
        COUNT(*) OVER (
            PARTITION BY handoff_band
        ) AS n
    FROM banded
)
SELECT
    handoff_band,
    COUNT(*) AS cases,
    ROUND(
        AVG(
            CASE
                WHEN rn IN (
                    FLOOR((n + 1) / 2),
                    CEIL((n + 1) / 2)
                )
                THEN cycle_time_days_raw
            END
        ),
        2
    ) AS median_cycle_days,
    ROUND(AVG(event_count), 2) AS avg_events
FROM ranked
GROUP BY handoff_band
ORDER BY FIELD(handoff_band, '0', '1-2', '3-5', '6-10', '11+');


-- ============================================================
-- 13. MEANINGFUL PROCESS VARIANTS
-- ============================================================

WITH variant_base AS (
    SELECT
        variant_id,
        cycle_time_days_raw,
        po_modification_flag,
        invoice_reversal_flag,
        gr_reversal_flag,
        resource_handoff_count,
        ROW_NUMBER() OVER (
            PARTITION BY variant_id
            ORDER BY cycle_time_days_raw
        ) AS rn,
        COUNT(*) OVER (
            PARTITION BY variant_id
        ) AS n
    FROM p2p_case_level
    WHERE timestamp_anomaly_flag = 0
),
variant_summary AS (
    SELECT
        variant_id,
        MAX(n) AS cases,
        AVG(
            CASE
                WHEN rn IN (
                    FLOOR((n + 1) / 2),
                    CEIL((n + 1) / 2)
                )
                THEN cycle_time_days_raw
            END
        ) AS median_cycle_days,
        AVG(po_modification_flag) AS po_modification_rate,
        AVG(invoice_reversal_flag) AS invoice_reversal_rate,
        AVG(gr_reversal_flag) AS gr_reversal_rate,
        AVG(resource_handoff_count) AS avg_resource_handoffs
    FROM variant_base
    GROUP BY variant_id
)
SELECT
    variant_id,
    cases,
    ROUND(median_cycle_days, 2) AS median_cycle_days,
    ROUND(100.0 * po_modification_rate, 2) AS po_modification_rate_pct,
    ROUND(100.0 * invoice_reversal_rate, 2) AS invoice_reversal_rate_pct,
    ROUND(100.0 * gr_reversal_rate, 2) AS gr_reversal_rate_pct,
    ROUND(avg_resource_handoffs, 2) AS avg_resource_handoffs
FROM variant_summary
WHERE cases >= 100
ORDER BY cases DESC;


-- ============================================================
-- 14. EXCEPTION SIGNAL COUNT
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
    FROM p2p_case_level
)
SELECT
    exception_signal_count,
    COUNT(*) AS cases,
    ROUND(
        100.0 * COUNT(*) /
        SUM(COUNT(*)) OVER (),
        2
    ) AS case_share_pct
FROM scored
GROUP BY exception_signal_count
ORDER BY exception_signal_count;


-- ============================================================
-- 15. CASES WITH MULTIPLE EXCEPTION SIGNALS
-- ============================================================

SELECT
    case_id,
    vendor,
    spend_area,
    document_type,
    item_category,
    ROUND(cycle_time_days_raw, 2) AS cycle_time_days,
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
FROM p2p_case_level
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
-- 16. PROCESS CATEGORY EXCEPTION COMPARISON
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
        AVG(po_intervention_flag) AS po_intervention_rate,
        AVG(invoice_reversal_flag) AS invoice_reversal_rate,
        AVG(gr_reversal_flag) AS gr_reversal_rate,
        AVG(payment_block_handling_flag) AS payment_block_handling_rate,
        AVG(repeated_activity_flag) AS repeated_activity_rate
    FROM p2p_case_level
    WHERE timestamp_anomaly_flag = 0
    GROUP BY item_category
)
SELECT
    f.item_category,
    f.cases,
    ROUND(100.0 * f.po_modification_rate, 2) AS po_modification_rate_pct,
    ROUND(100.0 * f.po_intervention_rate, 2) AS po_intervention_rate_pct,
    ROUND(100.0 * f.invoice_reversal_rate, 2) AS invoice_reversal_rate_pct,
    ROUND(100.0 * f.gr_reversal_rate, 2) AS gr_reversal_rate_pct,
    ROUND(100.0 * f.payment_block_handling_rate, 2)
        AS payment_block_handling_rate_pct,
    ROUND(100.0 * f.repeated_activity_rate, 2) AS repeated_activity_rate_pct,
    ROUND(m.median_cycle_days, 2) AS median_cycle_days
FROM flags f
JOIN medians m
    ON f.item_category <=> m.item_category
ORDER BY f.cases DESC;


-- ============================================================
-- END OF EXCEPTION ANALYSIS
-- Next: 04_business_analysis.sql
-- ============================================================
