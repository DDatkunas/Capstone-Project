/*
Monthly Recurring Revenue (MRR) Bridge Ledger
A Ledger which calculates monthly cashflows from each customers
Types of monthly revenue are separated into these segments: 1) New MRR, 2) Reactivation MRR, 3) Churn MRR, 4) Expansion MRR; 5) Contraction MRR
Data from this table was reused in further queries.
*/
CREATE OR REPLACE TABLE `aws_saas_sales.mrr_bridge_ledger`
AS
WITH
  date_range AS (
    SELECT
      date
    FROM
      UNNEST(GENERATE_DATE_ARRAY('2020-01-01', '2023-12-01', INTERVAL 1 MONTH))
        AS date
  ),
  dimensions AS (
    SELECT DISTINCT
      dr.date AS month,
      s.customer,
      s.industry
    FROM `aws_saas_sales.aws_saas_sales` s
    CROSS JOIN date_range dr
  ),
  mrr_table AS (
    SELECT
      d.month,
      d.customer,
      d.industry,
      COALESCE(SUM(s.monthly_payment), 0) AS mrr,
      COALESCE(SUM(s.monthly_profit), 0) AS monthly_profit
    FROM dimensions AS d
    LEFT JOIN `aws_saas_sales.aws_saas_sales` AS s
      ON
        d.customer = s.customer
        AND d.month >= DATE_TRUNC(s.order_date, MONTH)
        AND d.month <= DATE_TRUNC(s.subscription_end, MONTH)
    GROUP BY d.month, d.customer, d.industry
  ),
  mrr_expanded AS (
    SELECT
      month,
      customer,
      industry,
      mrr AS current_mrr,
      COALESCE(LAG(mrr) OVER (PARTITION BY customer ORDER BY month), 0)
        AS prior_mrr,
      COUNTIF(mrr > 0)
        OVER (
          PARTITION BY customer
          ORDER BY month
          ROWS BETWEEN UNBOUNDED PRECEDING AND 1 PRECEDING
        ) AS prior_active_months,
      monthly_profit
    FROM mrr_table
  ),
  mrr_ledger AS (
    SELECT
      month,
      customer,
      industry,
      current_mrr,
      prior_mrr,
      (current_mrr - prior_mrr) AS mrr_change,
      prior_active_months,
      CASE
        WHEN prior_mrr = 0 AND current_mrr > 0 AND prior_active_months = 0
          THEN current_mrr
        ELSE 0
        END AS new_mrr,
      CASE
        WHEN prior_mrr = 0 AND current_mrr > 0 AND prior_active_months > 0
          THEN current_mrr
        ELSE 0
        END AS reactivation_mrr,
      CASE
        WHEN
          prior_mrr > current_mrr
          AND current_mrr > 0
          AND prior_active_months > 0
          THEN (current_mrr - prior_mrr)
        ELSE 0
        END AS contraction_mrr,
      CASE
        WHEN
          prior_mrr < current_mrr
          AND prior_mrr > 0
          AND prior_active_months > 0
          THEN (current_mrr - prior_mrr)
        ELSE 0
        END AS expansion_mrr,
      CASE
        WHEN prior_mrr > 0 AND current_mrr = 0 THEN (-prior_mrr)
        ELSE 0
        END AS churn_mrr,
      monthly_profit
    FROM mrr_expanded
    WHERE current_mrr > 0 OR prior_active_months > 0
  )
SELECT
  *
FROM mrr_ledger
ORDER BY month, customer
