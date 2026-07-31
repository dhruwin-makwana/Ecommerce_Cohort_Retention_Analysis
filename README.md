# 🛒 E-Commerce Customer Retention & Cohort Analysis
**Author:** Dhruwin Bhimjibhai Makwana

### 🛠️ Tech Stack & Tools
* **Database:** PostgreSQL
* **Data Visualization:** Power BI, Microsoft Excel
* **SQL:** The core engine of this project, used to extract, manipulate, and analyze large volumes of data. 🗄️
* **Visual Studio Code (VS Code):** Used for making the commits and write the documentation for the project. 
* **DBeaver:** The preferred database IDE for writing, formatting, and executing SQL scripts. 💻
* **Git & GitHub:** Utilized for version control, project tracking, and sharing findings with the community. 🐙
* **Dataset:** Microsoft Contoso Retail Enterprise Dataset


### 🛠️ Technical Architecture & Tooling Strategy

This project follows a multi-tiered data pipeline designed to mirror real-world enterprise analytics workflows—pushing heavy processing up to the database layer while leveraging reporting tools for validation and executive delivery.

### 1. PostgreSQL (The Transformation & Logic Engine)
* **Role:** Heavy data processing and business logic.
* **Execution:** All cohort windowing (365-day repeat gates), date-truncation, CTEs, dynamic exchange-rate currency conversions, and customer sequence indexing were executed directly inside PostgreSQL. 
* **Key Artifact:** Engineered the foundational `public.cohort_analysis` database view to serve as a single source of truth for majorly all downstream queries.

### 2. Microsoft Excel (Data Auditing & Tabular Summaries)
* **Role:** Data verification and tabular stakeholder delivery.
* **Execution:** Query results were exported to Excel to perform rapid statistical checks, format percentage metrics, build preliminary ad-hoc charts, and structure clean summary sheets (`.xlsx`) in the `/results` repository directory for financial auditing.

### 3. Power BI (Executive Dashboarding & Visual Storytelling)
* **Role:** Interactive reporting and dynamic KPI tracking.
* **Execution:** Connected directly to the finalized SQL outputs to construct an interactive executive dashboard. Utilized DAX (Data Analysis Expressions) for dynamic measures like `365-Day Retention %`, `LTV Multiplier`, and `Days-to-Second-Order Distribution` to enable seamless cross-filtering across gateway product subcategories.

---

## 🚀 Executive Summary (TL;DR)--
*To be filled out once all analysis is complete. Provide 3-4 bullet points of your highest-impact findings here.*
* [ 💡 PLACEHOLDER: E.g., "Repeat buyers drive X% of total revenue despite only making up Y% of the customer base." ]
* [ 💡 PLACEHOLDER: E.g., "Identified [Subcategory] as the ultimate Gateway Product, driving a 365-day retention rate XX% above the company baseline." ]
* [ 💡 PLACEHOLDER: E.g., "Discovered that X% of returning customers take over 90 days to make a second purchase, indicating current 30-day retargeting campaigns are mistimed." ]

---

## 📖 Business Scenario & Case Study Context

**The Company:** Contoso, an established global e-commerce retailer.

**The Problem:** The E-Commerce Leadership Team has historically focused heavily on New Customer Acquisition (which carries a high Customer Acquisition Cost, or CAC). However, overall profitability is stagnating. Treating e-commerce buyers like monthly subscribers leads to misaligned marketing campaigns. The business suspects that a massive portion of acquired customers only buy once and never return, leaving substantial revenue on the table.

**The Objective:** Shift the strategic focus from pure acquisition to activation and retention. As the lead Data Analyst, my goal is to investigate repeat purchase timing, quantify the "One-and-Done" revenue leak, prove the financial value (LTV) of repeat buyers, and provide marketing with data-driven "Gateway Product" triggers to convert first-time buyers into loyal customers.

---

## ⚙️ Analytical Methodology & Scope

