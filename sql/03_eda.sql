-- ============================================================
-- E-COMMERCE CUSTOMER & SALES INTELLIGENCE
-- Exploratory Data Analysis — Data Quality & Business Overview
-- Author: Suriyaprasath Parameswaran
-- Dataset: Brazilian Olist E-Commerce (Kaggle)
-- Run after: 01_schema.sql → 02_load_data.sql
-- ============================================================

-- ============================================================
-- SECTION 1: ROW COUNTS & TABLE INVENTORY
-- ============================================================

SELECT
    table_name,
    to_regclass(table_name)                         AS exists_check,
    (SELECT COUNT(*) FROM customers)                AS customers,
    (SELECT COUNT(*) FROM sellers)                  AS sellers,
    (SELECT COUNT(*) FROM products)                 AS products,
    (SELECT COUNT(*) FROM orders)                   AS orders,
    (SELECT COUNT(*) FROM order_items)              AS order_items,
    (SELECT COUNT(*) FROM order_payments)           AS order_payments,
    (SELECT COUNT(*) FROM order_reviews)            AS order_reviews,
    (SELECT COUNT(*) FROM geolocation)              AS geolocation
FROM (SELECT 'row_counts' AS table_name) t;

-- Cleaner version — one row per table for easy scanning
SELECT 'customers'       AS table_name, COUNT(*) AS row_count FROM customers     UNION ALL
SELECT 'sellers',                        COUNT(*) FROM sellers                    UNION ALL
SELECT 'products',                       COUNT(*) FROM products                   UNION ALL
SELECT 'orders',                         COUNT(*) FROM orders                     UNION ALL
SELECT 'order_items',                    COUNT(*) FROM order_items                UNION ALL
SELECT 'order_payments',                 COUNT(*) FROM order_payments             UNION ALL
SELECT 'order_reviews',                  COUNT(*) FROM order_reviews              UNION ALL
SELECT 'geolocation',                    COUNT(*) FROM geolocation
ORDER BY row_count DESC;

-- ============================================================
-- SECTION 2: NULL AUDIT — EVERY KEY COLUMN, EVERY TABLE
-- ============================================================

-- 2.1 Orders table null audit
SELECT
    COUNT(*)                                                        AS total_rows,
    COUNT(*) FILTER (WHERE order_id IS NULL)                        AS null_order_id,
    COUNT(*) FILTER (WHERE customer_id IS NULL)                     AS null_customer_id,
    COUNT(*) FILTER (WHERE order_status IS NULL)                    AS null_order_status,
    COUNT(*) FILTER (WHERE order_purchase_timestamp IS NULL)        AS null_purchase_ts,
    COUNT(*) FILTER (WHERE order_approved_at IS NULL)               AS null_approved_at,
    COUNT(*) FILTER (WHERE order_delivered_carrier_date IS NULL)    AS null_carrier_date,
    COUNT(*) FILTER (WHERE order_delivered_customer_date IS NULL)   AS null_delivered_date,
    COUNT(*) FILTER (WHERE order_estimated_delivery_date IS NULL)   AS null_estimated_date,
    -- As percentages
    ROUND(COUNT(*) FILTER (WHERE order_approved_at IS NULL)
        * 100.0 / COUNT(*), 2)                                      AS pct_null_approved,
    ROUND(COUNT(*) FILTER (WHERE order_delivered_customer_date IS NULL)
        * 100.0 / COUNT(*), 2)                                      AS pct_null_delivered
FROM orders;

-- 2.2 Products null audit (product descriptions often incomplete)
SELECT
    COUNT(*)                                                            AS total_rows,
    COUNT(*) FILTER (WHERE product_category_name IS NULL)              AS null_category,
    COUNT(*) FILTER (WHERE product_name_length IS NULL)                AS null_name_length,
    COUNT(*) FILTER (WHERE product_description_length IS NULL)         AS null_desc_length,
    COUNT(*) FILTER (WHERE product_weight_g IS NULL)                   AS null_weight,
    ROUND(COUNT(*) FILTER (WHERE product_category_name IS NULL)
        * 100.0 / COUNT(*), 2)                                         AS pct_null_category,
    ROUND(COUNT(*) FILTER (WHERE product_weight_g IS NULL)
        * 100.0 / COUNT(*), 2)                                         AS pct_null_weight
FROM products;

-- 2.3 Order reviews null audit (comments are optional — expected nulls)
SELECT
    COUNT(*)                                                            AS total_rows,
    COUNT(*) FILTER (WHERE review_score IS NULL)                        AS null_score,
    COUNT(*) FILTER (WHERE review_comment_title IS NULL)                AS null_title,
    COUNT(*) FILTER (WHERE review_comment_message IS NULL)              AS null_message,
    ROUND(COUNT(*) FILTER (WHERE review_comment_message IS NULL)
        * 100.0 / COUNT(*), 2)                                          AS pct_no_comment
