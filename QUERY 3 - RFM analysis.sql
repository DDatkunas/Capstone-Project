/*
RFM analysis
Recency 1-2
Frequency 1-3
Monetary 1-3

More information about RFM segmentation is in the report.
*/

WITH
  rfm_table AS (
    SELECT
      customer,
      industry,
      DATE_DIFF(DATE('2023-12-01'), DATE_TRUNC(MAX(order_date), MONTH), MONTH)
        AS recency,
      SUM(sales * (1 - discount)) AS monetary,
      COUNT(DISTINCT order_id) AS frequency
    FROM `aws_saas_sales.aws_saas_sales`
    GROUP BY customer, industry
  ),
  rfm_metrics AS (
    SELECT
      customer,
      industry,
      recency,
      COALESCE(frequency, 0) AS frequency,
      monetary
    FROM rfm_table
  ),
  rfm_scores AS (
    SELECT
      customer,
      industry,
      recency,
      frequency,
      monetary,
      CASE
        WHEN recency = 0 THEN 2
        ELSE 1
        END AS r_score,
      NTILE(3) OVER (ORDER BY frequency) AS f_score,
      NTILE(3) OVER (ORDER BY monetary) AS m_score
    FROM rfm_metrics
  ),
  rfm_query AS (
    SELECT
      customer,
      industry,
      recency,
      frequency,
      monetary,
      r_score,
      f_score,
      m_score,
      CONCAT(r_score, f_score, m_score) AS rfm_cell,
      CASE
        WHEN r_score = 2 AND f_score = 3 AND m_score = 3 THEN 'Champions'
        WHEN r_score = 2 AND f_score >= 2 AND m_score >= 2 THEN 'Loyal Customers'
        WHEN r_score = 2 AND f_score = 1 AND m_score = 1 THEN 'Recent Customers'
        WHEN r_score = 2 AND f_score <= 2 THEN 'Potential Loyalists'
        WHEN r_score = 1 AND m_score = 3 THEN 'Cant Lose Them'
        WHEN r_score = 1 AND f_score >= 2 THEN 'At Risk'
        WHEN r_score = 1 AND f_score = 1 THEN 'Hibernating'
        ELSE 'Needs Attention'
        END AS customer_segment
    FROM rfm_scores
  )
SELECT
  *
FROM rfm_query
ORDER BY customer_segment
