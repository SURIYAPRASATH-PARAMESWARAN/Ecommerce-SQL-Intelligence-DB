# Power BI Setup Guide
## E-Commerce Customer & Sales Intelligence

---

## Connecting Power BI to PostgreSQL

1. Open Power BI Desktop
2. **Get Data** → **PostgreSQL database**
3. Server: `localhost`, Database: `ecommerce_olist`
4. **Import** mode (not DirectQuery — dataset is static)
5. Select these views/tables to import:
   - `vw_order_master` ← main fact table
   - `vw_customer_segments` ← RFM segments
   - `vw_cohort_retention` ← cohort heatmap data

---

## Dashboard Structure — 3 Pages

---

### PAGE 1: Executive Revenue Overview

**KPI Cards (top row)**
- Total Gross Revenue
- Total Orders
- Unique Customers
- Average Order Value
- Freight as % of Revenue

**Visuals**
| Visual | Type | Fields |
|--------|------|--------|
| Monthly Revenue Trend | Line chart | order_month → gross sum(price) |
| MoM Growth % | Line chart | order_month → mom_growth_pct (calculated) |
| Revenue by Category | Horizontal bar | product_category → sum(price) Top N = 15 |
| Revenue by State | Filled map | customer_state → sum(price) |
| Payment Type Split | Donut chart | payment_type → count(order_id) |
| Delivery Status | Donut chart | delivery_status → count |

**DAX Measures**
```
Gross Revenue = SUM(vw_order_master[price])

Freight Revenue = SUM(vw_order_master[freight_value])

Net Revenue = [Gross Revenue] - [Freight Revenue]

Avg Order Value = DIVIDE([Gross Revenue], DISTINCTCOUNT(vw_order_master[order_id]))

Freight Pct = DIVIDE([Freight Revenue], [Gross Revenue])

MoM Growth % = 
VAR CurrentMonth = [Gross Revenue]
VAR PrevMonth = CALCULATE([Gross Revenue], DATEADD('DateTable'[Date], -1, MONTH))
RETURN DIVIDE(CurrentMonth - PrevMonth, PrevMonth)

Late Delivery Rate =
DIVIDE(
    CALCULATE(COUNTROWS(vw_order_master), vw_order_master[delivery_status] = "Late"),
    COUNTROWS(vw_order_master)
)
```

---

### PAGE 2: Customer Intelligence & RFM Segmentation

**KPI Cards**
- Total Unique Customers
- Repeat Purchase Rate %
- Champions Count
- At Risk Customers
- Average Customer LTV

**Visuals**
| Visual | Type | Fields |
|--------|------|--------|
| Customer Segment Distribution | Treemap | customer_segment → count |
| Avg LTV by Segment | Clustered bar | customer_segment → avg(monetary_value) |
| Revenue Concentration (Decile) | Bar chart | decile → pct_of_total_revenue |
| Customers by State | Filled map | customer_state → count |
| RFM Scatter Plot | Scatter | x=frequency, y=monetary_value, size=recency |
| New vs Returning | KPI card | calculated measure |

**DAX Measures**
```
Unique Customers = DISTINCTCOUNT(vw_customer_segments[customer_unique_id])

Champions = 
CALCULATE(
    COUNTROWS(vw_customer_segments),
    vw_customer_segments[customer_segment] = "Champions"
)

Avg LTV = AVERAGE(vw_customer_segments[monetary_value])

At Risk Customers =
CALCULATE(
    COUNTROWS(vw_customer_segments),
    vw_customer_segments[customer_segment] = "At Risk"
)

Repeat Rate % =
DIVIDE(
    CALCULATE(
        COUNTROWS(vw_customer_segments),
        vw_customer_segments[frequency] > 1
    ),
    COUNTROWS(vw_customer_segments)
)
```

---

### PAGE 3: Seller Performance & Operations

**KPI Cards**
- Active Sellers
- Avg Delivery Days
- On-Time Delivery Rate
- Avg Review Score
- Late Deliveries Count

**Visuals**
| Visual | Type | Fields |
|--------|------|--------|
| Seller Revenue vs Review Score | Scatter | x=gross_revenue, y=avg_review, size=orders |
| Delivery Performance by State | Bar | customer_state → avg_actual_delivery_days |
| Late Delivery Rate by State | Bar | customer_state → late_pct (sorted desc) |
| Review Score Distribution | Column chart | review_score → count |
| Cohort Retention Heatmap | Matrix | cohort (rows) × period_number (cols) → retention_pct |

**DAX for Cohort Heatmap Conditional Formatting**
```
-- Apply to retention_pct field in matrix
-- Background colour scale: 0% = Red, 50% = Yellow, 100% = Green
-- This creates the classic cohort heatmap look

Retention Color = 
IF(
    ISBLANK([retention_pct]),
    BLANK(),
    [retention_pct]
)
```

---

## Slicers (apply across all pages)
- Year slicer (order_year)
- Order Status slicer
- Customer State slicer
- Product Category slicer

---

## Colour Theme
Use a dark professional theme:
- Background: `#1A1A2E`
- Accent 1: `#E94560`
- Accent 2: `#0F3460`
- Text: `#FFFFFF`
- Positive: `#00B894`
- Negative: `#D63031`

Export theme JSON from powerbi.microsoft.com/en-us/blog/power-bi-themes