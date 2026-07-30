/* 
Business Question Solved:
- Sub-Question 1B: Year-over-Year Retention & AOV Evolution
    Tracks 1-year customer retention rates and average order value (AOV) 
    expansion (Order #1 vs. Order #2) across complete historical cohorts.
*/

WITH eligible_cohort_orders AS (
    -- Step 1: Filter for orders eligible for 365-day tracking and index distinct acquisition months per year
    SELECT
        ca.*,
        DENSE_RANK() OVER(
            PARTITION BY ca.cohort_year 
            ORDER BY EXTRACT(MONTH FROM ca.first_purchase_date)
        ) AS months_in_cohort_year
    FROM
        cohort_analysis ca
    WHERE
        ca.first_purchase_date <= (
            SELECT
                MAX(orderdate) - INTERVAL '12 months'
            FROM
                cohort_analysis
        )
),

cohort_completeness_check AS (
    -- Step 2: Ensure cohort years have a full 12 months of acquisition data
    SELECT
        *,
        MAX(months_in_cohort_year) OVER(PARTITION BY cohort_year) AS total_distinct_months
    FROM
        eligible_cohort_orders
),

filtered_365d_orders AS (
    -- Step 3: Restrict to complete 12-month cohorts and index orders within 365 days of acquisition
    SELECT
        *,
        DENSE_RANK() OVER(PARTITION BY customerkey ORDER BY orderdate) AS order_rank,
        COUNT(customerkey) OVER(
            PARTITION BY customerkey 
            ORDER BY orderdate 
            ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING
        ) AS order_count
    FROM
        cohort_completeness_check
    WHERE
        total_distinct_months = 12
        AND orderdate <= (
            first_purchase_date + INTERVAL '365 days'
        )
),

customer_order_totals AS (
    -- Step 4: Count total order dates per customer within their acquisition cohort year
    SELECT
        cohort_year,
        customerkey,
        COUNT(orderdate) AS total_orders
    FROM
        filtered_365d_orders
    GROUP BY
        cohort_year,
        customerkey
),

customer_retention_volumes AS (
    -- Step 5: Aggregate customer acquisition volumes, churn/retention split, and retention % per cohort year
    SELECT
        cohort_year,
        COUNT(customerkey) AS total_acquired_customers,
        COUNT(CASE WHEN total_orders = 1 THEN customerkey END) AS churned_customer_count,
        COUNT(CASE WHEN total_orders >= 2 THEN customerkey END) AS retained_customer_count,
        ROUND(
            (COUNT(CASE WHEN total_orders >= 2 THEN customerkey END) * 100.0 / COUNT(customerkey))::NUMERIC, 
            2
        ) AS retention_rate_pct
    FROM
        customer_order_totals
    GROUP BY
        cohort_year
),

retained_aov_by_order AS (
    -- Step 6: Compute Order #1 AOV vs. Order #2 AOV specifically for retained customers (order_count >= 2)
    SELECT
        cohort_year,
        ROUND(
            (SUM(CASE WHEN order_rank = 1 THEN total_net_revenue END) / 
             COUNT(CASE WHEN order_rank = 1 THEN customerkey END))::NUMERIC, 
            2
        ) AS retained_order_1_aov,
        ROUND(
            (SUM(CASE WHEN order_rank = 2 THEN total_net_revenue END) / 
             COUNT(CASE WHEN order_rank = 2 THEN customerkey END))::NUMERIC, 
            2
        ) AS retained_order_2_aov
    FROM
        filtered_365d_orders
    WHERE
        order_count >= 2
        AND order_rank BETWEEN 1 AND 2
    GROUP BY
        cohort_year
)
-- Final Output: Historical retention trajectory alongside Order #1 vs Order #2 AOV expansion by cohort year
SELECT
    crv.cohort_year,
    crv.total_acquired_customers,
    crv.churned_customer_count,
    crv.retained_customer_count,
    crv.retention_rate_pct,
    aov.retained_order_1_aov,
    aov.retained_order_2_aov
FROM
    customer_retention_volumes crv
INNER JOIN 
    retained_aov_by_order aov ON
    crv.cohort_year = aov.cohort_year
ORDER BY
    crv.cohort_year ASC;