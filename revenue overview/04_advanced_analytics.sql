-- ============================================================
-- E-COMMERCE CUSTOMER & SALES INTELLIGENCE
-- Advanced Business Analytics — Window Functions, CTEs, Cohorts
-- Author: Suriyaprasath Parameswaran
-- ============================================================

-- ============================================================
-- SECTION 3: TIME-SERIES REVENUE ANALYSIS
-- ============================================================

-- 3.1 Monthly revenue with MoM growth using LAG()
WITH monthly_revenue AS (
    SELECT
        DATE_TRUNC('month', o.order_purchase_timestamp) AS revenue_month,
        ROUND(SUM(oi.price), 2)                         AS gross_revenue,
        COUNT(DISTINCT o.order_id)                      AS total_orders,
        COUNT(DISTINCT o.customer_id)                   AS unique_customers
    FROM orders o
    JOIN order_items oi ON o.order_id = oi.order_id
    WHERE o.order_status = 'delivered'
    GROUP BY revenue_month
)
SELECT
    TO_CHAR(revenue_month, 'YYYY-MM')               AS month,
    gross_revenue,
    total_orders,
    unique_customers,
    LAG(gross_revenue) OVER (ORDER BY revenue_month) AS prev_month_revenue,
    ROUND(
        (gross_revenue - LAG(gross_revenue) OVER (ORDER BY revenue_month))
        / NULLIF(LAG(gross_revenue) OVER (ORDER BY revenue_month), 0) * 100, 2
    )                                               AS mom_growth_pct,
    ROUND(AVG(gross_revenue) OVER (
        ORDER BY revenue_month
        ROWS BETWEEN 2 PRECEDING AND CURRENT ROW
    ), 2)                                           AS rolling_3m_avg_revenue
FROM monthly_revenue
ORDER BY revenue_month;

-- 3.2 Day-of-week order patterns (operational insight)
SELECT
    TO_CHAR(order_purchase_timestamp, 'Day')    AS day_of_week,
    EXTRACT(DOW FROM order_purchase_timestamp)  AS dow_num,
    COUNT(*)                                    AS total_orders,
    ROUND(AVG(oi.price), 2)                     AS avg_order_value
FROM orders o
JOIN order_items oi ON o.order_id = oi.order_id
WHERE o.order_status = 'delivered'
GROUP BY day_of_week, dow_num
ORDER BY dow_num;

-- ============================================================
-- SECTION 4: CUSTOMER LIFETIME VALUE & SEGMENTATION
-- ============================================================

