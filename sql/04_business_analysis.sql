-- ============================================================
-- 04_business_analysis.sql
-- Project: Purchase-to-Pay Process Mining & Exception Intelligence
-- Database: MySQL 8.0+
-- Purpose:
--   Management-facing analysis and investigation prioritization.
-- ============================================================

USE p2p;


-- ============================================================
-- 1. CREATE REUSABLE BUSINESS ANALYSIS VIEW
-- ============================================================

CREATE OR REPLACE VIEW vw_case_business_analysis AS
SELECT
    c.*,

    (
        c.po_modification_flag
      + c.po_intervention_flag
      + c.invoice_reversal_flag
      + c.gr_reversal_flag
      + c.payment_block_handling_flag
      + c.repeated_activity_flag
    ) AS exception_signal_count,

    CASE
        WHEN c.cycle_time_days_raw >= t.p90_cycle_days
        THEN 1 ELSE 0
    END AS long_cycle_flag,

    CASE
        WHEN c.resource_handoff_count >= t.p90_handoffs
        THEN 1 ELSE 0
    END AS high_handoff_flag,

    (
          2 * CASE
                WHEN c.cycle_time_days_raw >= t.p90_cycle_days
                THEN 1 ELSE 0
              END
        + 2 * c.invoice_reversal_flag
        + 2 * c.gr_reversal_flag
        + 1 * c.po_modification_flag
        + 1 * c.po_intervention_flag
        + 1 * c.payment_block_handling_flag
        + 1 * c.repeated_activity_flag
        + 1 * CASE
                WHEN c.resource_handoff_count >= t.p90_handoffs
                THEN 1 ELSE 0
              END
    ) AS investigation_priority_score,

    CASE
        WHEN (
              2 * CASE
                    WHEN c.cycle_time_days_raw >= t.p90_cycle_days
                    THEN 1 ELSE 0
                  END
            + 2 * c.invoice_reversal_flag
            + 2 * c.gr_reversal_flag
            + c.po_modification_flag
            + c.po_intervention_flag
            + c.payment_block_handling_flag
            + c.repeated_activity_flag
            + CASE
                WHEN c.resource_handoff_count >= t.p90_handoffs
                THEN 1 ELSE 0
              END
        ) <= 1
            THEN 'Low'

        WHEN (
              2 * CASE
                    WHEN c.cycle_time_days_raw >= t.p90_cycle_days
                    THEN 1 ELSE 0
                  END
            + 2 * c.invoice_reversal_flag
            + 2 * c.gr_reversal_flag
            + c.po_modification_flag
            + c.po_intervention_flag
            + c.payment_block_handling_flag
            + c.repeated_activity_flag
            + CASE
                WHEN c.resource_handoff_count >= t.p90_handoffs
                THEN 1 ELSE 0
              END
        ) <= 3
            THEN 'Medium'

        ELSE 'High'
    END AS investigation_priority

FROM p2p_case_level c
CROSS JOIN p2p_analysis_thresholds t
WHERE c.timestamp_anomaly_flag = 0;


-- ============================================================
-- 2. MANAGEMENT KPI SUMMARY
-- ============================================================

WITH ranked AS (
    SELECT
        cycle_time_days_raw,
        ROW_NUMBER() OVER (ORDER BY cycle_time_days_raw) AS rn,
        COUNT(*) OVER () AS n
    FROM vw_case_business_analysis
)
SELECT
    (SELECT COUNT(*) FROM vw_case_business_analysis) AS analysis_cases,

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

    ROUND(
        (SELECT p90_cycle_days FROM p2p_analysis_thresholds),
        2
    ) AS p90_cycle_days,

    (SELECT SUM(long_cycle_flag) FROM vw_case_business_analysis)
        AS long_cycle_cases,

    ROUND(
        100.0 *
        (SELECT AVG(long_cycle_flag) FROM vw_case_business_analysis),
        2
    ) AS long_cycle_rate_pct,

    (SELECT SUM(po_modification_flag) FROM vw_case_business_analysis)
        AS po_modification_cases,

    ROUND(
        100.0 *
        (SELECT AVG(po_modification_flag) FROM vw_case_business_analysis),
        2
    ) AS po_modification_rate_pct,

    (SELECT SUM(invoice_reversal_flag) FROM vw_case_business_analysis)
        AS invoice_reversal_cases,

    ROUND(
        100.0 *
        (SELECT AVG(invoice_reversal_flag) FROM vw_case_business_analysis),
        2
    ) AS invoice_reversal_rate_pct,

    (SELECT SUM(gr_reversal_flag) FROM vw_case_business_analysis)
        AS gr_reversal_cases,

    ROUND(
        100.0 *
        (SELECT AVG(gr_reversal_flag) FROM vw_case_business_analysis),
        2
    ) AS gr_reversal_rate_pct,

    (SELECT SUM(payment_block_handling_flag) FROM vw_case_business_analysis)
        AS payment_block_handling_cases,

    ROUND(
        100.0 *
        (SELECT AVG(payment_block_handling_flag) FROM vw_case_business_analysis),
        2
    ) AS payment_block_handling_rate_pct,

    (SELECT SUM(repeated_activity_flag) FROM vw_case_business_analysis)
        AS repeated_activity_cases,

    ROUND(
        100.0 *
        (SELECT AVG(repeated_activity_flag) FROM vw_case_business_analysis),
        2
    ) AS repeated_activity_rate_pct

