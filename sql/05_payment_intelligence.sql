-- ============================================================
-- E-COMMERCE CUSTOMER & SALES INTELLIGENCE
-- Payment Intelligence — Method Analysis, Installments, Reconciliation
-- Author: Suriyaprasath Parameswaran
-- Dataset: Brazilian Olist E-Commerce (Kaggle)
-- Run after: 04_advanced_analytics.sql
-- ============================================================

-- ============================================================
-- SECTION 9: PAYMENT METHOD INTELLIGENCE
-- ============================================================

-- 9.1 Payment method split — volume, revenue, and avg order value
SELECT
    payment_type,
    COUNT(DISTINCT order_id)                                        AS order_count,
    ROUND(SUM(payment_value), 2)                                    AS total_payment_value,
    ROUND(AVG(payment_value), 2)                                    AS avg_payment_value,
    ROUND(COUNT(DISTINCT order_id) * 100.0
        / SUM(COUNT(DISTINCT order_id)) OVER (), 2)                 AS pct_of_orders,
    ROUND(SUM(payment_value) * 100.0
        / SUM(SUM(payment_value)) OVER (), 2)                       AS pct_of_revenue
FROM order_payments
GROUP BY payment_type
ORDER BY total_payment_value DESC;

-- 9.2 Installment analysis — how does credit usage split across order sizes?
WITH installment_buckets AS (
    SELECT
        order_id,
        payment_installments,
        payment_value,
        CASE
            WHEN payment_installments = 1  THEN '1 (full pay)'
            WHEN payment_installments <= 3 THEN '2-3 installments'
            WHEN payment_installments <= 6 THEN '4-6 installments'
            WHEN payment_installments <= 12 THEN '7-12 installments'
            ELSE '12+ installments'
        END AS installment_bucket
    FROM order_payments
    WHERE payment_type = 'credit_card'
)
SELECT
    installment_bucket,
    COUNT(DISTINCT order_id)                                            AS order_count,
    ROUND(AVG(payment_value), 2)                                        AS avg_order_value,
    ROUND(MIN(payment_value), 2)                                        AS min_order_value,
    ROUND(MAX(payment_value), 2)                                        AS max_order_value,
    ROUND(SUM(payment_value), 2)                                        AS total_revenue,
    ROUND(COUNT(DISTINCT order_id) * 100.0
        / SUM(COUNT(DISTINCT order_id)) OVER (), 2)                     AS pct_of_cc_orders
FROM installment_buckets
GROUP BY installment_bucket
ORDER BY
    CASE installment_bucket
        WHEN '1 (full pay)'      THEN 1
        WHEN '2-3 installments'  THEN 2
        WHEN '4-6 installments'  THEN 3
        WHEN '7-12 installments' THEN 4
        ELSE 5
    END;

-- 9.3 Payment method vs review score — does how you pay affect satisfaction?
SELECT
    op.payment_type,
    COUNT(DISTINCT r.order_id)          AS reviewed_orders,
    ROUND(AVG(r.review_score), 3)       AS avg_review_score,
    COUNT(*) FILTER (
        WHERE r.review_score >= 4
    )                                   AS positive_reviews,
    COUNT(*) FILTER (
        WHERE r.review_score <= 2
    )                                   AS negative_reviews,
    ROUND(COUNT(*) FILTER (WHERE r.review_score <= 2)
        * 100.0 / NULLIF(COUNT(*), 0), 2) AS pct_negative
FROM order_payments op
JOIN order_reviews r ON op.order_id = r.order_id
GROUP BY op.payment_type
HAVING COUNT(DISTINCT r.order_id) > 100     -- filter out noise
ORDER BY avg_review_score DESC;

-- 9.4 Multi-payment orders — same order paid across multiple methods
-- (e.g. voucher + credit card split)
WITH payment_method_count AS (
    SELECT
        order_id,
        COUNT(DISTINCT payment_type)    AS distinct_payment_types,
        STRING_AGG(DISTINCT payment_type, ' + ' ORDER BY payment_type) AS payment_combination,
        ROUND(SUM(payment_value), 2)    AS total_paid,
        MAX(payment_installments)       AS max_installments
    FROM order_payments
    GROUP BY order_id
)
SELECT
    payment_combination,
    COUNT(*)                            AS order_count,
    ROUND(AVG(total_paid), 2)           AS avg_order_value,
    ROUND(COUNT(*) * 100.0
        / SUM(COUNT(*)) OVER (), 2)     AS pct_of_orders
FROM payment_method_count
GROUP BY payment_combination
ORDER BY order_count DESC;

