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
<br/><br/>

![Customer Retention vs. Churn Breakdown (Matured Cohort)](/assets/01_q1_customer_retention.png)

*Donut chart displaying the percentage of acquired customers converting to a second purchase within a year.*

**🔍Resultant Table and Visualization Link**: [**01_q1_q2_cohort_retention_ltv_multiplier.xlsx**](/result_tables(.xlsx)/01_q1_q2_cohort_retention_ltv_multiplier.xlsx)

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
<br/><br/>

![Days taken to place second order in the cohort year](/assets/02_q1A_repeat_cust_bucket.png)

*Vertical Column chart displaying the count of retained customers bucketed quaterly based on days taken for placing second purchase order after the first purchase.*

**🔍Resultant Table and Visualization Link**: [**02_q1a_return_cadence_time_to_second_order.xlsx**](/result_tables(.xlsx)/02_q1a_return_cadence_time_to_second_order.xlsx)

**💡 Key Insights:**

* **Front-Loaded Retention Velocity:** Nearly a quarter of all repeat buyers (22.6%) return within the first 90 days. Repurchase momentum peaks immediately following the initial order and steadily decays across subsequent quarters.

* **Mid-Lifecycle Plateau (Days 181–365):** Repurchase behavior stabilizes during the second half of the retention cycle, holding flat at ~15% of repeat buyers per quarter (15.0% in Q3, 15.1% in Q4). This represents a predictable "slow-drip" replenishment window before customers hit the churn threshold.

* **Substantial Reactivation Potential:** Over a quarter of all repeat transactions (28.0%) occur after the 365-day churn mark. This reveals that lapsed customers carry significant latent brand equity rather than permanent churn.

* **Business Takeaways:**
   * Days 0–90: High-Intent Cross-Sell & Onboarding
      * Action: Deploy immediate post-purchase engagement workflows, product usage guides, and targeted cross-sell recommendations within 30 to 60 days of Order 1.
     * Rationale: Customer brand recall and product interest are at their peak. Capturing buyers during this window yields the highest conversion efficiency (22.6% of repeat buyers) and accelerates customer lifetime value (LTV).

   * Days 270–365: Pre-Churn Risk Mitigation
      * Action: Trigger automated "at-risk" retention campaigns with personalized incentives (e.g., loyalty points, discount codes, tailored category recommendations) at the 9-month mark.
      * Rationale: The 15.1% conversion rate between Days 271–365 shows a steady stream of late-stage within-window buyers. Re-engaging them before Day 365 prevents them from slipping into the churned pool entirely.

   * Days 365+: Automated Win-Back & Anniversary Triggers
      * Action: Implement automated 12-month and 18-month "Anniversary" or "We Miss You" campaigns aimed at inactive profiles.
      * Rationale: The massive 28.0% volume of 365+ day buyers proves that long-term lapsed buyers are highly recoverable. Re-engaging dormant users through low-cost automated email/SMS channels carries a far lower Customer Acquisition Cost (CAC) than acquiring entirely net-new users.

*Note on Retention Window vs. Reactivation: While the business defines customer churn at 365 days, this analysis includes repeat orders beyond Day 365 to capture complete customer lifecycle data. Buyers returning within 0–365 days (72.0% of all repeat buyers; 21.0% total cohort conversion) represent strictly retained active customers. Buyers returning at 365+ days (28.0% of repeat buyers; 8.2% total cohort conversion) represent reactivated/win-back customers. Including both segments ensures we evaluate active retention velocity alongside long-tail win-back potential without distorting core churn metrics.*

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
<br/><br/>

![Y-o-Y mature cohort year comparison](/assets/03_q1b_yoy_retention.png)

*Combo chart displaying the Y-o-Y mature cohort year comparison for customers acquired and retained.*

**🔍Resultant Table and Visualization Link**: [**03_q1b_yoy_retention_and_aov_trend.xlsx**](/result_tables(.xlsx)/03_q1b_yoy_retention_and_aov_trend.xlsx)

