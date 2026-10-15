--SIMGE SINAV MIUUL SQL-1

--Section 1

-- 1. Overall: 830 orders, 809 shipped, 37 late; Late Shipment Rate: 4.57%.

-- 2. Yearly: 1997 had the most orders (408) and the highest delay rate (5.39%).
-- 1998 had the lowest rate (3.21%).

-- 3. Country: Ireland had the highest delay rate (15.79%).
-- The USA had the most late shipments (7).

-- 4. Order Value: The $5,000+ group had the highest delay rate (6.67%).
-- The $100–$499.99 group had the lowest rate (3.17%).

-- 5. Employee: Margaret Peacock had the most orders (420) and highest sales ($232,890.85).
-- Anne Dodsworth had the highest delay rate (7.69%), while Steven Buchanan had the lowest (0.85%).


--OVERALL

SELECT
    COUNT(*) AS TotalOrders,
    (COUNT(*)) - (COUNT(ShippedDate)) AS Null_Date ,
    COUNT(ShippedDate) AS ShippedOrders,
    SUM(CASE WHEN ShippedDate > RequiredDate THEN 1 ELSE 0 END) AS LateShipments,
    CAST(
    ROUND(100.0 * SUM(CASE WHEN ShippedDate > RequiredDate THEN 1 ELSE 0 END)
        / NULLIF(COUNT(ShippedDate), 0), 2) AS DECIMAL(5,2) ) AS LateShipmentRate
FROM Orders;

--BY YEAR
SELECT
    YEAR(OrderDate) AS OrderYear,
    COUNT(*) AS TotalOrders,
    CAST(
    ROUND(100.0 * SUM(CASE WHEN ShippedDate > RequiredDate THEN 1 ELSE 0 END)
        / NULLIF(COUNT(ShippedDate), 0), 2) AS DECIMAL(5,2) ) AS LateShipmentRate
FROM Orders
GROUP BY YEAR(OrderDate)
ORDER BY OrderYear;


--BY COUNTRY
SELECT
    ShipCountry,
    COUNT(*) AS TotalOrders,
    CAST(
    ROUND(100.0 * SUM(CASE WHEN ShippedDate > RequiredDate THEN 1 ELSE 0 END)
        / NULLIF(COUNT(ShippedDate), 0), 2) AS DECIMAL(5,2) )AS LateShipmentRate
FROM Orders
GROUP BY ShipCountry
ORDER BY LateShipmentRate DESC;


--BY ORDER VALUE
WITH O AS (
    SELECT o.OrderID, o.ShippedDate, o.RequiredDate,
           SUM(d.UnitPrice * d.Quantity * (1.0 - d.Discount)) AS Amount
    FROM Orders o
    INNER JOIN OrderDetails d ON o.OrderID = d.OrderID
    GROUP BY o.OrderID, o.ShippedDate, o.RequiredDate
)
SELECT
    CASE
        WHEN Amount < 100 THEN 'Under $100'
        WHEN Amount < 500 THEN '$100-$499.99'
        WHEN Amount < 1000 THEN '$500-$999.99'
        WHEN Amount < 2000 THEN '$1000-$1999.99'
        WHEN Amount < 5000 THEN '$2000-$4999.99'
        ELSE '$5000+'
    END AS OrderAmountGroup,
    COUNT(*) AS TotalOrders,
    ROUND(AVG(Amount),0,2) AS Avg_Amount,
    CAST(
    ROUND(100.0 * SUM(CASE WHEN ShippedDate > RequiredDate THEN 1 ELSE 0 END)
        / NULLIF(COUNT(ShippedDate), 0), 2) AS DECIMAL(5,2) ) AS LateShipmentRate
FROM O
GROUP BY CASE
        WHEN Amount < 100 THEN 'Under $100'
        WHEN Amount < 500 THEN '$100-$499.99'
        WHEN Amount < 1000 THEN '$500-$999.99'
        WHEN Amount < 2000 THEN '$1000-$1999.99'
        WHEN Amount < 5000 THEN '$2000-$4999.99'
        ELSE '$5000+'
    END
ORDER BY MIN(Amount);


