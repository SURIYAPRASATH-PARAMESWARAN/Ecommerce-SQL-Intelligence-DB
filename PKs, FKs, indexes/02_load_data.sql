-- ============================================================
-- E-COMMERCE CUSTOMER & SALES INTELLIGENCE
-- Data Loading — Standard COPY (SQLTools compatible)
-- Author: Suriyaprasath Parameswaran
-- ============================================================

COPY customers
FROM 'F:/PORTFOLIO/projects/ecommerce sql intelligence/data/olist_customers_dataset.csv'
DELIMITER ',' CSV HEADER;

COPY sellers
FROM 'F:/PORTFOLIO/projects/ecommerce sql intelligence/data/olist_sellers_dataset.csv'
DELIMITER ',' CSV HEADER;

COPY products
FROM 'F:/PORTFOLIO/projects/ecommerce sql intelligence/data/olist_products_dataset.csv'
DELIMITER ',' CSV HEADER;

COPY product_category_translation
FROM 'F:/PORTFOLIO/projects/ecommerce sql intelligence/data/product_category_name_translation.csv'
DELIMITER ',' CSV HEADER;

COPY geolocation
FROM 'F:/PORTFOLIO/projects/ecommerce sql intelligence/data/olist_geolocation_dataset.csv'
DELIMITER ',' CSV HEADER;

COPY orders
FROM 'F:/PORTFOLIO/projects/ecommerce sql intelligence/data/olist_orders_dataset.csv'
DELIMITER ',' CSV HEADER;

COPY order_items
FROM 'F:/PORTFOLIO/projects/ecommerce sql intelligence/data/olist_order_items_dataset.csv'
DELIMITER ',' CSV HEADER;

COPY order_payments
FROM 'F:/PORTFOLIO/projects/ecommerce sql intelligence/data/olist_order_payments_dataset.csv'
DELIMITER ',' CSV HEADER;

COPY order_reviews
FROM 'F:/PORTFOLIO/projects/ecommerce sql intelligence/data/olist_order_reviews_dataset.csv'
DELIMITER ',' CSV HEADER;

-- ============================================================
-- VALIDATION — Row Counts
-- ============================================================
SELECT 'customers'      AS table_name, COUNT(*) AS row_count FROM customers
UNION ALL
SELECT 'sellers',                       COUNT(*) FROM sellers
UNION ALL
SELECT 'products',                      COUNT(*) FROM products
UNION ALL
SELECT 'orders',                        COUNT(*) FROM orders
UNION ALL
SELECT 'order_items',                   COUNT(*) FROM order_items
UNION ALL
SELECT 'order_payments',                COUNT(*) FROM order_payments
UNION ALL
SELECT 'order_reviews',                 COUNT(*) FROM order_reviews
ORDER BY table_name;