-- 4.1 Customer LTV with RFM scoring using window functions
WITH customer_metrics AS (
    SELECT
        c.customer_unique_id,
        c.customer_state,
        COUNT(DISTINCT o.order_id)                          AS frequency,
        ROUND(SUM(oi.price), 2)                             AS monetary_value,
        MAX(o.order_purchase_timestamp)::DATE               AS last_purchase_date,
        MIN(o.order_purchase_timestamp)::DATE               AS first_purchase_date,
        CURRENT_DATE - MAX(o.order_purchase_timestamp)::DATE AS recency_days
    FROM customers c
    JOIN orders o       ON c.customer_id  = o.customer_id
    JOIN order_items oi ON o.order_id     = oi.order_id
    WHERE o.order_status = 'delivered'
    GROUP BY c.customer_unique_id, c.customer_state
),
rfm_scores AS (
    SELECT *,
        NTILE(5) OVER (ORDER BY recency_days DESC)      AS r_score,
        NTILE(5) OVER (ORDER BY frequency ASC)          AS f_score,
        NTILE(5) OVER (ORDER BY monetary_value ASC)     AS m_score
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
    (r_score + f_score + m_score)                       AS rfm_total,
    CASE
        WHEN (r_score + f_score + m_score) >= 13 THEN 'Champions'
        WHEN (r_score + f_score + m_score) >= 10 THEN 'Loyal Customers'
        WHEN (r_score + f_score + m_score) >= 7  THEN 'Potential Loyalists'
        WHEN r_score >= 4 AND (f_score + m_score) <= 4 THEN 'New Customers'
        WHEN r_score <= 2 AND (f_score + m_score) >= 8 THEN 'At Risk'
        WHEN r_score <= 2 AND (f_score + m_score) >= 5 THEN 'Cant Lose Them'
        ELSE 'Lost'
    END                                                 AS customer_segment
FROM rfm_scores
ORDER BY rfm_total DESC;

-- 4.2 Customer segment summary (for dashboard KPI cards)
WITH customer_metrics AS (
    SELECT
        c.customer_unique_id,
        COUNT(DISTINCT o.order_id)                          AS frequency,
        ROUND(SUM(oi.price), 2)                             AS monetary_value,
        CURRENT_DATE - MAX(o.order_purchase_timestamp)::DATE AS recency_days
    FROM customers c
    JOIN orders o       ON c.customer_id  = o.customer_id
    JOIN order_items oi ON o.order_id     = oi.order_id
    WHERE o.order_status = 'delivered'
    GROUP BY c.customer_unique_id
),
rfm_scores AS (
    SELECT *,
        NTILE(5) OVER (ORDER BY recency_days DESC)  AS r_score,
        NTILE(5) OVER (ORDER BY frequency ASC)      AS f_score,
        NTILE(5) OVER (ORDER BY monetary_value ASC) AS m_score
    FROM customer_metrics
),
segments AS (
    SELECT *,
        CASE
            WHEN (r_score + f_score + m_score) >= 13 THEN 'Champions'
            WHEN (r_score + f_score + m_score) >= 10 THEN 'Loyal Customers'
            WHEN (r_score + f_score + m_score) >= 7  THEN 'Potential Loyalists'
            WHEN r_score >= 4 AND (f_score + m_score) <= 4 THEN 'New Customers'
            WHEN r_score <= 2 AND (f_score + m_score) >= 8 THEN 'At Risk'
            WHEN r_score <= 2 AND (f_score + m_score) >= 5 THEN 'Cant Lose Them'
            ELSE 'Lost'
        END AS customer_segment
    FROM rfm_scores
)
SELECT
    customer_segment,
    COUNT(*)                            AS customer_count,
    ROUND(AVG(monetary_value), 2)       AS avg_ltv,
    ROUND(SUM(monetary_value), 2)       AS total_segment_revenue,
    ROUND(AVG(recency_days), 0)         AS avg_recency_days,
    ROUND(AVG(frequency), 2)            AS avg_orders_per_customer
FROM segments
GROUP BY customer_segment
ORDER BY total_segment_revenue DESC;

-- 4.3 Top 10% customers by LTV (revenue concentration check)
WITH customer_revenue AS (
    SELECT
        c.customer_unique_id,
        ROUND(SUM(oi.price), 2) AS total_spend,
        NTILE(10) OVER (ORDER BY SUM(oi.price)) AS decile
    FROM customers c
    JOIN orders o       ON c.customer_id  = o.customer_id
    JOIN order_items oi ON o.order_id     = oi.order_id
    WHERE o.order_status = 'delivered'
    GROUP BY c.customer_unique_id
)
SELECT
    decile,
    COUNT(*)                                        AS customer_count,
    ROUND(SUM(total_spend), 2)                      AS decile_revenue,
    ROUND(SUM(total_spend) * 100.0
        / SUM(SUM(total_spend)) OVER (), 2)         AS pct_of_total_revenue
FROM customer_revenue
GROUP BY decile
ORDER BY decile DESC;

-- ============================================================
-- SECTION 5: COHORT RETENTION ANALYSIS
-- ============================================================

-- 5.1 Monthly acquisition cohort — retention matrix
WITH first_purchase AS (
    SELECT
        c.customer_unique_id,
        DATE_TRUNC('month', MIN(o.order_purchase_timestamp)) AS cohort_month
    FROM customers c
    JOIN orders o ON c.customer_id = o.customer_id
    WHERE o.order_status = 'delivered'
    GROUP BY c.customer_unique_id
),
customer_activity AS (
    SELECT
        c.customer_unique_id,
        DATE_TRUNC('month', o.order_purchase_timestamp) AS activity_month
    FROM customers c
    JOIN orders o ON c.customer_id = o.customer_id
    WHERE o.order_status = 'delivered'
),
cohort_data AS (
    SELECT
        fp.cohort_month,
        ca.activity_month,
        COUNT(DISTINCT ca.customer_unique_id) AS active_customers,
        EXTRACT(YEAR FROM AGE(ca.activity_month, fp.cohort_month)) * 12
        + EXTRACT(MONTH FROM AGE(ca.activity_month, fp.cohort_month)) AS months_since_acquisition
    FROM first_purchase fp
    JOIN customer_activity ca ON fp.customer_unique_id = ca.customer_unique_id
    GROUP BY fp.cohort_month, ca.activity_month, months_since_acquisition
),
cohort_sizes AS (
    SELECT cohort_month, COUNT(DISTINCT customer_unique_id) AS cohort_size
    FROM first_purchase
    GROUP BY cohort_month
)
SELECT
    TO_CHAR(cd.cohort_month, 'YYYY-MM')         AS cohort,
    cs.cohort_size,
    cd.months_since_acquisition                  AS period,
    cd.active_customers,
    ROUND(cd.active_customers * 100.0
        / cs.cohort_size, 2)                     AS retention_rate_pct
FROM cohort_data cd
JOIN cohort_sizes cs ON cd.cohort_month = cs.cohort_month
WHERE cd.months_since_acquisition BETWEEN 0 AND 11
ORDER BY cd.cohort_month, cd.months_since_acquisition;

-- 5.2 Repeat purchase rate (30 / 60 / 90 day windows)
WITH ordered_purchases AS (
    SELECT
        c.customer_unique_id,
        o.order_purchase_timestamp,
        ROW_NUMBER() OVER (
            PARTITION BY c.customer_unique_id
            ORDER BY o.order_purchase_timestamp
        ) AS purchase_rank
    FROM customers c
    JOIN orders o ON c.customer_id = o.customer_id
    WHERE o.order_status = 'delivered'
),
first_and_second AS (
    SELECT
        a.customer_unique_id,
        a.order_purchase_timestamp                              AS first_purchase,
        b.order_purchase_timestamp                              AS second_purchase,
        (b.order_purchase_timestamp - a.order_purchase_timestamp) AS days_to_repeat
    FROM ordered_purchases a
    LEFT JOIN ordered_purchases b
        ON  a.customer_unique_id = b.customer_unique_id
        AND b.purchase_rank = 2
    WHERE a.purchase_rank = 1
)
SELECT
    COUNT(*)                                                    AS total_customers,
    COUNT(second_purchase)                                      AS repeat_customers,
    ROUND(COUNT(second_purchase) * 100.0 / COUNT(*), 2)        AS overall_repeat_rate_pct,
    COUNT(*) FILTER (
        WHERE EXTRACT(EPOCH FROM days_to_repeat)/86400 <= 30
    )                                                           AS repeat_within_30d,
    COUNT(*) FILTER (
        WHERE EXTRACT(EPOCH FROM days_to_repeat)/86400 <= 60
    )                                                           AS repeat_within_60d,
    COUNT(*) FILTER (
        WHERE EXTRACT(EPOCH FROM days_to_repeat)/86400 <= 90
    )                                                           AS repeat_within_90d,
    ROUND(COUNT(*) FILTER (
        WHERE EXTRACT(EPOCH FROM days_to_repeat)/86400 <= 30
    ) * 100.0 / NULLIF(COUNT(second_purchase), 0), 2)          AS pct_repeat_within_30d
FROM first_and_second;

-- ============================================================
-- SECTION 6: SELLER PERFORMANCE INTELLIGENCE
-- ============================================================

-- 6.1 Seller scorecard — revenue, delivery, satisfaction
WITH seller_metrics AS (
    SELECT
        s.seller_id,
        s.seller_state,
        COUNT(DISTINCT oi.order_id)                         AS total_orders,
        COUNT(DISTINCT oi.product_id)                       AS unique_products,
        ROUND(SUM(oi.price), 2)                             AS gross_revenue,
        ROUND(AVG(oi.price), 2)                             AS avg_item_price,
        ROUND(AVG(
            EXTRACT(EPOCH FROM (
                o.order_delivered_customer_date - o.order_purchase_timestamp
            )) / 86400
        ), 1)                                               AS avg_delivery_days,
        ROUND(AVG(
            EXTRACT(EPOCH FROM (
                o.order_estimated_delivery_date - o.order_delivered_customer_date
            )) / 86400
        ), 1)                                               AS avg_days_vs_estimate,
        COUNT(*) FILTER (
            WHERE o.order_delivered_customer_date > o.order_estimated_delivery_date
        )                                                   AS late_deliveries,
        ROUND(COUNT(*) FILTER (
            WHERE o.order_delivered_customer_date > o.order_estimated_delivery_date
        ) * 100.0 / NULLIF(COUNT(*), 0), 2)                AS late_delivery_rate_pct
    FROM sellers s
    JOIN order_items oi  ON s.seller_id  = oi.seller_id
    JOIN orders o        ON oi.order_id  = o.order_id
    WHERE o.order_status = 'delivered'
      AND o.order_delivered_customer_date IS NOT NULL
    GROUP BY s.seller_id, s.seller_state
),
seller_reviews AS (
    SELECT
        oi.seller_id,
        ROUND(AVG(r.review_score), 2) AS avg_review_score,
        COUNT(r.review_id)            AS total_reviews
    FROM order_items oi
    JOIN order_reviews r ON oi.order_id = r.order_id
    GROUP BY oi.seller_id
)
SELECT
    sm.*,
    sr.avg_review_score,
    sr.total_reviews,
    RANK() OVER (ORDER BY sm.gross_revenue DESC)            AS revenue_rank,
    RANK() OVER (ORDER BY sr.avg_review_score DESC)         AS satisfaction_rank,
    RANK() OVER (ORDER BY sm.late_delivery_rate_pct ASC)    AS delivery_rank
FROM seller_metrics sm
LEFT JOIN seller_reviews sr ON sm.seller_id = sr.seller_id
ORDER BY gross_revenue DESC
LIMIT 50;

-- 6.2 Delivery performance — actual vs estimated by state
SELECT
    c.customer_state,
    COUNT(*)                            AS delivered_orders,
    ROUND(AVG(
        EXTRACT(EPOCH FROM (
            o.order_delivered_customer_date - o.order_purchase_timestamp
        )) / 86400
    ), 1)                               AS avg_actual_delivery_days,
    ROUND(AVG(
        EXTRACT(EPOCH FROM (
            o.order_estimated_delivery_date - o.order_purchase_timestamp
        )) / 86400
    ), 1)                               AS avg_estimated_delivery_days,
    ROUND(AVG(
        EXTRACT(EPOCH FROM (
            o.order_estimated_delivery_date - o.order_delivered_customer_date
        )) / 86400
    ), 1)                               AS avg_days_early_positive,
    COUNT(*) FILTER (
        WHERE o.order_delivered_customer_date > o.order_estimated_delivery_date
    )                                   AS late_count,
    ROUND(COUNT(*) FILTER (
        WHERE o.order_delivered_customer_date > o.order_estimated_delivery_date
    ) * 100.0 / COUNT(*), 2)            AS late_pct
FROM orders o
JOIN customers c ON o.customer_id = c.customer_id
WHERE o.order_status = 'delivered'
  AND o.order_delivered_customer_date IS NOT NULL
GROUP BY c.customer_state
ORDER BY late_pct DESC;

-- ============================================================
-- SECTION 7: PRODUCT & CATEGORY INTELLIGENCE
-- ============================================================

-- 7.1 Category performance with running revenue share
WITH category_revenue AS (
    SELECT
        COALESCE(t.product_category_name_english, 'Unknown') AS category,
        COUNT(DISTINCT oi.order_id)     AS total_orders,
        ROUND(SUM(oi.price), 2)         AS gross_revenue,
        ROUND(AVG(r.review_score), 2)   AS avg_review_score
    FROM order_items oi
    JOIN orders o        ON oi.order_id  = o.order_id
    JOIN products p      ON oi.product_id = p.product_id
    LEFT JOIN product_category_translation t
                         ON p.product_category_name = t.product_category_name
    LEFT JOIN order_reviews r ON oi.order_id = r.order_id
    WHERE o.order_status = 'delivered'
    GROUP BY category
)
SELECT
    category,
    total_orders,
    gross_revenue,
    avg_review_score,
    ROUND(gross_revenue * 100.0
        / SUM(gross_revenue) OVER (), 2)            AS revenue_share_pct,
    ROUND(SUM(gross_revenue) OVER (
        ORDER BY gross_revenue DESC
        ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
    ) * 100.0 / SUM(gross_revenue) OVER (), 2)      AS cumulative_revenue_pct
FROM category_revenue
ORDER BY gross_revenue DESC;

-- 7.2 Review score distribution and its impact on reorders
SELECT
    r.review_score,
    COUNT(DISTINCT r.order_id)                      AS order_count,
    ROUND(AVG(oi.price), 2)                         AS avg_order_value,
    ROUND(COUNT(DISTINCT r.order_id) * 100.0
        / SUM(COUNT(DISTINCT r.order_id)) OVER (), 2) AS pct_of_reviews
FROM order_reviews r
JOIN order_items oi ON r.order_id = oi.order_id
GROUP BY r.review_score
ORDER BY r.review_score DESC;

-- ============================================================
-- SECTION 8: BUSINESS INSIGHT VIEWS (for Power BI)
-- ============================================================

-- View 1: Master fact table for Power BI import
CREATE OR REPLACE VIEW vw_order_master AS
SELECT
    o.order_id,
    o.order_status,
    o.order_purchase_timestamp,
    o.order_delivered_customer_date,
    o.order_estimated_delivery_date,
    DATE_TRUNC('month', o.order_purchase_timestamp)     AS order_month,
    EXTRACT(YEAR  FROM o.order_purchase_timestamp)      AS order_year,
    EXTRACT(MONTH FROM o.order_purchase_timestamp)      AS order_month_num,
    EXTRACT(DOW   FROM o.order_purchase_timestamp)      AS order_dow,
    c.customer_unique_id,
    c.customer_state,
    c.customer_city,
    oi.product_id,
    oi.seller_id,
    oi.price,
    oi.freight_value,
    oi.price + oi.freight_value                         AS total_item_value,
    COALESCE(t.product_category_name_english, 'Unknown') AS product_category,
    s.seller_state,
    r.review_score,
    CASE
        WHEN o.order_delivered_customer_date > o.order_estimated_delivery_date
        THEN 'Late'
        WHEN o.order_delivered_customer_date IS NULL THEN 'Pending'
        ELSE 'On Time'
    END                                                 AS delivery_status,
    EXTRACT(EPOCH FROM (
        o.order_delivered_customer_date - o.order_purchase_timestamp
    )) / 86400                                          AS actual_delivery_days
FROM orders o
JOIN customers c    ON o.customer_id   = c.customer_id
JOIN order_items oi ON o.order_id      = oi.order_id
JOIN products p     ON oi.product_id   = p.product_id
JOIN sellers s      ON oi.seller_id    = s.seller_id
LEFT JOIN product_category_translation t
                    ON p.product_category_name = t.product_category_name
LEFT JOIN order_reviews r ON o.order_id = r.order_id;

-- View 2: RFM segments for Power BI customer page
CREATE OR REPLACE VIEW vw_customer_segments AS
WITH customer_metrics AS (
    SELECT
        c.customer_unique_id,
        c.customer_state,
        COUNT(DISTINCT o.order_id)                          AS frequency,
        ROUND(SUM(oi.price), 2)                             AS monetary_value,
        CURRENT_DATE - MAX(o.order_purchase_timestamp)::DATE AS recency_days
    FROM customers c
    JOIN orders o       ON c.customer_id  = o.customer_id
    JOIN order_items oi ON o.order_id     = oi.order_id
    WHERE o.order_status = 'delivered'
    GROUP BY c.customer_unique_id, c.customer_state
),
rfm AS (
    SELECT *,
        NTILE(5) OVER (ORDER BY recency_days DESC)  AS r_score,
        NTILE(5) OVER (ORDER BY frequency ASC)      AS f_score,
        NTILE(5) OVER (ORDER BY monetary_value ASC) AS m_score
    FROM customer_metrics
)
SELECT *,
    CASE
        WHEN (r_score + f_score + m_score) >= 13 THEN 'Champions'
        WHEN (r_score + f_score + m_score) >= 10 THEN 'Loyal Customers'
        WHEN (r_score + f_score + m_score) >= 7  THEN 'Potential Loyalists'
        WHEN r_score >= 4 AND (f_score + m_score) <= 4 THEN 'New Customers'
        WHEN r_score <= 2 AND (f_score + m_score) >= 8 THEN 'At Risk'
        WHEN r_score <= 2 AND (f_score + m_score) >= 5 THEN 'Cant Lose Them'
        ELSE 'Lost'
    END AS customer_segment
FROM rfm;

-- View 3: Monthly cohort retention for Power BI heatmap
CREATE OR REPLACE VIEW vw_cohort_retention AS
WITH first_purchase AS (
    SELECT
        c.customer_unique_id,
        DATE_TRUNC('month', MIN(o.order_purchase_timestamp)) AS cohort_month
    FROM customers c
    JOIN orders o ON c.customer_id = o.customer_id
    WHERE o.order_status = 'delivered'
    GROUP BY c.customer_unique_id
),
activity AS (
    SELECT
        c.customer_unique_id,
        DATE_TRUNC('month', o.order_purchase_timestamp) AS activity_month
    FROM customers c
    JOIN orders o ON c.customer_id = o.customer_id
    WHERE o.order_status = 'delivered'
),
cohort_sizes AS (
    SELECT cohort_month, COUNT(DISTINCT customer_unique_id) AS cohort_size
    FROM first_purchase GROUP BY cohort_month
)
SELECT
    TO_CHAR(fp.cohort_month, 'YYYY-MM')                 AS cohort,
    cs.cohort_size,
    EXTRACT(YEAR FROM AGE(a.activity_month, fp.cohort_month)) * 12
    + EXTRACT(MONTH FROM AGE(a.activity_month, fp.cohort_month)) AS period_number,
    COUNT(DISTINCT a.customer_unique_id)                AS active_customers,
    ROUND(COUNT(DISTINCT a.customer_unique_id) * 100.0
        / cs.cohort_size, 2)                            AS retention_pct
FROM first_purchase fp
JOIN activity a         ON fp.customer_unique_id = a.customer_unique_id
JOIN cohort_sizes cs    ON fp.cohort_month = cs.cohort_month
WHERE EXTRACT(YEAR FROM AGE(a.activity_month, fp.cohort_month)) * 12
    + EXTRACT(MONTH FROM AGE(a.activity_month, fp.cohort_month)) BETWEEN 0 AND 11
GROUP BY fp.cohort_month, cs.cohort_size, period_number
ORDER BY fp.cohort_month, period_number;