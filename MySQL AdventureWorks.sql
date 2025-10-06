create database AdventureWorks;
use AdventureWorks;

select * from factinternetsales;
select * from fact_internet_sales_new;
select * from dimproduct;
select * from dimproductcategory;
select * from dimproductsubcategory;
select * from dimcustomer;
select * from dimdate;
select * from dimsalesterritory;

DESCRIBE factinternetsales;
DESCRIBE fact_internet_sales_new;

-- Appending

SELECT 'factinternetsales' AS src, COUNT(*) AS `rows` FROM `factinternetsales`
UNION ALL
SELECT 'fact_internet_sales_new', COUNT(*) As `rows`FROM `fact_internet_sales_new`;

ALTER TABLE factinternetsales
CHANGE COLUMN ExtendAmount ExtendedAmount DECIMAL(18,2);

DROP TABLE IF EXISTS factinternetsalesall;
CREATE TABLE factinternetsalesall LIKE factinternetsales;

INSERT INTO factinternetsalesall
SELECT * FROM factinternetsales
UNION ALL
SELECT * FROM fact_internet_sales_new;

select * from factInternetsalesall;

-- Merging

DROP TABLE IF EXISTS dimproductall;

CREATE TABLE dimproductall AS
SELECT 
    -- From DimProduct
    dp.ProductKey,
    dp.ProductAlternateKey,
    dp.ProductSubCategoryKey,
    dp.WeightUnitMeasureCode,
    dp.SizeUnitMeasureCode,
    dp.EnglishProductName,
    dp.SpanishProductName,
    dp.FrenchProductName,
    dp.StandardCost,
    dp.FinishedGoodsFlag,
    dp.Color,
    dp.SafetyStockLevel,
    dp.ReorderPoint,
    dp.ListPrice,
    dp.Size,
    dp.SizeRange,
    dp.Weight,
    dp.DaysToManufacture,
    dp.ProductLine,
    dp.DealerPrice,
    dp.Class,
    dp.Style,
    dp.ModelName,
    dp.EnglishDescription,
    dp.FrenchDescription,
    dp.ChineseDescription,
    dp.ArabicDescription,
    dp.HebrewDescription,
    dp.ThaiDescription,
    dp.GermanDescription,
    dp.JapaneseDescription,
    dp.TurkishDescription,
    dp.StartDate,
    dp.EndDate,
    dp.Status,

    -- From DimProductSubCategory
    dpsc.ProductSubCategoryAlternateKey,
    dpsc.EnglishProductSubCategoryName,
    dpsc.SpanishProductSubCategoryName,
    dpsc.FrenchProductSubCategoryName,
    dpsc.ProductCategoryKey,

    -- From DimProductCategory
    dpc.ProductCategoryAlternateKey,
    dpc.EnglishProductCategoryName,
    dpc.SpanishProductCategoryName,
    dpc.FrenchProductCategoryName

FROM DimProduct dp
LEFT JOIN DimProductSubCategory dpsc
    ON dp.ProductSubCategoryKey = dpsc.ProductSubCategoryKey
LEFT JOIN DimProductCategory dpc
    ON dpsc.ProductCategoryKey = dpc.ProductCategoryKey;

-- Show merged data
SELECT * FROM dimproductall;

-- JOIN factinternetsalesall with dimproductall on ProductKey:

SELECT 
    s.*,
    p.EnglishProductName
FROM factinternetsalesall s
LEFT JOIN dimproductall p
    ON s.ProductKey = p.ProductKey;
    
-- 1) Lookup Customer Full Name and Unit Price to Sales sheet

SELECT 
    s.*,
    CONCAT(c.FirstName, ' ', c.LastName) AS CustomerFullName
FROM factinternetsalesall s
LEFT JOIN dimcustomer c
    ON s.CustomerKey = c.CustomerKey
LEFT JOIN dimproductall p
    ON s.ProductKey = p.ProductKey;
    
-- Calculate fields from OrderDateKey

SELECT
    s.OrderDateKey,
    STR_TO_DATE(s.OrderDateKey, '%Y%m%d') AS OrderDate,

    -- A. Year
    YEAR(STR_TO_DATE(s.OrderDateKey, '%Y%m%d')) AS Year,

    -- B. Month No
    MONTH(STR_TO_DATE(s.OrderDateKey, '%Y%m%d')) AS MonthNo,

    -- C. Month Full Name
    MONTHNAME(STR_TO_DATE(s.OrderDateKey, '%Y%m%d')) AS MonthFullName,

    -- D. Quarter
    CONCAT('Q', QUARTER(STR_TO_DATE(s.OrderDateKey, '%Y%m%d'))) AS Quarter,

    -- E. YearMonth
    DATE_FORMAT(STR_TO_DATE(s.OrderDateKey, '%Y%m%d'), '%Y-%b') AS YearMonth,

    -- F. Weekday Number
    (WEEKDAY(STR_TO_DATE(s.OrderDateKey, '%Y%m%d')) + 1) AS WeekdayNo,


    -- G. Weekday Name
    DAYNAME(STR_TO_DATE(s.OrderDateKey, '%Y%m%d')) AS WeekdayName,

    -- H. Financial Month (April = 1, May = 2, ..., March = 12)
    CASE
        WHEN MONTH(STR_TO_DATE(s.OrderDateKey, '%Y%m%d')) >= 4 
        THEN MONTH(STR_TO_DATE(s.OrderDateKey, '%Y%m%d')) - 3
        ELSE MONTH(STR_TO_DATE(s.OrderDateKey, '%Y%m%d')) + 9
    END AS FinancialMonth,

    -- I. Financial Quarter
    CASE
        WHEN MONTH(STR_TO_DATE(s.OrderDateKey, '%Y%m%d')) BETWEEN 4 AND 6 THEN 'Q1'
        WHEN MONTH(STR_TO_DATE(s.OrderDateKey, '%Y%m%d')) BETWEEN 7 AND 9 THEN 'Q2'
        WHEN MONTH(STR_TO_DATE(s.OrderDateKey, '%Y%m%d')) BETWEEN 10 AND 12 THEN 'Q3'
        ELSE 'Q4'
    END AS FinancialQuarter


