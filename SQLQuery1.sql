Create Database Walmart
Use walmart
select * from train
select * from stores
select * from features

/* Check NULL values */
SELECT COUNT(*) AS null_count
FROM features
WHERE Fuel_Price IS NULL;

/* Check negative values */
SELECT COUNT(*) AS negative_count
FROM features
WHERE TRY_CAST(Fuel_Price AS FLOAT) < 0;

/* Check non-numeric values */
SELECT *
FROM features
WHERE TRY_CAST(Fuel_Price AS FLOAT) IS NULL
  AND Fuel_Price IS NOT NULL;

/* check for negative  values so using order by and top 10 */
  SELECT TOP 20 Fuel_Price
FROM features
ORDER BY TRY_CAST(Fuel_Price AS FLOAT);

/* Altering the table with new field */
IF COL_LENGTH('features', 'Fuel_Price_Clean') IS NULL
BEGIN
ALTER TABLE features
ADD Fuel_Price_Clean FLOAT
End;

/* Check NULL values */
SELECT COUNT(*) AS null_count
FROM features
WHERE temperature IS NULL;

/* Check negative values */
SELECT COUNT(*) AS negative_count
FROM features
WHERE TRY_CAST(temperature AS FLOAT) < 0;

/* Check non-numeric values */
SELECT *
FROM features
WHERE TRY_CAST(temperature AS FLOAT) IS NULL
  AND temperature IS NOT NULL;

SELECT TOP 20 temperature
FROM features
ORDER BY TRY_CAST(temperature AS FLOAT);

/* Altering the table with new field */
IF COL_LENGTH('features', 'temperature_Clean') IS NULL
BEGIN
ALTER TABLE features
ADD temperature_Clean FLOAT
End;

UPDATE features
SET 
    Fuel_Price_Clean = TRY_CAST(Fuel_Price AS FLOAT),
    temperature_Clean = TRY_CAST(temperature AS FLOAT);

/* Check non-numeric values */
SELECT *
FROM train
WHERE TRY_CAST(weekly_sales AS FLOAT) IS NULL
  AND weekly_sales IS NOT NULL;


/* check for negative  values so using order by and top 10 */
  SELECT TOP 20 WEEKLY_SALES
FROM train
ORDER BY TRY_CAST(Weekly_Sales AS FLOAT);

/* Altering the table with new field */
IF COL_LENGTH('train', 'weekly_sales_Clean') IS NULL
BEGIN
ALTER TABLE train
ADD weekly_sales_Clean FLOAT
End;

UPDATE train
SET weekly_sales_Clean = TRY_CAST(weekly_sales AS FLOAT);

/* Final Sales data */
IF OBJECT_ID('final_sales_data','U') IS NOT NULL DROP TABLE final_sales_data;

SELECT
    t.Store,
    t.Dept,
    t.Date,
    t.Weekly_Sales_clean AS Weekly_Sales,
    CASE 
        WHEN t.Weekly_Sales_clean < 0 THEN 'Return'
        ELSE 'Sale'
    END AS Sales_Type,
    t.IsHoliday,
    f.Temperature_Clean AS Temperature,
    f.Fuel_Price_Clean AS Fuel_Price,
    f.CPI,
    f.Unemployment
INTO final_sales_data
FROM train t
LEFT JOIN features f
    ON t.Store = f.Store
   AND t.Date = f.Date;

SELECT * FROM final_sales_data

/* Store Performance Summary */
IF OBJECT_ID('store_performance_summary','U') IS NOT NULL DROP TABLE store_performance_summary;
SELECT
    Store,
    COUNT(*) AS Total_Records,
    SUM(CASE WHEN Sales_Type = 'Sale' THEN Weekly_Sales ELSE 0 END) AS Total_Sales,
    SUM(CASE WHEN Sales_Type = 'Return' THEN ABS(Weekly_Sales) ELSE 0 END) AS Total_Returns,
    SUM(Weekly_Sales) AS Net_Sales,
    SUM(CASE WHEN IsHoliday = 1 THEN Weekly_Sales ELSE 0 END) AS Holiday_Sales,
    SUM(CASE WHEN IsHoliday = 0 THEN Weekly_Sales ELSE 0 END) AS Non_Holiday_Sales,
    AVG(Temperature) AS Avg_Temperature,
    AVG(Fuel_Price) AS Avg_Fuel_Price,
    AVG(CPI) AS Avg_CPI,
    AVG(Unemployment) AS Avg_Unemployment
INTO store_performance_summary
FROM final_sales_data
GROUP BY Store;


SELECT
    MIN(Net_Sales) AS Min_Net_Sales,
    MAX(Net_Sales) AS Max_Net_Sales,
    AVG(Net_Sales) AS Avg_Net_Sales
FROM store_performance_summary;

/* Store crisis based on Net sales */

IF OBJECT_ID('store_crisis_flag','U') IS NOT NULL DROP TABLE store_crisis_flag;
WITH avg_sales AS (
    SELECT AVG(Net_Sales) AS avg_net_sales
    FROM store_performance_summary
)

