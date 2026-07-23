-- ============================================================
-- Customer Segmentation v2 — Olist (PostgreSQL)
-- Replaces rfm_analysis.sql. Run in the `olist` database.
--
-- WHY THIS VERSION EXISTS (this is the project's real story):
-- Standard RFM assumes all three dimensions carry signal. On
-- Olist they do not. Measured result:
--     frequency = 1  ->  90,557 customers (97.0%)
--     frequency = 2  ->   2,573 customers ( 2.8%)
--     frequency >= 3 ->     228 customers ( 0.2%)
-- With 97% of customers tied at a single purchase, NTILE(5) on
-- frequency splits identical values into arbitrary buckets. The
-- v1 segments were therefore recency rankings wearing RFM
-- labels: "Champions" averaged 1.09 orders and 90 days recency,
-- while "New / Promising" averaged 1.00 orders and 91 days —
-- statistically the same people under two different names.
--
-- v2 fixes this by:
--   1. Treating the 97% single-purchase rate as the headline
--      finding rather than an inconvenience.
--   2. Segmenting on Recency x Monetary, the two dimensions
--      that actually vary.
--   3. Splitting repeat buyers into their own cohort, where
--      frequency is meaningful, instead of diluting them across
--      segments dominated by one-time buyers.
--
-- Keep rfm_analysis.sql in the repo. Showing v1 -> diagnosis ->
-- v2 is stronger evidence of analytical judgment than shipping
-- v2 alone.
-- ============================================================

-- ---------- 1. Headline: the repeat-purchase problem ----------
DROP VIEW IF EXISTS purchase_frequency_dist CASCADE;
CREATE VIEW purchase_frequency_dist AS
WITH order_payments AS (
    SELECT order_id, SUM(payment_value) AS order_value
    FROM olist_order_payments_dataset GROUP BY order_id
),
customer_orders AS (
    SELECT c.customer_unique_id, o.order_id
    FROM olist_orders_dataset o
    JOIN olist_customers_dataset c ON o.customer_id = c.customer_id
    WHERE o.order_status = 'delivered'
),
per_customer AS (
    SELECT customer_unique_id, COUNT(DISTINCT order_id) AS orders
    FROM customer_orders GROUP BY customer_unique_id
)
SELECT orders AS purchases,
       COUNT(*) AS customers,
       ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 2) AS pct_of_customers
FROM per_customer
GROUP BY orders;

-- ---------- 2. Main segmentation view ----------
DROP VIEW IF EXISTS customer_segments CASCADE;
CREATE VIEW customer_segments AS
WITH order_payments AS (
    SELECT order_id, SUM(payment_value) AS order_value
    FROM olist_order_payments_dataset
    GROUP BY order_id
),
customer_orders AS (
    SELECT
        c.customer_unique_id,
        o.order_id,
        o.order_purchase_timestamp,
        op.order_value
    FROM olist_orders_dataset o
    JOIN olist_customers_dataset c ON o.customer_id = c.customer_id
    LEFT JOIN order_payments op     ON o.order_id   = op.order_id
    WHERE o.order_status = 'delivered'
),
snapshot AS (
    SELECT (MAX(order_purchase_timestamp)::date + INTERVAL '1 day')::date AS snap
    FROM customer_orders
),
cust_base AS (
    SELECT
        customer_unique_id,
        (SELECT snap FROM snapshot) - MAX(order_purchase_timestamp)::date AS recency_days,
        COUNT(DISTINCT order_id)                                          AS frequency,
        SUM(order_value)                                                  AS monetary
    FROM customer_orders
    GROUP BY customer_unique_id
),
scored AS (
    SELECT
        *,
        CASE WHEN frequency = 1 THEN 'One-time' ELSE 'Repeat' END AS buyer_type,
        -- only two scored dimensions: the two that actually vary
        NTILE(5) OVER (ORDER BY recency_days DESC) AS r_score,  -- recent -> 5
        NTILE(5) OVER (ORDER BY monetary ASC)      AS m_score   -- big spend -> 5
    FROM cust_base
)
SELECT
    customer_unique_id,
    buyer_type,
    recency_days,
    frequency,
    monetary,
    r_score,
    m_score,
    CASE
        -- repeat buyers first: rare enough that they deserve their own labels
        WHEN buyer_type = 'Repeat' AND m_score >= 4 THEN 'Repeat - High Value'
        WHEN buyer_type = 'Repeat'                  THEN 'Repeat - Standard'
        -- one-time buyers segmented on recency x monetary
        WHEN r_score >= 4 AND m_score >= 4 THEN 'Recent High Spender'
        WHEN r_score >= 4                  THEN 'Recent Low Spender'
        WHEN r_score <= 2 AND m_score >= 4 THEN 'Lapsed High Spender'
        WHEN r_score <= 2                  THEN 'Lapsed Low Spender'
        ELSE 'Mid Recency'
    END AS segment
FROM scored;

-- ---------- 3. Segment summary (feeds Tableau) ----------
SELECT
    segment,
    COUNT(*)                    AS customers,
    ROUND(AVG(recency_days), 0) AS avg_recency_days,
    ROUND(AVG(frequency), 2)    AS avg_frequency,
    ROUND(AVG(monetary), 2)     AS avg_monetary,
    ROUND(SUM(monetary), 2)     AS total_revenue,
    ROUND(100.0 * SUM(monetary) / SUM(SUM(monetary)) OVER (), 1) AS pct_of_revenue
FROM customer_segments
GROUP BY segment
ORDER BY total_revenue DESC;

-- ---------- 4. Supporting cuts for the dashboard ----------
-- Repeat vs one-time: value of a retained customer
-- SELECT buyer_type, COUNT(*) AS customers,
--        ROUND(AVG(monetary), 2) AS avg_lifetime_value,
--        ROUND(SUM(monetary), 2) AS total_revenue
-- FROM customer_segments GROUP BY buyer_type;

-- Revenue concentration: what share comes from the top decile
-- WITH d AS (SELECT monetary, NTILE(10) OVER (ORDER BY monetary DESC) AS decile
--            FROM customer_segments)
-- SELECT decile, ROUND(SUM(monetary), 2) AS revenue,
--        ROUND(100.0 * SUM(monetary) / SUM(SUM(monetary)) OVER (), 1) AS pct
-- FROM d GROUP BY decile ORDER BY decile;