FROM order_reviews;

-- ============================================================
-- SECTION 3: DUPLICATE DETECTION
-- ============================================================

-- 3.1 Duplicate orders (should be zero — order_id is PK)
SELECT
    order_id,
    COUNT(*) AS occurrences
FROM orders
GROUP BY order_id
HAVING COUNT(*) > 1
ORDER BY occurrences DESC;

-- 3.2 Duplicate customers — same unique_id mapped to multiple customer_ids (expected in Olist)
SELECT
    customer_unique_id,
    COUNT(DISTINCT customer_id)     AS id_count,
    COUNT(DISTINCT customer_state)  AS states_used,
    COUNT(DISTINCT customer_city)   AS cities_used
FROM customers
GROUP BY customer_unique_id
HAVING COUNT(DISTINCT customer_id) > 1
ORDER BY id_count DESC
LIMIT 20;

-- 3.3 Geolocation duplicates — multiple coords per zip code (known Olist quirk)
SELECT
    geolocation_zip_code,
    COUNT(*)                    AS total_rows,
    COUNT(DISTINCT ROUND(geolocation_lat::NUMERIC, 4))  AS distinct_lat,
    COUNT(DISTINCT ROUND(geolocation_lng::NUMERIC, 4))  AS distinct_lng
FROM geolocation
GROUP BY geolocation_zip_code
HAVING COUNT(*) > 1
ORDER BY total_rows DESC
LIMIT 20;

-- 3.4 Order items — check for unexpected duplicate line items
SELECT
    order_id,
    order_item_id,
    COUNT(*) AS occurrences
FROM order_items
GROUP BY order_id, order_item_id
HAVING COUNT(*) > 1;

-- ============================================================
-- SECTION 4: DATE RANGE & TEMPORAL INTEGRITY
-- ============================================================

-- 4.1 Full date range of the dataset
SELECT
    MIN(order_purchase_timestamp)::DATE     AS earliest_order,
    MAX(order_purchase_timestamp)::DATE     AS latest_order,
    MAX(order_purchase_timestamp)::DATE
        - MIN(order_purchase_timestamp)::DATE AS date_span_days,
    COUNT(DISTINCT DATE_TRUNC('month', order_purchase_timestamp)) AS active_months
FROM orders;

-- 4.2 Temporal logic violations — orders with impossible timestamps
SELECT
    COUNT(*) FILTER (
        WHERE order_approved_at < order_purchase_timestamp
    )                                       AS approved_before_purchased,
    COUNT(*) FILTER (
        WHERE order_delivered_customer_date < order_delivered_carrier_date
    )                                       AS delivered_before_shipped,
    COUNT(*) FILTER (
        WHERE order_delivered_customer_date < order_purchase_timestamp
    )                                       AS delivered_before_purchased,
    COUNT(*) FILTER (
        WHERE order_estimated_delivery_date < order_purchase_timestamp
    )                                       AS estimated_before_purchased
FROM orders;

-- 4.3 Orders per month — spot any missing months or data spikes
SELECT
    TO_CHAR(DATE_TRUNC('month', order_purchase_timestamp), 'YYYY-MM') AS month,
    COUNT(*)                                                            AS order_count,
    COUNT(DISTINCT customer_id)                                         AS unique_customers,
    ROUND(COUNT(*) * 100.0
        / SUM(COUNT(*)) OVER (), 2)                                     AS pct_of_total
FROM orders
GROUP BY DATE_TRUNC('month', order_purchase_timestamp)
ORDER BY month;

-- ============================================================
-- SECTION 5: ORDER STATUS DISTRIBUTION
-- ============================================================

SELECT
    order_status,
    COUNT(*)                                                        AS order_count,
    ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (), 2)             AS pct_of_orders,
    COUNT(*) FILTER (WHERE order_delivered_customer_date IS NULL)   AS missing_delivery_date,
    ROUND(AVG(
        EXTRACT(EPOCH FROM (
            order_delivered_customer_date - order_purchase_timestamp
        )) / 86400
    ), 1)                                                           AS avg_delivery_days
FROM orders
GROUP BY order_status
ORDER BY order_count DESC;

-- ============================================================
-- SECTION 6: DISTRIBUTION ANALYSIS — KEY NUMERIC FIELDS
-- ============================================================

