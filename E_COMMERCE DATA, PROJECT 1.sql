#Create database
CREATE DATABASE ecommerce_db;

#use database
USE ecommerce_db;

#create table for data
CREATE TABLE IF NOT EXISTS ecommerce_raw(
    InvoiceNo VARCHAR(20),
    StockCode VARCHAR(20),
    Description VARCHAR(255),
    Quantity INT,
    InvoiceDate VARCHAR(30),
    UnitPrice DECIMAL(10, 2),
    CustomerID VARCHAR(20),
    Country VARCHAR(50));
    
#import data into the table
#import from local directory 
SET GLOBAL local_infile = 1;

LOAD DATA LOCAL INFILE 'D:/data Analysis/data.csv'
INTO TABLE ecommerce_raw
CHARACTER SET latin1
FIELDS TERMINATED BY ','
OPTIONALLY ENCLOSED BY '"'
LINES TERMINATED BY '\r\n'
IGNORE 1 LINEs;

#Create duplicate staging table structure
CREATE TABLE ecommerce_staging LIKE ecommerce_raw;

#Copy all rows into staging table
INSERT INTO ecommerce_staging
SELECT * FROM ecommerce_raw;

#Verify total row count in staging table
SELECT COUNT(*) AS total_rows 
FROM ecommerce_staging	;				#output = 541909	

#----------------------------------------DATA CLEANING STARTS HERE------------------------------------------------------------------
#----------------------------------------STEP 1 : REMOVE DUPLICATES----------------------------------------------------------------------
#IDEFTIFY DUPLICATE RECORDS
WITH duplicates AS(
SELECT *, 
ROW_NUMBER() OVER(PARTITION BY InvoiceNo, StockCode, Description, Quantity, InvoiceDate, UnitPrice, CustomerID, Country
ORDER BY InvoiceNo) AS row_num

FROM ecommerce_staging)
SELECT * FROM duplicates
WHERE row_num > 1;         #5268 rows retuned

#identify unique and duplicate rows
WITH flagged_duplicates AS (
    SELECT *,
           ROW_NUMBER() OVER(
               PARTITION BY InvoiceNo, StockCode, Description, Quantity, InvoiceDate, UnitPrice, CustomerID, Country
               ORDER BY InvoiceNo
           ) AS row_num
    FROM ecommerce_staging
)
SELECT 
    COUNT(*) AS total_rows,
    SUM(CASE WHEN row_num = 1 THEN 1 ELSE 0 END) AS unique_rows,  
    SUM(CASE WHEN row_num > 1 THEN 1 ELSE 0 END) AS duplicate_rows
	FROM flagged_duplicates;
    /* unique rows = 536641 ,   duplicate rows = 5268 */
    
#Create deduplicated table keeping only unique rows
CREATE TABLE ecommerce_dedup AS
WITH ranked_rows AS (
    SELECT *,
           ROW_NUMBER() OVER(
               PARTITION BY InvoiceNo, StockCode, Description, Quantity, InvoiceDate, UnitPrice, CustomerID, Country
               ORDER BY InvoiceNo
           ) AS row_num
    FROM ecommerce_staging
)
SELECT InvoiceNo, StockCode, Description, Quantity, InvoiceDate, UnitPrice, CustomerID, Country
FROM ranked_rows
WHERE row_num = 1;

# Replace old staging table with deduplicated table
DROP TABLE ecommerce_staging;
# Rename table
RENAME TABLE ecommerce_dedup TO ecommerce_staging;

#Verify final count
SELECT COUNT(*) AS total_rows FROM ecommerce_staging;

#------------------------------------------STANDARDIZE THE DATE COLUMN------------------------------------------------------

#STEP 1: Add a temporary DATETIME column
ALTER TABLE ecommerce_staging
ADD COLUMN InvoiceDate_Clean DATETIME AFTER InvoiceDate;

#STEP 2:Convert string dates into MySQL DATETIME format
UPDATE ecommerce_staging
SET InvoiceDate_Clean = STR_TO_DATE(InvoiceDate, '%m/%d/%Y %H:%i');

#STEP 3: Replace the original VARCHAR column with the clean DATETIME column
ALTER TABLE ecommerce_staging
DROP COLUMN InvoiceDate, 
CHANGE COLUMN InvoiceDate_Clean InvoiceDate DATETIME;

#STEP 4 : Preview to verify the updated format
SELECT *
FROM ecommerce_staging 
LIMIT 5;

#----------------------------------------CLEAN DESCRIPTION COLUMN-----------------------------------------------
#STEP 1: VIEW THE COLUMN VALUES
SELECT DISTINCT Description
FROM ecommerce_staging 
LIMIT 100;

#STEP 2:Update Description by trimming whitespace and standardizing to uppercase
UPDATE ecommerce_staging
SET Description = TRIM(UPPER(Description))
WHERE Description IS NOT NULL;

#STEP 3:Preview sample descriptions to verify clean output
SELECT DISTINCT Description 
FROM ecommerce_staging 
WHERE Description IS NOT NULL 
LIMIT 100;

#-----------------------------------HANDLE BLANK CUSTOMER ID VALUES------------------------------------------------

