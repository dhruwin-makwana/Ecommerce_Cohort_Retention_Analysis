/* 
Business Questions Solved:
- Primary Question 3: Gateway Product Performance
    Which initial product subcategories ("Gateway Products") drive the 
    highest rate of 2nd purchases?
- Sub-Question 3A: Conversion Baseline Comparison
    How do individual product subcategories perform against our overall 
    company baseline retention rate (in percentage points variance)?
*/

WITH max_date_anchor AS (
    -- Anchor CTE: Pull the max dataset date once to avoid repeated full table scans
    SELECT
        MAX(orderdate) AS max_date
    FROM
        sales
),

customer_first_purchases AS (
    -- Step 1: Map product details and compute each customer's first purchase date
    SELECT
        s.orderkey,
        s.linenumber,
        s.orderdate,
        MIN(orderdate) OVER(PARTITION BY s.customerkey ORDER BY s.orderdate) AS first_purchase_date,
        s.customerkey,
        s.productkey,
        p.subcategorykey,
        p.subcategoryname
    FROM
        sales s
    INNER JOIN 
        product p ON s.productkey = p.productkey
),

cohort_filtered_orders AS (
    -- Step 2: Restrict analysis to the mature customer cohort (acquired 12-24 months ago)
    -- and index their transactions chronologically within a 365-day window
    SELECT
        DENSE_RANK() OVER(PARTITION BY cfp.customerkey ORDER BY cfp.orderdate) AS order_num,
        cfp.*
    FROM
        customer_first_purchases cfp
    CROSS JOIN 
        max_date_anchor mda
    WHERE
        first_purchase_date <= (mda.max_date - INTERVAL '12 months')
        AND first_purchase_date >= (mda.max_date - INTERVAL '24 months')
        AND orderdate <= (first_purchase_date + INTERVAL '365 days')
),

customer_order_totals AS (
    -- Step 3: Calculate total orders placed per customer within the 1-year window
    SELECT
        MAX(cfo.order_num) OVER(PARTITION BY cfo.customerkey) AS total_order_placed,
        cfo.*
    FROM
        cohort_filtered_orders cfo
),

acquired_cust_by_subcategory AS (
    -- Step 4: Calculate total distinct customers acquired per subcategory on Order #1
    SELECT
        subcategoryname,
        COUNT(DISTINCT customerkey) AS total_acquired_cust
    FROM
        customer_order_totals
    WHERE
        order_num = 1
    GROUP BY
        subcategoryname
),

company_baseline AS (
    -- Step 5: Compute the overall 1-year cohort retention rate across the entire business
    SELECT 
        ROUND(
            (COUNT(DISTINCT CASE WHEN total_order_placed >= 2 THEN customerkey END) * 100.0 / 
             COUNT(DISTINCT customerkey))::NUMERIC, 
            2
        ) AS baseline_rate
    FROM 
        customer_order_totals
    WHERE 
        order_num = 1
)

-- Final Output: Aggregate retained customers, compute Subcategory Retention Rate,
-- and measure variance against Company Baseline Performance (% Points)
SELECT
    cot.subcategoryname,
    COUNT(DISTINCT cot.customerkey) AS retained_customer_count,
    MAX(acs.total_acquired_cust) AS total_acquired_customer_count,
    
    -- Subcategory 1-year retention rate %
    ROUND(
        (COUNT(DISTINCT cot.customerkey) * 100.0 / MAX(acs.total_acquired_cust)), 
        2
    ) AS subcategory_retention_rate_pct,
    
    MAX(cb.baseline_rate) AS company_baseline_rate_pct,
    
    -- Variance against overall company baseline retention rate (Percentage Points)
    ROUND(
        (COUNT(DISTINCT cot.customerkey) * 100.0 / MAX(acs.total_acquired_cust)), 
        2
    ) - MAX(cb.baseline_rate) AS vs_baseline_pct_points

FROM
    customer_order_totals cot
RIGHT JOIN 
    acquired_cust_by_subcategory acs ON acs.subcategoryname = cot.subcategoryname
CROSS JOIN 
    company_baseline cb
WHERE
    cot.order_num = 1
    AND cot.total_order_placed >= 2
GROUP BY
    cot.subcategoryname
ORDER BY
    retained_customer_count DESC;