**💡 Key Insights:**

* **5x Multi-Year Retention Growth:** The 365-day retention rate experienced a dramatic long-term improvement, climbing from 4.18% in 2015 to a peak of 21.94% in 2022. Total retained customers grew 16.7x (from 118 to 1,977 buyers).

* **The 2020 Anomaly:** Retention dropped sharply to 5.44% in the 2020 cohort (down from 12.28% in 2019), coinciding with a steep decline in new customer acquisition (3,031 customers). This highlights significant external disruptions in customer purchasing behavior during that period.

* **Scalable Retention at Volume:** The post-2020 recovery was immediate and robust. The 2022 cohort achieved the highest retention rate in company history (21.94%) while simultaneously absorbing the largest acquisition volume on record (9,010 new customers), proving that retention quality did not degrade as acquisition scaled.

* **Volume Scale vs. AOV Compression:** While retention rate and retained volume peaked in 2022 (21.94% / 1,977 customers), Order 1 AOV ($2,377.55) and Order 2 AOV ($2,105.98) hit historical lows. Lower average prices likely broadened customer acquisition and retention, but reduced per-customer basket sizes.

* **Order 2 Value Decay:** In recent high-performing cohorts (2021 and 2022), Order 2 AOV consistently dropped below Order 1 AOV (an 11.4% decline in 2022 from $2,377.55 to $2,105.98). Repeat buyers return more frequently, but spend less on their second purchase than their first.

* **Business Takeaway:** Onboarding and retention strategies implemented over the 8-year period have successfully transformed customer retention from an early weak point into a reliable, scalable driver of business value.
  * Net Revenue Strategy Succeeded (Volume Outpaced Basket Size)
     * Rationale: Total revenue generated by retained customers grew substantially over time despite AOV compression. A 16.7x increase in retained buyers far outweighs the ~18% to 25% decrease in AOVs between 2015 and 2022. Lowering price thresholds successfully unlocked scalable retention.

  * Target Order 2 Basket Expansion (Upsell & Cross-Sell)
    * Rationale: Because Order 2 AOV is declining relative to Order 1 AOV in modern cohorts ($2,105.98 vs $2,377.55 in 2022), second-order monetization is underperforming. Implementing targeted post-purchase bundles, minimum threshold discounts (e.g., "Spend $X more for free shipping on your second order"), and premium accessory attachments can bridge this gap and maximize per-customer profit margins.

*Note on AOV Dilution vs. Customer Diversification: A moderate decline in Average Order Value (~15%–18%) is an expected and acceptable tradeoff when retention rates scale dramatically from 4.18% to 21.94%. Early, low-volume cohorts (2015–2017) were skewed toward high-spending niche adopters. As acquisition volume expanded, the customer base diversified across broader demographics with varied spending capacities. Because total retained buyer volume expanded by 16.7x, aggregate gross revenue grew substantially despite slightly lower individual basket sizes. However, this AOV compression highlights a key untapped profit margin opportunity: capturing lost basket size on Order 2 through targeted upselling can further accelerate bottom-line growth.*

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
<br/><br/>

![LTV comparison](/assets/04_q2_ltv_comparison.png)

*Bar Chart displaying the Average LTV (Lifetime Value) comaprison between the churned customers and retained customers for the most recent matured cohort year.*

![Revenue share Comaprison](/assets/05_q2_rev_comparison.png)

*100% Stacked Bar Chart displaying the share percetage among the total acquired customers and the share of revenue contributed by the churned customers and retained customers for the most recent matured cohort year.*

**🔍Resultant Table and Visualization Link**: [**01_q1_q2_cohort_retention_ltv_multiplier.xlsx**](/result_tables(.xlsx)/01_q1_q2_cohort_retention_ltv_multiplier.xlsx)

**💡 Key Insights:**

