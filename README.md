# 🛒 E-Commerce Customer Retention & Cohort Analysis
**Author:** Dhruwin Bhimjibhai Makwana

### 🛠️ Tech Stack & Tools
* **Database:** PostgreSQL
* **Data Visualization:** Power BI, Microsoft Excel
* **SQL Techniques:** Window Functions (`MIN() OVER`, `LEAD()`), Common Table Expressions (CTEs), Cohort Windowing, Dynamic Currency Conversion
* **Dataset:** Microsoft Contoso Retail Enterprise Dataset

---

## 🚀 Executive Summary (TL;DR)
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

* **The "Mature Cohort" Gate:** Baseline metrics are restricted to customers acquired 12 to 24 months prior to the latest database entry. This ensures every customer analyzed had a full, fair 365 days to make a second purchase.
* **The 365-Day Activation Window:** A repeat buyer is strictly defined as someone who makes their 2nd purchase within 365 days of their 1st purchase.
* **Clean YoY Trending:** When comparing annual cohorts (e.g., 2021 vs 2022), partial business launch years or incomplete current years are excluded to prevent volatile, inaccurate percentage spikes.

---

## 🗃️ Data Architecture & Schema

This analysis relies on a relational star schema built from the Contoso dataset. To optimize query performance and standardize business logic (like currency conversion and cohort generation), a foundational SQL view was created.

### The Foundation: `public.cohort_analysis` View
Instead of repeating complex aggregation logic across every query, I engineered a base view that:
1. Calculates total net revenue adjusted dynamically for exchange rates.
2. Aggregates order counts per customer per transaction date.
3. Windows each customer's absolute `first_purchase_date` and `cohort_year` for downstream retention models.

[ 💻 PLACEHOLDER: Insert a link to your 00_create_view_cohort_analysis.sql file here ]

[ 🖼️ PLACEHOLDER: Optional - Insert a screenshot of your Entity Relationship Diagram (ERD) mapping the Sales, Customer, and Product tables here. ]

---

## 🎯 Deep-Dive Analysis: The 3 Core Business Questions

### 📊 Phase 1: Baseline Retention Efficiency & Return Cadence (Question 1)
**Core Objective:** Quantify the size of the "One-and-Done" revenue leak and identify the exact post-purchase timing window for re-engagement.

#### Q1: What percentage of our acquired customers convert from a first purchase to a second purchase within 365 days?
* **Hypothesis:** Because e-commerce relies heavily on acquisition, the baseline repeat rate is likely low, creating a "one-and-done" bottleneck.
* **Why this matters:** We cannot improve what we don't measure. Establishing a strict baseline shows the exact size of the retention gap.

<details>
<summary><b>🔍 Click to view SQL Query</b></summary>

```sql
[ 💻 PLACEHOLDER: Insert your Q1 SQL code here ]
```
</details>
[ 🖼️ PLACEHOLDER: Insert visual/chart for Q1A ]

Key Insight: [ 💡 PLACEHOLDER: Insight here ]

#### Q1A: For the customers who do return, how many days does it take them to place their second order?
* **Why this matters:** Understanding when people organically return tells marketing exactly when to trigger retargeting ads and automated email flows.

<details>
<summary><b>🔍 Click to view SQL Query</b></summary>

```sql
[ 💻 PLACEHOLDER: Insert your Q1A SQL code here ]
```
</details>
[ 🖼️ PLACEHOLDER: Insert visual/chart for Q1A ]

Key Insight: [ 💡 PLACEHOLDER: Insight here ]

#### Q1B: How has our 1-year retention rate percentage evolved year-over-year across mature historical cohorts?
* **Why this matters:** Tracks whether the company's customer loyalty is naturally improving or degrading over time.

<details>
<summary><b>🔍 Click to view SQL Query</b></summary>

```sql
[ 💻 PLACEHOLDER: Insert your Q1B SQL code here ]
```
</details>
[ 🖼️ PLACEHOLDER: Insert visual/chart for Q1B ]

Key Insight: [ 💡 PLACEHOLDER: Insight here ]

### 📈 Phase 2: The Revenue & LTV Multiplier (Question 2)
**Core Objective:** Prove the financial ROI of a repeat buyer to justify shifting budget from pure acquisition to retention.
* **Hypothesis:** "Because repeat rates are low, the small group of repeat buyers must be generating a disproportionately massive chunk of our total Lifetime Value (LTV) to keep the business profitable."

#### Q2 & Q2A: What is the average LTV of a single-order buyer versus a repeat buyer, and what is their revenue concentration?
* **Why this matters:** Proves to stakeholders that a small segment of retained users drives the majority of the business.

<details>
<summary><b>🔍 Click to view SQL Query</b></summary>

```sql
[ 💻 PLACEHOLDER: Insert your Q2/Q2A SQL code here ]
```
</details>
[ 🖼️ PLACEHOLDER: Insert visual/chart for Q2/Q2A ]

Key Insight: [ 💡 PLACEHOLDER: Insight here ]

#### Q2B (The LTV Multiplier): By what exact factor ($X\times$) does customer value expand when a first-time buyer is converted into a second-time buyer?
* **Why this matters:** Quantifies exactly how much more a customer is worth if marketing can successfully get them to buy a second time.

<details>
<summary><b>🔍 Click to view SQL Query</b></summary>

```sql
[ 💻 PLACEHOLDER: Insert your Q2B SQL code here ]
```
</details>
[ 🖼️ PLACEHOLDER: Insert visual/chart for Q2B ]

Key Insight: [ 💡 PLACEHOLDER: Insight here ]

### 🛒 Phase 3: Gateway Products for 2nd-Purchase Conversion (Question 3)
**Core Objective:** Provide the marketing team with tactical, product-level triggers for retargeting campaigns.
* **Hypothesis:** "If repeat buyers drive most of our profit, there must be specific gateway products in their FIRST purchase that naturally encourage them to come back."

#### Q3A: Which initial product subcategories ("Gateway Products") drive the highest rate of 2nd purchases compared to the baseline?
* **Why this matters:** If we know which products naturally create loyal customers, marketing can feature those specific products in top-of-funnel acquisition ads.Proves to stakeholders that a small segment of retained users drives the majority of the business.

<details>
<summary><b>🔍 Click to view SQL Query</b></summary>

```sql
[ 💻 PLACEHOLDER: Insert your Q3A SQL code here ]
```
</details>
[ 🖼️ PLACEHOLDER: Insert visual/chart for Q3A ]

Key Insight: [ 💡 PLACEHOLDER: Insight here ]

#### Q3B: What specific products or categories do customers most frequently buy on their second order after purchasing a specific Gateway Product?
* **Why this matters:**  Maps the exact cross-sell pathway ($O_1 \rightarrow O_2$) so marketing can build highly personalized product recommendation engines.

<details>
<summary><b>🔍 Click to view SQL Query</b></summary>

```sql
[ 💻 PLACEHOLDER: Insert your Q3B SQL code here ]
```
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
3. Execute `00_schema_setup.sql` to generate the table structures.
4. Execute `01_load_contoso_dataset.sql` (requires local mapping to the CSVs in the `contoso_raw_data/` folder).
5. Run the query scripts in the `queries/` folder in numerical order, starting with the base view creation.