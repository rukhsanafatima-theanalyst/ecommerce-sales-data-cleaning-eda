# ecommerce-sales-data-cleaning-eda
End-to-end data cleaning, data transformation, and exploratory data analysis (EDA) using MySQL Workbench on transactional e-commerce data.
## Executive Summary
This project delivers a comprehensive end-to-end data processing and analytical pipeline on a global e-commerce transactional dataset containing over 500,000 order records. Using **MySQL Workbench**, raw operational transactional records were cleaned, standardized, and modeled into analytics-ready data structures. 

Exploratory Data Analysis (EDA) was performed to extract key commercial insights regarding revenue concentration, geographic distribution, customer purchasing patterns, and seasonal sales trends.

---

## Technical Architecture & Tools
* **Database Engine:** MySQL Workbench 8.0
* **Query Language:** SQL (Window Functions, CTEs, Data Type Transformation, Aggregations, Subqueries)
* **Dataset:** [E-Commerce Data (Kaggle)](https://www.kaggle.com/datasets/carrie1/ecommerce-data)
* **Output Artifacts:** Cleaned database schemas, SQL scripts, and exported analytical query results (CSV format).

---

## Data Cleaning & Transformation Pipeline

The initial dataset contained operational noise, missing keys, and invalid transaction records. The following cleaning protocol was executed in MySQL:

1. **Handling Missing & Identifier Anomalies:**
   - Identified and isolated records with missing `CustomerID` entries.
   - Filtered out non-transactional system testing logs and missing product descriptions.
2. **Data Type Casting & Formatting:**
   - Standardized text-based timestamps (`InvoiceDate`) into native `DATETIME` (`YYYY-MM-DD HH:MM:SS`) SQL formats.
   - Cast unit prices and quantity metrics into appropriate numeric data types (`DECIMAL`, `INT`).
3. **Filtering Cancellations & Negative Outliers:**
   - Segregated order cancellations (invoices starting with `'C'`) to prevent revenue skewing.
   - Removed negative quantities and zero-value unit pricing transactions.
4. **Data Normalization & Feature Engineering:**
   - Created a calculated field `TotalSpend` = `Quantity * UnitPrice`.
   - Extracted temporal attributes (`Year`, `Month`, `DayOfWeek`, `Hour`) to support time-series analysis.

---

## Business Questions & Key Analytical Findings

### 1. Revenue & Geographic Distribution
- **Dominant Market:** The UK accounts for the overwhelming majority of total sales revenue and customer transactions.
- **Top International Markets:** Primary cross-border expansion markets include Netherlands, EIRE (Ireland), Germany, and France.

| Market / Country | Total Transactions | Total Revenue ($) | Share of Total Revenue |
| :--- | :--- | :--- | :--- |
| **United Kingdom** | ~350,000+ | $6,854,000 | ~84% |
| **Netherlands** | ~2,300 | $285,400 | ~3.5% |
| **EIRE (Ireland)** | ~1,800 | $250,200 | ~3.1% |
| **Germany** | ~1,400 | $220,100 | ~2.7% |
| **France** | ~1,200 | $197,000 | ~2.4% |



---

### 2. Customer Segmentation & Revenue Concentration
- **Pareto Principle Observed:** The top **10% of active repeat customers** account for over **60% of overall gross sales revenue**.
- **High-Value Repeat Buyers:** Identified key B2B/wholesaler accounts exhibiting frequent high-volume purchasing behavior.

---

### 3. Sales Seasonality & Peak Operational Times
- **Fourth Quarter Surge:** Monthly revenue peaks sharply during Q4 (October through November), driven primarily by holiday restocking and seasonal shopping.
- **Peak Order Hours:** Transaction volumes peak between **10:00 AM and 2:00 PM GMT**, indicating optimal windows for promotional outreach and email campaigns.
