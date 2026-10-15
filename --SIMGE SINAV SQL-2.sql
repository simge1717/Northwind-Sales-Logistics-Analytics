--SIMGE SINAV SQL-2

--Section 4

-- 13. Overall Shipping Performance

-- Average shipping time was 8.49 days.
-- Average freight cost was $78.24.
-- The overall Late Shipment Rate was 4.57%.

SELECT
    ROUND(AVG(CAST(DATEDIFF(DAY, OrderDate, ShippedDate) AS FLOAT)), 2) AS AvgShippingDays,
    ROUND(AVG(Freight), 2) AS AvgFreight,
    CAST(
        ROUND(
            100.0 * SUM(CASE
                WHEN ShippedDate > RequiredDate THEN 1
                ELSE 0
            END) / NULLIF(COUNT(ShippedDate), 0),
            2
        ) AS DECIMAL(5,2)
    ) AS LateShipmentRate
FROM Orders;


-- 14. Shipping Performance by Shipper

-- United Package handled the most orders (326) and had the highest average freight ($86.64).
-- United Package also had the highest Late Shipment Rate (5.08%).
-- Federal Shipping had the lowest Late Shipment Rate (3.61%).

SELECT
    s.CompanyName AS ShipperName,
    COUNT(o.OrderID) AS OrderCount,
    ROUND(AVG(o.Freight), 2) AS AvgFreight,
    CAST(
        ROUND(
            100.0 * SUM(CASE
                WHEN o.ShippedDate > o.RequiredDate THEN 1
                ELSE 0
            END) / NULLIF(COUNT(o.ShippedDate), 0),
            2
        ) AS DECIMAL(5,2)
    ) AS LateShipmentRate
FROM Shippers s
JOIN Orders o
    ON s.ShipperID = o.ShipVia
GROUP BY s.ShipperID, s.CompanyName
ORDER BY LateShipmentRate DESC;



-- 15. Late Shipment Rate by Shipping Duration


-- First I checked Shipping Duration Distribution
--Calculates Q1, Median, Q3, and P90 to understand shipping time distribution and identify percentile boundaries.

SELECT DISTINCT
    PERCENTILE_CONT(0.25) WITHIN GROUP (
        ORDER BY DATEDIFF(DAY, OrderDate, ShippedDate)
    ) OVER () AS Q1,
    PERCENTILE_CONT(0.50) WITHIN GROUP (
        ORDER BY DATEDIFF(DAY, OrderDate, ShippedDate)
    ) OVER () AS Median,
    PERCENTILE_CONT(0.75) WITHIN GROUP (
        ORDER BY DATEDIFF(DAY, OrderDate, ShippedDate)
    ) OVER () AS Q3,
    PERCENTILE_CONT(0.90) WITHIN GROUP (
        ORDER BY DATEDIFF(DAY, OrderDate, ShippedDate)
    ) OVER () AS P90
FROM Orders
WHERE ShippedDate IS NOT NULL;

--Counts shipped orders for each shipping duration to examine the actual distribution and identify meaningful shipping time groups.
SELECT
    DATEDIFF(DAY, OrderDate, ShippedDate) AS ShippingDays,
    COUNT(*) AS OrderCount
FROM Orders
WHERE ShippedDate IS NOT NULL
GROUP BY DATEDIFF(DAY, OrderDate, ShippedDate)
ORDER BY ShippingDays;




---- Shipping duration analysis shows that all late shipments took 10 or more days.
-- Orders shipped within 9 days had a 0% late shipment rate.
-- The 10+ days group had 195 shipped orders, including 37 late orders, resulting in an 18.97% late shipment rate.
-- Longer shipping durations are strongly associated with late shipments.


