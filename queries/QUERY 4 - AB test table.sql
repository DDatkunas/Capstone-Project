/*
Calculating the number of unprofitable deals based on discount segment
Data from this table was used for the A/B test.
*/

WITH discount_sales AS (
    SELECT
        transaction_id,
        CASE WHEN discount <= 0.2 THEN '0-20% Discount'
             WHEN discount > 0.2 THEN '20+% Discount'
        END AS discount_size,
        CASE WHEN profit <= 0 THEN 1
             ELSE 0
        END AS unprofitable_deals, 
        sales,
        profit
    FROM `aws_saas_sales.aws_saas_sales` 
)

SELECT
    discount_size,
    SUM(unprofitable_deals) AS unprofitable_deals,
    COUNT(1) AS all_segment_deals,
    ROUND(SUM(unprofitable_deals) / COUNT(1) * 100, 2) AS unprofitable_rate,
    ROUND(SUM(sales), 2) AS total_sales,
    ROUND(SUM(sales) / (SELECT SUM(sales) FROM discount_sales) * 100, 2) AS pct_of_sales,
    ROUND(SUM(profit), 2) AS total_profit,
    ROUND(SUM(profit) / SUM(sales) * 100, 2) AS profit_margin,
FROM discount_sales
GROUP BY discount_size 
ORDER BY discount_size ASC
