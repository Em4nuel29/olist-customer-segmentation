-- ============================================================
-- Olist E-Commerce — Table Schema (PostgreSQL)
-- Run this first, against an empty database, e.g.:
--   createdb olist
--   psql -d olist -f schema.sql
-- Column names match the Kaggle CSVs exactly, including the
-- dataset's real misspellings ("lenght") so \copy lines up.
-- Constraints are kept light on purpose: some Olist files
-- contain duplicate keys (e.g. review_id), so strict PKs
-- would make the load fail. Add indexes after loading instead.
-- ============================================================

DROP TABLE IF EXISTS olist_customers_dataset CASCADE;
CREATE TABLE olist_customers_dataset (
    customer_id              VARCHAR,
    customer_unique_id       VARCHAR,   -- the REAL person across orders (use this for RFM)
    customer_zip_code_prefix INTEGER,
    customer_city            VARCHAR,
    customer_state           VARCHAR
);

DROP TABLE IF EXISTS olist_orders_dataset CASCADE;
CREATE TABLE olist_orders_dataset (
    order_id                      VARCHAR,
    customer_id                   VARCHAR,   -- per-ORDER key, NOT the person
    order_status                  VARCHAR,
    order_purchase_timestamp      TIMESTAMP,
    order_approved_at             TIMESTAMP,
    order_delivered_carrier_date  TIMESTAMP,
    order_delivered_customer_date TIMESTAMP,
    order_estimated_delivery_date TIMESTAMP
);

DROP TABLE IF EXISTS olist_order_items_dataset CASCADE;
CREATE TABLE olist_order_items_dataset (
    order_id            VARCHAR,
    order_item_id       INTEGER,
    product_id          VARCHAR,
    seller_id           VARCHAR,
    shipping_limit_date TIMESTAMP,
    price               NUMERIC,
    freight_value       NUMERIC
);

DROP TABLE IF EXISTS olist_order_payments_dataset CASCADE;
CREATE TABLE olist_order_payments_dataset (
    order_id             VARCHAR,
    payment_sequential   INTEGER,   -- an order can have multiple payment rows
    payment_type         VARCHAR,
    payment_installments INTEGER,
    payment_value        NUMERIC
);

DROP TABLE IF EXISTS olist_order_reviews_dataset CASCADE;
CREATE TABLE olist_order_reviews_dataset (
    review_id               VARCHAR,   -- NOT unique in this dataset
    order_id                VARCHAR,
    review_score            INTEGER,
    review_comment_title    VARCHAR,
    review_comment_message  VARCHAR,
    review_creation_date    TIMESTAMP,
    review_answer_timestamp TIMESTAMP
);

DROP TABLE IF EXISTS olist_products_dataset CASCADE;
CREATE TABLE olist_products_dataset (
    product_id                 VARCHAR,
    product_category_name      VARCHAR,
    product_name_lenght        INTEGER,   -- sic: dataset misspelling
    product_description_lenght INTEGER,   -- sic
    product_photos_qty         INTEGER,
    product_weight_g           NUMERIC,
    product_length_cm          NUMERIC,
    product_height_cm          NUMERIC,
    product_width_cm           NUMERIC
);

DROP TABLE IF EXISTS olist_sellers_dataset CASCADE;
CREATE TABLE olist_sellers_dataset (
    seller_id              VARCHAR,
    seller_zip_code_prefix INTEGER,
    seller_city            VARCHAR,
    seller_state           VARCHAR
);

DROP TABLE IF EXISTS product_category_name_translation CASCADE;
CREATE TABLE product_category_name_translation (
    product_category_name         VARCHAR,
    product_category_name_english VARCHAR
);

-- Helpful indexes for the RFM joins (create AFTER loading data):
-- CREATE INDEX idx_orders_customer ON olist_orders_dataset(customer_id);
-- CREATE INDEX idx_orders_status   ON olist_orders_dataset(order_status);
-- CREATE INDEX idx_payments_order  ON olist_order_payments_dataset(order_id);
-- CREATE INDEX idx_customers_uid   ON olist_customers_dataset(customer_unique_id);