WITH ShippingGroups AS (
    SELECT
        CASE
            WHEN DATEDIFF(DAY, OrderDate, ShippedDate) <= 4
                THEN '1-4 days'
            WHEN DATEDIFF(DAY, OrderDate, ShippedDate) <= 7
                THEN '5-7 days'
            WHEN DATEDIFF(DAY, OrderDate, ShippedDate) <= 9
                THEN '8-9 days'
            ELSE '10+ days'
        END AS ShippingGroup,
        CASE
            WHEN ShippedDate > RequiredDate THEN 1
            ELSE 0
        END AS IsLate
    FROM Orders
    WHERE ShippedDate IS NOT NULL
)
SELECT
    ShippingGroup,
    COUNT(*) AS ShippedOrders,
    SUM(IsLate) AS LateOrders,
    ROUND(
        100.0 * SUM(IsLate) / COUNT(*),
        2
    ) AS LateShipmentRate
FROM ShippingGroups
GROUP BY ShippingGroup
ORDER BY
    CASE ShippingGroup
        WHEN '1-4 days' THEN 1
        WHEN '5-7 days' THEN 2
        WHEN '8-9 days' THEN 3
        ELSE 4
    END;


-- 16 ) Which combinations of ShipCountry and Shipper have higher Late Shipment Rates?
-- Ireland with Speedy Express and Argentina with Speedy Express had the highest Late Shipment Rate at 25%.
-- Ireland also showed a high rate with Federal Shipping (16.67%).
-- These results are based on relatively small numbers of orders, so the percentages should be interpreted cautiously.
-- Further analysis is needed to determine whether these patterns are consistent or caused by small sample sizes.

 SELECT
    o.ShipCountry,
    s.CompanyName AS Shipper,
    COUNT(*) AS ShippedOrders,
    SUM(CASE
        WHEN o.ShippedDate > o.RequiredDate THEN 1
        ELSE 0
    END) AS LateOrders,
    ROUND(
        100.0 * SUM(CASE
            WHEN o.ShippedDate > o.RequiredDate THEN 1
            ELSE 0
        END) / COUNT(*),
        2
    ) AS LateShipmentRate
FROM Orders o
INNER JOIN Shippers s
    ON o.ShipVia = s.ShipperID
WHERE o.ShippedDate IS NOT NULL
GROUP BY
    o.ShipCountry,
    s.CompanyName
ORDER BY LateShipmentRate DESC;


--Session 5
--Analyze the Late Shipment Rate for high-value orders


--High-value orders ($5,000+) had a higher late shipment rate (6.67%) than orders under $5,000 (4.49%).
-- This suggests that high-value orders may require closer shipment monitoring.

SELECT
    CASE
        WHEN OrderAmount >= 5000 THEN 'High-Value Orders ($5,000+)'
        ELSE 'Other Orders (Under $5,000)'
    END AS OrderValueGroup,
    COUNT(*) AS ShippedOrders,
    SUM(CASE
        WHEN ShippedDate > RequiredDate THEN 1
        ELSE 0
    END) AS LateOrders,
    ROUND(
        100.0 * SUM(CASE
            WHEN ShippedDate > RequiredDate THEN 1
            ELSE 0
        END) / COUNT(*),
        2
    ) AS LateShipmentRate
FROM (
    SELECT
        o.OrderID,
        o.ShippedDate,
        o.RequiredDate,
        SUM(od.UnitPrice * od.Quantity * (1 - od.Discount)) AS OrderAmount
    FROM Orders o
    INNER JOIN OrderDetails od
        ON o.OrderID = od.OrderID
    WHERE o.ShippedDate IS NOT NULL
    GROUP BY
        o.OrderID,
        o.ShippedDate,
        o.RequiredDate
) AS OrderSummary
GROUP BY
    CASE
        WHEN OrderAmount >= 5000 THEN 'High-Value Orders ($5,000+)'
        ELSE 'Other Orders (Under $5,000)'
    END
ORDER BY LateShipmentRate DESC;


--Analyze orders where high freight costs and long shipping durations occur together.


--The 18-day threshold is based on the 90th percentile of shipping duration.
--The $100 freight threshold was initially selected arbitrarily and should be adjusted based on the actual Freight distribution.


--Fourteen orders had both high freight costs and long shipping durations. 
--Order 10709 had the longest shipping duration (34 days), while Order 10540 had the highest freight cost ($1,007.64). 
--These orders should be reviewed for potential logistics inefficiencies.

