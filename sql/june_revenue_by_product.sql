-- June 2026 revenue by product, ranked high to low.
--
-- Revenue is quantity * unit_price summed per product (unit_price lives on the
-- order, not the product). The single June orders file is enough for the dollar
-- figures; the join to products.csv only adds the human-readable name and
-- category, which the orders file doesn't carry.
--
-- Run: duckdb -csv -f sql/june_revenue_by_product.sql
SELECT
    p.product_name,
    p.category,
    SUM(o.quantity)                          AS units_sold,
    ROUND(SUM(o.quantity * o.unit_price), 2) AS revenue
FROM 'data/orders_2026_06.csv' AS o
JOIN 'data/products.csv'       AS p USING (product_id)
GROUP BY ALL
ORDER BY revenue DESC;
