/* 
Business Question Solved:
- Order Frequency Breakdown: How are repeat customers distributed across 
  exact order counts (1 Order vs. 2 Orders vs. 3+ Orders) within 365 days?
 */

WITH mature_cohort_customers AS (
    -- Step 1: Isolate mature customer cohort acquired between 12 and 24 months ago
    SELECT
        ca.customerkey,
        MIN(ca.orderdate) AS cohort_date
    FROM
        cohort_analysis ca
    GROUP BY
        ca.customerkey
    HAVING
        MIN(ca.orderdate) >= (
            SELECT
                MAX(ca.orderdate)
            FROM
                cohort_analysis ca
        ) - INTERVAL '24 months'
        AND MIN(ca.orderdate) <= (
            SELECT
                MAX(ca.orderdate)
            FROM
                cohort_analysis ca
        ) - INTERVAL '12 months'
),

customer_365d_orders AS (
    -- Step 2: Extract all orders placed within 365 days of first purchase
    SELECT
        ca.customerkey,
        ca.orderdate,
        ca.total_net_revenue
    FROM
        mature_cohort_customers m
    INNER JOIN 
        cohort_analysis ca ON m.customerkey = ca.customerkey
    WHERE
        ca.orderdate <= m.cohort_date + INTERVAL '365 days'
),

customer_buckets AS (
    -- Step 3: Bucket customers by order volume frequency (1 Order, 2 Orders, 3+ Orders)
    SELECT
        customerkey,
        CASE
            WHEN COUNT(customerkey) = 1 THEN '1_Order'
            WHEN COUNT(customerkey) = 2 THEN '2_Orders'
            ELSE '3+_Orders'
        END AS order_frequency_bucket,
        SUM(total_net_revenue) AS total_customer_revenue
    FROM
        customer_365d_orders
    GROUP BY
        customerkey
)

-- Final Output: Customer volume distribution and revenue contribution by order frequency
SELECT
    order_frequency_bucket,
    COUNT(customerkey) AS total_customer_count,
    ROUND(
        COUNT(customerkey) * 100.0 / SUM(COUNT(customerkey)) OVER(), 
        1
    ) AS customer_share_pct,
    
    SUM(total_customer_revenue) AS total_segment_revenue,
    ROUND(
        (SUM(total_customer_revenue) * 100.0 / SUM(SUM(total_customer_revenue)) OVER())::NUMERIC, 
        1
    ) AS revenue_share_pct

FROM
    customer_buckets
GROUP BY
    order_frequency_bucket
ORDER BY
    order_frequency_bucket ASC;