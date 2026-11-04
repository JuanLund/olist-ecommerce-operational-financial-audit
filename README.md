# 🛒 E-Commerce Operational & Financial Audit: Olist Case
![BigQuery](https://img.shields.io/badge/Google_BigQuery-Cloud_SQL-4285F4?logo=google-cloud&logoColor=white)
![Tableau](https://img.shields.io/badge/Tableau-Public-E97627?logo=tableau&logoColor=white)
![Status](https://img.shields.io/badge/Status-Completed-success)

> **Operational and Financial Audit of 96,470 Real Sales: Forensic Diagnosis of Logistics Bottlenecks, Freight Disparities, and Repurchase Retention**  
> **Author:** Juan E. Lund — Operations & Partner Manager | Data & Decision Scientist  
> **Language:** **English** | [Versión en Español](README.es.md)

---

## 1. Executive Summary (Answer-First)

To protect operating contribution margins and scale sales volume without relying solely on paid customer acquisition (CAC), Olist's leadership must execute a surgical three-pronged operational intervention: **decouple last-mile carrier delivery in Rio de Janeiro from the state postal service, correct the multi-item freight pricing distortion in heavy categories (>23% freight ratio), and activate an automated retention replenishment engine between days 65 and 85 post-delivery**.

This audit demonstrates that gross GMV growth was concealing severe SLA failures and margin leakage, and establishes an action plan backed by an 8-week A/B testing framework projecting an **annualized business value of R$ 1,230,000** (~R$ 680K in GMV protected from detractor churn and R$ 550K in incremental organic repurchase sales at zero CAC).

---

## 2. Business Problem & Operational Audit (Ask)

Olist's executive committee identified three structural operational challenges:
* **Logistics SLA Breaches:** Customer complaints concentrated in high-density corridors.
* **Freight Pricing Friction:** Heavy and bulky categories where shipping fees exceed a quarter of the product value, inflating checkout abandonment.
* **Zero Organic Retention:** A 97.0% reliance on single-purchase transactions.

The business objective was to audit the relational schema in Google BigQuery to isolate root causes and design measurable, data-backed operational interventions.

---

## 3. Data Cleaning & Schema Architecture (Prepare & Process)

The audit examined Olist's 7-table relational ecosystem (`orders`, `order_items`, `order_payments`, `order_reviews`, `customers`, `products`, `sellers`).

* **Tools:** Google BigQuery (Advanced SQL: Relational Joins, Multi-stage CTEs, Window Functions `ROW_NUMBER`, `LAG`, `RANK`, Materialized Views) and Tableau Public.
* **Volume & Hygiene:** 99,441 raw orders were audited. Strict business filters removed 1,107 orders in transit, 625 canceled orders, 8 missing delivery dates, and 609 out-of-stock orders (~R$ 97K in phantom inventory).
* **Certified Population:** View `vw_orders_clean` finalized with **96,470 completed sales** and **93,350 unique customers**.

---

## 4. Key Quantitative Insights (Analyze)

1. **The "Day 4 SLA Cliff" (Satisfaction Collapse):**
   * Customers tolerate 1 to 3 days of carrier delay past the estimated date (maintaining 3.76 ★ and only 19.3% complaint rates).
   * **Upon crossing Day 4 of delay, satisfaction plummets to 2.31 ★ and detractor complaints triple to 61.6%**, reaching 78.3% past Day 7.
2. **Rio de Janeiro Last-Mile Failure (Carrier vs. Seller Breakdown):**
   * The São Paulo → Rio de Janeiro corridor (`SP -> RJ`) concentrates nearly 10% of national volume (9,403 orders) and suffers a 14.85% delay rate with an average 12.6-day lag.
   * Decomposing fulfillment intervals in SQL revealed that sellers dispatch packages in just 4.6 days, but **carriers take 31.3 days on delayed shipments (87.2% of total delay occurs during the postal last mile in Rio)**.
3. **Algorithmic Multi-Item Freight Inefficiency (>23% Shipping):**
   * In heavy categories such as Furniture (`moveis_decoracao`: 23.65% freight) and Housewares (`utilidades_domesticas`: 23.19%), the checkout algorithm charged 100% freight per additional unit without parcel consolidation, driving freight to 27.4% on 2+ units and depressing average order value (AOV).
4. **Late Repurchase Window (81.7 Days):**
   * Among the 2,801 repeat buyers identified via `LAG()`, the natural replenishment cycle spans **81.7 to 116.8 days** (not the first 15 days). Furthermore, experiencing an initial delivery delay reduces repeat purchase propensity by -17.4% relative.

---

## 5. Executive Visualization (Share)

Findings were structured into an interactive executive dashboard in Tableau Public:

![Dashboard Preview](./assets/tableau_dashboard.png)

* **View 1:** Logistics Corridor Performance Ranking.
* **View 2:** Dual-Axis Curve of the SLA Satisfaction Cliff.
* **View 3:** Category-Level Unit Economics and Freight Ratio Matrix.

---

## 6. Strategic Recommendations & A/B Experimentation (Act)

* **Operation Unlock Rio + 72-Hour Preventive Trigger:** Route critical postal codes to private 3PL carriers and offer a 15% freight discount for pickup at secure lockers (PUDO). Trigger automated WhatsApp tracking and compensation vouchers at 24 hours of delay before reaching the Day 4 cliff (protecting ~R$ 680K GMV).
* **Incremental Freight Discount (> R$ 150) & Geo-Prioritization:** Discount secondary-unit freight by 50% for orders > R$ 150 from the same seller (compressing freight ratio to ~14.8%). Prioritize local intrastate sellers in search algorithms for bulky items (generating +R$ 310K in GMV).
* **"Day 65" Replenishment Engine in Health & Beauty:** Trigger automated reorder sequences between days 65 and 75 post-delivery for satisfied customers in Health & Beauty (Olist's #1 sales category with R$ 1.23M), supported by in-box QR codes to capture app downloads at CAC = $0 (+R$ 240K GMV).

---

## 7. Repository Structure

```text
olist-ecommerce-operational-financial-audit/
├── deliverables/
│   ├── Olist_Presentacion_Ejecutiva_Final.pptx    # 13-slide executive presentation with speaker notes
│   ├── Olist_Log_Auditoria_Metodologica.docx      # Comprehensive audit log and business rules
│   └── Olist_Caso_Estudio_Completo.md             # Full case study documentation
├── sql/
│   ├── 01_vw_orders_clean.sql                     # Certified master view in BigQuery
│   ├── 02_sla_cliff_and_last_mile_audit.sql       # First-mile vs. last-mile breakdown
│   ├── 03_unit_economics_and_multi_item_freight.sql# Freight ratio and AOV analysis
│   └── 04_cohort_retention_and_sla_impact.sql     # Cohort analysis with ROW_NUMBER and LAG
├── data/
│   ├── 01_corredores_logisticos_bigquery.csv      # Extracted corridor performance metrics
│   ├── 02_unit_economics_categorias_bigquery.csv  # Extracted category unit economics
│   └── 03_sla_cliff_satisfaccion_bigquery.csv     # Extracted SLA cliff distribution
├── assets/
│   ├── tableau_dashboard.png                      # Interactive dashboard screenshot
│   └── sla_cliff_chart.png                        # Satisfaction cliff curve
├── README.es.md                                   # Spanish version of documentation
└── README.md                                      # Primary English documentation
```

---

### Links & Deliverables
* 📊 **Executive Presentation:** [Download Deck in `/deliverables`](./deliverables/Olist_Presentacion_Ejecutiva_Final.pptx)
* 💻 **SQL Scripts:** [BigQuery Queries in `/sql`](./sql/)
* 📈 **Tableau Dashboard:** [View on Tableau Public](https://public.tableau.com/views/Brazil_ecomercce/Dashboard1?:language=es-ES&:sid=&:redirect=auth&:display_count=n&:origin=viz_share_link)
