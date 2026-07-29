/* 
Business Questions Solved:
- Q1: Repeat purchase conversion rate (% of acquired customers retained within 365 days)
- Q2: Average Lifetime Value of a single-order buyer versus a repeat buyer
- Q2A: Revenue concentration (Revenue split: Churned vs. Retained)
- Q2B: LTV Multiplier (Expansion factor of repeat buyers vs. 1-time buyers) */

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
    -- Step 2: Extract all orders placed within a 365-day window from each customer's first purchase
    SELECT
        ca.customerkey,
        ca.orderdate,
        ca.total_net_revenue
    FROM
        mature_cohort_customers m
    INNER JOIN 
        cohort_analysis ca ON
        m.customerkey = ca.customerkey
    WHERE
        ca.orderdate <= m.cohort_date + INTERVAL '365 days'
),

customer_buckets AS (
    -- Step 3: Segment customers into Churned (1 order) vs. Retained (2+ orders) and calculate total revenue
    SELECT
        customerkey,
        CASE
            WHEN COUNT(customerkey) = 1 THEN 'Churned_Cust'
            WHEN COUNT(customerkey) >= 2 THEN 'Retained_Cust'
        END AS customer_segment,
        SUM(total_net_revenue) AS total_customer_revenue
    FROM
        customer_365d_orders
    GROUP BY
        customerkey
)
-- Final Output: Cohort volume, revenue concentration %, LTV, and LTV multiplier comparison
SELECT
    customer_segment,
    COUNT(customerkey) AS total_customer_count,
    ROUND(
        COUNT(customerkey) * 100.0 / SUM(COUNT(customerkey)) OVER(),
        1
    ) AS customer_share_pct,
    
    SUM(total_customer_revenue) AS total_segment_revenue,
    ROUND(
        (SUM(total_customer_revenue) * 100.0 / SUM(SUM(total_customer_revenue)) OVER())::NUMERIC, 
        1
    ) AS revenue_share_pct,
    
    ROUND(
        (SUM(total_customer_revenue) / COUNT(customerkey))::NUMERIC, 
        2
    ) AS avg_ltv,
    ROUND(
        ((SUM(total_customer_revenue) / COUNT(customerkey)) / FIRST_VALUE(SUM(total_customer_revenue) / COUNT(customerkey)) OVER(ORDER BY customer_segment))::NUMERIC, 
        2
    ) AS ltv_multiplier
FROM
    customer_buckets
GROUP BY
    customer_segment
ORDER BY
    customer_segment ASC;