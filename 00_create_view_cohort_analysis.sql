/*
Purpose:
    Creates the base reporting view `public.cohort_analysis`.
    Normalizes raw transactional data by:
       1. Calculating total net revenue adjusted for exchange rates.
       2. Aggregating order counts per customer per transaction date.
       3. Extracting customer metadata (full name, age, country).
       4. Windowing each customer's absolute `first_purchase_date` and 
          `cohort_year` for downstream cohort retention models.
*/

CREATE OR REPLACE VIEW public.cohort_analysis AS 
WITH customer_revenue AS (
    -- Step 1: Calculate total net revenue (adjusted for currency exchange rates)
    -- and order counts per customer per transaction date, joining demographic data.
    SELECT
        s.customerkey,
        s.orderdate,
        SUM(s.quantity * s.netprice / s.exchangerate) AS total_net_revenue,
        COUNT(s.orderkey) AS num_orders,
        c.givenname,
        c.surname,
        c.age,
        c.countryfull
    FROM
        sales s
    LEFT JOIN 
        customer c ON c.customerkey = s.customerkey
    GROUP BY
        s.customerkey,
        s.orderdate,
        c.givenname,
        c.surname,
        c.age,
        c.countryfull
)

-- Step 2: Compute acquisition cohort windows (first_purchase_date and cohort_year) 
-- across the full transaction timeline for each customer.
SELECT
    cr.customerkey,
    cr.orderdate,
    cr.total_net_revenue,
    cr.num_orders,
    CONCAT(TRIM(cr.givenname), ' ', TRIM(cr.surname)) AS full_name,
    cr.age,
    cr.countryfull,
    MIN(cr.orderdate) OVER (PARTITION BY cr.customerkey) AS first_purchase_date,
    EXTRACT(YEAR FROM MIN(cr.orderdate) OVER (PARTITION BY cr.customerkey)) AS cohort_year
FROM
    customer_revenue cr;