-- 9.5 Payment value vs order item total — reconciliation check
-- Flags orders where what was paid ≠ what was charged
WITH order_totals AS (
    SELECT
        order_id,
        ROUND(SUM(price + freight_value), 2) AS charged_total
    FROM order_items
    GROUP BY order_id
),
payment_totals AS (
    SELECT
        order_id,
        ROUND(SUM(payment_value), 2)    AS paid_total
    FROM order_payments
    GROUP BY order_id
),
reconciliation AS (
    SELECT
        ot.order_id,
        ot.charged_total,
        pt.paid_total,
        ROUND(pt.paid_total - ot.charged_total, 2)  AS variance,
        ABS(ROUND(pt.paid_total - ot.charged_total, 2)) AS abs_variance
    FROM order_totals ot
    JOIN payment_totals pt ON ot.order_id = pt.order_id
)
SELECT
    COUNT(*)                                                    AS total_orders,
    COUNT(*) FILTER (WHERE abs_variance = 0)                    AS exact_match,
    COUNT(*) FILTER (WHERE abs_variance > 0 AND abs_variance <= 0.01) AS rounding_diff,
    COUNT(*) FILTER (WHERE abs_variance > 0.01)                 AS material_mismatch,
    ROUND(AVG(abs_variance) FILTER (WHERE abs_variance > 0), 2) AS avg_mismatch_when_present,
    ROUND(MAX(abs_variance), 2)                                  AS max_variance
FROM reconciliation;

-- 9.6 Voucher usage analysis — discount impact on order value and satisfaction
WITH voucher_orders AS (
    SELECT
        op.order_id,
        SUM(op.payment_value) FILTER (WHERE op.payment_type = 'voucher') AS voucher_amount,
        SUM(op.payment_value) FILTER (WHERE op.payment_type != 'voucher') AS non_voucher_amount,
        SUM(op.payment_value) AS total_paid,
        MAX(CASE WHEN op.payment_type = 'voucher' THEN 1 ELSE 0 END) AS used_voucher
    FROM order_payments op
    GROUP BY op.order_id
)
SELECT
    CASE WHEN used_voucher = 1 THEN 'Used Voucher' ELSE 'No Voucher' END AS voucher_usage,
    COUNT(*)                                            AS order_count,
    ROUND(AVG(total_paid), 2)                           AS avg_order_value,
    ROUND(AVG(r.review_score), 3)                       AS avg_review_score,
    ROUND(AVG(voucher_amount)
        FILTER (WHERE used_voucher = 1), 2)             AS avg_voucher_discount
FROM voucher_orders vo
JOIN order_reviews r ON vo.order_id = r.order_id
GROUP BY used_voucher
ORDER BY used_voucher DESC;

-- 9.7 High-installment risk proxy — customers splitting large purchases thin
-- Business risk: customers paying 12+ installments on small orders
SELECT
    payment_installments,
    COUNT(DISTINCT order_id)                AS order_count,
    ROUND(AVG(payment_value), 2)            AS avg_total_value,
    ROUND(AVG(payment_value
        / NULLIF(payment_installments, 0)), 2) AS avg_monthly_payment,
    ROUND(MIN(payment_value), 2)            AS min_order_value,
    COUNT(*) FILTER (
        WHERE payment_value
            / NULLIF(payment_installments, 0) < 20
    )                                       AS micro_installment_count
FROM order_payments
WHERE payment_type = 'credit_card'
  AND payment_installments > 0
GROUP BY payment_installments
HAVING COUNT(DISTINCT order_id) >= 50
ORDER BY payment_installments;

-- ============================================================
-- SECTION 10: DML — OPERATIONAL DATA MANAGEMENT
-- ============================================================

-- 10.1 Create a persistent audit table for late delivery flags
-- (demonstrates INSERT INTO + UPDATE pattern)

