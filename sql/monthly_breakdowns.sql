-- Jan-Jun 2026 revenue broken out across region, category, and product, with
-- per-month columns, a half-year total, and month-to-month movement.
--
-- Grain note: every product maps to exactly one category, so "product" already
-- carries its category. The independent dimensions are therefore region (4),
-- category (4), product (20), and their crosses. Both lookup joins are n:1
-- (verified: 900k order rows in, 900k out), so no revenue is double-counted.
--
-- Revenue = quantity * unit_price (unit_price is the price paid, on the order).
-- region comes from customers.csv, category/product_name from products.csv.
-- Per-month columns use SUM(rev) FILTER (WHERE month = '...') so each row keeps
-- its six monthly figures plus a half-year total in one pass.
--
-- Run: duckdb -box -f sql/monthly_breakdowns.sql

-- Shared enriched grain: one row per order line, tagged with month + dimensions.
CREATE OR REPLACE TEMP VIEW enriched AS
SELECT
    strftime(o.order_date, '%Y-%m') AS month,
    c.region,
    p.category,
    p.product_name,
    o.quantity * o.unit_price        AS rev
FROM 'data/orders_*.csv' AS o
JOIN 'data/customers.csv' AS c USING (customer_id)
JOIN 'data/products.csv'  AS p USING (product_id);

-- ============================================================================
-- 1. Overall revenue by month, with month-to-month movement (the headline).
-- ============================================================================
.print '== 1. Overall revenue by month + month-over-month movement =='
WITH m AS (
    SELECT month, ROUND(SUM(rev), 2) AS revenue
    FROM enriched
    GROUP BY month
)
SELECT
    month,
    revenue,
    ROUND(revenue - lag(revenue) OVER (ORDER BY month), 2)               AS mom_delta,
    ROUND(100.0 * (revenue / lag(revenue) OVER (ORDER BY month) - 1), 2) AS mom_pct
FROM m
ORDER BY month;

-- ============================================================================
-- 2. Revenue by REGION, per month + total.
-- ============================================================================
.print '== 2. Revenue by region (per month + total) =='
SELECT
    region,
    ROUND(SUM(rev) FILTER (month = '2026-01'), 2) AS jan,
    ROUND(SUM(rev) FILTER (month = '2026-02'), 2) AS feb,
    ROUND(SUM(rev) FILTER (month = '2026-03'), 2) AS mar,
    ROUND(SUM(rev) FILTER (month = '2026-04'), 2) AS apr,
    ROUND(SUM(rev) FILTER (month = '2026-05'), 2) AS may,
    ROUND(SUM(rev) FILTER (month = '2026-06'), 2) AS jun,
    ROUND(SUM(rev), 2)                            AS total
FROM enriched
GROUP BY region
ORDER BY total DESC;

-- ============================================================================
-- 3. Revenue by CATEGORY, per month + total.
-- ============================================================================
.print '== 3. Revenue by category (per month + total) =='
SELECT
    category,
    ROUND(SUM(rev) FILTER (month = '2026-01'), 2) AS jan,
    ROUND(SUM(rev) FILTER (month = '2026-02'), 2) AS feb,
    ROUND(SUM(rev) FILTER (month = '2026-03'), 2) AS mar,
    ROUND(SUM(rev) FILTER (month = '2026-04'), 2) AS apr,
    ROUND(SUM(rev) FILTER (month = '2026-05'), 2) AS may,
    ROUND(SUM(rev) FILTER (month = '2026-06'), 2) AS jun,
    ROUND(SUM(rev), 2)                            AS total
FROM enriched
GROUP BY category
ORDER BY total DESC;

-- ============================================================================
-- 4. Revenue by PRODUCT, per month + total.
-- ============================================================================
.print '== 4. Revenue by product (per month + total) =='
SELECT
    product_name,
    category,
    ROUND(SUM(rev) FILTER (month = '2026-01'), 2) AS jan,
    ROUND(SUM(rev) FILTER (month = '2026-02'), 2) AS feb,
    ROUND(SUM(rev) FILTER (month = '2026-03'), 2) AS mar,
    ROUND(SUM(rev) FILTER (month = '2026-04'), 2) AS apr,
    ROUND(SUM(rev) FILTER (month = '2026-05'), 2) AS may,
    ROUND(SUM(rev) FILTER (month = '2026-06'), 2) AS jun,
    ROUND(SUM(rev), 2)                            AS total
FROM enriched
GROUP BY product_name, category
ORDER BY total DESC;

-- ============================================================================
-- 5. Revenue by REGION x CATEGORY, per month + total (16 rows).
-- ============================================================================
.print '== 5. Revenue by region x category (per month + total) =='
SELECT
    region,
    category,
    ROUND(SUM(rev) FILTER (month = '2026-01'), 2) AS jan,
    ROUND(SUM(rev) FILTER (month = '2026-02'), 2) AS feb,
    ROUND(SUM(rev) FILTER (month = '2026-03'), 2) AS mar,
    ROUND(SUM(rev) FILTER (month = '2026-04'), 2) AS apr,
    ROUND(SUM(rev) FILTER (month = '2026-05'), 2) AS may,
    ROUND(SUM(rev) FILTER (month = '2026-06'), 2) AS jun,
    ROUND(SUM(rev), 2)                            AS total
FROM enriched
GROUP BY region, category
ORDER BY region, total DESC;

-- ============================================================================
-- 6. Revenue by REGION x PRODUCT, per month + total (80 rows).
-- ============================================================================
.print '== 6. Revenue by region x product (per month + total) =='
SELECT
    region,
    product_name,
    ROUND(SUM(rev) FILTER (month = '2026-01'), 2) AS jan,
    ROUND(SUM(rev) FILTER (month = '2026-02'), 2) AS feb,
    ROUND(SUM(rev) FILTER (month = '2026-03'), 2) AS mar,
    ROUND(SUM(rev) FILTER (month = '2026-04'), 2) AS apr,
    ROUND(SUM(rev) FILTER (month = '2026-05'), 2) AS may,
    ROUND(SUM(rev) FILTER (month = '2026-06'), 2) AS jun,
    ROUND(SUM(rev), 2)                            AS total
FROM enriched
GROUP BY region, product_name
ORDER BY region, total DESC;
