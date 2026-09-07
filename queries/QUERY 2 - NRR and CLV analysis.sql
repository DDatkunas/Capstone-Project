/*
Net revenue Retention (NRR) Cohort analysis and CLV analysis
CLV calculated using David Skok's formula. More information about the formula is in the report.
*/
WITH
  cohorts AS (
    SELECT
      customer,
      DATE_TRUNC(MIN(order_date), MONTH) AS cohort_month
    FROM `aws_saas_sales.aws_saas_sales`
    GROUP BY customer
  ),
  metrics AS (
    SELECT
      c.cohort_month,
      m.month AS order_month,
      DATE_DIFF(m.month, c.cohort_month, MONTH) AS months_since_start,
      SUM(m.current_mrr) AS total_revenue,
      LAG(SUM(m.current_mrr))
        OVER (
          PARTITION BY cohort_month
          ORDER BY DATE_DIFF(m.month, c.cohort_month, MONTH)
        ) AS previous_month_revenue,
      FIRST_VALUE(SUM(m.current_mrr)) 
        OVER (
          PARTITION BY c.cohort_month
          ORDER BY DATE_DIFF(m.month, c.cohort_month, MONTH) 
        ) AS starting_revenue,
      SUM(m.monthly_profit) AS total_profit,
      COUNT(DISTINCT m.customer) AS total_customers,
      (SUM(m.current_mrr) / COUNT(DISTINCT m.customer)) AS arpu,
      (SUM(m.monthly_profit) / SUM(m.current_mrr)) AS gross_margin,
      COALESCE(
        SAFE_DIVIDE(
          (SUM(m.expansion_mrr) - SUM(m.contraction_mrr)),
          LAG(SUM(m.current_mrr))
            OVER (
              PARTITION BY c.cohort_month
              ORDER BY DATE_DIFF(m.month, c.cohort_month, MONTH)
            )),
        0) AS growth_rate,
      (
        COUNT(DISTINCT m.customer)
        - LAG(COUNT(DISTINCT m.customer))
          OVER (
            PARTITION BY c.cohort_month
            ORDER BY DATE_DIFF(m.month, c.cohort_month, MONTH)
          )) AS churned_customers
    FROM `aws_saas_sales.mrr_bridge_ledger` AS m
    INNER JOIN cohorts AS C
      ON c.customer = m.customer
    GROUP BY c.cohort_month, m.month
  ),
  metrics_expanded AS (
    SELECT
      cohort_month,
      months_since_start,
      total_revenue,
      starting_revenue,
      total_customers,
      arpu,
      gross_margin,
      AVG(growth_rate)
        OVER (
          PARTITION BY cohort_month
          ORDER BY months_since_start
        ) AS avg_growth_rate,
      SUM(arpu)
        OVER (
          PARTITION BY cohort_month
          ORDER BY months_since_start
        ) AS cummulative_arpu,
      COALESCE(
        SAFE_DIVIDE(
          total_customers,
          LAG(total_customers)
            OVER (
              PARTITION BY cohort_month 
              ORDER BY months_since_start)),
        1) AS customer_retention_rate
    FROM metrics
  )

SELECT
  cohort_month,
  months_since_start,
  ROUND(total_revenue, 2) AS total_revenue,
  ROUND(starting_revenue, 2) AS starting_revenue,
  ROUND((total_revenue / starting_revenue), 2) AS revenue_retention_rate,
  total_customers,
  ROUND(arpu, 2) AS arpu,
  ROUND(cummulative_arpu, 2) AS cummulative_arpu,
  ROUND(avg_growth_rate, 2) AS avg_growth_rate,
  ROUND(
    (
      arpu * gross_margin * (
        (1 / (1 - (customer_retention_rate * (1 - (20 / 12 / 100))))
        + (
          (avg_growth_rate * (customer_retention_rate * (1 - (20 / 12 / 100)))))
          / POWER(1 - (customer_retention_rate * (1 - (20 / 12 / 100))), 2)))),
    2) AS skok_clv
FROM metrics_expanded
ORDER BY cohort_month, months_since_start;