--BY EMPLOYEE
WITH O AS (
    SELECT
        o.OrderID, o.EmployeeID, o.ShippedDate, o.RequiredDate,
        SUM(d.UnitPrice * d.Quantity * (1.0 - d.Discount)) AS SalesAmount
    FROM Orders o
    INNER JOIN OrderDetails d ON o.OrderID = d.OrderID
    GROUP BY o.OrderID, o.EmployeeID, o.ShippedDate, o.RequiredDate
)
SELECT
    e.FirstName + ' ' + e.LastName AS EmployeeName,
    COUNT(*) AS TotalOrders,
    ROUND(SUM(O.SalesAmount), 2) AS SalesAmount,
    ROUND(100.0 * SUM(CASE WHEN O.ShippedDate > O.RequiredDate THEN 1 ELSE 0 END)
        / NULLIF(COUNT(O.ShippedDate), 0), 2) AS LateShipmentRate
FROM O
JOIN Employees e ON O.EmployeeID = e.EmployeeID
GROUP BY e.EmployeeID, e.FirstName, e.LastName
ORDER BY TotalOrders DESC;




--Section 2 CUSTOMER AND ORDER PROFILES

--Analyze order frequency, average order value, and Late Shipment Rate for each customer.

-- Save-a-lot Markets had the most orders (31).
-- QUICK-Stop had the highest average order amount ($3,938.48).
-- Hungry Owl All-Night Grocers had the highest delay rate (15.79%).
-- Rattlesnake Canyon Grocery, Frankenversand, and Ernst Handel had a 0% delay rate.


WITH OrderSummary AS (
    SELECT
        o.OrderID,
        o.CustomerID,
        o.ShippedDate,
        o.RequiredDate,
        SUM(d.UnitPrice * d.Quantity * (1.0 - d.Discount)) AS OrderAmount
    FROM Orders o
    JOIN OrderDetails d ON o.OrderID = d.OrderID
    GROUP BY o.OrderID, o.CustomerID, o.ShippedDate, o.RequiredDate
)
SELECT
    c.CustomerID,
    c.CompanyName,
    COUNT(*) AS OrderFrequency,
    ROUND(AVG(os.OrderAmount), 2) AS AvgOrderAmount,
    CAST(
        ROUND(
            100.0 * SUM(CASE
                WHEN os.ShippedDate > os.RequiredDate THEN 1
                ELSE 0
            END) / NULLIF(COUNT(os.ShippedDate), 0),
            2
        ) AS DECIMAL(5,2)
    ) AS LateShipmentRate
FROM OrderSummary os
JOIN Customers c ON os.CustomerID = c.CustomerID
GROUP BY c.CustomerID, c.CompanyName
ORDER BY OrderFrequency DESC;


--Analyze customer countries and shipping countries together.

-- Ireland had the highest delay rate (15.79%) with 19 orders.
-- The USA had the most orders (122), with a delay rate of 5.88%.
-- All 21 country combinations had matching customer and shipping countries.

SELECT
    c.Country AS CustomerCountry,
    o.ShipCountry,
    COUNT(*) AS TotalOrders,
    ROUND(
        100.0 * SUM(CASE
            WHEN o.ShippedDate > o.RequiredDate THEN 1
            ELSE 0
        END) / NULLIF(COUNT(o.ShippedDate), 0), 2
    ) AS LateShipmentRate
FROM Customers c
JOIN Orders o
    ON c.CustomerID = o.CustomerID
GROUP BY c.Country, o.ShipCountry
ORDER BY LateShipmentRate DESC;


--Late Shipment Rate for Customers' First Orders

-- There were 89 customers with first orders.
-- 3 first orders were shipped late.
-- The Late Shipment Rate for first orders was 3.37%.

WITH OrderSummary AS (
    SELECT
        o.OrderID,
        o.CustomerID,
        o.OrderDate,
        o.ShippedDate,
        o.RequiredDate,
        ROW_NUMBER() OVER (
            PARTITION BY o.CustomerID
            ORDER BY o.OrderDate, o.OrderID
        ) AS OrderRank
    FROM Orders o
)
SELECT
    COUNT(*) AS FirstOrders,
    SUM(CASE
        WHEN ShippedDate > RequiredDate THEN 1
        ELSE 0
    END) AS LateFirstOrders,
    CAST(
        ROUND(
            100.0 * SUM(CASE
                WHEN ShippedDate > RequiredDate THEN 1
                ELSE 0
            END) / NULLIF(COUNT(ShippedDate), 0),
            2
        ) AS DECIMAL(5,2)
    ) AS LateShipmentRate
FROM OrderSummary
WHERE OrderRank = 1;




-- SECTION 3  Product and Sales Performance

-- 9. Sales Performance by Category

-- Beverages had the highest sales ($267,868.18) and quantity sold (9,532).
-- Dairy Products ranked second in sales ($234,507.29).
-- Beverages had the most orders (354).
-- Grains/Cereals had the lowest sales ($95,744.59).

