CREATE OR REPLACE VIEW public.cohort_analysis AS 
WITH customer_revenue AS (
    SELECT
        s.customerkey,
            s.orderdate,
            sum(s.quantity * s.netprice / s.exchangerate) AS total_net_revenue,
            count(s.orderkey) AS num_orders,
            c.givenname,
            c.surname,
            c.age,
            c.countryfull
    FROM
        sales s
    LEFT JOIN customer c ON c.customerkey = s.customerkey
    GROUP BY
        c.givenname,
        c.surname,
        c.age,
        c.countryfull,
        s.customerkey,
        s.orderdate
)
 SELECT
    customerkey,
    orderdate,
    total_net_revenue,
    num_orders,
    concat(TRIM(givenname), ' ', TRIM(surname)) AS full_name,
    age,
    countryfull,
    min(orderdate) OVER (PARTITION BY customerkey) AS first_purchase_date,
    EXTRACT(YEAR FROM min(orderdate) OVER (PARTITION BY customerkey)) AS cohort_year
FROM
    customer_revenue cr;