FROM ranked;


-- ============================================================
-- 3. PRIORITY DISTRIBUTION
-- ============================================================

SELECT
    investigation_priority,
    COUNT(*) AS cases,
    ROUND(
        100.0 * COUNT(*) /
        SUM(COUNT(*)) OVER (),
        2
    ) AS case_share_pct
FROM vw_case_business_analysis
GROUP BY investigation_priority
ORDER BY FIELD(investigation_priority, 'Low', 'Medium', 'High');


-- ============================================================
-- 4. HIGHEST-PRIORITY CASES
-- ============================================================

SELECT
    case_id,
    vendor,
    spend_area,
    document_type,
    item_category,
    ROUND(cycle_time_days_raw, 2) AS cycle_time_days,
    event_count,
    unique_activity_count,
    unique_resource_count,
    resource_handoff_count,
    po_modification_flag,
    po_intervention_flag,
    invoice_reversal_flag,
    gr_reversal_flag,
    payment_block_handling_flag,
    repeated_activity_flag,
    long_cycle_flag,
    high_handoff_flag,
    exception_signal_count,
    investigation_priority_score,
    investigation_priority,
    variant_id
FROM vw_case_business_analysis
WHERE investigation_priority = 'High'
ORDER BY
    investigation_priority_score DESC,
    cycle_time_days_raw DESC
LIMIT 500;


-- ============================================================
-- 5. VENDOR ANALYSIS — COUNT AND RATE
-- ============================================================

WITH ranked AS (
    SELECT
        vendor,
        cycle_time_days_raw,
        ROW_NUMBER() OVER (
            PARTITION BY vendor
            ORDER BY cycle_time_days_raw
        ) AS rn,
        COUNT(*) OVER (
            PARTITION BY vendor
        ) AS n
    FROM vw_case_business_analysis
),
medians AS (
    SELECT
        vendor,
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
    GROUP BY vendor
),
vendor_summary AS (
    SELECT
        vendor,
        COUNT(*) AS cases,
        SUM(exception_signal_count > 0) AS exception_cases,
        AVG(exception_signal_count > 0) AS exception_rate,
        AVG(long_cycle_flag) AS long_cycle_rate,
        AVG(po_modification_flag) AS po_modification_rate,
        AVG(invoice_reversal_flag) AS invoice_reversal_rate,
        AVG(gr_reversal_flag) AS gr_reversal_rate,
        AVG(payment_block_handling_flag) AS payment_block_handling_rate
    FROM vw_case_business_analysis
    GROUP BY vendor
)
SELECT
    v.vendor,
    v.cases,
    v.exception_cases,
    ROUND(100.0 * v.exception_rate, 2) AS exception_rate_pct,
    ROUND(m.median_cycle_days, 2) AS median_cycle_days,
    ROUND(100.0 * v.long_cycle_rate, 2) AS long_cycle_rate_pct,
    ROUND(100.0 * v.po_modification_rate, 2) AS po_modification_rate_pct,
    ROUND(100.0 * v.invoice_reversal_rate, 2) AS invoice_reversal_rate_pct,
    ROUND(100.0 * v.gr_reversal_rate, 2) AS gr_reversal_rate_pct,
    ROUND(
        100.0 * v.payment_block_handling_rate,
        2
    ) AS payment_block_handling_rate_pct
FROM vendor_summary v
JOIN medians m
    ON v.vendor <=> m.vendor
WHERE v.cases >= 100
ORDER BY
    exception_rate_pct DESC,
    v.cases DESC;


-- ============================================================
-- 6. VENDORS CONTRIBUTING MOST EXCEPTION CASES
-- ============================================================

SELECT
    vendor,
    COUNT(*) AS cases,
    SUM(exception_signal_count > 0) AS exception_cases,
    ROUND(
        100.0 * AVG(exception_signal_count > 0),
        2
    ) AS exception_rate_pct
FROM vw_case_business_analysis
GROUP BY vendor
ORDER BY exception_cases DESC
LIMIT 50;


-- ============================================================
-- 7. VENDOR PARETO
-- ============================================================

