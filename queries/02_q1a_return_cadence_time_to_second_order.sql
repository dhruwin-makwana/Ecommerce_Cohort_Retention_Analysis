/*
Business Question Solved:
- Sub-Question 1A: Return Cadence Analysis
    How many days does it take retained customers to place their second order?
    Calculates distribution across time-to-second-order buckets as a percentage
    of total repeat buyers and overall acquired cohort.
*/

WITH customer_order_sequence AS (
    -- Step 1: Index transaction history chronologically for the 12-24 month mature cohort
    SELECT
        ROW_NUMBER() OVER(PARTITION BY ca.customerkey ORDER BY ca.orderdate) AS order_num,
        ca.customerkey,
        ca.first_purchase_date,
        ca.orderdate
    FROM
        cohort_analysis ca
    WHERE
        ca.first_purchase_date >= (
            SELECT
                MAX(ca.orderdate)
            FROM
                cohort_analysis ca
        ) - INTERVAL '24 months'
        AND ca.first_purchase_date <= (
            SELECT
                MAX(ca.orderdate)
            FROM
                cohort_analysis ca
        ) - INTERVAL '12 months'
),

retained_second_orders AS (
    -- Step 2: Isolate the second transaction (Order #2) and calculate days elapsed from first purchase
    SELECT
        customerkey,
        first_purchase_date,
        orderdate AS second_purchase_date,
        (orderdate - first_purchase_date) AS days_to_second_order
    FROM
        customer_order_sequence
    WHERE
        order_num = 2
)

-- Final Output: Group return cadence into actionable time windows with share percentages
SELECT 
    CASE
        WHEN days_to_second_order BETWEEN 0 AND 90 THEN '01. 0-90 Days'
        WHEN days_to_second_order BETWEEN 91 AND 180 THEN '02. 91-180 Days'
        WHEN days_to_second_order BETWEEN 181 AND 270 THEN '03. 181-270 Days'
        WHEN days_to_second_order BETWEEN 271 AND 365 THEN '04. 271-365 Days'
        ELSE '05. 365+ Days'
    END AS return_window_bucket,
    
    COUNT(customerkey) AS repeat_customer_count,
    
    -- Share % relative to total retained (repeat) buyers
    ROUND(
        COUNT(customerkey) * 100.0 / SUM(COUNT(customerkey)) OVER(), 
        1
    ) AS repeat_buyer_share_pct,
    
    -- Conversion % relative to total top-of-funnel acquired cohort
    ROUND(
        COUNT(customerkey) * 100.0 / (
            SELECT COUNT(customerkey) 
            FROM customer_order_sequence 
            WHERE order_num = 1
        ), 
        1
    ) AS cohort_conversion_pct

FROM 
    retained_second_orders
GROUP BY 
    return_window_bucket
ORDER BY 
    return_window_bucket ASC;