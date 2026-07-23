-- ============================================================
-- Load Olist CSVs into PostgreSQL
-- Run with psql AFTER schema.sql:
--   psql -d olist -f load_data.sql
--
-- \copy is a psql client command (runs on YOUR machine, no
-- server-side file permissions needed). Edit the path prefix
-- below to wherever you unzipped the Kaggle download.
--
-- CSV mode treats empty unquoted fields as NULL, which is what
-- Olist uses for missing timestamps — so those load cleanly.
-- ============================================================

\set datadir '/CHANGE/ME/olist-data/'

\copy olist_customers_dataset            FROM :'datadir'olist_customers_dataset.csv            WITH (FORMAT csv, HEADER true)
\copy olist_orders_dataset               FROM :'datadir'olist_orders_dataset.csv               WITH (FORMAT csv, HEADER true)
\copy olist_order_items_dataset          FROM :'datadir'olist_order_items_dataset.csv          WITH (FORMAT csv, HEADER true)
\copy olist_order_payments_dataset       FROM :'datadir'olist_order_payments_dataset.csv       WITH (FORMAT csv, HEADER true)
\copy olist_order_reviews_dataset        FROM :'datadir'olist_order_reviews_dataset.csv        WITH (FORMAT csv, HEADER true)
\copy olist_products_dataset             FROM :'datadir'olist_products_dataset.csv             WITH (FORMAT csv, HEADER true)
\copy olist_sellers_dataset              FROM :'datadir'olist_sellers_dataset.csv              WITH (FORMAT csv, HEADER true)
\copy product_category_name_translation  FROM :'datadir'product_category_name_translation.csv  WITH (FORMAT csv, HEADER true)

-- Quick sanity checks (expected rough counts):
--   customers ~ 99,441 | orders ~ 99,441 | order_items ~ 112,650
--   payments  ~ 103,886 | reviews ~ 99,224
SELECT 'customers' AS tbl, COUNT(*) FROM olist_customers_dataset
UNION ALL SELECT 'orders',     COUNT(*) FROM olist_orders_dataset
UNION ALL SELECT 'order_items',COUNT(*) FROM olist_order_items_dataset
UNION ALL SELECT 'payments',   COUNT(*) FROM olist_order_payments_dataset
UNION ALL SELECT 'reviews',    COUNT(*) FROM olist_order_reviews_dataset;