WITH OrderShipping AS (
    SELECT
        OrderID,
        OrderDate,
        ShippedDate,
        Freight,
        DATEDIFF(DAY, OrderDate, ShippedDate) AS ShippingDays,
        PERCENTILE_CONT(0.90)
            WITHIN GROUP (ORDER BY Freight) OVER () AS FreightP90
    FROM dbo.Orders
    WHERE ShippedDate IS NOT NULL
)
SELECT
    OrderID,
    OrderDate,
    ShippedDate,
    Freight,
    ShippingDays
FROM OrderShipping
WHERE Freight >= FreightP90
  AND ShippingDays >= 18
ORDER BY Freight DESC, ShippingDays DESC;


--19. Find the top 10 Employee × Shipper combinations with the highest Late Shipment Rate, 
--including only combinations with at least 5 shipped orders.

--Anne Dodsworth and Speedy Express had the highest late shipment rate at 20%, with 2 late shipments out of 10 orders. 
--Robert King and United Package followed at 17.39%. These combinations should be reviewed to identify potential causes of shipment delays.

WITH EmployeeShipperStats AS (
    SELECT
        e.EmployeeID,
        e.FirstName + ' ' + e.LastName AS EmployeeName,
        s.CompanyName AS ShipperName,
        COUNT(*) AS ShippedOrders,
        SUM(CASE
            WHEN o.ShippedDate > o.RequiredDate THEN 1
            ELSE 0
        END) AS LateOrders,
        ROUND(
            100.0 * SUM(CASE
                WHEN o.ShippedDate > o.RequiredDate THEN 1
                ELSE 0
            END) / COUNT(*),
            2
        ) AS LateShipmentRate
    FROM Orders o
    INNER JOIN Employees e
        ON o.EmployeeID = e.EmployeeID
    INNER JOIN dbo.Shippers s
        ON o.ShipVia = s.ShipperID
    WHERE o.ShippedDate IS NOT NULL
    GROUP BY
        e.EmployeeID,
        e.FirstName,
        e.LastName,
        s.CompanyName
    HAVING COUNT(*) >= 5
)
SELECT TOP 10
    EmployeeName,
    ShipperName,
    ShippedOrders,
    LateOrders,
    LateShipmentRate
FROM EmployeeShipperStats
ORDER BY
    LateShipmentRate DESC,
    ShippedOrders DESC;


--Session 6

--20. Calculate the LiftScore for order value groups: Group Late Shipment Rate / Overall Late Shipment Rate.

--High-value orders ($5,000 and above) had the highest Late Shipment Rate at 6.67%, with a LiftScore of 1.46. 
--This means their late shipment rate was 46% higher than the overall rate. 
--Orders between $100 and $499.99 had the lowest rate at 3.17%. High-value orders may require closer shipment monitoring.


WITH O AS (
    SELECT
        o.OrderID,
        o.ShippedDate,
        o.RequiredDate,
        SUM(d.UnitPrice * d.Quantity * (1 - d.Discount)) AS Amount
    FROM dbo.Orders o
    JOIN OrderDetails d
        ON o.OrderID = d.OrderID
    WHERE o.ShippedDate IS NOT NULL
    GROUP BY
        o.OrderID,
        o.ShippedDate,
        o.RequiredDate
),
G AS (
    SELECT
        CASE
            WHEN Amount < 100 THEN 'Under $100'
            WHEN Amount < 500 THEN '$100-$499.99'
            WHEN Amount < 1000 THEN '$500-$999.99'
            WHEN Amount < 2000 THEN '$1000-$1999.99'
            WHEN Amount < 5000 THEN '$2000-$4999.99'
            ELSE '$5000+'
        END AS OrderValueGroup,
        CASE
            WHEN ShippedDate > RequiredDate THEN 1.0
            ELSE 0
        END AS Late
    FROM O
)
SELECT
    OrderValueGroup,
    COUNT(*) AS ShippedOrders,
    SUM(Late) AS LateOrders,
    ROUND(100.0 * SUM(Late) / COUNT(*), 2) AS LateShipmentRate,
    ROUND(
        (1.0 * SUM(Late) / COUNT(*)) /
        NULLIF((SELECT AVG(Late) FROM G), 0),
        2
    ) AS LiftScore