FROM factinternetsalesall s;

-- 4) SalesAmount
SELECT
    SalesOrderNumber,
    ProductKey,
    (UnitPrice * OrderQuantity) - (UnitPrice * OrderQuantity * UnitPriceDiscountPct) AS SalesAmount
FROM factinternetsalesall;

-- 5) Production cost

SELECT
    SalesOrderNumber,
    ProductKey,
    (ProductStandardCost * OrderQuantity) AS ProductionCost
FROM factinternetsalesall;

-- 6) Profits

SELECT
    SalesOrderNumber,
    ProductKey,
    ROUND((UnitPrice * OrderQuantity) - DiscountAmount, 2) AS SalesAmount,
    ROUND(ProductStandardCost * OrderQuantity, 2) AS ProductionCost,
    ROUND(((UnitPrice * OrderQuantity) - DiscountAmount) - (ProductStandardCost * OrderQuantity), 2) AS Profit
FROM factinternetsalesall;

-- Chart 1: Sales and profits by years

SELECT
    YEAR(STR_TO_DATE(OrderDateKey, '%Y%m%d')) AS Year,
    ROUND(SUM(ExtendedAmount), 2) AS TotalSales,
    ROUND(SUM(ExtendedAmount - (ProductStandardCost * OrderQuantity)), 2) AS TotalProfit
FROM factinternetsalesall
GROUP BY YEAR(STR_TO_DATE(OrderDateKey, '%Y%m%d'))
ORDER BY Year;

-- Chart 2: Sales by ProductCategory

SELECT
    p.EnglishProductCategoryName AS ProductCategory,
    ROUND(SUM((s.UnitPrice * s.OrderQuantity) - s.DiscountAmount), 2) AS TotalSales
FROM factinternetsalesall s
LEFT JOIN dimproductall p
    ON s.ProductKey = p.ProductKey
GROUP BY p.EnglishProductCategoryName
ORDER BY TotalSales DESC;

-- Chart 3: Top 5 subCategory by sales

SELECT
    p.EnglishProductSubCategoryName AS ProductSubCategory,
    ROUND(SUM((s.UnitPrice * s.OrderQuantity) - s.DiscountAmount), 2) AS TotalSales
FROM factinternetsalesall s
LEFT JOIN dimproductall p
    ON s.ProductKey = p.ProductKey
GROUP BY p.EnglishProductSubCategoryName
ORDER BY TotalSales DESC
LIMIT 5;

-- Chart 4: Quarterly sales by Ranking with ProfitOverlay

SELECT
    CONCAT('Q', QUARTER(STR_TO_DATE(s.OrderDateKey, '%Y%m%d'))) AS Quarter,
    YEAR(STR_TO_DATE(s.OrderDateKey, '%Y%m%d')) AS Year,
    ROUND(SUM((s.UnitPrice * s.OrderQuantity) - s.DiscountAmount), 2) AS TotalSales,
    ROUND(SUM((s.UnitPrice * s.OrderQuantity) - s.DiscountAmount - (s.ProductStandardCost * s.OrderQuantity)), 2) AS TotalProfit,
    RANK() OVER (PARTITION BY YEAR(STR_TO_DATE(s.OrderDateKey, '%Y%m%d')) ORDER BY SUM((s.UnitPrice * s.OrderQuantity) - s.DiscountAmount) DESC) AS SalesRank
FROM factinternetsalesall s
GROUP BY Year, Quarter
ORDER BY Year, Quarter;

-- Chart 5: Top 10 customers Sales by IncomeSegment

SELECT
    c.CustomerKey,
    CONCAT(c.FirstName, ' ', c.LastName) AS CustomerName,
    CASE
        WHEN c.YearlyIncome < 50000 THEN 'Low'
        WHEN c.YearlyIncome BETWEEN 50000 AND 100000 THEN 'Medium'
        ELSE 'High'
    END AS IncomeSegment,
    ROUND(SUM((s.UnitPrice * s.OrderQuantity) - s.DiscountAmount), 2) AS TotalSales
FROM factinternetsalesall s
JOIN dimcustomer c
    ON s.CustomerKey = c.CustomerKey
GROUP BY c.CustomerKey, CustomerName, IncomeSegment
ORDER BY TotalSales DESC
LIMIT 10;

-- Chart 6: Sales by Region

SELECT
    t.SalesTerritoryRegion AS Region,
    ROUND(SUM((s.UnitPrice * s.OrderQuantity) - s.DiscountAmount), 2) AS TotalSales
FROM factinternetsalesall s
LEFT JOIN dimsalesterritory t
    ON s.SalesTerritoryKey = t.SalesTerritoryKey
GROUP BY t.SalesTerritoryRegion
ORDER BY TotalSales DESC;

-- Chart 7: Sales by Country

SELECT
    t.SalesTerritoryCountry AS Country,
    ROUND(SUM((s.UnitPrice * s.OrderQuantity) - s.DiscountAmount), 2) AS TotalSales
FROM factinternetsalesall s
LEFT JOIN dimsalesterritory t
    ON s.SalesTerritoryKey = t.SalesTerritoryKey
GROUP BY t.SalesTerritoryCountry
ORDER BY TotalSales DESC;




