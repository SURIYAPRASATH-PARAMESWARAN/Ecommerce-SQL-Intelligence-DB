# E-Commerce Customer & Sales Intelligence Engine
### End-to-End Analytics Pipeline | PostgreSQL · Advanced SQL · Window Functions · RFM Segmentation · Cohort Analysis · Power BI

---

## Business Problem

An e-commerce operator running across 27 Brazilian states needs to answer four strategic questions:

1. **Where is revenue leaking?** — which categories, states, and sellers underperform on margin
2. **Who are the customers worth keeping?** — segmenting 96K customers by lifetime value and churn risk
3. **Is delivery performance hurting retention?** — quantifying the link between late delivery and review scores
4. **Which cohorts retain?** — identifying acquisition months that produced the most loyal customers

This project builds a full SQL analytics layer on the Olist dataset and surfaces key revenue findings in a Power BI dashboard.

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
| Database | PostgreSQL 17 |
| Query Development | VS Code + SQLTools |
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

---

## Project Structure

```
ecommerce-sql-intelligence/
│
├── sql/
│   ├── 01_schema.sql              # Full DDL — tables, PKs, FKs, indexes
│   ├── 02_load_data.sql           # COPY commands + row count validation
│   ├── 03_eda.sql                 # Data quality audit + revenue overview
│   └── 04_advanced_analytics.sql # Window functions, RFM, cohorts, seller KPIs
│                                  # + 3 Power BI views
│
├── docs/
│   └── powerbi_setup.md           # DAX measures + dashboard build guide
│
├── outputs/
│   └── dashboard_revenue.png      # Power BI dashboard screenshot
│
└── README.md
```

---

## Key Findings

### Revenue
- **£13.65M gross revenue** across 99,441 orders (2016–2018)
- Top 5 product categories account for ~42% of total gross revenue
- São Paulo (SP) generates ~40% of all orders — heavy geographic concentration
- Freight cost averages ~17% of order value

### Delivery & Operations
- **8% late delivery rate** nationally
- 90% of orders delivered on time or early
- Late deliveries concentrated in northern states

### Customer Intelligence (RFM Segmentation)
- **93,000 unique customers** segmented by Recency, Frequency, Monetary value
- **15,000 Champions** — highest LTV segment at avg £330 per customer
- Loyal Customers avg £201 LTV vs New Customers at £25
- Cohort analysis reveals most customers are one-time buyers — retention is the key growth lever

---

## How to Run

### Prerequisites
- PostgreSQL 17+
- VS Code + SQLTools extension
- Power BI Desktop
- Olist dataset from Kaggle

### Steps

```bash
# 1. Clone the repo
git clone https://github.com/SURIYAPRASATH-PARAMESWARAN/Ecommerce-SQL-Intelligence
cd Ecommerce-SQL-Intelligence

# 2. Create the database in PostgreSQL
# Then run SQL files in order:
# 01_schema.sql → 02_load_data.sql → 03_eda.sql → 04_advanced_analytics.sql

# 3. Open Power BI and connect to PostgreSQL localhost
# Import: vw_order_master, vw_customer_segments, vw_cohort_retention
```

---

## Dashboard

**E-Commerce Revenue Intelligence Dashboard — Power BI**

![Dashboard](outputs/dashboard_revenue.png)

| KPI | Value |
|-----|-------|
| Gross Revenue | £13.65M |
| Net Revenue | £11.39M |
| Avg Order Value | £138.37 |
| Freight % | 17% |
| Late Delivery Rate | 8% |

---

## Skills Demonstrated

`PostgreSQL` `Advanced SQL` `Window Functions` `CTEs` `Cohort Analysis` `RFM Segmentation` `Power BI` `DAX` `Data Modelling` `EDA` `Business Intelligence` `Customer Analytics`

---

*Part of the [Suriyaprasath Parameswaran](https://github.com/SURIYAPRASATH-PARAMESWARAN) data analytics portfolio.*