SELECT
    s.*,
    CASE
        WHEN s.Net_Sales < 0.3 * a.avg_net_sales THEN 'High Risk'
        WHEN s.Net_Sales < 0.6 * a.avg_net_sales THEN 'Moderate Risk'
        ELSE 'Stable'
    END AS Crisis_Status
	INTO store_crisis_flag
FROM store_performance_summary s
CROSS JOIN avg_sales a;	

SELECT
    Crisis_Status,
    COUNT(*) AS Store_Count
FROM store_crisis_flag
GROUP BY Crisis_Status;

/* Monthly_sales_trend */
-- Negative sales represent returns and are retained for analysis
IF OBJECT_ID('monthly_sales_trend', 'U') IS NOT NULL
    DROP TABLE monthly_sales_trend;

SELECT
    DATEPART(YEAR, Date) AS Year,
    DATEPART(MONTH, Date) AS Month,
    SUM(Weekly_Sales) AS Total_Sales,
    SUM(CASE WHEN Sales_Type = 'Return' THEN ABS(Weekly_Sales) ELSE 0 END) AS Total_Returns,
    SUM(Weekly_Sales) - 
    SUM(CASE WHEN Sales_Type = 'Return' THEN ABS(Weekly_Sales) ELSE 0 END) AS Net_Sales
INTO monthly_sales_trend
FROM final_sales_data
GROUP BY DATEPART(YEAR, Date), DATEPART(MONTH, Date)
ORDER BY Year, Month;

SELECT *
FROM monthly_sales_trend
ORDER BY Year, Month;

 /* Growth and Drop in sales monthwise for each year */
SELECT
    Year,
    Month,
    Net_Sales,
    LAG(Net_Sales) OVER (ORDER BY Year, Month) AS Prev_Month_Sales,
    Net_Sales - LAG(Net_Sales) OVER (ORDER BY Year, Month) AS Change,
    CASE
        WHEN Net_Sales - LAG(Net_Sales) OVER (ORDER BY Year, Month) < -30000000 THEN 'Sharp Drop'
        WHEN Net_Sales - LAG(Net_Sales) OVER (ORDER BY Year, Month) < 0 THEN 'Drop'
        ELSE 'Growth'
    END AS Trend_Flag
into Growth_and_Drop 
FROM monthly_sales_trend
ORDER BY Year, Month;

/* Holiday vs non-holiday impact */
SELECT
    IsHoliday,
    SUM(Weekly_Sales) AS Total_Sales,
    AVG(Weekly_Sales) AS Avg_Sales
FROM final_sales_data
GROUP BY IsHoliday;

/* Top 10 and bottom 10 stores */
SELECT TOP 10
    Store,
    Net_Sales,
    Crisis_Status
FROM store_crisis_flag
ORDER BY Net_Sales DESC;

SELECT TOP 10
    Store,
    Net_Sales,
    Crisis_Status
FROM store_crisis_flag
ORDER BY Net_Sales ASC;

/* Department Analysis */
SELECT
    Dept,
    SUM(Weekly_Sales) AS Net_Sales,
    SUM(CASE WHEN Sales_Type = 'Return' THEN ABS(Weekly_Sales) ELSE 0 END) AS Total_Returns
FROM final_sales_data
GROUP BY Dept
ORDER BY Net_Sales DESC;

/* Return Percentage */

SELECT
    Store,
    SUM(CASE WHEN Sales_Type='Return' THEN ABS(Weekly_Sales) ELSE 0 END) * 1.0 /
    SUM(CASE WHEN Sales_Type='Sale' THEN Weekly_Sales ELSE 0 END) AS Return_Percentage
FROM final_sales_data
GROUP BY Store;


/* Top risky stores */
SELECT TOP 5
    Store,
    Net_Sales,
    Crisis_Status
FROM store_crisis_flag
ORDER BY Net_Sales ASC;

/* Return Summary */
IF OBJECT_ID('store_return_summary', 'U') IS NOT NULL
    DROP TABLE store_return_summary;
GO

SELECT
    Store,
    SUM(CASE WHEN Sales_Type = 'Sale' THEN Weekly_Sales ELSE 0 END) AS Total_Sales,
    SUM(CASE WHEN Sales_Type = 'Return' THEN ABS(Weekly_Sales) ELSE 0 END) AS Total_Returns,
    CASE
        WHEN SUM(CASE WHEN Sales_Type = 'Sale' THEN Weekly_Sales ELSE 0 END) = 0 THEN NULL
        ELSE
            SUM(CASE WHEN Sales_Type = 'Return' THEN ABS(Weekly_Sales) ELSE 0 END) * 100.0
            / SUM(CASE WHEN Sales_Type = 'Sale' THEN Weekly_Sales ELSE 0 END)
    END AS Return_Percentage
INTO store_return_summary
FROM final_sales_data
GROUP BY Store;

SELECT TOP 10 *
FROM store_return_summary
ORDER BY Return_Percentage DESC;