WITH vendor_summary AS (
    SELECT
        vendor,
        SUM(exception_signal_count > 0) AS exception_cases
    FROM vw_case_business_analysis
    GROUP BY vendor
),
ranked AS (
    SELECT
        vendor,
        exception_cases,
        SUM(exception_cases) OVER (
            ORDER BY exception_cases DESC, vendor
            ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
        ) AS cumulative_exception_cases,
        SUM(exception_cases) OVER () AS total_exception_cases,
        ROW_NUMBER() OVER (
            ORDER BY exception_cases DESC, vendor
        ) AS vendor_rank
    FROM vendor_summary
)
SELECT
    vendor,
    exception_cases,
    cumulative_exception_cases,
    ROUND(
        100.0 * cumulative_exception_cases /
        NULLIF(total_exception_cases, 0),
        2
    ) AS cumulative_exception_share_pct,
    vendor_rank
FROM ranked
ORDER BY vendor_rank;

WITH vendor_summary AS (
    SELECT
        vendor,
        SUM(exception_signal_count > 0) AS exception_cases
    FROM vw_case_business_analysis
    GROUP BY vendor
),
ranked AS (
    SELECT
        ROW_NUMBER() OVER (
            ORDER BY exception_cases DESC, vendor
        ) AS vendor_rank,
        100.0 *
        SUM(exception_cases) OVER (
            ORDER BY exception_cases DESC, vendor
            ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
        ) /
        NULLIF(SUM(exception_cases) OVER (), 0)
            AS cumulative_exception_share_pct
    FROM vendor_summary
)
SELECT
    MIN(vendor_rank) AS vendors_to_reach_80pct
FROM ranked
WHERE cumulative_exception_share_pct >= 80;


-- ============================================================
-- 8. SPEND AREA PERFORMANCE
-- ============================================================

WITH ranked AS (
    SELECT
        spend_area,
        cycle_time_days_raw,
        ROW_NUMBER() OVER (
            PARTITION BY spend_area
            ORDER BY cycle_time_days_raw
        ) AS rn,
        COUNT(*) OVER (
            PARTITION BY spend_area
        ) AS n
    FROM vw_case_business_analysis
),
medians AS (
    SELECT
        spend_area,
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
    GROUP BY spend_area
),
agg AS (
    SELECT
        spend_area,
        COUNT(*) AS cases,
        AVG(exception_signal_count > 0) AS exception_rate,
        AVG(long_cycle_flag) AS long_cycle_rate,
        AVG(po_modification_flag) AS po_modification_rate,
        AVG(invoice_reversal_flag) AS invoice_reversal_rate,
        AVG(gr_reversal_flag) AS gr_reversal_rate,
        AVG(payment_block_handling_flag) AS payment_block_handling_rate,
        SUM(investigation_priority = 'High') AS high_priority_cases
    FROM vw_case_business_analysis
    GROUP BY spend_area
)
SELECT
    a.spend_area,
    a.cases,
    ROUND(m.median_cycle_days, 2) AS median_cycle_days,
    ROUND(100.0 * a.exception_rate, 2) AS exception_rate_pct,
    ROUND(100.0 * a.long_cycle_rate, 2) AS long_cycle_rate_pct,
    ROUND(100.0 * a.po_modification_rate, 2) AS po_modification_rate_pct,
    ROUND(100.0 * a.invoice_reversal_rate, 2) AS invoice_reversal_rate_pct,
    ROUND(100.0 * a.gr_reversal_rate, 2) AS gr_reversal_rate_pct,
    ROUND(
        100.0 * a.payment_block_handling_rate,
        2
    ) AS payment_block_handling_rate_pct,
    a.high_priority_cases
FROM agg a
JOIN medians m
    ON a.spend_area <=> m.spend_area
ORDER BY a.cases DESC;


-- ============================================================
-- 9. DOCUMENT TYPE PERFORMANCE
-- ============================================================

WITH ranked AS (
    SELECT
        document_type,
        cycle_time_days_raw,
        ROW_NUMBER() OVER (
            PARTITION BY document_type
            ORDER BY cycle_time_days_raw
        ) AS rn,
        COUNT(*) OVER (
            PARTITION BY document_type
        ) AS n
    FROM vw_case_business_analysis
),
medians AS (
    SELECT
        document_type,
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
    GROUP BY document_type
)
SELECT
    c.document_type,
    COUNT(*) AS cases,
    ROUND(m.median_cycle_days, 2) AS median_cycle_days,
    ROUND(100.0 * AVG(c.exception_signal_count > 0), 2)
        AS exception_rate_pct,
    ROUND(100.0 * AVG(c.po_modification_flag), 2)
        AS po_modification_rate_pct,
    ROUND(100.0 * AVG(c.repeated_activity_flag), 2)
        AS repeated_activity_rate_pct,
    ROUND(100.0 * AVG(c.long_cycle_flag), 2)
        AS long_cycle_rate_pct,
    ROUND(AVG(c.resource_handoff_count), 2)
        AS avg_handoffs