* **More Than Double the Lifetime Value (2.12x Multiplier):** Repeat buyers achieve an average LTV of $4,535.52, compared to $2,136.68 for single-order buyers. Securing a second purchase instantly unlocks an additional $2,398.84 in incremental revenue per customer.

* **Disproportionate Revenue Contribution:** Despite accounting for only 21.0% of total acquired customers, repeat buyers generate 36.1% ($8.20M) of the company's cumulative net revenue.

* **Massive Financial Upside:** Single-order buyers currently lock up $14.52M across 6,794 churned customers. Converting just 10% of these single-order buyers into repeat customers would generate an estimated ~$1.63M in incremental baseline revenue.

* **Business Takeaway:** Retention is not just a loyalty metric—it is the single highest-leverage growth driver for the business. Acquisition efforts should be calibrated around customer quality rather than raw volume.

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
<br/><br/>

**🔍Resultant Table Link**: [**01_q1_q2_cohort_retention_ltv_multiplier.xlsx**](/result_tables(.xlsx)/01_q1_q2_cohort_retention_ltv_multiplier.xlsx)

**💡 Key Insights:**

* **Exact Multiplier (2.12x Value Expansion):** Converting a single-order customer into a second-time buyer expands their total lifetime value by an exact factor of 2.12x (a +112.3% net increase in revenue).

* **Quantified Revenue Delta:** Moving a customer past the second-order threshold immediately unlocks an additional +$2,398.84 in incremental LTV ($4,535.52 vs. $2,136.68).

* **CAC Retargeting Allowance:** Because securing a second order doubles customer value, the business can profitably allocate up to $2,398.84 in lifetime retention marketing, loyalty discounts, and re-engagement campaigns per customer before hitting diminishing returns compared to single-order buyers.

* **Business Takeaway:** Retention marketing operates at a far higher leverage point than cold acquisition. Re-engaging an existing buyer yields double the economic return of acquiring a new one-time purchaser.

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
<br></br>

![Product Subcategory Scattering](/assets/06_q3_subcategory_scattering.png)

*Scatter Plot displaying the product subcategories scattered on the basis of cutomer acquired and subcategory wise retention rate for the most recent matured cohort year.*

![Product Subcategory Scattering (Selective)](/assets/07_q3_selective_subcategory_scattering.png)

*Scatter Plot displaying the few selected product subcategories (for clarity) scattered on the basis of cutomer acquired and subcategory wise retention rate for the most recent matured cohort year.*

**🔍Resultant Table and Visualization Link**: [**04_q3a_gateway_product_retention_vs_baseline.xlsx**](/result_tables(.xlsx)/04_q3a_gateway_product_retention_vs_baseline.xlsx)

**💡 Key Insights:**

* **Major Appliances Lead Retention:** Large household appliances drive the highest repeat purchase rates. Refrigerators (25.98%, +4.97% pts vs baseline) and Washers & Dryers (25.40%, +4.39% pts vs baseline) represent the top gateway products for customer loyalty.

* **Desktops as the Volume & Retention Winner:** Desktops serve as the premier high-scale gateway product, acquiring 1,570 customers while delivering a 23.12% retention rate (+2.11% pts above baseline).

* **High Acquisition Volume, Lower Loyalty:** The two largest acquisition drivers—Movie DVDs (2,953 customers) and Smart phones & PDAs (1,723 customers)—both perform below the company baseline at 20.62% (-0.39% pts) and 19.85% (-1.16% pts) respectively.

* **Significant Underperformers:** Home & Office Phones (18.87%, -2.14% pts) and Printers, Scanners & Fax (18.96%, -2.05% pts) lag furthest behind in converting initial buyers into repeat customers.