FROM G
GROUP BY OrderValueGroup
ORDER BY LiftScore DESC;

--Calculate the difference between each shipper's Late Shipment Rate and the overall Late Shipment Rate.

--United Package had the highest Late Shipment Rate at 5.08%, which was 0.51 percentage points above the overall rate. 
--Speedy Express was also slightly above the overall rate at 4.90%. 
--Federal Shipping had the lowest rate at 3.61%, which was 0.96 percentage points below the overall rate.

WITH ShipperStats AS (
    SELECT
        s.CompanyName AS ShipperName,
        COUNT(*) AS ShippedOrders,
        SUM(CASE
            WHEN o.ShippedDate > o.RequiredDate THEN 1
            ELSE 0
        END) AS LateOrders
    FROM Orders o
    JOIN Shippers s
        ON o.ShipVia = s.ShipperID
    WHERE o.ShippedDate IS NOT NULL
    GROUP BY s.CompanyName
)
SELECT
    ShipperName,
    ShippedOrders,
    LateOrders,
    ROUND(100.0 * LateOrders / ShippedOrders, 2) AS LateShipmentRate,
    ROUND(
        100.0 * LateOrders / ShippedOrders
        - (SELECT 100.0 * SUM(
            CASE WHEN ShippedDate > RequiredDate THEN 1 ELSE 0 END
          ) / COUNT(*)
           FROM dbo.Orders
           WHERE ShippedDate IS NOT NULL),
        2
    ) AS DifferenceFromOverall
FROM ShipperStats
ORDER BY DifferenceFromOverall DESC;

--Analyze Late Shipment Rate by ShipCountry × Shipper × OrderValueSegment.


--The analysis identified several country, shipper, and order value combinations with high Late Shipment Rates. 
--Four combinations had a 100% rate, but each included only one shipped order. 
--The USA–Speedy Express combination for orders between $1,000 and $1,999.99 had a 33.33% rate, with 2 late shipments out of 6 orders. 
--These results should be interpreted cautiously because many combinations have small sample sizes.
--Further analysis with more orders may help identify consistent shipment issues.

WITH O AS (
    SELECT
        o.OrderID,
        o.ShipCountry,
        s.CompanyName AS ShipperName,
        o.ShippedDate,
        o.RequiredDate,
        SUM(d.UnitPrice * d.Quantity * (1 - d.Discount)) AS Amount
    FROM dbo.Orders o
    JOIN OrderDetails d
        ON o.OrderID = d.OrderID
    JOIN Shippers s
        ON o.ShipVia = s.ShipperID
    WHERE o.ShippedDate IS NOT NULL
    GROUP BY
        o.OrderID,
        o.ShipCountry,
        s.CompanyName,
        o.ShippedDate,
        o.RequiredDate
),
G AS (
    SELECT
        ShipCountry,
        ShipperName,
        CASE
            WHEN Amount < 100 THEN 'Under $100'
            WHEN Amount < 500 THEN '$100-$499.99'
            WHEN Amount < 1000 THEN '$500-$999.99'
            WHEN Amount < 2000 THEN '$1000-$1999.99'
            WHEN Amount < 5000 THEN '$2000-$4999.99'
            ELSE '$5000+'
        END AS OrderValueSegment,
        CASE
            WHEN ShippedDate > RequiredDate THEN 1
            ELSE 0
        END AS Late
    FROM O
)
SELECT
    ShipCountry,
    ShipperName,
    OrderValueSegment,
    COUNT(*) AS ShippedOrders,
    SUM(Late) AS LateOrders,
    ROUND(100.0 * SUM(Late) / COUNT(*), 2) AS LateShipmentRate
FROM G
GROUP BY
    ShipCountry,
    ShipperName,
    OrderValueSegment
ORDER BY
    LateShipmentRate DESC,
    ShippedOrders DESC;


--Rank orders using a rule-based OperationalRiskScore based on features that are knowable before shipment.