FROM vw_case_business_analysis c
JOIN medians m
    ON c.document_type <=> m.document_type
GROUP BY
    c.document_type,
    m.median_cycle_days
ORDER BY cases DESC;


-- ============================================================
-- 10. PROCESS CATEGORY / MATCHING TYPE
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
    FROM vw_case_business_analysis
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
)
SELECT
    c.item_category,
    COUNT(*) AS cases,
    ROUND(
        100.0 * COUNT(*) /
        SUM(COUNT(*)) OVER (),
        2
    ) AS case_share_pct,
    ROUND(m.median_cycle_days, 2) AS median_cycle_days,
    ROUND(100.0 * AVG(c.exception_signal_count > 0), 2)
        AS exception_rate_pct,
    ROUND(100.0 * AVG(c.po_modification_flag), 2)
        AS po_modification_rate_pct,
    ROUND(100.0 * AVG(c.invoice_reversal_flag), 2)
        AS invoice_reversal_rate_pct,
    ROUND(100.0 * AVG(c.gr_reversal_flag), 2)
        AS gr_reversal_rate_pct,
    ROUND(100.0 * AVG(c.payment_block_handling_flag), 2)
        AS payment_block_handling_rate_pct,
    ROUND(AVG(c.resource_handoff_count), 2)
        AS avg_handoffs
FROM vw_case_business_analysis c
JOIN medians m
    ON c.item_category <=> m.item_category
GROUP BY
    c.item_category,
    m.median_cycle_days
ORDER BY cases DESC;


-- ============================================================
-- 11. HIGH-PRIORITY CONCENTRATION BY VENDOR
-- ============================================================

SELECT
    vendor,
    COUNT(*) AS total_cases,
    SUM(investigation_priority = 'High') AS high_priority_cases,
    ROUND(
        100.0 * AVG(investigation_priority = 'High'),
        2
    ) AS high_priority_rate_pct
FROM vw_case_business_analysis
GROUP BY vendor
HAVING COUNT(*) >= 100
ORDER BY
    high_priority_rate_pct DESC,
    high_priority_cases DESC;


-- ============================================================
-- 12. HIGH-PRIORITY CONCENTRATION BY SPEND AREA
-- ============================================================

SELECT
    spend_area,
    COUNT(*) AS total_cases,
    SUM(investigation_priority = 'High') AS high_priority_cases,
    ROUND(
        100.0 * AVG(investigation_priority = 'High'),
        2
    ) AS high_priority_rate_pct
FROM vw_case_business_analysis
GROUP BY spend_area
ORDER BY high_priority_cases DESC;


-- ============================================================
-- 13. COMPLEXITY VS CYCLE TIME BANDS
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
        event_count,
        exception_signal_count
    FROM vw_case_business_analysis
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
    ROUND(AVG(event_count), 2) AS avg_events,
    ROUND(AVG(exception_signal_count), 2) AS avg_exception_signals
FROM ranked
GROUP BY handoff_band
ORDER BY FIELD(handoff_band, '0', '1-2', '3-5', '6-10', '11+');


-- ============================================================
-- 14. FINAL MANAGEMENT INVESTIGATION TABLE
-- ============================================================

SELECT
    case_id,
    vendor,
    spend_area,
    sub_spend_area,
    document_type,
    item_category,
    purchasing_document,
    case_start,
    case_end,
    ROUND(cycle_time_days_raw, 2) AS cycle_time_days,
    event_count,
    unique_activity_count,
    unique_resource_count,
    resource_handoff_count,
    repeated_activity_count,
    po_modification_count,
    po_modification_flag,
    po_intervention_count,
    po_intervention_flag,
    invoice_reversal_count,
    invoice_reversal_flag,
    gr_reversal_count,
    gr_reversal_flag,
    payment_block_set_count,
    payment_block_set_flag,
    payment_block_remove_count,
    payment_block_remove_flag,
    payment_block_handling_flag,
    invoice_cleared_flag,
    variant_id,
    variant_case_count,
    variant_case_share_pct,
    exception_signal_count,
    long_cycle_flag,
    high_handoff_flag,
    investigation_priority_score,
    investigation_priority
FROM vw_case_business_analysis
ORDER BY
    investigation_priority_score DESC,
    cycle_time_days_raw DESC;


-- ============================================================
-- INTERPRETATION RULES
-- ============================================================
-- DO:
--   "Vendor X has a higher observed exception rate among vendors
--    with at least 100 cases."
--
--   "Higher handoffs are associated with longer observed cycle time."
--
--   "High-priority cases combine multiple review signals."
--
-- DO NOT:
--   claim vendor fault, employee fault, fraud, non-compliance,
--   causal delay, financial loss or ROI without additional evidence.
-- ============================================================
