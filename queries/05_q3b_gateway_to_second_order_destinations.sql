/* 
Business Questions Solved:
- Primary Question 3: Gateway Product Performance
    Which initial product subcategories ("Gateway Products") drive the 
    highest rate of 2nd purchases?
- Sub-Question 3B: Second Order Destination
    What specific products or categories do customers most frequently 
    buy on their second order after purchasing a specific Gateway Product?
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

retained_cust_order_1 AS (
    -- Step 4: Extract initial purchase details (Order #1) for retained customers
    SELECT DISTINCT 
        cot.total_order_placed,
        cot.order_num,
        cot.orderkey,
        cot.orderdate,
        cot.customerkey,
        cot.subcategorykey,
        cot.subcategoryname 
    FROM 
        customer_order_totals cot
    WHERE 
        cot.total_order_placed >= 2 
        AND cot.order_num = 1
),

retained_cust_order_2 AS (
    -- Step 5: Extract follow-up purchase details (Order #2) for retained customers
    SELECT DISTINCT 
        cot.total_order_placed,
        cot.order_num,
        cot.orderkey,
        cot.orderdate,
        cot.customerkey,
        cot.subcategorykey,
        cot.subcategoryname  
    FROM 
        customer_order_totals cot
    WHERE 
        cot.total_order_placed >= 2 
        AND cot.order_num = 2
),

mapped_O1_O2 AS (
    -- Step 6: Join Order #1 and Order #2 transactions at the customer level
    SELECT 
        rco1.total_order_placed,
        rco1.order_num AS o1_order_num,
        rco1.subcategorykey AS o1_subcategorykey,
        rco1.subcategoryname AS o1_subcategoryname,
        rco1.customerkey,
        rco2.order_num AS o2_order_num,
        rco2.subcategorykey AS o2_subcategorykey,
        rco2.subcategoryname AS o2_subcategoryname
    FROM 
        retained_cust_order_1 rco1
    INNER JOIN 
        retained_cust_order_2 rco2 ON rco1.customerkey = rco2.customerkey
),

gateway_retained_totals AS (
    -- Step 7: Total distinct retained customers for each Gateway Product (Order #1)
    SELECT 
        subcategoryname AS o1_subcategoryname,
        COUNT(DISTINCT customerkey) AS total_retained_gateway_cust
    FROM
        retained_cust_order_1
    GROUP BY
        subcategoryname
)

-- Final Output: Analyze gateway-to-second-order product pairs, cross-sell incidence rates,
-- and long-term retention into 3+ orders
SELECT 
    m.o1_subcategoryname AS order1_gateway_subcategory,
    m.o2_subcategoryname AS order2_destination_subcategory,
    COUNT(DISTINCT m.customerkey) AS pair_customer_count,
    MAX(grt.total_retained_gateway_cust) AS total_gateway_retained_customers,
    
    -- Incidence Rate (% of Order 1 retained buyers who bought this Order 2 subcategory)
    ROUND(
        (COUNT(DISTINCT m.customerkey) * 100.0 / MAX(grt.total_retained_gateway_cust))::NUMERIC, 
        2
    ) AS incidence_rate_pct,
    
    -- Subsequent loyalty performance (reaching 3 or more total orders)
    COUNT(DISTINCT CASE WHEN m.total_order_placed >= 3 THEN m.customerkey END) AS customers_reaching_3plus_orders,
    ROUND(
        (COUNT(DISTINCT CASE WHEN m.total_order_placed >= 3 THEN m.customerkey END) * 100.0 / COUNT(DISTINCT m.customerkey))::NUMERIC, 
        2
    ) AS pair_to_order3_conversion_pct

FROM
    mapped_O1_O2 m
INNER JOIN 
    gateway_retained_totals grt ON m.o1_subcategoryname = grt.o1_subcategoryname
GROUP BY 
    m.o1_subcategoryname, 
    m.o2_subcategoryname
ORDER BY 
    m.o1_subcategoryname ASC, 
    pair_customer_count DESC;