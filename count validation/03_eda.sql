-- ============================================================
-- E-COMMERCE CUSTOMER & SALES INTELLIGENCE
-- Exploratory Data Analysis
-- Author: Suriyaprasath Parameswaran
-- ============================================================

-- ============================================================
-- SECTION 1: DATA QUALITY AUDIT
-- ============================================================

-- 1.1 Null audit across critical columns
SELECT
    COUNT(*)                                                        AS total_orders,
    COUNT(*) FILTER (WHERE order_purchase_timestamp IS NULL)        AS null_purchase_ts,
    COUNT(*) FILTER (WHERE order_delivered_customer_date IS NULL)   AS null_delivery_date,
    COUNT(*) FILTER (WHERE order_approved_at IS NULL)               AS null_approved_at,
    COUNT(*) FILTER (WHERE customer_id IS NULL)                     AS null_customer_id,
    ROUND(
        COUNT(*) FILTER (WHERE order_delivered_customer_date IS NULL)
        * 100.0 / COUNT(*), 2
    )                                                               AS pct_missing_delivery
FROM orders;

-- 1.2 Order status distribution
SELECT
    order_status,
    COUNT(*)                                AS order_count,
    ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (), 2) AS pct_of_total
FROM orders
GROUP BY order_status
ORDER BY order_count DESC;

-- 1.3 Date range of the dataset
SELECT
    MIN(order_purchase_timestamp)::DATE AS earliest_order,
    MAX(order_purchase_timestamp)::DATE AS latest_order,
    MAX(order_purchase_timestamp)::DATE - MIN(order_purchase_timestamp)::DATE AS days_span
FROM orders;

-- 1.4 Payment type distribution
SELECT
    payment_type,
    COUNT(DISTINCT order_id)                AS order_count,
    ROUND(SUM(payment_value), 2)            AS total_revenue,
    ROUND(AVG(payment_value), 2)            AS avg_payment,
    ROUND(COUNT(DISTINCT order_id) * 100.0
        / SUM(COUNT(DISTINCT order_id)) OVER(), 2) AS pct_orders
FROM order_payments
GROUP BY payment_type
ORDER BY order_count DESC;

-- ============================================================
-- SECTION 2: REVENUE OVERVIEW
-- ============================================================

-- 2.1 Overall revenue KPIs
SELECT
    COUNT(DISTINCT o.order_id)                      AS total_orders,
    COUNT(DISTINCT o.customer_id)                   AS unique_customers,
    COUNT(DISTINCT oi.seller_id)                    AS active_sellers,
    ROUND(SUM(oi.price), 2)                         AS gross_revenue,
    ROUND(SUM(oi.freight_value), 2)                 AS total_freight,
    ROUND(SUM(oi.price) - SUM(oi.freight_value), 2) AS net_revenue,
    ROUND(AVG(oi.price), 2)                         AS avg_order_value,
    ROUND(SUM(oi.freight_value)
        / NULLIF(SUM(oi.price), 0) * 100, 2)        AS freight_as_pct_revenue
FROM orders o
JOIN order_items oi ON o.order_id = oi.order_id
WHERE o.order_status = 'delivered';

-- 2.2 Revenue by product category (top 20)
SELECT
    COALESCE(t.product_category_name_english, p.product_category_name, 'Unknown') AS category,
    COUNT(DISTINCT oi.order_id)     AS total_orders,
    COUNT(oi.order_item_id)         AS units_sold,
    ROUND(SUM(oi.price), 2)         AS gross_revenue,
    ROUND(AVG(oi.price), 2)         AS avg_item_price,
    ROUND(SUM(oi.freight_value), 2) AS total_freight_cost,
    ROUND(SUM(oi.price) - SUM(oi.freight_value), 2) AS net_revenue
FROM order_items oi
JOIN orders o       ON oi.order_id  = o.order_id
JOIN products p     ON oi.product_id = p.product_id
LEFT JOIN product_category_translation t
                    ON p.product_category_name = t.product_category_name
WHERE o.order_status = 'delivered'
GROUP BY category
ORDER BY gross_revenue DESC
LIMIT 20;

-- 2.3 Revenue by customer state
SELECT
    c.customer_state                            AS state,
    COUNT(DISTINCT o.order_id)                  AS total_orders,
    COUNT(DISTINCT c.customer_unique_id)        AS unique_customers,
    ROUND(SUM(oi.price), 2)                     AS gross_revenue,
    ROUND(AVG(oi.price), 2)                     AS avg_order_value
FROM orders o
JOIN customers c    ON o.customer_id  = c.customer_id
JOIN order_items oi ON o.order_id     = oi.order_id
WHERE o.order_status = 'delivered'
GROUP BY state
ORDER BY gross_revenue DESC;