To ensure statistical accuracy and avoid right-censoring bias (where recent customers haven't had enough time to return), this project employs strict cohort definitions:

* **The "Mature Cohort" Gate:** Baseline metrics are restricted to customers acquired 12 to 24 months prior to the latest database entry. This ensures every customer analyzed had a full, fair 365 days to make a second purchase. This frame sereves as a mature cohort and the most latest data on which we can make accurate analysis on.
* **The 365-Day Activation Window:** A repeat buyer is strictly defined as someone who makes their 2nd purchase within 365 days of their 1st purchase. Thus we can say our company has the churn cycle of 365 days.
* **Clean YoY Trending:** When comparing annual cohorts (e.g., 2021 vs 2022), partial business launch years or incomplete current years are excluded to prevent volatile, inaccurate percentage spikes.

---

## 🗃️ Data Architecture & Schema

This analysis relies on a relational star schema built from the Contoso dataset. To optimize query performance and standardize business logic (like currency conversion and cohort generation), a foundational SQL view was created.

### The Foundation: `public.cohort_analysis` View
Instead of repeating complex aggregation logic across every query, I engineered a base view that:
1. Calculates total net revenue adjusted dynamically for exchange rates.
2. Aggregates order counts per customer per transaction date.
3. Windows each customer's absolute `first_purchase_date` and `cohort_year` for downstream retention models.

<details>
<summary><b>🔍 Click here to view "Create_View" Query

**🖥️ Query**: [00_create_view_cohort_analysis.sql](/queries/00_create_view_cohort_analysis.sql)
</b></summary>

```sql
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
```
</details>


![Top Paying Remote Data Analyst Jobs](/assets/Schema.png)
*Entity-Relationship Diagram*

**🖼️ Click here for better view**: [Entity-Relationship Diagram](/assets/Schema.png)

---

## 🎯 Deep-Dive Analysis: The 3 Core Business Questions

### 📊 Phase 1: Baseline Retention Efficiency & Return Cadence (Question 1)
**Core Objective:** Quantify the size of the "One-and-Done" revenue leak and identify the exact post-purchase timing window for re-engagement.
* **Hypothesis:** Because e-commerce relies heavily on acquisition, the baseline repeat rate is likely low, creating a "one-and-done" bottleneck.
#### **Q1: What percentage of our acquired customers convert from a first purchase to a second purchase within 365 days?**

* **Why this matters:** We cannot improve what we don't measure. Establishing a strict baseline shows the exact size of the retention gap.

<details>
<summary><b>🔍 Click to view SQL Query

**🖥️ Query**: [01_q1_q2_cohort_retention_ltv_multiplier.sql](/queries/01_q1_q2_cohort_retention_ltv_multiplier.sql) 
</b></summary>

```sql
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
```
</details>

<details>
<summary><b>🔍 Click to view Resultant Table</b></summary>

|customer_segment|total_customer_count|customer_share_pct|total_segment_revenue|revenue_share_pct|avg_ltv|ltv_multiplier|
|----------------|--------------------|------------------|---------------------|-----------------|-------|--------------|
|Churned_Cust|6794|79.0|14516604.705265613|63.9|2136.68|1.00|
|Retained_Cust|1807|21.0|8195692.105907859|36.1|4535.52|2.12|

</details>

[ 🖼️ PLACEHOLDER: Insert visual/chart for Q1A ]

Key Insight: [ 💡 PLACEHOLDER: Insight here ]

#### **Q1A: For the customers who do return, how many days does it take them to place their second order?**
* **Why this matters:** Understanding when people organically return tells marketing exactly when to trigger retargeting ads and automated email flows.

<details>
<summary><b>🔍 Click to view SQL Query

**🖥️ Query**: [02_q1a_return_cadence_time_to_second_order.sql](/queries/02_q1a_return_cadence_time_to_second_order.sql)
</b></summary>

```sql
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
```
</details>

<details>
<summary><b>🔍 Click to view Resultant Table</b></summary>

|return_window_bucket|repeat_customer_count|repeat_buyer_share_pct|cohort_conversion_pct|
|--------------------|---------------------|----------------------|---------------------|
|01. 0-90 Days|568|22.6|6.6|
|02. 91-180 Days|484|19.3|5.6|
|03. 181-270 Days|377|15.0|4.4|
|04. 271-365 Days|378|15.1|4.4|
|05. 365+ Days|704|28.0|8.2|

</details>

[ 🖼️ PLACEHOLDER: Insert visual/chart for Q1A ]

Key Insight: [ 💡 PLACEHOLDER: Insight here ]

#### **Q1B: How has our 1-year retention rate percentage evolved year-over-year across mature historical cohorts?**
* **Why this matters:** Tracks whether the company's customer loyalty is naturally improving or degrading over time.

<details>
<summary><b>🔍 Click to view SQL Query

**🖥️ Query**: [03_q1b_yoy_retention_and_aov_trend.sql](/queries/03_q1b_yoy_retention_and_aov_trend.sql)
</b></summary>

```sql
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
```
</details>

<details>
<summary><b>🔍 Click to view Resultant Table</b></summary>

|cohort_year|total_acquired_customers|churned_customer_count|retained_customer_count|retention_rate_pct|retained_order_1_aov|retained_order_2_aov|
|-----------|------------------------|----------------------|-----------------------|------------------|--------------------|--------------------|
|2015|2825|2707|118|4.18|2923.70|2829.59|
|2016|3397|3250|147|4.33|2609.22|2463.34|
|2017|4068|3698|370|9.10|3211.49|3337.31|
|2018|7446|6371|1075|14.44|2825.48|2862.89|
|2019|7755|6803|952|12.28|2936.91|2481.62|
|2020|3031|2866|165|5.44|2681.62|2902.72|
|2021|4663|3735|928|19.90|2629.34|2427.28|
|2022|9010|7033|1977|21.94|2377.55|2105.98|

</details>


[ 🖼️ PLACEHOLDER: Insert visual/chart for Q1B ]

Key Insight: [ 💡 PLACEHOLDER: Insight here ]

### 📈 Phase 2: The Revenue & LTV Multiplier (Question 2)
**Core Objective:** Prove the financial ROI of a repeat buyer to justify shifting budget from pure acquisition to retention.
* **Hypothesis:** "Because repeat rates are low, the small group of repeat buyers must be generating a disproportionately massive chunk of our total Lifetime Value (LTV) to keep the business profitable."

#### **Q2 & Q2A: What is the average LTV of a single-order buyer versus a repeat buyer, and what is their revenue concentration(percentage of our total cumulative net revenue)?**
* **Why this matters:** Proves to stakeholders that a small segment of retained users drives the majority of the business.

<details>
<summary><b>🔍 Click to view SQL Query

**🖥️ Query**: [01_q1_q2_cohort_retention_ltv_multiplier.sql](/queries/01_q1_q2_cohort_retention_ltv_multiplier.sql)
</b></summary>

```sql
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
```
</details>

<details>
<summary><b>🔍 Click to view Resultant Table</b></summary>

|customer_segment|total_customer_count|customer_share_pct|total_segment_revenue|revenue_share_pct|avg_ltv|ltv_multiplier|
|----------------|--------------------|------------------|---------------------|-----------------|-------|--------------|
|Churned_Cust|6794|79.0|14516604.705265613|63.9|2136.68|1.00|
|Retained_Cust|1807|21.0|8195692.105907859|36.1|4535.52|2.12|

</details>

[ 🖼️ PLACEHOLDER: Insert visual/chart for Q2/Q2A ]

Key Insight: [ 💡 PLACEHOLDER: Insight here ]

#### **Q2B (The LTV Multiplier): By what exact factor ($X\times$) does customer value expand when a first-time buyer is converted into a second-time buyer?**
* **Why this matters:** Quantifies exactly how much more a customer is worth if marketing can successfully get them to buy a second time.

<details>
<summary><b>🔍 Click to view SQL Query

**🖥️ Query**: [01_q1_q2_cohort_retention_ltv_multiplier.sql](/queries/01_q1_q2_cohort_retention_ltv_multiplier.sql)
</b></summary>

```sql
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
```
</details>

<details>
<summary><b>🔍 Click to view Resultant Table</b></summary>

|customer_segment|total_customer_count|customer_share_pct|total_segment_revenue|revenue_share_pct|avg_ltv|ltv_multiplier|
|----------------|--------------------|------------------|---------------------|-----------------|-------|--------------|
|Churned_Cust|6794|79.0|14516604.705265613|63.9|2136.68|1.00|
|Retained_Cust|1807|21.0|8195692.105907859|36.1|4535.52|2.12|

</details>


[ 🖼️ PLACEHOLDER: Insert visual/chart for Q2B ]

Key Insight: [ 💡 PLACEHOLDER: Insight here ]

### 🛒 Phase 3: Gateway Products for 2nd-Purchase Conversion (Question 3)
**Core Objective:** Provide the marketing team with tactical, product-level triggers for retargeting campaigns.
* **Hypothesis:** "If repeat buyers drive most of our profit, there must be specific gateway products in their FIRST purchase that naturally encourage them to come back."

#### **Q3 & Q3A: Which initial product subcategories ("Gateway Products") drive the highest rate of 2nd purchases; and How do individual product subcategories perform against our overall company baseline retention rate?**
* **Why this matters:** If we know which products naturally create loyal customers, marketing can feature those specific products in top-of-funnel acquisition ads.

<details>
<summary><b>🔍 Click to view SQL Query

**🖥️ Query**: [04_q3a_gateway_product_retention_vs_baseline.sql](/queries/04_q3a_gateway_product_retention_vs_baseline.sql)
</b></summary>

```sql
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
```
</details>

<details>
<summary><b>🔍 Click to view Resultant Table</b></summary>

|subcategoryname|retained_customer_count|total_acquired_customer_count|subcategory_retention_rate_pct|company_baseline_rate_pct|vs_baseline_pct_points|
|---------------|-----------------------|-----------------------------|------------------------------|-------------------------|----------------------|
|Movie DVD|609|2953|20.62|21.01|-0.39|
|Desktops|363|1570|23.12|21.01|2.11|
|Smart phones & PDAs |342|1723|19.85|21.01|-1.16|
|Touch Screen Phones |309|1458|21.19|21.01|0.18|
|Boxed Games|196|962|20.37|21.01|-0.64|
|Cell phones Accessories|161|828|19.44|21.01|-1.57|
|Televisions|158|760|20.79|21.01|-0.22|
|Computers Accessories|153|686|22.30|21.01|1.29|
|Home & Office Phones|150|795|18.87|21.01|-2.14|
|Laptops|149|661|22.54|21.01|1.53|
|Monitors|149|659|22.61|21.01|1.60|
|Projectors & Screens|147|641|22.93|21.01|1.92|
|Download Games|139|702|19.80|21.01|-1.21|
|Printers, Scanners & Fax|124|654|18.96|21.01|-2.05|
|Bluetooth Headphones|91|464|19.61|21.01|-1.40|
|Water Heaters|85|422|20.14|21.01|-0.87|
|Microwaves|83|399|20.80|21.01|-0.21|
|VCD & DVD|73|345|21.16|21.01|0.15|
|Car Video|64|275|23.27|21.01|2.26|
|Digital SLR Cameras|62|290|21.38|21.01|0.37|
|Refrigerators|53|204|25.98|21.01|4.97|
|Camcorders|51|226|22.57|21.01|1.56|
|Digital Cameras|51|210|24.29|21.01|3.28|
|Recording Pen|48|224|21.43|21.01|0.42|
|Home Theater System|42|214|19.63|21.01|-1.38|
|MP4&MP3|37|175|21.14|21.01|0.13|
|Coffee Machines|36|184|19.57|21.01|-1.44|
|Cameras & Camcorders Accessories|35|179|19.55|21.01|-1.46|
|Air Conditioners|33|171|19.30|21.01|-1.71|
|Washers & Dryers|32|126|25.40|21.01|4.39|
|Fans|28|127|22.05|21.01|1.04|
|Lamps|26|130|20.00|21.01|-1.01|

</details>

[ 🖼️ PLACEHOLDER: Insert visual/chart for Q3A ]

Key Insight: [ 💡 PLACEHOLDER: Insight here ]

#### **Q3B: What specific products or categories do customers most frequently buy on their second order after purchasing a specific Gateway Product?**
* **Why this matters:**  Maps the exact cross-sell pathway ($O_1 \rightarrow O_2$) so marketing can build highly personalized product recommendation engines.

<details>
<summary><b>🔍 Click to view SQL Query

**🖥️ Query**: [05_q3b_gateway_to_second_order_destinations.sql](/queries/05_q3b_gateway_to_second_order_destinations.sql)
</b></summary>

```sql
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
```
</details>

<details>
<summary><b>🔍 Click to view Resultant Table</b></summary>

|order1_gateway_subcategory|order2_destination_subcategory|pair_customer_count|total_gateway_retained_customers|incidence_rate_pct|customers_reaching_3plus_orders|pair_to_order3_conversion_pct|
|--------------------------|------------------------------|-------------------|--------------------------------|------------------|-------------------------------|-----------------------------|
|Air Conditioners|Movie DVD|15|33|45.45|3|20.00|
|Air Conditioners|Touch Screen Phones |5|33|15.15|1|20.00|
|Air Conditioners|Monitors|5|33|15.15|1|20.00|
|Air Conditioners|Smart phones & PDAs |5|33|15.15|0|0.00|
|Air Conditioners|Cell phones Accessories|4|33|12.12|0|0.00|
|Air Conditioners|Download Games|3|33|9.09|0|0.00|
|Air Conditioners|VCD & DVD|3|33|9.09|0|0.00|
|Air Conditioners|Desktops|3|33|9.09|1|33.33|
|Air Conditioners|Home & Office Phones|3|33|9.09|1|33.33|
|Air Conditioners|Camcorders|2|33|6.06|1|50.00|
|Air Conditioners|Car Video|2|33|6.06|0|0.00|
|Air Conditioners|Computers Accessories|2|33|6.06|0|0.00|
|Air Conditioners|Laptops|2|33|6.06|1|50.00|
|Air Conditioners|Recording Pen|2|33|6.06|1|50.00|
|Air Conditioners|Televisions|2|33|6.06|1|50.00|
|Air Conditioners|Water Heaters|2|33|6.06|2|100.00|
|Air Conditioners|Bluetooth Headphones|1|33|3.03|0|0.00|
|Air Conditioners|Refrigerators|1|33|3.03|0|0.00|
|Air Conditioners|Cameras & Camcorders Accessories|1|33|3.03|0|0.00|
|Air Conditioners|Boxed Games|1|33|3.03|0|0.00|
|Air Conditioners|Lamps|1|33|3.03|0|0.00|
|Air Conditioners|Home Theater System|1|33|3.03|0|0.00|
|Air Conditioners|Printers, Scanners & Fax|1|33|3.03|1|100.00|
|Bluetooth Headphones|Movie DVD|34|91|37.36|3|8.82|
|Bluetooth Headphones|Smart phones & PDAs |27|91|29.67|4|14.81|
|Bluetooth Headphones|Touch Screen Phones |21|91|23.08|2|9.52|
|Bluetooth Headphones|Desktops|20|91|21.98|1|5.00|
|Bluetooth Headphones|Televisions|11|91|12.09|1|9.09|
|Bluetooth Headphones|Home & Office Phones|9|91|9.89|0|0.00|
|Bluetooth Headphones|Computers Accessories|8|91|8.79|1|12.50|
|Bluetooth Headphones|Laptops|8|91|8.79|0|0.00|
|Bluetooth Headphones|Printers, Scanners & Fax|8|91|8.79|0|0.00|
|Bluetooth Headphones|Monitors|7|91|7.69|2|28.57|
|Bluetooth Headphones|Download Games|7|91|7.69|0|0.00|
|Bluetooth Headphones|Boxed Games|6|91|6.59|0|0.00|
|Bluetooth Headphones|Bluetooth Headphones|6|91|6.59|0|0.00|
|Bluetooth Headphones|Cell phones Accessories|6|91|6.59|0|0.00|
|Bluetooth Headphones|Digital SLR Cameras|5|91|5.49|0|0.00|
|Bluetooth Headphones|Home Theater System|4|91|4.40|0|0.00|
|Bluetooth Headphones|Microwaves|4|91|4.40|0|0.00|
|Bluetooth Headphones|Recording Pen|4|91|4.40|0|0.00|
|Bluetooth Headphones|Digital Cameras|3|91|3.30|1|33.33|
|Bluetooth Headphones|VCD & DVD|3|91|3.30|0|0.00|
|Bluetooth Headphones|Water Heaters|3|91|3.30|0|0.00|
|Bluetooth Headphones|Refrigerators|3|91|3.30|0|0.00|
|Bluetooth Headphones|Projectors & Screens|3|91|3.30|2|66.67|
|Bluetooth Headphones|MP4&MP3|2|91|2.20|1|50.00|
|Bluetooth Headphones|Car Video|2|91|2.20|1|50.00|
|Bluetooth Headphones|Air Conditioners|1|91|1.10|0|0.00|
|Bluetooth Headphones|Cameras & Camcorders Accessories|1|91|1.10|0|0.00|
|Boxed Games|Movie DVD|61|196|31.12|8|13.11|
|Boxed Games|Smart phones & PDAs |37|196|18.88|2|5.41|
|Boxed Games|Touch Screen Phones |34|196|17.35|5|14.71|
|Boxed Games|Desktops|33|196|16.84|3|9.09|
|Boxed Games|Download Games|32|196|16.33|4|12.50|
|Boxed Games|Printers, Scanners & Fax|28|196|14.29|2|7.14|
|Boxed Games|Computers Accessories|26|196|13.27|4|15.38|
|Boxed Games|Boxed Games|22|196|11.22|3|13.64|
|Boxed Games|Laptops|19|196|9.69|3|15.79|
|Boxed Games|Televisions|16|196|8.16|3|18.75|
|Boxed Games|Monitors|16|196|8.16|3|18.75|
|Boxed Games|Home & Office Phones|15|196|7.65|3|20.00|
|Boxed Games|Projectors & Screens|14|196|7.14|1|7.14|
|Boxed Games|Cell phones Accessories|11|196|5.61|1|9.09|
|Boxed Games|Digital SLR Cameras|10|196|5.10|2|20.00|
|Boxed Games|Water Heaters|10|196|5.10|0|0.00|
|Boxed Games|Bluetooth Headphones|9|196|4.59|1|11.11|
|Boxed Games|Digital Cameras|9|196|4.59|2|22.22|
|Boxed Games|Air Conditioners|7|196|3.57|0|0.00|
|Boxed Games|Home Theater System|7|196|3.57|1|14.29|
|Boxed Games|VCD & DVD|7|196|3.57|0|0.00|
|Boxed Games|Car Video|6|196|3.06|1|16.67|
|Boxed Games|Microwaves|6|196|3.06|0|0.00|
|Boxed Games|Washers & Dryers|6|196|3.06|0|0.00|
|Boxed Games|Recording Pen|6|196|3.06|0|0.00|
|Boxed Games|MP4&MP3|5|196|2.55|1|20.00|
|Boxed Games|Camcorders|5|196|2.55|0|0.00|
|Boxed Games|Cameras & Camcorders Accessories|4|196|2.04|1|25.00|
|Boxed Games|Lamps|4|196|2.04|0|0.00|
|Boxed Games|Fans|4|196|2.04|0|0.00|
|Boxed Games|Refrigerators|3|196|1.53|1|33.33|
|Boxed Games|Coffee Machines|2|196|1.02|0|0.00|
|Camcorders|Movie DVD|12|51|23.53|2|16.67|
|Camcorders|Smart phones & PDAs |12|51|23.53|2|16.67|
|Camcorders|Boxed Games|10|51|19.61|1|10.00|
|Camcorders|Printers, Scanners & Fax|8|51|15.69|1|12.50|
|Camcorders|Projectors & Screens|6|51|11.76|0|0.00|
|Camcorders|Home & Office Phones|6|51|11.76|1|16.67|
|Camcorders|Water Heaters|6|51|11.76|0|0.00|
|Camcorders|Touch Screen Phones |5|51|9.80|0|0.00|
|Camcorders|Computers Accessories|5|51|9.80|2|40.00|
|Camcorders|Download Games|5|51|9.80|0|0.00|
|Camcorders|Monitors|4|51|7.84|1|25.00|
|Camcorders|Desktops|4|51|7.84|0|0.00|
|Camcorders|Televisions|4|51|7.84|1|25.00|
|Camcorders|Recording Pen|3|51|5.88|0|0.00|
|Camcorders|MP4&MP3|3|51|5.88|1|33.33|
|Camcorders|Digital Cameras|3|51|5.88|1|33.33|
|Camcorders|Cell phones Accessories|3|51|5.88|0|0.00|
|Camcorders|Bluetooth Headphones|2|51|3.92|0|0.00|
|Camcorders|Cameras & Camcorders Accessories|2|51|3.92|0|0.00|
|Camcorders|Microwaves|2|51|3.92|0|0.00|
|Camcorders|Refrigerators|1|51|1.96|0|0.00|
|Camcorders|Home Theater System|1|51|1.96|1|100.00|
|Camcorders|Digital SLR Cameras|1|51|1.96|0|0.00|
|Camcorders|VCD & DVD|1|51|1.96|0|0.00|
|Camcorders|Washers & Dryers|1|51|1.96|0|0.00|
|Camcorders|Camcorders|1|51|1.96|0|0.00|
|Cameras & Camcorders Accessories|Touch Screen Phones |11|35|31.43|0|0.00|
|Cameras & Camcorders Accessories|Movie DVD|7|35|20.00|0|0.00|
|Cameras & Camcorders Accessories|Boxed Games|7|35|20.00|0|0.00|
|Cameras & Camcorders Accessories|Water Heaters|5|35|14.29|0|0.00|
|Cameras & Camcorders Accessories|Televisions|5|35|14.29|0|0.00|
|Cameras & Camcorders Accessories|Smart phones & PDAs |5|35|14.29|0|0.00|
|Cameras & Camcorders Accessories|Desktops|5|35|14.29|1|20.00|
|Cameras & Camcorders Accessories|Computers Accessories|4|35|11.43|1|25.00|
|Cameras & Camcorders Accessories|Download Games|3|35|8.57|0|0.00|
|Cameras & Camcorders Accessories|Bluetooth Headphones|3|35|8.57|0|0.00|
|Cameras & Camcorders Accessories|Cell phones Accessories|2|35|5.71|0|0.00|
|Cameras & Camcorders Accessories|Coffee Machines|2|35|5.71|0|0.00|
|Cameras & Camcorders Accessories|Home & Office Phones|2|35|5.71|1|50.00|
|Cameras & Camcorders Accessories|Monitors|2|35|5.71|0|0.00|
|Cameras & Camcorders Accessories|Projectors & Screens|2|35|5.71|1|50.00|
|Cameras & Camcorders Accessories|Digital SLR Cameras|1|35|2.86|0|0.00|
|Cameras & Camcorders Accessories|Printers, Scanners & Fax|1|35|2.86|0|0.00|
|Cameras & Camcorders Accessories|Air Conditioners|1|35|2.86|0|0.00|
|Cameras & Camcorders Accessories|Recording Pen|1|35|2.86|0|0.00|
|Cameras & Camcorders Accessories|Refrigerators|1|35|2.86|0|0.00|
|Cameras & Camcorders Accessories|Car Video|1|35|2.86|0|0.00|
|Cameras & Camcorders Accessories|Cameras & Camcorders Accessories|1|35|2.86|0|0.00|
|Cameras & Camcorders Accessories|Camcorders|1|35|2.86|0|0.00|
|Cameras & Camcorders Accessories|VCD & DVD|1|35|2.86|1|100.00|
|Cameras & Camcorders Accessories|Laptops|1|35|2.86|0|0.00|
|Cameras & Camcorders Accessories|Washers & Dryers|1|35|2.86|0|0.00|
|Car Video|Movie DVD|30|64|46.88|5|16.67|
|Car Video|Touch Screen Phones |14|64|21.88|1|7.14|
|Car Video|Smart phones & PDAs |13|64|20.31|1|7.69|
|Car Video|Televisions|12|64|18.75|2|16.67|
|Car Video|Desktops|12|64|18.75|1|8.33|
|Car Video|Download Games|10|64|15.63|1|10.00|
|Car Video|Cell phones Accessories|9|64|14.06|1|11.11|
|Car Video|Monitors|8|64|12.50|1|12.50|
|Car Video|Printers, Scanners & Fax|8|64|12.50|1|12.50|
|Car Video|Boxed Games|7|64|10.94|2|28.57|
|Car Video|Laptops|6|64|9.38|1|16.67|
|Car Video|Projectors & Screens|6|64|9.38|1|16.67|
|Car Video|Home & Office Phones|5|64|7.81|0|0.00|
|Car Video|Computers Accessories|5|64|7.81|0|0.00|
|Car Video|Digital SLR Cameras|4|64|6.25|0|0.00|
|Car Video|Microwaves|4|64|6.25|0|0.00|
|Car Video|Coffee Machines|3|64|4.69|0|0.00|
|Car Video|Car Video|3|64|4.69|0|0.00|
|Car Video|Fans|2|64|3.13|0|0.00|
|Car Video|VCD & DVD|2|64|3.13|0|0.00|
|Car Video|Washers & Dryers|2|64|3.13|0|0.00|
|Car Video|Air Conditioners|2|64|3.13|0|0.00|
|Car Video|Recording Pen|2|64|3.13|0|0.00|
|Car Video|Home Theater System|2|64|3.13|0|0.00|
|Car Video|Lamps|1|64|1.56|0|0.00|
|Car Video|MP4&MP3|1|64|1.56|0|0.00|
|Car Video|Digital Cameras|1|64|1.56|1|100.00|
|Car Video|Refrigerators|1|64|1.56|1|100.00|
|Car Video|Cameras & Camcorders Accessories|1|64|1.56|0|0.00|
|Car Video|Bluetooth Headphones|1|64|1.56|0|0.00|
|Car Video|Water Heaters|1|64|1.56|0|0.00|
|Cell phones Accessories|Movie DVD|57|161|35.40|5|8.77|
|Cell phones Accessories|Smart phones & PDAs |36|161|22.36|6|16.67|
|Cell phones Accessories|Touch Screen Phones |30|161|18.63|3|10.00|
|Cell phones Accessories|Desktops|26|161|16.15|3|11.54|
|Cell phones Accessories|Cell phones Accessories|19|161|11.80|0|0.00|
|Cell phones Accessories|Download Games|18|161|11.18|3|16.67|
|Cell phones Accessories|Boxed Games|17|161|10.56|1|5.88|
|Cell phones Accessories|Printers, Scanners & Fax|16|161|9.94|2|12.50|
|Cell phones Accessories|Projectors & Screens|15|161|9.32|0|0.00|
|Cell phones Accessories|Computers Accessories|14|161|8.70|3|21.43|
|Cell phones Accessories|Bluetooth Headphones|12|161|7.45|3|25.00|
|Cell phones Accessories|Monitors|10|161|6.21|3|30.00|
|Cell phones Accessories|Laptops|10|161|6.21|2|20.00|
|Cell phones Accessories|Water Heaters|9|161|5.59|0|0.00|
|Cell phones Accessories|Home & Office Phones|9|161|5.59|0|0.00|
|Cell phones Accessories|Televisions|9|161|5.59|1|11.11|
|Cell phones Accessories|Recording Pen|7|161|4.35|0|0.00|
|Cell phones Accessories|Washers & Dryers|5|161|3.11|0|0.00|
|Cell phones Accessories|Microwaves|5|161|3.11|0|0.00|
|Cell phones Accessories|Digital SLR Cameras|5|161|3.11|0|0.00|
|Cell phones Accessories|Home Theater System|4|161|2.48|1|25.00|
|Cell phones Accessories|Car Video|4|161|2.48|0|0.00|
|Cell phones Accessories|Air Conditioners|4|161|2.48|1|25.00|
|Cell phones Accessories|Lamps|4|161|2.48|1|25.00|
|Cell phones Accessories|Coffee Machines|3|161|1.86|0|0.00|
|Cell phones Accessories|VCD & DVD|3|161|1.86|1|33.33|
|Cell phones Accessories|Refrigerators|2|161|1.24|1|50.00|
|Cell phones Accessories|MP4&MP3|2|161|1.24|1|50.00|
|Cell phones Accessories|Camcorders|1|161|0.62|1|100.00|
|Cell phones Accessories|Cameras & Camcorders Accessories|1|161|0.62|0|0.00|
|Cell phones Accessories|Fans|1|161|0.62|0|0.00|
|Cell phones Accessories|Digital Cameras|1|161|0.62|0|0.00|
|Coffee Machines|Movie DVD|14|36|38.89|1|7.14|
|Coffee Machines|Desktops|7|36|19.44|0|0.00|
|Coffee Machines|Smart phones & PDAs |6|36|16.67|1|16.67|
|Coffee Machines|Download Games|6|36|16.67|1|16.67|
|Coffee Machines|Computers Accessories|6|36|16.67|2|33.33|
|Coffee Machines|Touch Screen Phones |5|36|13.89|1|20.00|
|Coffee Machines|Laptops|5|36|13.89|0|0.00|
|Coffee Machines|Coffee Machines|3|36|8.33|0|0.00|
|Coffee Machines|Cell phones Accessories|3|36|8.33|0|0.00|
|Coffee Machines|Home & Office Phones|3|36|8.33|2|66.67|
|Coffee Machines|Home Theater System|2|36|5.56|1|50.00|
|Coffee Machines|Boxed Games|2|36|5.56|0|0.00|
|Coffee Machines|Monitors|2|36|5.56|0|0.00|
|Coffee Machines|Televisions|2|36|5.56|0|0.00|
|Coffee Machines|Bluetooth Headphones|1|36|2.78|0|0.00|
|Coffee Machines|Cameras & Camcorders Accessories|1|36|2.78|0|0.00|
|Coffee Machines|Car Video|1|36|2.78|0|0.00|
|Coffee Machines|Lamps|1|36|2.78|0|0.00|
|Coffee Machines|MP4&MP3|1|36|2.78|0|0.00|
|Coffee Machines|Printers, Scanners & Fax|1|36|2.78|0|0.00|
|Coffee Machines|Projectors & Screens|1|36|2.78|0|0.00|
|Coffee Machines|Refrigerators|1|36|2.78|0|0.00|
|Coffee Machines|Washers & Dryers|1|36|2.78|0|0.00|
|Coffee Machines|Water Heaters|1|36|2.78|0|0.00|
|Computers Accessories|Movie DVD|47|153|30.72|5|10.64|
|Computers Accessories|Touch Screen Phones |31|153|20.26|4|12.90|
|Computers Accessories|Smart phones & PDAs |30|153|19.61|1|3.33|
|Computers Accessories|Desktops|20|153|13.07|1|5.00|
|Computers Accessories|Download Games|19|153|12.42|5|26.32|
|Computers Accessories|Boxed Games|19|153|12.42|4|21.05|
|Computers Accessories|Printers, Scanners & Fax|16|153|10.46|2|12.50|
|Computers Accessories|Cell phones Accessories|15|153|9.80|2|13.33|
|Computers Accessories|Home & Office Phones|14|153|9.15|1|7.14|
|Computers Accessories|Televisions|14|153|9.15|3|21.43|
|Computers Accessories|Monitors|13|153|8.50|2|15.38|
|Computers Accessories|Laptops|11|153|7.19|2|18.18|
|Computers Accessories|Digital SLR Cameras|9|153|5.88|2|22.22|
|Computers Accessories|Computers Accessories|9|153|5.88|2|22.22|
|Computers Accessories|Projectors & Screens|9|153|5.88|0|0.00|
|Computers Accessories|Recording Pen|8|153|5.23|2|25.00|
|Computers Accessories|Car Video|7|153|4.58|0|0.00|
|Computers Accessories|Bluetooth Headphones|6|153|3.92|0|0.00|
|Computers Accessories|Washers & Dryers|5|153|3.27|0|0.00|
|Computers Accessories|Digital Cameras|5|153|3.27|1|20.00|
|Computers Accessories|Refrigerators|4|153|2.61|1|25.00|
|Computers Accessories|VCD & DVD|4|153|2.61|0|0.00|
|Computers Accessories|Fans|3|153|1.96|1|33.33|
|Computers Accessories|Lamps|3|153|1.96|1|33.33|
|Computers Accessories|Microwaves|3|153|1.96|1|33.33|
|Computers Accessories|Coffee Machines|3|153|1.96|0|0.00|
|Computers Accessories|Water Heaters|3|153|1.96|0|0.00|
|Computers Accessories|Camcorders|3|153|1.96|1|33.33|
|Computers Accessories|Air Conditioners|3|153|1.96|1|33.33|
|Computers Accessories|MP4&MP3|2|153|1.31|0|0.00|
|Computers Accessories|Home Theater System|2|153|1.31|1|50.00|
|Computers Accessories|Cameras & Camcorders Accessories|1|153|0.65|0|0.00|
|Desktops|Movie DVD|142|363|39.12|15|10.56|
|Desktops|Smart phones & PDAs |78|363|21.49|15|19.23|
|Desktops|Touch Screen Phones |69|363|19.01|7|10.14|
|Desktops|Desktops|52|363|14.33|14|26.92|
|Desktops|Download Games|41|363|11.29|3|7.32|
|Desktops|Cell phones Accessories|38|363|10.47|9|23.68|
|Desktops|Projectors & Screens|31|363|8.54|6|19.35|
|Desktops|Printers, Scanners & Fax|30|363|8.26|4|13.33|
|Desktops|Laptops|30|363|8.26|6|20.00|
|Desktops|Boxed Games|30|363|8.26|2|6.67|
|Desktops|Televisions|29|363|7.99|8|27.59|
|Desktops|Monitors|28|363|7.71|3|10.71|
|Desktops|Computers Accessories|26|363|7.16|4|15.38|
|Desktops|Water Heaters|24|363|6.61|3|12.50|
|Desktops|Home & Office Phones|21|363|5.79|4|19.05|
|Desktops|Bluetooth Headphones|19|363|5.23|3|15.79|
|Desktops|Microwaves|17|363|4.68|2|11.76|
|Desktops|Digital SLR Cameras|16|363|4.41|3|18.75|
|Desktops|Recording Pen|15|363|4.13|2|13.33|
|Desktops|Car Video|14|363|3.86|3|21.43|
|Desktops|Home Theater System|12|363|3.31|0|0.00|
|Desktops|Cameras & Camcorders Accessories|12|363|3.31|2|16.67|
|Desktops|VCD & DVD|11|363|3.03|2|18.18|
|Desktops|Digital Cameras|10|363|2.75|2|20.00|
|Desktops|Air Conditioners|7|363|1.93|1|14.29|
|Desktops|Coffee Machines|7|363|1.93|1|14.29|
|Desktops|Camcorders|6|363|1.65|3|50.00|
|Desktops|MP4&MP3|5|363|1.38|1|20.00|
|Desktops|Washers & Dryers|5|363|1.38|1|20.00|
|Desktops|Lamps|4|363|1.10|1|25.00|
|Desktops|Refrigerators|3|363|0.83|0|0.00|
|Desktops|Fans|3|363|0.83|0|0.00|
|Digital Cameras|Movie DVD|19|51|37.25|2|10.53|
|Digital Cameras|Touch Screen Phones |9|51|17.65|1|11.11|
|Digital Cameras|Desktops|9|51|17.65|3|33.33|
|Digital Cameras|Smart phones & PDAs |8|51|15.69|1|12.50|
|Digital Cameras|Laptops|6|51|11.76|1|16.67|
|Digital Cameras|Download Games|6|51|11.76|0|0.00|
|Digital Cameras|Home & Office Phones|5|51|9.80|0|0.00|
|Digital Cameras|Cell phones Accessories|4|51|7.84|0|0.00|
|Digital Cameras|Printers, Scanners & Fax|4|51|7.84|0|0.00|
|Digital Cameras|Bluetooth Headphones|4|51|7.84|2|50.00|
|Digital Cameras|Car Video|3|51|5.88|0|0.00|
|Digital Cameras|Recording Pen|3|51|5.88|0|0.00|
|Digital Cameras|Cameras & Camcorders Accessories|3|51|5.88|1|33.33|
|Digital Cameras|Televisions|3|51|5.88|0|0.00|
|Digital Cameras|Water Heaters|2|51|3.92|0|0.00|
|Digital Cameras|Air Conditioners|2|51|3.92|1|50.00|
|Digital Cameras|Boxed Games|2|51|3.92|1|50.00|
|Digital Cameras|Computers Accessories|2|51|3.92|1|50.00|
|Digital Cameras|Digital Cameras|2|51|3.92|0|0.00|
|Digital Cameras|Monitors|2|51|3.92|0|0.00|
|Digital Cameras|Projectors & Screens|2|51|3.92|0|0.00|
|Digital Cameras|VCD & DVD|2|51|3.92|0|0.00|
|Digital Cameras|Refrigerators|1|51|1.96|0|0.00|
|Digital Cameras|Lamps|1|51|1.96|0|0.00|
|Digital Cameras|Home Theater System|1|51|1.96|0|0.00|
|Digital Cameras|Fans|1|51|1.96|0|0.00|
|Digital Cameras|Digital SLR Cameras|1|51|1.96|0|0.00|
|Digital Cameras|Microwaves|1|51|1.96|0|0.00|
|Digital SLR Cameras|Movie DVD|25|62|40.32|4|16.00|
|Digital SLR Cameras|Smart phones & PDAs |13|62|20.97|3|23.08|
|Digital SLR Cameras|Desktops|12|62|19.35|1|8.33|
|Digital SLR Cameras|Touch Screen Phones |12|62|19.35|2|16.67|
|Digital SLR Cameras|Boxed Games|8|62|12.90|1|12.50|
|Digital SLR Cameras|Home & Office Phones|8|62|12.90|1|12.50|
|Digital SLR Cameras|Download Games|8|62|12.90|3|37.50|
|Digital SLR Cameras|Printers, Scanners & Fax|7|62|11.29|2|28.57|
|Digital SLR Cameras|Televisions|7|62|11.29|0|0.00|
|Digital SLR Cameras|Projectors & Screens|6|62|9.68|0|0.00|
|Digital SLR Cameras|Cell phones Accessories|6|62|9.68|1|16.67|
|Digital SLR Cameras|Bluetooth Headphones|3|62|4.84|0|0.00|
|Digital SLR Cameras|Computers Accessories|3|62|4.84|0|0.00|
|Digital SLR Cameras|Digital Cameras|3|62|4.84|2|66.67|
|Digital SLR Cameras|Car Video|3|62|4.84|1|33.33|
|Digital SLR Cameras|VCD & DVD|3|62|4.84|2|66.67|
|Digital SLR Cameras|Cameras & Camcorders Accessories|2|62|3.23|1|50.00|
|Digital SLR Cameras|Digital SLR Cameras|2|62|3.23|0|0.00|
|Digital SLR Cameras|Fans|2|62|3.23|0|0.00|
|Digital SLR Cameras|Laptops|2|62|3.23|0|0.00|
|Digital SLR Cameras|MP4&MP3|2|62|3.23|1|50.00|
|Digital SLR Cameras|Recording Pen|2|62|3.23|1|50.00|
|Digital SLR Cameras|Refrigerators|2|62|3.23|1|50.00|
|Digital SLR Cameras|Air Conditioners|1|62|1.61|0|0.00|
|Digital SLR Cameras|Lamps|1|62|1.61|0|0.00|
|Digital SLR Cameras|Monitors|1|62|1.61|0|0.00|
|Digital SLR Cameras|Microwaves|1|62|1.61|0|0.00|
|Digital SLR Cameras|Camcorders|1|62|1.61|0|0.00|
|Digital SLR Cameras|Coffee Machines|1|62|1.61|0|0.00|
|Download Games|Movie DVD|48|139|34.53|7|14.58|
|Download Games|Touch Screen Phones |28|139|20.14|3|10.71|
|Download Games|Desktops|27|139|19.42|1|3.70|
|Download Games|Smart phones & PDAs |21|139|15.11|2|9.52|
|Download Games|Laptops|16|139|11.51|2|12.50|
|Download Games|Projectors & Screens|12|139|8.63|1|8.33|
|Download Games|Printers, Scanners & Fax|12|139|8.63|2|16.67|
|Download Games|Download Games|11|139|7.91|1|9.09|
|Download Games|Boxed Games|11|139|7.91|1|9.09|
|Download Games|Cell phones Accessories|11|139|7.91|1|9.09|
|Download Games|Water Heaters|10|139|7.19|2|20.00|
|Download Games|Home & Office Phones|9|139|6.47|0|0.00|
|Download Games|Computers Accessories|9|139|6.47|1|11.11|
|Download Games|Monitors|9|139|6.47|1|11.11|
|Download Games|Car Video|8|139|5.76|0|0.00|
|Download Games|Televisions|8|139|5.76|0|0.00|
|Download Games|Bluetooth Headphones|7|139|5.04|0|0.00|
|Download Games|Microwaves|6|139|4.32|0|0.00|
|Download Games|Digital Cameras|6|139|4.32|3|50.00|
|Download Games|Camcorders|5|139|3.60|1|20.00|
|Download Games|MP4&MP3|4|139|2.88|1|25.00|
|Download Games|Digital SLR Cameras|4|139|2.88|0|0.00|
|Download Games|Home Theater System|4|139|2.88|0|0.00|
|Download Games|Lamps|4|139|2.88|0|0.00|
|Download Games|Recording Pen|4|139|2.88|1|25.00|
|Download Games|Washers & Dryers|2|139|1.44|0|0.00|
|Download Games|Air Conditioners|2|139|1.44|0|0.00|
|Download Games|Refrigerators|1|139|0.72|0|0.00|
|Download Games|Cameras & Camcorders Accessories|1|139|0.72|1|100.00|
|Download Games|Coffee Machines|1|139|0.72|0|0.00|
|Fans|Movie DVD|11|28|39.29|1|9.09|
|Fans|Smart phones & PDAs |7|28|25.00|1|14.29|
|Fans|Touch Screen Phones |6|28|21.43|0|0.00|
|Fans|Download Games|4|28|14.29|1|25.00|
|Fans|Desktops|4|28|14.29|2|50.00|
|Fans|Home & Office Phones|3|28|10.71|0|0.00|
|Fans|Monitors|3|28|10.71|0|0.00|
|Fans|Water Heaters|2|28|7.14|0|0.00|
|Fans|Computers Accessories|2|28|7.14|0|0.00|
|Fans|Laptops|2|28|7.14|0|0.00|
|Fans|Microwaves|2|28|7.14|0|0.00|
|Fans|Boxed Games|2|28|7.14|0|0.00|
|Fans|Printers, Scanners & Fax|2|28|7.14|0|0.00|
|Fans|Projectors & Screens|2|28|7.14|0|0.00|
|Fans|Bluetooth Headphones|2|28|7.14|1|50.00|
|Fans|MP4&MP3|1|28|3.57|0|0.00|
|Fans|VCD & DVD|1|28|3.57|0|0.00|
|Fans|Washers & Dryers|1|28|3.57|0|0.00|
|Fans|Recording Pen|1|28|3.57|0|0.00|
|Fans|Digital SLR Cameras|1|28|3.57|0|0.00|
|Fans|Lamps|1|28|3.57|0|0.00|
|Fans|Camcorders|1|28|3.57|0|0.00|
|Fans|Televisions|1|28|3.57|0|0.00|
|Fans|Digital Cameras|1|28|3.57|1|100.00|
|Fans|Cameras & Camcorders Accessories|1|28|3.57|1|100.00|
|Home & Office Phones|Movie DVD|57|150|38.00|9|15.79|
|Home & Office Phones|Touch Screen Phones |28|150|18.67|3|10.71|
|Home & Office Phones|Smart phones & PDAs |27|150|18.00|3|11.11|
|Home & Office Phones|Desktops|26|150|17.33|3|11.54|
|Home & Office Phones|Boxed Games|19|150|12.67|3|15.79|
|Home & Office Phones|Download Games|16|150|10.67|2|12.50|
|Home & Office Phones|Home & Office Phones|15|150|10.00|3|20.00|
|Home & Office Phones|Cell phones Accessories|14|150|9.33|2|14.29|
|Home & Office Phones|Printers, Scanners & Fax|13|150|8.67|3|23.08|
|Home & Office Phones|Projectors & Screens|12|150|8.00|0|0.00|
|Home & Office Phones|Computers Accessories|11|150|7.33|0|0.00|
|Home & Office Phones|Televisions|11|150|7.33|2|18.18|
|Home & Office Phones|Monitors|11|150|7.33|3|27.27|
|Home & Office Phones|Laptops|11|150|7.33|2|18.18|
|Home & Office Phones|Water Heaters|10|150|6.67|3|30.00|
|Home & Office Phones|Bluetooth Headphones|9|150|6.00|0|0.00|
|Home & Office Phones|Microwaves|8|150|5.33|1|12.50|
|Home & Office Phones|Refrigerators|6|150|4.00|0|0.00|
|Home & Office Phones|Car Video|6|150|4.00|1|16.67|
|Home & Office Phones|Camcorders|6|150|4.00|0|0.00|
|Home & Office Phones|Coffee Machines|5|150|3.33|0|0.00|
|Home & Office Phones|Digital SLR Cameras|4|150|2.67|0|0.00|
|Home & Office Phones|Recording Pen|4|150|2.67|0|0.00|
|Home & Office Phones|Lamps|3|150|2.00|0|0.00|
|Home & Office Phones|Cameras & Camcorders Accessories|3|150|2.00|1|33.33|
|Home & Office Phones|Digital Cameras|3|150|2.00|0|0.00|
|Home & Office Phones|Home Theater System|3|150|2.00|1|33.33|
|Home & Office Phones|Washers & Dryers|3|150|2.00|2|66.67|
|Home & Office Phones|Air Conditioners|2|150|1.33|0|0.00|
|Home & Office Phones|Fans|2|150|1.33|0|0.00|
|Home & Office Phones|VCD & DVD|1|150|0.67|0|0.00|
|Home & Office Phones|MP4&MP3|1|150|0.67|1|100.00|
|Home Theater System|Movie DVD|15|42|35.71|2|13.33|
|Home Theater System|Desktops|8|42|19.05|1|12.50|
|Home Theater System|Smart phones & PDAs |8|42|19.05|0|0.00|
|Home Theater System|Touch Screen Phones |5|42|11.90|0|0.00|
|Home Theater System|Televisions|4|42|9.52|0|0.00|
|Home Theater System|Boxed Games|4|42|9.52|0|0.00|
|Home Theater System|Home & Office Phones|4|42|9.52|1|25.00|
|Home Theater System|Bluetooth Headphones|4|42|9.52|0|0.00|
|Home Theater System|Computers Accessories|4|42|9.52|0|0.00|
|Home Theater System|Printers, Scanners & Fax|4|42|9.52|0|0.00|
|Home Theater System|Download Games|4|42|9.52|1|25.00|
|Home Theater System|VCD & DVD|3|42|7.14|0|0.00|
|Home Theater System|Monitors|3|42|7.14|1|33.33|
|Home Theater System|Cell phones Accessories|3|42|7.14|0|0.00|
|Home Theater System|Projectors & Screens|3|42|7.14|0|0.00|
|Home Theater System|Laptops|3|42|7.14|0|0.00|
|Home Theater System|Washers & Dryers|2|42|4.76|0|0.00|
|Home Theater System|Cameras & Camcorders Accessories|2|42|4.76|0|0.00|
|Home Theater System|Car Video|2|42|4.76|0|0.00|
|Home Theater System|Water Heaters|1|42|2.38|0|0.00|
|Home Theater System|Camcorders|1|42|2.38|0|0.00|
|Home Theater System|Microwaves|1|42|2.38|0|0.00|
|Home Theater System|Refrigerators|1|42|2.38|1|100.00|
|Lamps|Movie DVD|11|26|42.31|2|18.18|
|Lamps|Download Games|5|26|19.23|1|20.00|
|Lamps|Home & Office Phones|5|26|19.23|0|0.00|
|Lamps|Desktops|5|26|19.23|0|0.00|
|Lamps|Touch Screen Phones |5|26|19.23|2|40.00|
|Lamps|Printers, Scanners & Fax|5|26|19.23|2|40.00|
|Lamps|Computers Accessories|5|26|19.23|1|20.00|
|Lamps|Cell phones Accessories|4|26|15.38|0|0.00|
|Lamps|Smart phones & PDAs |4|26|15.38|1|25.00|
|Lamps|Monitors|3|26|11.54|1|33.33|
|Lamps|Televisions|3|26|11.54|1|33.33|
|Lamps|Projectors & Screens|3|26|11.54|0|0.00|
|Lamps|Boxed Games|2|26|7.69|0|0.00|
|Lamps|Coffee Machines|2|26|7.69|0|0.00|
|Lamps|Refrigerators|2|26|7.69|0|0.00|
|Lamps|Water Heaters|1|26|3.85|0|0.00|
|Lamps|Camcorders|1|26|3.85|1|100.00|
|Lamps|Cameras & Camcorders Accessories|1|26|3.85|0|0.00|
|Lamps|Digital Cameras|1|26|3.85|0|0.00|
|Lamps|Digital SLR Cameras|1|26|3.85|0|0.00|
|Lamps|Fans|1|26|3.85|0|0.00|
|Lamps|Home Theater System|1|26|3.85|0|0.00|
|Lamps|Laptops|1|26|3.85|0|0.00|
|Lamps|Recording Pen|1|26|3.85|0|0.00|
|Lamps|Washers & Dryers|1|26|3.85|0|0.00|
|Laptops|Movie DVD|55|149|36.91|6|10.91|
|Laptops|Desktops|29|149|19.46|5|17.24|
|Laptops|Smart phones & PDAs |25|149|16.78|4|16.00|
|Laptops|Boxed Games|21|149|14.09|5|23.81|
|Laptops|Touch Screen Phones |21|149|14.09|6|28.57|
|Laptops|Download Games|15|149|10.07|4|26.67|
|Laptops|Printers, Scanners & Fax|15|149|10.07|2|13.33|
|Laptops|Projectors & Screens|14|149|9.40|2|14.29|
|Laptops|Cell phones Accessories|12|149|8.05|0|0.00|
|Laptops|Monitors|12|149|8.05|0|0.00|
|Laptops|Computers Accessories|10|149|6.71|1|10.00|
|Laptops|Water Heaters|10|149|6.71|2|20.00|
|Laptops|Laptops|9|149|6.04|0|0.00|
|Laptops|Televisions|9|149|6.04|1|11.11|
|Laptops|Home & Office Phones|8|149|5.37|1|12.50|
|Laptops|Bluetooth Headphones|8|149|5.37|1|12.50|
|Laptops|Digital SLR Cameras|7|149|4.70|1|14.29|
|Laptops|Air Conditioners|6|149|4.03|2|33.33|
|Laptops|Home Theater System|6|149|4.03|0|0.00|
|Laptops|Microwaves|5|149|3.36|1|20.00|
|Laptops|Refrigerators|5|149|3.36|3|60.00|
|Laptops|Car Video|5|149|3.36|1|20.00|
|Laptops|VCD & DVD|4|149|2.68|1|25.00|
|Laptops|Recording Pen|3|149|2.01|0|0.00|
|Laptops|Fans|3|149|2.01|0|0.00|
|Laptops|Coffee Machines|3|149|2.01|0|0.00|
|Laptops|Camcorders|3|149|2.01|0|0.00|
|Laptops|Lamps|3|149|2.01|0|0.00|
|Laptops|Cameras & Camcorders Accessories|2|149|1.34|0|0.00|
|Laptops|Digital Cameras|2|149|1.34|0|0.00|
|Laptops|MP4&MP3|2|149|1.34|0|0.00|
|Laptops|Washers & Dryers|1|149|0.67|0|0.00|
|Microwaves|Movie DVD|31|83|37.35|2|6.45|
|Microwaves|Desktops|16|83|19.28|1|6.25|
|Microwaves|Smart phones & PDAs |16|83|19.28|0|0.00|
|Microwaves|Touch Screen Phones |16|83|19.28|0|0.00|
|Microwaves|Boxed Games|8|83|9.64|1|12.50|
|Microwaves|Water Heaters|8|83|9.64|1|12.50|
|Microwaves|Computers Accessories|8|83|9.64|1|12.50|
|Microwaves|Home & Office Phones|7|83|8.43|1|14.29|
|Microwaves|Monitors|7|83|8.43|1|14.29|
|Microwaves|Cell phones Accessories|6|83|7.23|1|16.67|
|Microwaves|Digital SLR Cameras|5|83|6.02|1|20.00|
|Microwaves|Download Games|5|83|6.02|0|0.00|
|Microwaves|Televisions|5|83|6.02|1|20.00|
|Microwaves|Projectors & Screens|5|83|6.02|1|20.00|
|Microwaves|Printers, Scanners & Fax|4|83|4.82|0|0.00|
|Microwaves|Recording Pen|4|83|4.82|1|25.00|
|Microwaves|Home Theater System|3|83|3.61|0|0.00|
|Microwaves|Camcorders|3|83|3.61|0|0.00|
|Microwaves|Cameras & Camcorders Accessories|3|83|3.61|0|0.00|
|Microwaves|Bluetooth Headphones|3|83|3.61|0|0.00|
|Microwaves|Microwaves|3|83|3.61|0|0.00|
|Microwaves|MP4&MP3|3|83|3.61|0|0.00|
|Microwaves|Laptops|2|83|2.41|0|0.00|
|Microwaves|Refrigerators|2|83|2.41|0|0.00|
|Microwaves|Lamps|2|83|2.41|0|0.00|
|Microwaves|VCD & DVD|2|83|2.41|0|0.00|
|Microwaves|Air Conditioners|2|83|2.41|0|0.00|
|Microwaves|Car Video|1|83|1.20|0|0.00|
|Microwaves|Coffee Machines|1|83|1.20|0|0.00|
|Monitors|Movie DVD|51|149|34.23|4|7.84|
|Monitors|Smart phones & PDAs |32|149|21.48|4|12.50|
|Monitors|Touch Screen Phones |31|149|20.81|2|6.45|
|Monitors|Projectors & Screens|17|149|11.41|2|11.76|
|Monitors|Desktops|17|149|11.41|3|17.65|
|Monitors|Monitors|17|149|11.41|2|11.76|
|Monitors|Download Games|16|149|10.74|3|18.75|
|Monitors|Home & Office Phones|14|149|9.40|1|7.14|
|Monitors|Laptops|13|149|8.72|0|0.00|
|Monitors|Cell phones Accessories|11|149|7.38|1|9.09|
|Monitors|Printers, Scanners & Fax|11|149|7.38|3|27.27|
|Monitors|Televisions|10|149|6.71|2|20.00|
|Monitors|Bluetooth Headphones|9|149|6.04|3|33.33|
|Monitors|Microwaves|8|149|5.37|2|25.00|
|Monitors|Boxed Games|7|149|4.70|2|28.57|
|Monitors|VCD & DVD|6|149|4.03|0|0.00|
|Monitors|Computers Accessories|6|149|4.03|1|16.67|
|Monitors|Digital SLR Cameras|5|149|3.36|1|20.00|
|Monitors|Fans|5|149|3.36|0|0.00|
|Monitors|Digital Cameras|5|149|3.36|1|20.00|
|Monitors|Cameras & Camcorders Accessories|5|149|3.36|1|20.00|
|Monitors|Home Theater System|4|149|2.68|1|25.00|
|Monitors|Refrigerators|4|149|2.68|0|0.00|
|Monitors|Water Heaters|3|149|2.01|0|0.00|
|Monitors|Car Video|3|149|2.01|0|0.00|
|Monitors|Recording Pen|3|149|2.01|1|33.33|
|Monitors|Air Conditioners|3|149|2.01|0|0.00|
|Monitors|Washers & Dryers|3|149|2.01|0|0.00|
|Monitors|Lamps|2|149|1.34|0|0.00|
|Monitors|Coffee Machines|2|149|1.34|0|0.00|
|Monitors|Camcorders|2|149|1.34|1|50.00|
|Monitors|MP4&MP3|2|149|1.34|0|0.00|
|Movie DVD|Movie DVD|231|609|37.93|26|11.26|
|Movie DVD|Desktops|118|609|19.38|18|15.25|
|Movie DVD|Smart phones & PDAs |110|609|18.06|14|12.73|
|Movie DVD|Touch Screen Phones |106|609|17.41|13|12.26|
|Movie DVD|Boxed Games|77|609|12.64|16|20.78|
|Movie DVD|Cell phones Accessories|57|609|9.36|6|10.53|
|Movie DVD|Download Games|57|609|9.36|6|10.53|
|Movie DVD|Home & Office Phones|53|609|8.70|9|16.98|
|Movie DVD|Projectors & Screens|49|609|8.05|2|4.08|
|Movie DVD|Printers, Scanners & Fax|47|609|7.72|10|21.28|
|Movie DVD|Laptops|45|609|7.39|10|22.22|
|Movie DVD|Monitors|41|609|6.73|3|7.32|
|Movie DVD|Computers Accessories|41|609|6.73|4|9.76|
|Movie DVD|Televisions|40|609|6.57|4|10.00|
|Movie DVD|Water Heaters|30|609|4.93|1|3.33|
|Movie DVD|Bluetooth Headphones|29|609|4.76|7|24.14|
|Movie DVD|Car Video|27|609|4.43|5|18.52|
|Movie DVD|Recording Pen|23|609|3.78|2|8.70|
|Movie DVD|VCD & DVD|23|609|3.78|2|8.70|
|Movie DVD|Digital SLR Cameras|22|609|3.61|5|22.73|
|Movie DVD|Digital Cameras|21|609|3.45|5|23.81|
|Movie DVD|Microwaves|18|609|2.96|1|5.56|
|Movie DVD|Cameras & Camcorders Accessories|18|609|2.96|4|22.22|
|Movie DVD|Air Conditioners|16|609|2.63|5|31.25|
|Movie DVD|MP4&MP3|16|609|2.63|2|12.50|
|Movie DVD|Home Theater System|13|609|2.13|2|15.38|
|Movie DVD|Camcorders|12|609|1.97|1|8.33|
|Movie DVD|Lamps|12|609|1.97|3|25.00|
|Movie DVD|Washers & Dryers|12|609|1.97|2|16.67|
|Movie DVD|Coffee Machines|11|609|1.81|0|0.00|
|Movie DVD|Refrigerators|9|609|1.48|3|33.33|
|Movie DVD|Fans|7|609|1.15|0|0.00|
|MP4&MP3|Movie DVD|12|37|32.43|0|0.00|
|MP4&MP3|Smart phones & PDAs |9|37|24.32|0|0.00|
|MP4&MP3|Touch Screen Phones |7|37|18.92|3|42.86|
|MP4&MP3|Download Games|7|37|18.92|2|28.57|
|MP4&MP3|Projectors & Screens|5|37|13.51|0|0.00|
|MP4&MP3|Desktops|5|37|13.51|1|20.00|
|MP4&MP3|Printers, Scanners & Fax|5|37|13.51|0|0.00|
|MP4&MP3|Televisions|4|37|10.81|1|25.00|
|MP4&MP3|Cell phones Accessories|4|37|10.81|0|0.00|
|MP4&MP3|Boxed Games|4|37|10.81|0|0.00|
|MP4&MP3|VCD & DVD|3|37|8.11|1|33.33|
|MP4&MP3|Air Conditioners|3|37|8.11|0|0.00|
|MP4&MP3|Home Theater System|3|37|8.11|0|0.00|
|MP4&MP3|Laptops|3|37|8.11|0|0.00|
|MP4&MP3|Monitors|3|37|8.11|0|0.00|
|MP4&MP3|Bluetooth Headphones|2|37|5.41|0|0.00|
|MP4&MP3|Car Video|2|37|5.41|0|0.00|
|MP4&MP3|Computers Accessories|2|37|5.41|0|0.00|
|MP4&MP3|Microwaves|2|37|5.41|0|0.00|
|MP4&MP3|Washers & Dryers|2|37|5.41|0|0.00|
|MP4&MP3|Home & Office Phones|1|37|2.70|0|0.00|
|MP4&MP3|Coffee Machines|1|37|2.70|1|100.00|
|MP4&MP3|Cameras & Camcorders Accessories|1|37|2.70|0|0.00|
|MP4&MP3|Water Heaters|1|37|2.70|0|0.00|
|MP4&MP3|Digital SLR Cameras|1|37|2.70|0|0.00|
|Printers, Scanners & Fax|Movie DVD|44|124|35.48|6|13.64|
|Printers, Scanners & Fax|Touch Screen Phones |26|124|20.97|1|3.85|
|Printers, Scanners & Fax|Smart phones & PDAs |18|124|14.52|0|0.00|
|Printers, Scanners & Fax|Desktops|16|124|12.90|3|18.75|
|Printers, Scanners & Fax|Boxed Games|16|124|12.90|2|12.50|
|Printers, Scanners & Fax|Televisions|16|124|12.90|4|25.00|
|Printers, Scanners & Fax|Printers, Scanners & Fax|14|124|11.29|3|21.43|
|Printers, Scanners & Fax|Download Games|13|124|10.48|0|0.00|
|Printers, Scanners & Fax|Home & Office Phones|13|124|10.48|1|7.69|
|Printers, Scanners & Fax|Cell phones Accessories|12|124|9.68|1|8.33|
|Printers, Scanners & Fax|Projectors & Screens|12|124|9.68|2|16.67|
|Printers, Scanners & Fax|Laptops|11|124|8.87|4|36.36|
|Printers, Scanners & Fax|Computers Accessories|11|124|8.87|0|0.00|
|Printers, Scanners & Fax|Monitors|9|124|7.26|2|22.22|
|Printers, Scanners & Fax|Digital Cameras|7|124|5.65|4|57.14|
|Printers, Scanners & Fax|Bluetooth Headphones|6|124|4.84|0|0.00|
|Printers, Scanners & Fax|Microwaves|6|124|4.84|0|0.00|
|Printers, Scanners & Fax|Water Heaters|6|124|4.84|1|16.67|
|Printers, Scanners & Fax|VCD & DVD|5|124|4.03|2|40.00|
|Printers, Scanners & Fax|Recording Pen|5|124|4.03|3|60.00|
|Printers, Scanners & Fax|MP4&MP3|4|124|3.23|0|0.00|
|Printers, Scanners & Fax|Digital SLR Cameras|4|124|3.23|1|25.00|
|Printers, Scanners & Fax|Car Video|2|124|1.61|1|50.00|
|Printers, Scanners & Fax|Air Conditioners|2|124|1.61|0|0.00|
|Printers, Scanners & Fax|Washers & Dryers|2|124|1.61|0|0.00|
|Printers, Scanners & Fax|Cameras & Camcorders Accessories|1|124|0.81|0|0.00|
|Printers, Scanners & Fax|Lamps|1|124|0.81|0|0.00|
|Printers, Scanners & Fax|Refrigerators|1|124|0.81|0|0.00|
|Printers, Scanners & Fax|Camcorders|1|124|0.81|0|0.00|
|Projectors & Screens|Movie DVD|54|147|36.73|5|9.26|
|Projectors & Screens|Smart phones & PDAs |34|147|23.13|3|8.82|
|Projectors & Screens|Touch Screen Phones |32|147|21.77|4|12.50|
|Projectors & Screens|Desktops|24|147|16.33|2|8.33|
|Projectors & Screens|Boxed Games|18|147|12.24|3|16.67|
|Projectors & Screens|Download Games|16|147|10.88|3|18.75|
|Projectors & Screens|Cell phones Accessories|14|147|9.52|2|14.29|
|Projectors & Screens|Printers, Scanners & Fax|12|147|8.16|1|8.33|
|Projectors & Screens|Laptops|12|147|8.16|1|8.33|
|Projectors & Screens|Projectors & Screens|11|147|7.48|0|0.00|
|Projectors & Screens|Televisions|10|147|6.80|0|0.00|
|Projectors & Screens|Home & Office Phones|9|147|6.12|2|22.22|
|Projectors & Screens|Monitors|9|147|6.12|0|0.00|
|Projectors & Screens|Bluetooth Headphones|9|147|6.12|1|11.11|
|Projectors & Screens|Computers Accessories|9|147|6.12|2|22.22|
|Projectors & Screens|Recording Pen|7|147|4.76|1|14.29|
|Projectors & Screens|Car Video|7|147|4.76|0|0.00|
|Projectors & Screens|VCD & DVD|6|147|4.08|0|0.00|
|Projectors & Screens|Washers & Dryers|6|147|4.08|0|0.00|
|Projectors & Screens|Digital SLR Cameras|5|147|3.40|2|40.00|
|Projectors & Screens|Water Heaters|5|147|3.40|0|0.00|
|Projectors & Screens|Lamps|4|147|2.72|1|25.00|
|Projectors & Screens|Coffee Machines|4|147|2.72|0|0.00|
|Projectors & Screens|Home Theater System|4|147|2.72|1|25.00|
|Projectors & Screens|Camcorders|3|147|2.04|0|0.00|
|Projectors & Screens|Refrigerators|3|147|2.04|1|33.33|
|Projectors & Screens|Air Conditioners|3|147|2.04|0|0.00|
|Projectors & Screens|Fans|3|147|2.04|0|0.00|
|Projectors & Screens|MP4&MP3|2|147|1.36|0|0.00|
|Projectors & Screens|Microwaves|2|147|1.36|0|0.00|
|Projectors & Screens|Cameras & Camcorders Accessories|2|147|1.36|0|0.00|
|Projectors & Screens|Digital Cameras|1|147|0.68|0|0.00|
|Recording Pen|Movie DVD|19|48|39.58|2|10.53|
|Recording Pen|Boxed Games|13|48|27.08|0|0.00|
|Recording Pen|Smart phones & PDAs |10|48|20.83|1|10.00|
|Recording Pen|Desktops|9|48|18.75|1|11.11|
|Recording Pen|Projectors & Screens|8|48|16.67|0|0.00|
|Recording Pen|Touch Screen Phones |6|48|12.50|2|33.33|
|Recording Pen|Printers, Scanners & Fax|5|48|10.42|2|40.00|
|Recording Pen|Home & Office Phones|5|48|10.42|0|0.00|
|Recording Pen|Digital SLR Cameras|4|48|8.33|0|0.00|
|Recording Pen|VCD & DVD|4|48|8.33|0|0.00|
|Recording Pen|Water Heaters|3|48|6.25|0|0.00|
|Recording Pen|Microwaves|3|48|6.25|0|0.00|
|Recording Pen|Bluetooth Headphones|2|48|4.17|0|0.00|
|Recording Pen|Cameras & Camcorders Accessories|2|48|4.17|1|50.00|
|Recording Pen|Car Video|2|48|4.17|0|0.00|
|Recording Pen|Cell phones Accessories|2|48|4.17|1|50.00|
|Recording Pen|Computers Accessories|2|48|4.17|0|0.00|
|Recording Pen|Fans|2|48|4.17|0|0.00|
|Recording Pen|Laptops|2|48|4.17|0|0.00|
|Recording Pen|Recording Pen|2|48|4.17|1|50.00|
|Recording Pen|Washers & Dryers|2|48|4.17|0|0.00|
|Recording Pen|Monitors|1|48|2.08|0|0.00|
|Recording Pen|Televisions|1|48|2.08|0|0.00|
|Recording Pen|Digital Cameras|1|48|2.08|0|0.00|
|Recording Pen|Coffee Machines|1|48|2.08|0|0.00|
|Recording Pen|Lamps|1|48|2.08|0|0.00|
|Recording Pen|Camcorders|1|48|2.08|0|0.00|
|Refrigerators|Movie DVD|17|53|32.08|1|5.88|
|Refrigerators|Smart phones & PDAs |13|53|24.53|3|23.08|
|Refrigerators|Touch Screen Phones |11|53|20.75|1|9.09|
|Refrigerators|Desktops|8|53|15.09|0|0.00|
|Refrigerators|Laptops|6|53|11.32|1|16.67|
|Refrigerators|Printers, Scanners & Fax|6|53|11.32|0|0.00|
|Refrigerators|Bluetooth Headphones|6|53|11.32|0|0.00|
|Refrigerators|Cell phones Accessories|5|53|9.43|0|0.00|
|Refrigerators|Monitors|5|53|9.43|0|0.00|
|Refrigerators|Boxed Games|4|53|7.55|1|25.00|
|Refrigerators|Projectors & Screens|4|53|7.55|0|0.00|
|Refrigerators|Home & Office Phones|4|53|7.55|0|0.00|
|Refrigerators|Water Heaters|3|53|5.66|0|0.00|
|Refrigerators|Car Video|3|53|5.66|0|0.00|
|Refrigerators|Download Games|3|53|5.66|0|0.00|
|Refrigerators|Televisions|3|53|5.66|0|0.00|
|Refrigerators|Refrigerators|2|53|3.77|0|0.00|
|Refrigerators|Air Conditioners|2|53|3.77|0|0.00|
|Refrigerators|Digital Cameras|2|53|3.77|0|0.00|
|Refrigerators|Home Theater System|2|53|3.77|0|0.00|
|Refrigerators|Computers Accessories|2|53|3.77|1|50.00|
|Refrigerators|Recording Pen|2|53|3.77|0|0.00|
|Refrigerators|Microwaves|1|53|1.89|0|0.00|
|Refrigerators|Fans|1|53|1.89|0|0.00|
|Refrigerators|Camcorders|1|53|1.89|0|0.00|
|Refrigerators|MP4&MP3|1|53|1.89|0|0.00|
|Smart phones & PDAs |Movie DVD|113|342|33.04|11|9.73|
|Smart phones & PDAs |Smart phones & PDAs |59|342|17.25|8|13.56|
|Smart phones & PDAs |Touch Screen Phones |59|342|17.25|5|8.47|
|Smart phones & PDAs |Desktops|58|342|16.96|10|17.24|
|Smart phones & PDAs |Laptops|40|342|11.70|5|12.50|
|Smart phones & PDAs |Download Games|37|342|10.82|4|10.81|
|Smart phones & PDAs |Boxed Games|36|342|10.53|7|19.44|
|Smart phones & PDAs |Cell phones Accessories|33|342|9.65|4|12.12|
|Smart phones & PDAs |Computers Accessories|29|342|8.48|3|10.34|
|Smart phones & PDAs |Home & Office Phones|27|342|7.89|5|18.52|
|Smart phones & PDAs |Monitors|26|342|7.60|3|11.54|
|Smart phones & PDAs |Printers, Scanners & Fax|26|342|7.60|5|19.23|
|Smart phones & PDAs |Televisions|25|342|7.31|7|28.00|
|Smart phones & PDAs |Projectors & Screens|24|342|7.02|1|4.17|
|Smart phones & PDAs |Bluetooth Headphones|21|342|6.14|6|28.57|
|Smart phones & PDAs |Recording Pen|18|342|5.26|2|11.11|
|Smart phones & PDAs |Water Heaters|18|342|5.26|1|5.56|
|Smart phones & PDAs |Microwaves|16|342|4.68|0|0.00|
|Smart phones & PDAs |Car Video|13|342|3.80|3|23.08|
|Smart phones & PDAs |Digital SLR Cameras|9|342|2.63|0|0.00|
|Smart phones & PDAs |Coffee Machines|8|342|2.34|1|12.50|
|Smart phones & PDAs |Digital Cameras|8|342|2.34|1|12.50|
|Smart phones & PDAs |VCD & DVD|8|342|2.34|2|25.00|
|Smart phones & PDAs |Refrigerators|7|342|2.05|1|14.29|
|Smart phones & PDAs |Lamps|5|342|1.46|2|40.00|
|Smart phones & PDAs |Cameras & Camcorders Accessories|5|342|1.46|1|20.00|
|Smart phones & PDAs |Home Theater System|5|342|1.46|1|20.00|
|Smart phones & PDAs |Air Conditioners|5|342|1.46|0|0.00|
|Smart phones & PDAs |MP4&MP3|5|342|1.46|0|0.00|
|Smart phones & PDAs |Washers & Dryers|4|342|1.17|0|0.00|
|Smart phones & PDAs |Camcorders|4|342|1.17|1|25.00|
|Smart phones & PDAs |Fans|3|342|0.88|0|0.00|
|Televisions|Movie DVD|53|158|33.54|9|16.98|
|Televisions|Touch Screen Phones |31|158|19.62|8|25.81|
|Televisions|Smart phones & PDAs |25|158|15.82|2|8.00|
|Televisions|Desktops|22|158|13.92|3|13.64|
|Televisions|Boxed Games|17|158|10.76|3|17.65|
|Televisions|Monitors|16|158|10.13|4|25.00|
|Televisions|Download Games|15|158|9.49|5|33.33|
|Televisions|Televisions|15|158|9.49|3|20.00|
|Televisions|Projectors & Screens|13|158|8.23|1|7.69|
|Televisions|Cell phones Accessories|13|158|8.23|2|15.38|
|Televisions|Printers, Scanners & Fax|12|158|7.59|2|16.67|
|Televisions|Microwaves|11|158|6.96|1|9.09|
|Televisions|Computers Accessories|11|158|6.96|2|18.18|
|Televisions|Car Video|10|158|6.33|2|20.00|
|Televisions|Laptops|10|158|6.33|1|10.00|
|Televisions|Water Heaters|9|158|5.70|2|22.22|
|Televisions|Home & Office Phones|8|158|5.06|2|25.00|
|Televisions|Home Theater System|7|158|4.43|2|28.57|
|Televisions|Bluetooth Headphones|7|158|4.43|2|28.57|
|Televisions|Digital Cameras|6|158|3.80|3|50.00|
|Televisions|Recording Pen|5|158|3.16|0|0.00|
|Televisions|Washers & Dryers|4|158|2.53|0|0.00|
|Televisions|VCD & DVD|4|158|2.53|0|0.00|
|Televisions|Coffee Machines|4|158|2.53|0|0.00|
|Televisions|Cameras & Camcorders Accessories|4|158|2.53|3|75.00|
|Televisions|Lamps|3|158|1.90|1|33.33|
|Televisions|Air Conditioners|2|158|1.27|0|0.00|
|Televisions|MP4&MP3|2|158|1.27|1|50.00|
|Televisions|Digital SLR Cameras|1|158|0.63|1|100.00|
|Televisions|Fans|1|158|0.63|0|0.00|
|Televisions|Refrigerators|1|158|0.63|0|0.00|
|Touch Screen Phones |Movie DVD|106|309|34.30|23|21.70|
|Touch Screen Phones |Smart phones & PDAs |67|309|21.68|11|16.42|
|Touch Screen Phones |Desktops|56|309|18.12|9|16.07|
|Touch Screen Phones |Touch Screen Phones |54|309|17.48|11|20.37|
|Touch Screen Phones |Boxed Games|50|309|16.18|8|16.00|
|Touch Screen Phones |Download Games|31|309|10.03|6|19.35|
|Touch Screen Phones |Printers, Scanners & Fax|29|309|9.39|3|10.34|
|Touch Screen Phones |Televisions|29|309|9.39|7|24.14|
|Touch Screen Phones |Cell phones Accessories|28|309|9.06|4|14.29|
|Touch Screen Phones |Projectors & Screens|23|309|7.44|4|17.39|
|Touch Screen Phones |Home & Office Phones|21|309|6.80|2|9.52|
|Touch Screen Phones |Monitors|19|309|6.15|2|10.53|
|Touch Screen Phones |Laptops|17|309|5.50|4|23.53|
|Touch Screen Phones |Bluetooth Headphones|16|309|5.18|2|12.50|
|Touch Screen Phones |Water Heaters|14|309|4.53|3|21.43|
|Touch Screen Phones |Recording Pen|14|309|4.53|1|7.14|
|Touch Screen Phones |Digital SLR Cameras|13|309|4.21|1|7.69|
|Touch Screen Phones |Cameras & Camcorders Accessories|12|309|3.88|3|25.00|
|Touch Screen Phones |Car Video|11|309|3.56|5|45.45|
|Touch Screen Phones |Computers Accessories|11|309|3.56|2|18.18|
|Touch Screen Phones |VCD & DVD|10|309|3.24|1|10.00|
|Touch Screen Phones |Microwaves|10|309|3.24|0|0.00|
|Touch Screen Phones |Air Conditioners|10|309|3.24|1|10.00|
|Touch Screen Phones |Lamps|7|309|2.27|0|0.00|
|Touch Screen Phones |Refrigerators|7|309|2.27|1|14.29|
|Touch Screen Phones |MP4&MP3|6|309|1.94|2|33.33|
|Touch Screen Phones |Digital Cameras|6|309|1.94|2|33.33|
|Touch Screen Phones |Washers & Dryers|5|309|1.62|2|40.00|
|Touch Screen Phones |Camcorders|4|309|1.29|0|0.00|
|Touch Screen Phones |Coffee Machines|4|309|1.29|1|25.00|
|Touch Screen Phones |Home Theater System|3|309|0.97|0|0.00|
|Touch Screen Phones |Fans|3|309|0.97|0|0.00|
|VCD & DVD|Movie DVD|28|73|38.36|7|25.00|
|VCD & DVD|Touch Screen Phones |13|73|17.81|2|15.38|
|VCD & DVD|Smart phones & PDAs |12|73|16.44|3|25.00|
|VCD & DVD|Desktops|11|73|15.07|3|27.27|
|VCD & DVD|Boxed Games|11|73|15.07|4|36.36|
|VCD & DVD|Home & Office Phones|9|73|12.33|1|11.11|
|VCD & DVD|Monitors|6|73|8.22|1|16.67|
|VCD & DVD|Projectors & Screens|5|73|6.85|1|20.00|
|VCD & DVD|Printers, Scanners & Fax|5|73|6.85|1|20.00|
|VCD & DVD|Car Video|5|73|6.85|2|40.00|
|VCD & DVD|Water Heaters|5|73|6.85|1|20.00|
|VCD & DVD|Download Games|5|73|6.85|2|40.00|
|VCD & DVD|Digital Cameras|4|73|5.48|1|25.00|
|VCD & DVD|Computers Accessories|4|73|5.48|1|25.00|
|VCD & DVD|Cell phones Accessories|4|73|5.48|0|0.00|
|VCD & DVD|MP4&MP3|3|73|4.11|1|33.33|
|VCD & DVD|Refrigerators|3|73|4.11|1|33.33|
|VCD & DVD|Digital SLR Cameras|3|73|4.11|0|0.00|
|VCD & DVD|Televisions|3|73|4.11|0|0.00|
|VCD & DVD|Laptops|3|73|4.11|0|0.00|
|VCD & DVD|Fans|2|73|2.74|0|0.00|
|VCD & DVD|Bluetooth Headphones|2|73|2.74|0|0.00|
|VCD & DVD|Air Conditioners|2|73|2.74|1|50.00|
|VCD & DVD|Recording Pen|2|73|2.74|0|0.00|
|VCD & DVD|VCD & DVD|2|73|2.74|0|0.00|
|VCD & DVD|Home Theater System|1|73|1.37|1|100.00|
|VCD & DVD|Cameras & Camcorders Accessories|1|73|1.37|0|0.00|
|VCD & DVD|Washers & Dryers|1|73|1.37|0|0.00|
|VCD & DVD|Camcorders|1|73|1.37|0|0.00|
|VCD & DVD|Lamps|1|73|1.37|0|0.00|
|Washers & Dryers|Movie DVD|10|32|31.25|1|10.00|
|Washers & Dryers|Smart phones & PDAs |8|32|25.00|1|12.50|
|Washers & Dryers|Touch Screen Phones |6|32|18.75|1|16.67|
|Washers & Dryers|Desktops|5|32|15.63|1|20.00|
|Washers & Dryers|Water Heaters|5|32|15.63|1|20.00|
|Washers & Dryers|Download Games|4|32|12.50|0|0.00|
|Washers & Dryers|Boxed Games|4|32|12.50|2|50.00|
|Washers & Dryers|Televisions|3|32|9.38|1|33.33|
|Washers & Dryers|Digital SLR Cameras|3|32|9.38|1|33.33|
|Washers & Dryers|Cell phones Accessories|2|32|6.25|0|0.00|
|Washers & Dryers|VCD & DVD|2|32|6.25|1|50.00|
|Washers & Dryers|Washers & Dryers|2|32|6.25|0|0.00|
|Washers & Dryers|Home & Office Phones|2|32|6.25|0|0.00|
|Washers & Dryers|Lamps|2|32|6.25|0|0.00|
|Washers & Dryers|Laptops|2|32|6.25|0|0.00|
|Washers & Dryers|Projectors & Screens|2|32|6.25|0|0.00|
|Washers & Dryers|Microwaves|1|32|3.13|0|0.00|
|Washers & Dryers|Cameras & Camcorders Accessories|1|32|3.13|0|0.00|
|Washers & Dryers|Coffee Machines|1|32|3.13|1|100.00|
|Washers & Dryers|Digital Cameras|1|32|3.13|0|0.00|
|Washers & Dryers|Bluetooth Headphones|1|32|3.13|0|0.00|
|Washers & Dryers|Monitors|1|32|3.13|0|0.00|
|Washers & Dryers|Printers, Scanners & Fax|1|32|3.13|0|0.00|
|Washers & Dryers|Recording Pen|1|32|3.13|1|100.00|
|Washers & Dryers|Refrigerators|1|32|3.13|0|0.00|
|Water Heaters|Movie DVD|27|85|31.76|2|7.41|
|Water Heaters|Touch Screen Phones |20|85|23.53|5|25.00|
|Water Heaters|Desktops|17|85|20.00|4|23.53|
|Water Heaters|Smart phones & PDAs |15|85|17.65|4|26.67|
|Water Heaters|Boxed Games|13|85|15.29|4|30.77|
|Water Heaters|Computers Accessories|11|85|12.94|3|27.27|
|Water Heaters|Monitors|8|85|9.41|2|25.00|
|Water Heaters|Download Games|8|85|9.41|0|0.00|
|Water Heaters|Projectors & Screens|7|85|8.24|0|0.00|
|Water Heaters|Water Heaters|7|85|8.24|0|0.00|
|Water Heaters|Printers, Scanners & Fax|7|85|8.24|1|14.29|
|Water Heaters|Home & Office Phones|7|85|8.24|4|57.14|
|Water Heaters|Televisions|6|85|7.06|1|16.67|
|Water Heaters|Laptops|5|85|5.88|2|40.00|
|Water Heaters|Cell phones Accessories|5|85|5.88|1|20.00|
|Water Heaters|Digital SLR Cameras|4|85|4.71|2|50.00|
|Water Heaters|Bluetooth Headphones|4|85|4.71|1|25.00|
|Water Heaters|Car Video|4|85|4.71|1|25.00|
|Water Heaters|Home Theater System|4|85|4.71|3|75.00|
|Water Heaters|Refrigerators|3|85|3.53|0|0.00|
|Water Heaters|Digital Cameras|3|85|3.53|1|33.33|
|Water Heaters|VCD & DVD|2|85|2.35|0|0.00|
|Water Heaters|Recording Pen|2|85|2.35|1|50.00|
|Water Heaters|Lamps|1|85|1.18|0|0.00|
|Water Heaters|Microwaves|1|85|1.18|0|0.00|
|Water Heaters|Washers & Dryers|1|85|1.18|0|0.00|
|Water Heaters|Cameras & Camcorders Accessories|1|85|1.18|0|0.00|
|Water Heaters|Air Conditioners|1|85|1.18|0|0.00|

</details>

[ 🖼️ PLACEHOLDER: Insert visual/chart for Q3B ]

Key Insight: [ 💡 PLACEHOLDER: Insight here ]

## 🔮 Future Analysis & Advanced Considerations (Out of Scope)

To maintain a focused scope on enterprise lifecycle value and initial activation, the following advanced models were noted but excluded from this phase:
1. **Established Churn (Individual Periodicity):** Predicting churn for mature customers (3+ orders) requires calculating an individualized purchase cadence rather than a macro 365-day window.
2. **Long-Cycle vs. Activation Churn:** Customers returning after 365+ days are classified operationally as "Win-Backs." These long gaps often reflect hardware replacement cycles rather than standard retention.
3. **Product-Level Churn:** Analyzing whether a customer stopped buying a specific product category (e.g., they still buy laptops, but switched to a competitor for ink) requires market-basket lifecycle modeling.

*Note: For a detailed technical breakdown of model limitations and a glossary of metrics used, please view the [`GLOSSARY_AND_NOTES.md`](./GLOSSARY_AND_NOTES.md) file.*

---

## 🚀 Final Business Insights & Recommendations

Based on the combined analytical findings, I recommend the following strategic shifts for Contoso:

1. [ 💡 PLACEHOLDER: Actionable Recommendation 1 (e.g., related to timing retargeting ads based on Q1A) ]
2. [ 💡 PLACEHOLDER: Actionable Recommendation 2 (e.g., related to shifting budget based on the LTV multiplier in Q2) ]
3. [ 💡 PLACEHOLDER: Actionable Recommendation 3 (e.g., related to featuring specific gateway products in acquisition campaigns based on Q3) ]

---

## 🛠️ How to Run This Project

To reproduce this analysis locally:
1. Clone this repository.
2. Navigate to the `sql_load/` directory.
3. Execute `contoso_100k.sql` to generate the table structures and load the contoso dataset in the table.
4. Run the query scripts in the `queries/` folder in numerical order, starting with the base view creation.