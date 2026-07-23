-- ============================================================
-- RFM Analysis — Olist (PostgreSQL)
-- Run AFTER schema.sql + load_data.sql:
--   psql -d olist -f rfm_analysis.sql
--
-- This builds a view `customer_rfm` (one row per real customer,
-- with R/F/M scores and a segment label) that Tableau connects
-- to. The logic below was validated against a synthetic copy of
-- this schema before shipping.
--
-- THREE THINGS TO UNDERSTAND (and to be ready to explain in an
-- interview — this is where you show you actually get it):
--
-- 1) GROUPING KEY. We group by customer_unique_id, NOT
--    customer_id. In Olist, customer_id is generated PER ORDER,
--    so grouping by it makes almost everyone look like a
--    one-time buyer. customer_unique_id is the real person.
--
-- 2) RECENCY DIRECTION. Fewer days since last order = more
--    recent = better. NTILE assigns tile 1 to the first rows,
--    so we ORDER BY recency_days DESC to push the most recent
--    customers into tile 5.
--
-- 3) FREQUENCY IS SKEWED. In Olist the large majority of
--    customers bought exactly once, so frequency has very
--    little spread. NTILE will split all those tied 1s across
--    tiles somewhat arbitrarily. Don't oversell F here — say so
--    honestly, lean on R and M, and mention that a repeat-heavy
--    dataset would make F far more meaningful.
-- ============================================================

DROP VIEW IF EXISTS customer_rfm;

CREATE VIEW customer_rfm AS
WITH order_payments AS (
    -- collapse multiple payment rows per order into one order total
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
    WHERE o.order_status = 'delivered'   -- only revenue that actually completed
),
snapshot AS (
    -- reference date = day after the last purchase in the data
    SELECT (MAX(order_purchase_timestamp)::date + INTERVAL '1 day')::date AS snap
    FROM customer_orders
),
rfm_base AS (
    SELECT
        co.customer_unique_id,
        (SELECT snap FROM snapshot) - MAX(co.order_purchase_timestamp)::date AS recency_days,
        COUNT(DISTINCT co.order_id)                                          AS frequency,
        SUM(co.order_value)                                                  AS monetary
    FROM customer_orders co
    GROUP BY co.customer_unique_id
),
rfm_scored AS (
    SELECT
        *,
        NTILE(5) OVER (ORDER BY recency_days DESC) AS r_score,  -- most recent -> 5
        NTILE(5) OVER (ORDER BY frequency ASC)     AS f_score,  -- most orders -> 5
        NTILE(5) OVER (ORDER BY monetary ASC)      AS m_score   -- biggest spend -> 5
    FROM rfm_base
)
SELECT
    customer_unique_id,
    recency_days,
    frequency,
    monetary,
    r_score,
    f_score,
    m_score,
    (r_score::text || f_score::text || m_score::text) AS rfm_cell,
    CASE
        WHEN r_score >= 4 AND f_score >= 4 THEN 'Champions'
        WHEN r_score >= 3 AND f_score >= 3 THEN 'Loyal'
        WHEN r_score >= 4 AND f_score <= 2 THEN 'New / Promising'
        WHEN r_score <= 2 AND f_score >= 3 THEN 'At Risk'
        WHEN r_score <= 2 AND f_score <= 2 THEN 'Hibernating / Lost'
        ELSE 'Needs Attention'
    END AS segment
FROM rfm_scored;

-- ---- Segment summary (this is what feeds the Tableau dashboard) ----
SELECT
    segment,
    COUNT(*)                        AS customers,
    ROUND(AVG(recency_days), 0)     AS avg_recency_days,
    ROUND(AVG(frequency), 2)        AS avg_frequency,
    ROUND(AVG(monetary), 2)         AS avg_monetary,
    ROUND(SUM(monetary), 2)         AS total_revenue,
    ROUND(100.0 * SUM(monetary) / SUM(SUM(monetary)) OVER (), 1) AS pct_of_revenue
FROM customer_rfm
GROUP BY segment
ORDER BY total_revenue DESC;
