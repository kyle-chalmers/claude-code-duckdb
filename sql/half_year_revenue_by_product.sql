-- Jan-Jun 2026 revenue by product, ranked high to low (all six monthly files).
--
-- The data/orders_*.csv glob reads every monthly orders file as one table, so
-- this is the half-year total, not a single month. Revenue is
-- quantity * unit_price summed per product (unit_price lives on the order, not
-- the product). The join to products.csv only adds the human-readable name and
-- category, which the orders files don't carry.
--
-- Run: duckdb -box -f sql/half_year_revenue_by_product.sql
SELECT
    p.product_name,
    p.category,
    SUM(o.quantity)                          AS units_sold,
    ROUND(SUM(o.quantity * o.unit_price), 2) AS revenue
FROM 'data/orders_*.csv' AS o
JOIN 'data/products.csv'  AS p USING (product_id)
GROUP BY ALL
ORDER BY revenue DESC;