* **Business Takeaway:** Gateway Portfolio Optimization Strategy

  * **Core Drivers (High Volume + High Retention):** Maintain sustained marketing investment and primary campaign placement on proven scaling anchors like Desktops. These products drive both top-of-funnel volume and top-tier long-term value.

  * **Hidden Gems (Low Volume + High Retention):** Accelerate ad spend and promotional exposure for categories like Major Appliances. Increasing top-of-funnel reach for these under-leveraged products presents the fastest path to expanding overall retention rates and driving high-LTV revenue.

  * **Acquisition Workhorses (High Volume + Lower Retention):** Continue funding entry channels like Movie DVDs and Smartphones if budget permits, or selectively reallocate marginal ad spend toward higher-retention products. Because these categories bring in the vast majority of total new customers, keep them active while enforcing immediate post-purchase cross-sell workflows (Days 0–30) to rescue retention.

  * **Laggards (Low Volume + Low Retention):** Deprioritize marketing spend and operational focus for bottom-tier products like Home & Office Phones. Reallocate these resources to high-converting gateway products to maximize return on ad spend (ROAS).

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

<details>
<summary><b>🔍 Click to view a glimpse of the Resultant Table 

(This is a filtered table that we actually need. It has the top 3 Order 2 and Order 1 subcategory products pari with highest retention. All the Order 1 subcategory products are the gateway subcategory products that are valid for our further analysis.)</b></summary>

|order1_gateway_subcategory|order2_destination_subcategory|pair_customer_count|total_gateway_retained_customers|incidence_rate_pct|customers_reaching_3plus_orders|pair_to_order3_conversion_pct|
|----------------|----------------|----------------|----------------|----------------|----------------|----------------|
|Car Video|Movie DVD|30|64|46.88|5|16.67|
|Car Video|Touch Screen Phones|14|64|21.88|1|7.14|
|Car Video|Smart phones & PDAs|13|64|20.31|1|7.69|
|Desktops|Movie DVD|142|363|39.12|15|10.56|
|Desktops|Smart phones & PDAs|78|363|21.49|15|19.23|
|Desktops|Touch Screen Phones|69|363|19.01|7|10.14|
|Digital Cameras|Movie DVD|19|51|37.25|2|10.53|
|Digital Cameras|Touch Screen Phones|9|51|17.65|1|11.11|
|Digital Cameras|Desktops|9|51|17.65|3|33.33|
|Movie DVD|Movie DVD|231|609|37.93|26|11.26|
|Movie DVD|Desktops|118|609|19.38|18|15.25|
|Movie DVD|Smart phones & PDAs|110|609|18.06|14|12.73|
|Refrigerators|Movie DVD|17|53|32.08|1|5.88|
|Refrigerators|Smart phones & PDAs|13|53|24.53|3|23.08|
|Refrigerators|Touch Screen Phones|11|53|20.75|1|9.09|
|Smart phones & PDAs|Movie DVD|113|342|33.04|11|9.73|
|Smart phones & PDAs|Smart phones & PDAs|59|342|17.25|8|13.56|
|Smart phones & PDAs|Touch Screen Phones|59|342|17.25|5|8.47|
|Touch Screen Phones|Movie DVD|106|309|34.32|23|21.7|
|Touch Screen Phones|Smart phones & PDAs|67|309|21.68|11|16.42|
|Touch Screen Phones|Desktops|56|309|18.12|9|16.07|
|Washers & Dryers|Movie DVD|10|32|31.25|1|10|
|Washers & Dryers|Smart phones & PDAs|8|32|25|1|12.5|
|Washers & Dryers|Touch Screen Phones|6|32|18.75|1|16.67|

</details>


**🔍Click to view Full Resultant Table:**
[**05_q3b_gateway_to_second_order_destinations**](/result_tables(.xlsx)/05_q3b_gateway_to_second_order_destinations.xlsx)


**💡 Key Insights:**

* **Movie DVD is the Universal Repurchase Magnet:** Regardless of the initial entry point, Movie DVD serves as the #1 Order 2 destination subcategory across every gateway product analyzed, capturing between 31.25% (Washers & Dryers) and 46.88% (Car Video) of all second purchases. It acts as a universal, low-friction bridging product for repeat engagement.