CREATE TABLE IF NOT EXISTS order_delivery_audit (
    order_id                VARCHAR(50) PRIMARY KEY,
    customer_state          CHAR(2),
    actual_delivery_days    NUMERIC(6,1),
    estimated_delivery_days NUMERIC(6,1),
    days_variance           NUMERIC(6,1),
    delivery_flag           VARCHAR(20),
    review_score            SMALLINT,
    flagged_at              TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- 10.2 Populate audit table — INSERT INTO from analytical query
INSERT INTO order_delivery_audit (
    order_id,
    customer_state,
    actual_delivery_days,
    estimated_delivery_days,
    days_variance,
    delivery_flag,
    review_score
)
SELECT
    o.order_id,
    c.customer_state,
    ROUND(EXTRACT(EPOCH FROM (
        o.order_delivered_customer_date - o.order_purchase_timestamp
    )) / 86400, 1),
    ROUND(EXTRACT(EPOCH FROM (
        o.order_estimated_delivery_date - o.order_purchase_timestamp
    )) / 86400, 1),
    ROUND(EXTRACT(EPOCH FROM (
        o.order_estimated_delivery_date - o.order_delivered_customer_date
    )) / 86400, 1),
    CASE
        WHEN o.order_delivered_customer_date > o.order_estimated_delivery_date
            THEN 'LATE'
        WHEN EXTRACT(EPOCH FROM (
            o.order_estimated_delivery_date - o.order_delivered_customer_date
        )) / 86400 >= 7
            THEN 'EARLY_7+'
        ELSE 'ON_TIME'
    END,
    r.review_score
FROM orders o
JOIN customers c     ON o.customer_id = c.customer_id
LEFT JOIN order_reviews r ON o.order_id = r.order_id
WHERE o.order_status = 'delivered'
  AND o.order_delivered_customer_date IS NOT NULL
ON CONFLICT (order_id) DO NOTHING;   -- safe re-run

-- 10.3 UPDATE — backfill NULL review scores in audit with median for state
UPDATE order_delivery_audit aud
SET review_score = sub.state_median_score
FROM (
    SELECT
        customer_state,
        PERCENTILE_CONT(0.5) WITHIN GROUP (
            ORDER BY review_score
        )::SMALLINT AS state_median_score
    FROM order_delivery_audit
    WHERE review_score IS NOT NULL
    GROUP BY customer_state
) sub
WHERE aud.customer_state = sub.customer_state
  AND aud.review_score IS NULL;

-- 10.4 Verify audit table — late delivery impact on satisfaction
SELECT
    delivery_flag,
    COUNT(*)                            AS order_count,
    ROUND(AVG(review_score), 3)         AS avg_review_score,
    ROUND(AVG(actual_delivery_days), 1) AS avg_delivery_days,
    ROUND(AVG(days_variance), 1)        AS avg_days_vs_estimate,
    COUNT(*) FILTER (
        WHERE review_score <= 2
    )                                   AS low_score_count,
    ROUND(COUNT(*) FILTER (WHERE review_score <= 2)
        * 100.0 / NULLIF(COUNT(*), 0), 2) AS pct_low_score
FROM order_delivery_audit
GROUP BY delivery_flag
ORDER BY avg_review_score DESC;

-- ============================================================
-- SECTION 11: STORED FUNCTION — REUSABLE DELIVERY STATUS CLASSIFIER
-- ============================================================

CREATE OR REPLACE FUNCTION get_delivery_status(
    delivered_date  TIMESTAMP,
    estimated_date  TIMESTAMP
)
RETURNS VARCHAR(20)
LANGUAGE plpgsql
IMMUTABLE
AS $$
BEGIN
    IF delivered_date IS NULL THEN
        RETURN 'PENDING';
    ELSIF delivered_date > estimated_date THEN
        RETURN 'LATE';
    ELSIF estimated_date - delivered_date >= INTERVAL '7 days' THEN
        RETURN 'EARLY_7+';
    ELSE
        RETURN 'ON_TIME';
    END IF;
END;
$$;

-- Usage example — replace inline CASE WHEN with function call
SELECT
    order_id,
    get_delivery_status(
        order_delivered_customer_date,
        order_estimated_delivery_date
    ) AS delivery_status
FROM orders
WHERE order_status = 'delivered'
LIMIT 20;

-- ============================================================
-- SECTION 12: CORRECTED RFM — HANDLES FREQUENCY SKEW
-- ============================================================
-- Fix: ~96% of Olist customers buy exactly once.
-- NTILE(5) on frequency = 1 produces random scores.
-- Solution: explicit bucketing on actual frequency values.

WITH customer_metrics AS (
    SELECT
        c.customer_unique_id,
        c.customer_state,
        COUNT(DISTINCT o.order_id)                              AS frequency,
        ROUND(SUM(oi.price), 2)                                 AS monetary_value,
        CURRENT_DATE - MAX(o.order_purchase_timestamp)::DATE    AS recency_days
    FROM customers c
    JOIN orders o       ON c.customer_id  = o.customer_id
    JOIN order_items oi ON o.order_id     = oi.order_id
    WHERE o.order_status = 'delivered'
    GROUP BY c.customer_unique_id, c.customer_state
),
rfm_scores AS (
    SELECT *,
        -- Recency: NTILE works fine (continuous distribution)
        NTILE(5) OVER (ORDER BY recency_days DESC)          AS r_score,

        -- Frequency: explicit buckets — NTILE breaks when 96% of values = 1
        CASE
            WHEN frequency = 1 THEN 1
            WHEN frequency = 2 THEN 2
            WHEN frequency = 3 THEN 3
            WHEN frequency BETWEEN 4 AND 6 THEN 4
            ELSE 5
        END                                                 AS f_score,

        -- Monetary: NTILE works (continuous), but exclude top 1% outliers from distorting
        NTILE(5) OVER (
            ORDER BY LEAST(monetary_value,
                PERCENTILE_CONT(0.99) WITHIN GROUP (
                    ORDER BY monetary_value
                ) OVER ()
            )
        )                                                   AS m_score
    FROM customer_metrics
)
SELECT
    customer_unique_id,
    customer_state,
    frequency,
    monetary_value,
    recency_days,
    r_score,
    f_score,
    m_score,
    (r_score + f_score + m_score)                           AS rfm_total,
    CASE
        WHEN (r_score + f_score + m_score) >= 13 THEN 'Champions'
        WHEN (r_score + f_score + m_score) >= 10 THEN 'Loyal Customers'
        WHEN (r_score + f_score + m_score) >= 7  THEN 'Potential Loyalists'
        WHEN r_score >= 4 AND (f_score + m_score) <= 4 THEN 'New Customers'
        WHEN r_score <= 2 AND (f_score + m_score) >= 8 THEN 'At Risk'
        WHEN r_score <= 2 AND (f_score + m_score) >= 5 THEN 'Cant Lose Them'
        ELSE 'Lost'
    END                                                     AS customer_segment
FROM rfm_scores
ORDER BY rfm_total DESC;