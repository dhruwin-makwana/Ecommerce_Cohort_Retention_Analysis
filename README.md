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

**🖥️ Query Link**: [00_create_view_cohort_analysis.sql](/queries/00_create_view_cohort_analysis.sql)
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

**🖥️ Query Link**: [01_q1_q2_cohort_retention_ltv_multiplier.sql](/queries/01_q1_q2_cohort_retention_ltv_multiplier.sql) 
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

![Customer Retention vs. Churn Breakdown (Matured Cohort)](/assets/01_q1_customer_retention.png)

*Donut chart displaying the percentage of acquired customers converting to a second purchase within a year.*

**💡 Key Insights:**

* **Low Baseline Retention:** Only 21.0% of acquired customers (1,807 out of 8,601 total) successfully converted to a second purchase within a 365-day window.

* **High Post-Acquisition Churn:** Nearly 4 out of every 5 customers (79.0%) are "one-and-done" buyers who never return to the ecosystem after their initial transaction.

* **Business Takeaway:** The company is currently operating with a highly leaky bucket. Without improving the onboarding experience or immediate post-purchase retargeting, top-of-funnel acquisition budgets are largely being spent on customers who will not generate long-term value.

#### **Q1A: For the customers who do return, how many days does it take them to place their second order?**
* **Why this matters:** Understanding when people organically return tells marketing exactly when to trigger retargeting ads and automated email flows.

<details>
<summary><b>🔍 Click to view SQL Query

**🖥️ Query Link**: [02_q1a_return_cadence_time_to_second_order.sql](/queries/02_q1a_return_cadence_time_to_second_order.sql)
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

![Days taken to place second order in the cohort year](/assets/02_q1A_repeat_cust_bucket.png)

*Vertical Column chart displaying the count of retained customers bucketed quaterly based on days taken for placing second purchase order after the first purchase.*

**💡 Key Insights:**

* **Early Momentum is Critical:** Nearly a quarter of all repeat buyers (22.6%) make their second purchase within the first 90 days. The likelihood of a customer returning steadily declines after this initial three-month window.

* **The "Late Returner" Phenomenon:** Surprisingly, the largest single segment of repeat buyers (28.0%) takes more than a full year (365+ days) to make their second purchase.

* **Business Takeaway:** The marketing team should deploy a two-pronged retargeting strategy. First, launch aggressive re-engagement campaigns within the 0-90 day window to capture early momentum. Second, implement an automated "anniversary" win-back campaign at the 12-month mark to successfully convert the massive pool of late returners.

#### **Q1B: How has our 1-year retention rate percentage evolved year-over-year across mature historical cohorts?**
* **Why this matters:** Tracks whether the company's customer loyalty is naturally improving or degrading over time.

<details>
<summary><b>🔍 Click to view SQL Query

**🖥️ Query Link**: [03_q1b_yoy_retention_and_aov_trend.sql](/queries/03_q1b_yoy_retention_and_aov_trend.sql)
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

**🖥️ Query Link**: [01_q1_q2_cohort_retention_ltv_multiplier.sql](/queries/01_q1_q2_cohort_retention_ltv_multiplier.sql)
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

**🖥️ Query Link**: [01_q1_q2_cohort_retention_ltv_multiplier.sql](/queries/01_q1_q2_cohort_retention_ltv_multiplier.sql)
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

**🖥️ Query Link**: [04_q3a_gateway_product_retention_vs_baseline.sql](/queries/04_q3a_gateway_product_retention_vs_baseline.sql)
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

**🖥️ Query Link**: [05_q3b_gateway_to_second_order_destinations.sql](/queries/05_q3b_gateway_to_second_order_destinations.sql)
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

[**🔍Click to view Resultant Table**](/result_tables/.xlsx)

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