* **Mobile Tech Dominates Secondary Basket Mix:** Outside of Movie DVDs, repeat buyers overwhelmingly migrate into personal mobile technology—specifically Smart phones & PDAs and Touch Screen Phones. These two categories consistently claim the remaining top-three destination slots across major appliance, computing, and consumer electronics gateways.
* **High-Ticket Tech Cross-Sells Drive Multi-Order Retention (3+ Orders):** While Movie DVDs maximize initial second-order volume, higher-ticket technology transitions deliver superior long-term customer retention:
  * **Digital Cameras $\rightarrow$ Desktops:** Leads all pathways with a 33.33% conversion rate to 3+ orders.
  * **Refrigerators $\rightarrow$ Smart phones & PDAs:** Achieves a 23.08% conversion rate to 3+ orders.
  * **Touch Screen Phones $\rightarrow$ Movie DVD:** Delivers a 21.70% conversion rate to 3+ orders.
  * **Desktops $\rightarrow$ Smart phones & PDAs:** Generates a 19.23% conversion rate to 3+ orders.

* **Business Takeaways: Empirical Retargeting & Personalization Bridge**
  * **Deploy Automated Post-Purchase Ad Workflows (Order 1 $\rightarrow$ Order 2 Bridge)** 
    * **Action:** Use this empirical transition data as the exact blueprint for automated post-purchase ad targeting. The moment a customer purchases an Order 1 Gateway product, immediately trigger targeted cross-sell campaigns showcasing the top destination products favored by historical retained buyers for that specific gateway.
    * **Rationale:** Re-engaging customers with products mathematically proven to drive repeat orders eliminates guesswork, boosts ad conversion rates, and builds immediate second-order retention momentum.
  * **Capitalize on Hidden Gems (Refrigerators, Washers & Dryers)**
    * **Action:** Increase acquisition exposure for these high-retention products, then immediately retarget buyers with personalized ads for Smartphones & PDAs and Touch Screen Phones alongside low-friction catalog items.
    * **Rationale:** Unlocking top-of-funnel acquisition for these high-loyalty gateways and immediately routing buyers into proven secondary tech categories expands total company revenue and retention quality simultaneously.
  * **Maximize Core Driver LTV (Desktops)**
    * **Action:** Retarget Desktop buyers with mobile tech accessories and ecosystem devices within 30–60 days of purchase.
    * **Rationale:** Because Desktops balanced acquisition volume with high retention, cross-selling them into Smartphones (21.49% incidence) solidifies customer loyalty across multiple product categories.
  * **Rescue Volume Workhorses (Movie DVDs)**
    * **Action:** For the massive volume of customers entering through Movie DVDs, immediately present cross-sell recommendations for higher-ticket hardware (Desktops and Smartphones).
    * **Rationale:** Moving buyers from low-margin, lower-retention media into high-margin tech categories elevates customer lifetime value and prevents early churn.
  * **Full-Spectrum Personalization (Beyond the "Vital Few")**
    * **Action:** Apply automated cross-sell triggers across all remaining long-tail and niche gateway pairs in the underlying dataset, extending targeting rules beyond the primary "vital few" subcategories.
    * **Rationale:** While executive strategy prioritizes high-volume anchor categories for maximum top-line impact, calculating transitions for 100% of gateway products ensures no customer segment is neglected. Capturing even small retention gains across lower-volume categories guarantees total customer base coverage and plugs hidden lifetime value leaks.
    
*Note on Order 3 Long-Tail Conversion Data: Order 3 retention rates (pair_to_order3_conversion_pct) have been calculated to provide deeper directional visibility into multi-order customer lifecycles, though evaluating 3+ orders remains strictly outside the primary scope of this Phase 3 retention framework. These metrics highlight key areas for future optimization: order pairs that demonstrate strong second-order retention but suffer sharp conversion drop-offs on Order 3 pinpoint prime targets for improved 3rd-order re-engagement campaigns, allowing the business to capture extended retention on established high-volume bridges.*

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