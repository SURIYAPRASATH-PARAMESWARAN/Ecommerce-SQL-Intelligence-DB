# E-Commerce Customer & Sales Intelligence Engine
### End-to-End Analytics Pipeline | PostgreSQL · Power BI · RFM Segmentation · Cohort Analysis

---

## Business Problem

An e-commerce operator running across 27 Brazilian states needs to answer four strategic questions:

1. **Where is revenue leaking?** — which categories, states, and sellers underperform on margin
2. **Who are the customers worth keeping?** — segmenting 96K customers by lifetime value and churn risk
3. **Is delivery performance hurting retention?** — quantifying the link between late delivery and review scores
4. **Which cohorts retain?** — identifying acquisition months that produced the most loyal customers

This project builds a full SQL analytics layer on the Olist dataset and surfaces findings in a 3-page Power BI dashboard designed for executive and operational audiences.

---

## Dataset

**Source:** [Brazilian E-Commerce Public Dataset by Olist](https://www.kaggle.com/datasets/olistbr/brazilian-ecommerce) — Kaggle

| Table | Rows | Description |
|-------|------|-------------|
| `orders` | 99,441 | Master order fact table |
| `order_items` | 112,650 | Line-level products per order |
| `customers` | 99,441 | Customer dimension |
| `sellers` | 3,095 | Seller dimension |
| `products` | 32,951 | Product dimension |
| `order_payments` | 103,886 | Payment records |
| `order_reviews` | 99,224 | Review scores 1–5 |
| `geolocation` | 1,000,163 | ZIP-to-lat/lng mapping |

**Date range:** September 2016 – October 2018 | **Country:** Brazil (27 states)

---

## Tech Stack

| Layer | Tool |
|-------|------|
| Database | PostgreSQL 16 |
| Query Development | pgAdmin 4 / DBeaver |
| Visualisation | Power BI Desktop |
| Version Control | Git / GitHub |

---

## SQL Techniques Demonstrated

| Technique | Where Used |
|-----------|-----------|
| Multi-table JOINs (4–6 tables) | All analysis queries |
| CTEs (`WITH` clauses) | Revenue trends, RFM, cohorts |
| Window Functions — `RANK()`, `NTILE()`, `LAG()`, `SUM() OVER` | LTV ranking, MoM growth, running totals |
| Cohort Analysis | Monthly retention matrix |
| Conditional Aggregation (`FILTER WHERE`) | Repeat purchase windows, late delivery rate |
| `CASE WHEN` segmentation | RFM scoring, delivery status, customer segments |
| Views for BI layer | `vw_order_master`, `vw_customer_segments`, `vw_cohort_retention` |
| Performance indexing | 7 indexes on high-cardinality join columns |
| Date arithmetic | Delivery day calculations, cohort period offsets |
| `NULLIF` / `COALESCE` | Safe division, null handling |
| `PERCENTILE_CONT` / IQR outlier detection | EDA distribution analysis |
| `INSERT INTO` / `UPDATE` / `ON CONFLICT` | Delivery audit table population |
| Stored Functions (`plpgsql`) | Reusable delivery status classifier |

---

## Project Structure

```
ecommerce-sql-intelligence/
│
├── sql/
│   ├── 01_schema.sql                  # Full DDL — tables, PKs, FKs, indexes
│   ├── 02_load_data.sql               # COPY commands + row count validation
│   ├── 03_eda.sql                     # Data quality audit, null checks, outlier detection
│   ├── 04_advanced_analytics.sql      # Window functions, RFM, cohorts, seller KPIs
│   │                                  # + 3 Power BI views
│   └── 05_payment_intelligence.sql    # Payment method analysis, installments,
│                                      # reconciliation, DML, stored function
│
├── docs/
│   └── powerbi_setup.md               # DAX measures + dashboard build guide
│
├── outputs/
│   ├── dashboard_page1_revenue.png
│   ├── dashboard_page2_customers.png
│   └── dashboard_page3_sellers.png
│
└── README.md
```

---

## Key Findings

### Revenue
- Top 5 product categories account for **~42% of total gross revenue**
- São Paulo (SP) generates **~40% of all orders** — heavy geographic concentration risk
- Freight cost averages **~20% of order value** — highest burden on lowest-margin categories

### Payment Intelligence
- Credit card dominates at **~74% of orders** — voucher usage correlates with higher review scores
- 60%+ of credit card orders are paid in a single instalment — avg order value rises sharply with instalment count
- Payment value reconciles to within £0.01 of charged total on **99%+ of orders** — clean financial data confirmed

### Customer Intelligence
- **Only 3.1% of customers place more than one order** — retention is the single biggest growth lever
- RFM segmentation reveals **Champions** (top 13 RFM score) generate **~8× the revenue** of Lost customers
- Top revenue decile accounts for **~30% of total GMV** — Pareto holds

### Delivery & Satisfaction
- Average delivery time: **12.5 days** (estimated: 23.6 days) — customers receive orders ~11 days early on average
- Late delivery rate: **8.1%** nationally — spikes to **~18% in northern states** (AM, RR, AP)
- Review scores correlate directly with delivery performance: late orders average **2.7 stars** vs **4.3 stars** for on-time

### Cohort Retention
- **Month 1 retention across all cohorts averages ~3%** — almost all customers are one-time buyers
- November 2017 cohort shows the highest Month 1 retention (**5.2%**) — likely Black Friday effect
- Cohort quality peaked mid-2017 and declined into 2018

---

## How to Run

### Prerequisites
- PostgreSQL 16+ installed
- pgAdmin 4 or DBeaver (for running queries)
- Power BI Desktop (free)
- Olist dataset downloaded from Kaggle

### Steps

```bash
# 1. Clone the repo
git clone https://github.com/SURIYAPRASATH-PARAMESWARAN/ecommerce-sql-intelligence
cd ecommerce-sql-intelligence

# 2. Create the database
psql -U postgres -c "CREATE DATABASE ecommerce_olist;"

# 3. Run schema
psql -U postgres -d ecommerce_olist -f sql/01_schema.sql

# 4. Load data (update file paths in 02_load_data.sql first)
psql -U postgres -d ecommerce_olist -f sql/02_load_data.sql

# 5. Run EDA — data quality audit + distribution checks
psql -U postgres -d ecommerce_olist -f sql/03_eda.sql

# 6. Run advanced analytics + create views
psql -U postgres -d ecommerce_olist -f sql/04_advanced_analytics.sql

# 7. Run payment intelligence + DML examples
psql -U postgres -d ecommerce_olist -f sql/05_payment_intelligence.sql

# 8. Open Power BI and connect to the 3 views
#    See docs/powerbi_setup.md for full instructions
```

---

## Dashboard Preview

| Page | Focus |
|------|-------|
| **Revenue Overview** | Monthly trends, MoM growth, category/state breakdown, payment split |
| **Customer Intelligence** | RFM segments, LTV distribution, revenue concentration, repeat rate |
| **Seller & Operations** | Seller scorecard, delivery heatmap by state, review distribution, cohort retention matrix |

*(Screenshots in `/outputs/`)*

---

## Skills Demonstrated

`PostgreSQL` `Advanced SQL` `Window Functions` `CTEs` `Cohort Analysis` `RFM Segmentation` `Power BI` `DAX` `Data Modelling` `EDA` `Business Intelligence` `Customer Analytics` `Stored Functions` `DML`

---

*Part of the [Suriyaprasath Parameswaran](https://suriyaprasath-parameswaran.github.io) data analytics portfolio.*