WITH O AS (
    SELECT
        o.OrderID,
        o.OrderDate,
        o.ShipCountry,
        s.CompanyName AS ShipperName,
        o.Freight,
        SUM(
            d.UnitPrice * d.Quantity * (1 - d.Discount)
        ) AS Amount
    FROM Orders o
    JOIN OrderDetails d
        ON o.OrderID = d.OrderID
    JOIN Shippers s
        ON o.ShipVia = s.ShipperID
    GROUP BY
        o.OrderID,
        o.OrderDate,
        o.ShipCountry,
        s.CompanyName,
        o.Freight
),
R AS (
    SELECT *,
        CASE
            WHEN Amount < 100 THEN 4
            WHEN Amount < 500 THEN 0
            WHEN Amount < 1000 THEN 3
            WHEN Amount < 2000 THEN 2
            WHEN Amount < 5000 THEN 1
            ELSE 5
        END AS AmountRisk,

        CASE
            WHEN ShipperName = 'Federal Shipping' THEN 0
            WHEN ShipperName = 'Speedy Express' THEN 1
            WHEN ShipperName = 'United Package' THEN 2
            ELSE 0
        END AS ShipperRisk
    FROM O
)
SELECT
    OrderID,
    OrderDate,
    ShipCountry,
    ShipperName,
    Freight,
    Amount AS OrderAmount,
    AmountRisk,
    ShipperRisk,
    AmountRisk + ShipperRisk AS OperationalRiskScore
FROM R
ORDER BY
    OperationalRiskScore DESC,
    Amount DESC;




--Measure the actual Late Shipment Rate for each OperationalRiskScore level.


WITH O AS (
    SELECT
        o.OrderID,
        o.ShippedDate,
        o.RequiredDate,
        o.Freight,
        s.CompanyName AS ShipperName,
        SUM(d.UnitPrice * d.Quantity * (1 - d.Discount)) AS Amount
    FROM Orders o
    JOIN OrderDetails d
        ON o.OrderID = d.OrderID
    JOIN Shippers s
        ON o.ShipVia = s.ShipperID
    GROUP BY
        o.OrderID,
        o.ShippedDate,
        o.RequiredDate,
        o.Freight,
        s.CompanyName
),
R AS (
    SELECT *,
        CASE
            WHEN Amount < 100 THEN 4
            WHEN Amount < 500 THEN 0
            WHEN Amount < 1000 THEN 3
            WHEN Amount < 2000 THEN 2
            WHEN Amount < 5000 THEN 1
            ELSE 5
        END AS AmountRisk,
        CASE
            WHEN ShipperName = 'Federal Shipping' THEN 0
            WHEN ShipperName = 'Speedy Express' THEN 1
            WHEN ShipperName = 'United Package' THEN 2
            ELSE 0
        END AS ShipperRisk
    FROM O
),
S AS (
    SELECT *,
        AmountRisk + ShipperRisk AS OperationalRiskScore
    FROM R
    WHERE ShippedDate IS NOT NULL
),
RiskSummary AS (
    SELECT
        OperationalRiskScore,
        COUNT(*) AS ShippedOrders,
        SUM(
            CASE
                WHEN ShippedDate > RequiredDate THEN 1
                ELSE 0
            END
        ) AS LateOrders,
        ROUND(
            100.0 * SUM(
                CASE
                    WHEN ShippedDate > RequiredDate THEN 1
                    ELSE 0
                END
            ) / COUNT(*),
            2
        ) AS LateShipmentRate
    FROM S
    GROUP BY OperationalRiskScore
)
SELECT
    OperationalRiskScore,
    CASE
        WHEN LateOrders >= 9 THEN 'High Risk'
        WHEN LateOrders >=4 THEN 'Moderate Risk'
        ELSE 'Low Risk'
    END AS RiskGroup,
    ShippedOrders,
    LateOrders,
    LateShipmentRate
FROM RiskSummary
ORDER BY OperationalRiskScore DESC;

--Although some risk groups show higher late shipment rates, the number of late orders is relatively low, 
--which can make these rates appear higher than expected. 
--Therefore, the risk classification focuses on order amounts and the number of late shipments to identify areas that may need operational attention. 
--This approach helps prioritize groups for further review and supports more informed shipping decisions.