#STEP 1: Preview if Customer ID has NULL or empty space
SELECT count(CustomerID)
FROM ecommerce_staging
WHERE CustomerID = ''  OR CustomerID IS NULL ;
# out put = 135037 null values;

#STEP 2 : Update empty strings to NULL
UPDATE ecommerce_staging
SET CustomerID = NULL
WHERE CustomerID = '';

#STEP 3: Verify the count of NULL values
SELECT COUNT(*) 
FROM ecommerce_staging 
WHERE CustomerID IS NULL;
# Output= 135037

#----------------------------------------------CHECK NEGATIVE OR ZERO QUANTITY-----------------------------------
#STEP 1:Check negative or zero Quantity
SELECT COUNT(*) AS zero_qty
FROM ecommerce_staging
WHERE Quantity = 0;
#output= 0

SELECT COUNT(*) AS negative_qty
FROM ecommerce_staging
WHERE Quantity < 0;
#OUTPUT = 10587 NEGATIVE qUANTITY
#In retail datasets, order cancellations often have a matching InvoiceNo starting with the letter 'C'

#STEP 2:Inspect Cancelled Orders
SELECT COUNT(*) AS cancelled_invoices
FROM ecommerce_staging
WHERE Quantity < 0 AND InvoiceNo LIKE 'C%';
#Output = 9251 
#That leaves 1,336 negative quantity rows (10,587 - 9,251) that do not start with 'C'. 
#These usually represent manual stock adjustments, damaged items, or system entries.

#STEP 3:Inspect Non-'C' Negative Quantities
SELECT InvoiceNo, StockCode, Description, Quantity, UnitPrice 
FROM ecommerce_staging
WHERE Quantity < 0 AND InvoiceNo NOT LIKE 'C%'
LIMIT 100;

#Look at the discription
SELECT DISTINCT Description
FROM ecommerce_staging
WHERE Quantity < 0 AND InvoiceNo NOT LIKE 'C%';

SELECT COUNT(Description)
FROM ecommerce_staging
WHERE Quantity < 0 AND InvoiceNo NOT LIKE 'C%';
# OUTPUT = 1336 (Damaged, faulty, Stock returned due to some issue)

#STEP 4:Delete rows with negative quantities
DELETE FROM ecommerce_staging
WHERE Quantity < 0;
# OUTPUT = 10586 ROWS AFFECTED

#STEP 5: Verify the new total row count
SELECT COUNT(*) AS total_rows_remaining 
FROM ecommerce_staging;
# Output = 526054 rows remaining

#----------------------------------------CHECk NEGATIVE OR ZERO UNIT PRICE COLUMN-------------------------------------
#STEP 1:Check number of 0's or Negative UnitPrice Column Values
SELECT COUNT(*) AS zero_or_negative_unit_price
FROM ecommerce_staging
WHERE UnitPrice <= 0;
# OUtput = 1180

SELECT InvoiceNo, StockCode, Description, Quantity, UnitPrice 
FROM ecommerce_staging
WHERE UnitPrice <= 0
LIMIT 100;

# check what kind of stock has 0 or less unit price
SELECT DISTINCT Description
FROM ecommerce_staging
WHERE UnitPrice <= 0;

SELECT COUNT(*) AS negative_price_count
FROM ecommerce_staging
WHERE UnitPrice < 0;
#output = 2

#1,180 total rows with zero or negative unit prices that do not represent real customer sales.
#STEP 2: Delete Zero and Negative Unit Prices
DELETE FROM ecommerce_staging
WHERE UnitPrice <= 0;
# OUTPUT = 1180 ROWS AFFECTED

#STEP 3:Verify total remaining rows
SELECT COUNT(*) AS total_rows_remaining
FROM ecommerce_staging;
#OUTPUT = 524874 ROWS REMAINING

#------------------------------------CLEAN COUNTRY COLUMN-------------------------------------------------------------
#STEP 1: Inspect Country Column
SELECT DISTINCT Country
FROM ecommerce_staging
ORDER BY Country;
#EIRE And 'Unspecified' are unusual

#STEP 2:Check Counts for EIRE and Unspecified
SELECT Country, COUNT(*) AS row_count
FROM ecommerce_staging
WHERE Country IN ('EIRE', 'Unspecified')
GROUP BY Country;
# OUTPUT = EIRE 7879, Unspecified 442

#STEP 3:Standardize EIRE to Ireland
UPDATE ecommerce_staging
SET Country = 'Ireland'
WHERE Country = 'EIRE';
# OUTPUT = 7879 ROWS AFFECTED

#STEP 4 : Verify the update
SELECT COUNT(*) AS ireland_count
FROM ecommerce_staging
WHERE Country = 'Ireland';
#---------------------------------------------DATA CLEANING DONE!-------------------------------------------------------
#----------------------------------------------------------------------------------------------------------------------
#---------------------------------------------EXPOLATORY DATA ANALYSIS--------------------------------------------------

