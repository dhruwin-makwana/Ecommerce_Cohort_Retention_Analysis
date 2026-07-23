CREATE VIEW cohort_analysis AS 
WITH customer_revenue AS(
    SELECT
        s.customerkey,
        s.orderdate,
        SUM(s.quantity * s.netprice * s.exchangerate) AS total_net_revenue,
        COUNT(s.orderkey) AS num_orders,
        c.givenname,
        c.surname,
        c.age,
        c.statefull 
    FROM
        sales s
    LEFT JOIN customer c ON c.customerkey = s.customerkey
    GROUP BY
        c.givenname,
        c.surname,
        c.age,
        c.statefull, 
        s.customerkey,
        s.orderdate
)

SELECT 
    cr.*,
    MIN(cr.orderdate) OVER(PARTITION BY cr.customerkey) AS first_purchase_date,
    EXTRACT(YEAR FROM MIN(cr.orderdate) OVER(PARTITION BY cr.customerkey)) AS cohort_year
FROM customer_revenue cr;


