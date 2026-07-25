WITH mature_cohort_customers AS (
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
        AND 
    MIN(ca.orderdate) <= (
            SELECT
                MAX(ca.orderdate)
            FROM
                cohort_analysis ca
        ) - INTERVAL '12 months'
),
    
customer_365d_orders AS (
    SELECT
        ca.customerkey,
        ca.orderdate,
        ca.total_net_revenue
    FROM
        mature_cohort_customers m
    INNER JOIN cohort_analysis ca ON
        m.customerkey = ca.customerkey
    WHERE
        ca.orderdate <= m.cohort_date + INTERVAL '365 days'
),

customer_buckets AS (
    SELECT
        customerkey,
        CASE
            WHEN COUNT(customerkey) = 1 THEN '1_Order'
            WHEN COUNT(customerkey) = 2 THEN '2_Orders'
            ELSE '3+_Orders'
        END AS customer_type,
        SUM(total_net_revenue) AS t_rev
    FROM
        customer_365d_orders
    GROUP BY
        customerkey
)

SELECT
    customer_type,
    COUNT(customerkey) AS total_type_customers,
    ROUND(COUNT(customerkey)* 100.0 / SUM(COUNT(customerkey)) OVER(), 1) AS "%_of_Customer_Base",
    SUM(t_rev) AS revenue,
    ROUND((SUM(t_rev) * 100.0 / SUM(SUM(t_rev)) OVER())::NUMERIC, 1) AS "%_of_Total_Revenue"
FROM
    customer_buckets
GROUP BY
    customer_type;