-- 6.1 Order value distribution — percentiles to spot outliers
SELECT
    ROUND(MIN(price), 2)                        AS min_price,
    ROUND(PERCENTILE_CONT(0.05) WITHIN GROUP (ORDER BY price)::NUMERIC, 2) AS p5,
    ROUND(PERCENTILE_CONT(0.25) WITHIN GROUP (ORDER BY price)::NUMERIC, 2) AS p25,
    ROUND(PERCENTILE_CONT(0.50) WITHIN GROUP (ORDER BY price)::NUMERIC, 2) AS median_price,
    ROUND(PERCENTILE_CONT(0.75) WITHIN GROUP (ORDER BY price)::NUMERIC, 2) AS p75,
    ROUND(PERCENTILE_CONT(0.95) WITHIN GROUP (ORDER BY price)::NUMERIC, 2) AS p95,
    ROUND(PERCENTILE_CONT(0.99) WITHIN GROUP (ORDER BY price)::NUMERIC, 2) AS p99,
    ROUND(MAX(price), 2)                        AS max_price,
    ROUND(AVG(price), 2)                        AS avg_price,
    ROUND(STDDEV(price)::NUMERIC, 2)            AS std_dev_price,
    COUNT(*) FILTER (WHERE price <= 0)          AS zero_or_negative_price
FROM order_items;

-- 6.2 Freight value distribution
SELECT
    ROUND(MIN(freight_value), 2)                AS min_freight,
    ROUND(PERCENTILE_CONT(0.50) WITHIN GROUP (ORDER BY freight_value)::NUMERIC, 2) AS median_freight,
    ROUND(PERCENTILE_CONT(0.95) WITHIN GROUP (ORDER BY freight_value)::NUMERIC, 2) AS p95_freight,
    ROUND(MAX(freight_value), 2)                AS max_freight,
    ROUND(AVG(freight_value), 2)                AS avg_freight,
    COUNT(*) FILTER (WHERE freight_value = 0)   AS free_shipping_count,
    ROUND(COUNT(*) FILTER (WHERE freight_value = 0)
        * 100.0 / COUNT(*), 2)                  AS pct_free_shipping
FROM order_items;

-- 6.3 Review score distribution
SELECT
    review_score,
    COUNT(*)                                                AS review_count,
    ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (), 2)     AS pct_of_reviews,
    LPAD('█', (COUNT(*) / 2000)::INT, '█')                 AS bar_chart
FROM order_reviews
WHERE review_score IS NOT NULL
GROUP BY review_score
ORDER BY review_score DESC;

-- 6.4 Order frequency per customer — reveals the one-time buyer problem
SELECT
    order_count                                     AS orders_per_customer,
    COUNT(*)                                        AS customer_count,
    ROUND(COUNT(*) * 100.0
        / SUM(COUNT(*)) OVER (), 2)                 AS pct_of_customers
FROM (
    SELECT customer_unique_id, COUNT(DISTINCT o.order_id) AS order_count
    FROM customers c
    JOIN orders o ON c.customer_id = o.customer_id
    WHERE o.order_status = 'delivered'
    GROUP BY customer_unique_id
) freq
GROUP BY order_count
HAVING order_count <= 10   -- cap display at 10+ to keep readable
ORDER BY order_count;

-- ============================================================
-- SECTION 7: REFERENTIAL INTEGRITY CHECKS
-- ============================================================

-- 7.1 Order items with no matching order (orphaned records)
SELECT COUNT(*) AS orphaned_order_items
FROM order_items oi
LEFT JOIN orders o ON oi.order_id = o.order_id
WHERE o.order_id IS NULL;

-- 7.2 Orders with no items (ghost orders)
SELECT COUNT(*) AS orders_with_no_items
FROM orders o
LEFT JOIN order_items oi ON o.order_id = oi.order_id
WHERE oi.order_id IS NULL;

-- 7.3 Orders with no payment record
SELECT COUNT(*) AS orders_with_no_payment
FROM orders o
LEFT JOIN order_payments op ON o.order_id = op.order_id
WHERE op.order_id IS NULL;

-- 7.4 Products in order_items not in products table
SELECT COUNT(DISTINCT oi.product_id) AS unmapped_products
FROM order_items oi
LEFT JOIN products p ON oi.product_id = p.product_id
WHERE p.product_id IS NULL;

-- 7.5 Product categories with no English translation
SELECT
    p.product_category_name,
    COUNT(DISTINCT oi.order_id) AS orders_affected
FROM products p
JOIN order_items oi ON p.product_id = oi.product_id
LEFT JOIN product_category_translation t
    ON p.product_category_name = t.product_category_name
WHERE t.product_category_name_english IS NULL
  AND p.product_category_name IS NOT NULL
GROUP BY p.product_category_name
ORDER BY orders_affected DESC;

-- ============================================================
-- SECTION 8: OUTLIER FLAGGING — IQR METHOD
-- ============================================================