# STEP1: Overall Sales & Customer Summary
SELECT 
    MIN(InvoiceDate) AS start_date,
    MAX(InvoiceDate) AS end_date,
    COUNT(DISTINCT InvoiceNo) AS total_orders,
    COUNT(DISTINCT CustomerID) AS total_customers,
    SUM(Quantity) AS total_items_sold,
    ROUND(SUM(Quantity * UnitPrice), 2) AS total_revenue
FROM ecommerce_staging;
/*OUTPUT=  start_date     01-12-2010 ,   end_date     09-12-2011,   total_orders     19960
		   total_customers     4338,     total_items_sold    5572416,      total_revenue    10642110.80*/

#STEP 2:Monthly Sales Trend
SELECT 
    DATE_FORMAT(InvoiceDate, '%Y-%m') AS month,
    COUNT(DISTINCT InvoiceNo) AS total_orders,
    ROUND(SUM(Quantity * UnitPrice), 2) AS monthly_revenue
FROM ecommerce_staging
GROUP BY DATE_FORMAT(InvoiceDate, '%Y-%m')
ORDER BY month;
#OUTPUT= 13 rows returned

#STEP 3:Top 10 Revenue-Generating Countries
SELECT 
    Country,
    COUNT(DISTINCT InvoiceNo) AS total_orders,
    ROUND(SUM(Quantity * UnitPrice), 2) AS total_revenue
FROM ecommerce_staging
GROUP BY Country
ORDER BY total_revenue DESC
LIMIT 10;
# OUTPUT= TOP 10 OUT OF 38 COUNTRIES WITH RESPECTIVE REVENUE RETURNED

#STEP4:Customer Analysis (MOST VALUABLE CUSTOMER)
SELECT 
    CustomerID, Country,
    DATEDIFF('2011-12-10', MAX(InvoiceDate)) AS recency_days,
    COUNT(DISTINCT InvoiceNo) AS total_orders,
    ROUND(SUM(Quantity * UnitPrice), 2) AS total_spent
FROM ecommerce_staging
WHERE CustomerID IS NOT NULL
GROUP BY CustomerID, Country
ORDER BY total_spent DESC
LIMIT 20;

#STEP 5:Sales Performance by Day of the Week
SELECT 
    DAYNAME(InvoiceDate) AS day_of_week,
    COUNT(DISTINCT InvoiceNo) AS total_orders,
    ROUND(SUM(Quantity * UnitPrice), 2) AS total_revenue
FROM ecommerce_staging
GROUP BY DAYNAME(InvoiceDate), WEEKDAY(InvoiceDate)
ORDER BY WEEKDAY(InvoiceDate);

#STEP 6:Peak Ordering Hours of the Day
SELECT 
    HOUR(InvoiceDate) AS order_hour,
    COUNT(DISTINCT InvoiceNo) AS total_orders,
    ROUND(SUM(Quantity * UnitPrice), 2) AS total_revenue
FROM ecommerce_staging
GROUP BY HOUR(InvoiceDate)
ORDER BY order_hour;
  
#STEP 7:Top 10 Best-Selling Products by Quantity (Volume Leaders)
SELECT Description,
    SUM(Quantity) AS total_units_sold,
    ROUND(SUM(Quantity * UnitPrice), 2) AS total_revenue
FROM ecommerce_staging
GROUP BY Description
ORDER BY total_units_sold DESC
LIMIT 20;
 
 #STEP 8:Repeat vs. One-Time Customer Analysis
 SELECT 
    CASE 
        WHEN order_count = 1 THEN 'One-Time Customer'
        ELSE 'Repeat Customer'
    END AS customer_type,
    COUNT(CustomerID) AS total_customers,
    ROUND(SUM(total_spent), 2) AS total_revenue
FROM (
    SELECT 
        CustomerID,
        COUNT(DISTINCT InvoiceNo) AS order_count,
        SUM(Quantity * UnitPrice) AS total_spent
    FROM ecommerce_staging
    WHERE CustomerID IS NOT NULL
    GROUP BY CustomerID
) AS customer_summary
GROUP BY customer_type;
# OUTPUT = One-Time Customer	1493	    613989.56
#           Repeat Customer	    2845	    8273219.33

#STEP 9:Average Order Value (AOV) & Basket Size Metrics
SELECT 
    ROUND(SUM(Quantity * UnitPrice) / COUNT(DISTINCT InvoiceNo), 2) AS avg_order_value,
    ROUND(SUM(Quantity) / COUNT(DISTINCT InvoiceNo), 2) AS avg_items_per_order,
    ROUND(AVG(UnitPrice), 2) AS avg_unit_price
FROM ecommerce_staging;
/*OUTPUT = avg_order_value 		avg_items_per_order			avg_unitPrice
			533.17				279.18						3.92*/
            
#STEP 10:Monthly Active Customers
SELECT 
    DATE_FORMAT(InvoiceDate, '%Y-%m') AS month,
    COUNT(DISTINCT CustomerID) AS active_customers
FROM ecommerce_staging
WHERE CustomerID IS NOT NULL
GROUP BY DATE_FORMAT(InvoiceDate, '%Y-%m')
ORDER BY month;

#-------------------------------------------------END OF EDA-------------------------------------------------------------