SELECT
    c.CategoryName,
    ROUND(SUM(od.UnitPrice * od.Quantity * (1.0 - od.Discount)), 2) AS TotalSales,
    SUM(od.Quantity) AS QuantitySold,
    COUNT(DISTINCT o.OrderID) AS OrderCount
FROM Categories c
JOIN Products p
    ON c.CategoryID = p.CategoryID
JOIN OrderDetails od
    ON p.ProductID = od.ProductID
JOIN Orders o
    ON od.OrderID = o.OrderID
GROUP BY c.CategoryName
ORDER BY TotalSales DESC;


-- 10. Late Shipment Rate by Category

-- Grains/Cereals had the highest delay rate (6.15%).
-- Meat/Poultry ranked second, with a delay rate of 5.10%.
-- Confections had the lowest delay rate (3.15%).

WITH OrderCategory AS (
    SELECT DISTINCT
        o.OrderID,
        o.ShippedDate,
        o.RequiredDate,
        c.CategoryID,
        c.CategoryName
    FROM Orders o
    JOIN OrderDetails od
        ON o.OrderID = od.OrderID
    JOIN Products p
        ON od.ProductID = p.ProductID
    JOIN Categories c
        ON p.CategoryID = c.CategoryID
)
SELECT
    CategoryName,
    COUNT(ShippedDate) AS ShippedOrders,
    SUM(CASE
        WHEN ShippedDate > RequiredDate THEN 1
        ELSE 0
    END) AS LateOrders,
    CAST(
        ROUND(
            100.0 * SUM(CASE
                WHEN ShippedDate > RequiredDate THEN 1
                ELSE 0
            END) / NULLIF(COUNT(ShippedDate), 0),
            2
        ) AS DECIMAL(5,2)
    ) AS LateShipmentRate
FROM OrderCategory
GROUP BY CategoryID, CategoryName
ORDER BY LateShipmentRate DESC;


-- 11. Top 10 Products by Sales

-- Côte de Blaye had the highest sales ($141,396.74).
-- Thüringer Rostbratwurst ranked second ($80,368.67).
-- Raclette Courdavault had the highest quantity sold among the top 10 products (1,496 units).

SELECT TOP 10
    p.ProductID,
    p.ProductName,
    ROUND(SUM(od.UnitPrice * od.Quantity * (1.0 - od.Discount)), 2) AS TotalSales,
    SUM(od.Quantity) AS QuantitySold
FROM Products p
JOIN OrderDetails od
    ON p.ProductID = od.ProductID
GROUP BY p.ProductID, p.ProductName
ORDER BY TotalSales DESC;


-- 12. Sales Amount and Late Shipment Rate by Discount Group

-- No Discount generated the highest sales ($750,698.61).
-- The 16%-25% discount group had the second-highest sales ($188,119.67).
-- The 6%-10% discount group had the highest delay rate (5.41%).
-- The 11%-15% discount group had the lowest delay rate (2.78%).

SELECT
    CASE
        WHEN od.Discount = 0 THEN 'No Discount'
        WHEN od.Discount <= 0.05 THEN '1%-5%'
        WHEN od.Discount <= 0.10 THEN '6%-10%'
        WHEN od.Discount <= 0.15 THEN '11%-15%'
        ELSE '16%-25%'
    END AS DiscountGroup,
    ROUND(
        SUM(od.UnitPrice * od.Quantity * (1.0 - od.Discount)), 2
    ) AS TotalSales,
    COUNT(DISTINCT o.OrderID) AS OrderCount,
    COUNT(DISTINCT CASE
        WHEN o.ShippedDate > o.RequiredDate THEN o.OrderID
    END) AS LateOrders,
    CAST(
        ROUND(
            100.0 * COUNT(DISTINCT CASE
                WHEN o.ShippedDate > o.RequiredDate THEN o.OrderID
            END)
            / NULLIF(COUNT(DISTINCT CASE
                WHEN o.ShippedDate IS NOT NULL THEN o.OrderID
            END), 0),
            2
        ) AS DECIMAL(5,2)
    ) AS LateShipmentRate
FROM Orders o
JOIN OrderDetails od
    ON o.OrderID = od.OrderID
GROUP BY
    CASE
        WHEN od.Discount = 0 THEN 'No Discount'
        WHEN od.Discount <= 0.05 THEN '1%-5%'
        WHEN od.Discount <= 0.10 THEN '6%-10%'
        WHEN od.Discount <= 0.15 THEN '11%-15%'
        ELSE '16%-25%'
    END
ORDER BY TotalSales DESC;