-- 8.1 Price outliers using IQR fence (> Q3 + 3 * IQR = extreme outlier)
WITH price_stats AS (
    SELECT
        PERCENTILE_CONT(0.25) WITHIN GROUP (ORDER BY price)::NUMERIC AS q1,
        PERCENTILE_CONT(0.75) WITHIN GROUP (ORDER BY price)::NUMERIC AS q3
    FROM order_items
),
bounds AS (
    SELECT
        q1,
        q3,
        (q3 - q1)           AS iqr,
        q3 + 3 * (q3 - q1)  AS upper_extreme_fence,
        q1 - 3 * (q3 - q1)  AS lower_extreme_fence
    FROM price_stats
)
SELECT
    b.q1,
    b.q3,
    ROUND(b.iqr, 2)                     AS iqr,
    ROUND(b.upper_extreme_fence, 2)     AS upper_extreme_fence,
    COUNT(*) FILTER (
        WHERE oi.price > b.upper_extreme_fence
    )                                   AS extreme_high_price_count,
    ROUND(MAX(oi.price), 2)             AS actual_max_price
FROM order_items oi
CROSS JOIN bounds b
GROUP BY b.q1, b.q3, b.iqr, b.upper_extreme_fence, b.lower_extreme_fence;

-- 8.2 Delivery time outliers — flag implausibly fast or slow deliveries
WITH delivery_stats AS (
    SELECT
        order_id,
        EXTRACT(EPOCH FROM (
            order_delivered_customer_date - order_purchase_timestamp
        )) / 86400 AS delivery_days
    FROM orders
    WHERE order_status = 'delivered'
      AND order_delivered_customer_date IS NOT NULL
)
SELECT
    COUNT(*) FILTER (WHERE delivery_days < 0)   AS negative_delivery_days,
    COUNT(*) FILTER (WHERE delivery_days = 0)   AS same_day_delivery,
    COUNT(*) FILTER (WHERE delivery_days > 60)  AS over_60_days,
    COUNT(*) FILTER (WHERE delivery_days > 120) AS over_120_days,
    ROUND(MAX(delivery_days), 0)                AS max_delivery_days,
    ROUND(MIN(delivery_days), 1)                AS min_delivery_days
FROM delivery_stats;

-- ============================================================
-- SECTION 9: REVENUE SANITY CHECK
-- ============================================================

-- 9.1 High-level revenue snapshot — validate against README figures
SELECT
    COUNT(DISTINCT o.order_id)              AS total_delivered_orders,
    COUNT(DISTINCT c.customer_unique_id)    AS unique_customers,
    COUNT(DISTINCT oi.seller_id)            AS active_sellers,
    ROUND(SUM(oi.price), 2)                 AS gross_revenue,
    ROUND(SUM(oi.freight_value), 2)         AS total_freight,
    ROUND(SUM(oi.price + oi.freight_value), 2) AS total_revenue_incl_freight,
    ROUND(AVG(oi.price + oi.freight_value), 2) AS avg_item_value,
    ROUND(SUM(oi.freight_value)
        / NULLIF(SUM(oi.price), 0) * 100, 2)   AS freight_as_pct_of_revenue
FROM orders o
JOIN order_items oi ON o.order_id = oi.order_id
JOIN customers c    ON o.customer_id = c.customer_id
WHERE o.order_status = 'delivered';

-- 9.2 Multi-item orders — what % of orders have more than one item?
SELECT
    item_count,
    COUNT(*)                                            AS order_count,
    ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (), 2) AS pct_of_orders
FROM (
    SELECT order_id, COUNT(*) AS item_count
    FROM order_items
    GROUP BY order_id
) item_freq
GROUP BY item_count
ORDER BY item_count;

-- ============================================================
-- SECTION 10: DATA QUALITY SUMMARY FLAG
-- ============================================================
-- One-shot overview — run this after loading to confirm data is clean

WITH checks AS (
    SELECT
        (SELECT COUNT(*) FROM orders WHERE order_id IS NULL)                AS null_order_ids,
        (SELECT COUNT(*) FROM order_items oi
            LEFT JOIN orders o ON oi.order_id = o.order_id
            WHERE o.order_id IS NULL)                                       AS orphaned_items,
        (SELECT COUNT(*) FROM orders
            WHERE order_delivered_customer_date < order_purchase_timestamp) AS delivery_before_purchase,
        (SELECT COUNT(*) FROM order_items WHERE price <= 0)                 AS zero_price_items,
        (SELECT COUNT(*) FROM orders
            WHERE order_approved_at < order_purchase_timestamp)             AS approved_before_purchase
)
SELECT
    null_order_ids,
    orphaned_items,
    delivery_before_purchase,
    zero_price_items,
    approved_before_purchase,
    CASE
        WHEN null_order_ids = 0
         AND orphaned_items = 0
         AND delivery_before_purchase = 0
         AND zero_price_items = 0
        THEN '✓ CLEAN — Safe to proceed to analytics'
        ELSE '⚠ ISSUES FOUND — Review above sections before analysis'
    END AS data_quality_verdict
FROM checks;