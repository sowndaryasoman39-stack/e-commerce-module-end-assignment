-- =====================================================================
-- Module End Assignment 2: MySQL - E-Commerce Customer Churn Analysis
-- =====================================================================
-- ASSUMPTIONS (change if your setup differs):
--   * Database name : ecomm
--   * Table name    : customer_churn  (the imported CSV dataset)
--   * Columns as in the dataset: CustomerID, Churn, Tenure, PreferredLoginDevice,
--     CityTier, WarehouseToHome, PreferredPaymentMode, Gender, HourSpendOnApp,
--     NumberOfDeviceRegistered, PreferedOrderCat, SatisfactionScore, MaritalStatus,
--     NumberOfAddress, Complain, OrderAmountHikeFromlastYear, CouponUsed,
--     OrderCount, DaySinceLastOrder, CashbackAmount
--   * MySQL 8.0+ (uses RENAME COLUMN)
--   * Blank cells in the CSV were imported as NULL. If your import stored them
--     as 0 or '' instead, adjust the "IS NULL" conditions in Part 1.
-- =====================================================================

CREATE DATABASE IF NOT EXISTS ecomm;
USE ecomm;

-- Allow UPDATE/DELETE without a key in the WHERE clause (needed in Workbench)
SET SQL_SAFE_UPDATES = 0;


-- =====================================================================
-- PART 1: DATA CLEANING (5 marks)
-- =====================================================================

-- ---------------------------------------------------------------------
-- 1.1 Handling missing values: impute MEAN (rounded to nearest integer)
--     for WarehouseToHome, HourSpendOnApp, OrderAmountHikeFromlastYear,
--     DaySinceLastOrder
--     (the mean is stored in a variable first, because MySQL does not allow
--      UPDATE with a subquery on the same table - error 1093)
-- ---------------------------------------------------------------------
SET @mean_warehouse = (SELECT ROUND(AVG(WarehouseToHome))             FROM customer_churn);
SET @mean_hours     = (SELECT ROUND(AVG(HourSpendOnApp))              FROM customer_churn);
SET @mean_hike      = (SELECT ROUND(AVG(OrderAmountHikeFromlastYear)) FROM customer_churn);
SET @mean_days      = (SELECT ROUND(AVG(DaySinceLastOrder))           FROM customer_churn);

UPDATE customer_churn SET WarehouseToHome            = @mean_warehouse WHERE WarehouseToHome            IS NULL;
UPDATE customer_churn SET HourSpendOnApp             = @mean_hours     WHERE HourSpendOnApp             IS NULL;
UPDATE customer_churn SET OrderAmountHikeFromlastYear = @mean_hike     WHERE OrderAmountHikeFromlastYear IS NULL;
UPDATE customer_churn SET DaySinceLastOrder          = @mean_days      WHERE DaySinceLastOrder          IS NULL;

-- ---------------------------------------------------------------------
-- 1.2 Impute MODE for Tenure, CouponUsed, OrderCount
-- ---------------------------------------------------------------------
SET @mode_tenure = (SELECT Tenure FROM customer_churn
                    WHERE Tenure IS NOT NULL
                    GROUP BY Tenure ORDER BY COUNT(*) DESC LIMIT 1);
SET @mode_coupon = (SELECT CouponUsed FROM customer_churn
                    WHERE CouponUsed IS NOT NULL
                    GROUP BY CouponUsed ORDER BY COUNT(*) DESC LIMIT 1);
SET @mode_order  = (SELECT OrderCount FROM customer_churn
                    WHERE OrderCount IS NOT NULL
                    GROUP BY OrderCount ORDER BY COUNT(*) DESC LIMIT 1);

UPDATE customer_churn SET Tenure     = @mode_tenure WHERE Tenure     IS NULL;
UPDATE customer_churn SET CouponUsed = @mode_coupon WHERE CouponUsed IS NULL;
UPDATE customer_churn SET OrderCount = @mode_order  WHERE OrderCount IS NULL;

-- ---------------------------------------------------------------------
-- 1.3 Handle outliers: delete rows where WarehouseToHome > 100
-- ---------------------------------------------------------------------
DELETE FROM customer_churn WHERE WarehouseToHome > 100;

-- ---------------------------------------------------------------------
-- 1.4 Dealing with inconsistencies
-- ---------------------------------------------------------------------
UPDATE customer_churn SET PreferredLoginDevice = 'Mobile Phone' WHERE PreferredLoginDevice = 'Phone';
UPDATE customer_churn SET PreferedOrderCat     = 'Mobile Phone' WHERE PreferedOrderCat     = 'Mobile';

UPDATE customer_churn SET PreferredPaymentMode = 'Cash on Delivery' WHERE PreferredPaymentMode = 'COD';
UPDATE customer_churn SET PreferredPaymentMode = 'Credit Card'      WHERE PreferredPaymentMode = 'CC';


-- =====================================================================
-- PART 2: DATA TRANSFORMATION (3 marks)
-- =====================================================================

-- 2.1 Column renaming
ALTER TABLE customer_churn RENAME COLUMN PreferedOrderCat TO PreferredOrderCat;
ALTER TABLE customer_churn RENAME COLUMN HourSpendOnApp   TO HoursSpentOnApp;

-- 2.2 Creating new columns
ALTER TABLE customer_churn ADD COLUMN ComplaintReceived VARCHAR(3);
UPDATE customer_churn
SET ComplaintReceived = CASE WHEN Complain = 1 THEN 'Yes' ELSE 'No' END;

ALTER TABLE customer_churn ADD COLUMN ChurnStatus VARCHAR(10);
UPDATE customer_churn
SET ChurnStatus = CASE WHEN Churn = 1 THEN 'Churned' ELSE 'Active' END;

-- 2.3 Column dropping
ALTER TABLE customer_churn DROP COLUMN Churn;
ALTER TABLE customer_churn DROP COLUMN Complain;

-- Quick check of the cleaned table
-- SELECT * FROM customer_churn LIMIT 10;


-- =====================================================================
-- PART 3: DATA EXPLORATION AND ANALYSIS (17 marks)
-- =====================================================================

-- Q1. Count of churned and active customers
SELECT ChurnStatus, COUNT(*) AS CustomerCount
FROM customer_churn
GROUP BY ChurnStatus;

-- Q2. Average tenure and total cashback amount of customers who churned
SELECT ROUND(AVG(Tenure), 2)  AS AvgTenure,
       SUM(CashbackAmount)    AS TotalCashbackAmount
FROM customer_churn
WHERE ChurnStatus = 'Churned';

-- Q3. Percentage of churned customers who complained
SELECT ROUND(SUM(ComplaintReceived = 'Yes') * 100.0 / COUNT(*), 2) AS PercentChurnedWhoComplained
FROM customer_churn
WHERE ChurnStatus = 'Churned';

-- Q4. City tier with the highest number of churned customers whose
--     preferred order category is Laptop & Accessory
SELECT CityTier, COUNT(*) AS ChurnedCustomers
FROM customer_churn
WHERE ChurnStatus = 'Churned'
  AND PreferredOrderCat = 'Laptop & Accessory'
GROUP BY CityTier
ORDER BY ChurnedCustomers DESC
LIMIT 1;

-- Q5. Most preferred payment mode among active customers
SELECT PreferredPaymentMode, COUNT(*) AS CustomerCount
FROM customer_churn
WHERE ChurnStatus = 'Active'
GROUP BY PreferredPaymentMode
ORDER BY CustomerCount DESC
LIMIT 1;

-- Q6. Total order amount hike from last year for customers who are single
--     and prefer mobile phones for ordering
SELECT SUM(OrderAmountHikeFromlastYear) AS TotalOrderAmountHike
FROM customer_churn
WHERE MaritalStatus = 'Single'
  AND PreferredOrderCat = 'Mobile Phone';

-- Q7. Average number of devices registered among customers who used UPI
SELECT ROUND(AVG(NumberOfDeviceRegistered), 2) AS AvgDevicesRegistered
FROM customer_churn
WHERE PreferredPaymentMode = 'UPI';

-- Q8. City tier with the highest number of customers
SELECT CityTier, COUNT(*) AS CustomerCount
FROM customer_churn
GROUP BY CityTier
ORDER BY CustomerCount DESC
LIMIT 1;

-- Q9. Gender that utilized the highest number of coupons
SELECT Gender, SUM(CouponUsed) AS TotalCouponsUsed
FROM customer_churn
GROUP BY Gender
ORDER BY TotalCouponsUsed DESC
LIMIT 1;

-- Q10. Number of customers and maximum hours spent on the app in each
--      preferred order category
SELECT PreferredOrderCat,
       COUNT(*)             AS CustomerCount,
       MAX(HoursSpentOnApp) AS MaxHoursSpentOnApp
FROM customer_churn
GROUP BY PreferredOrderCat;

-- Q11. Total order count for customers who prefer credit cards and have
--      the maximum satisfaction score
SELECT SUM(OrderCount) AS TotalOrderCount
FROM customer_churn
WHERE PreferredPaymentMode = 'Credit Card'
  AND SatisfactionScore = (SELECT MAX(SatisfactionScore) FROM customer_churn);

-- Q12. Average satisfaction score of customers who have complained
SELECT ROUND(AVG(SatisfactionScore), 2) AS AvgSatisfactionScore
FROM customer_churn
WHERE ComplaintReceived = 'Yes';

-- Q13. Preferred order category among customers who used more than 5 coupons
SELECT PreferredOrderCat, COUNT(*) AS CustomerCount
FROM customer_churn
WHERE CouponUsed > 5
GROUP BY PreferredOrderCat
ORDER BY CustomerCount DESC;

-- Q14. Top 3 preferred order categories with the highest average cashback amount
SELECT PreferredOrderCat, ROUND(AVG(CashbackAmount), 2) AS AvgCashbackAmount
FROM customer_churn
GROUP BY PreferredOrderCat
ORDER BY AvgCashbackAmount DESC
LIMIT 3;

-- Q15. Preferred payment modes of customers whose average tenure is 10 months
--      and who have placed more than 500 orders
SELECT PreferredPaymentMode
FROM customer_churn
GROUP BY PreferredPaymentMode
HAVING AVG(Tenure) = 10
   AND SUM(OrderCount) > 500;
-- NOTE: an average is rarely exactly 10, so this can return no rows. If so,
-- replace the HAVING line with:  HAVING ROUND(AVG(Tenure)) = 10

-- Q16. Categorize customers by distance from warehouse to home and show the
--      churn status breakdown for each distance category
SELECT CASE
           WHEN WarehouseToHome <= 5  THEN 'Very Close Distance'
           WHEN WarehouseToHome <= 10 THEN 'Close Distance'
           WHEN WarehouseToHome <= 15 THEN 'Moderate Distance'
           ELSE 'Far Distance'
       END AS DistanceCategory,
       ChurnStatus,
       COUNT(*) AS CustomerCount
FROM customer_churn
GROUP BY DistanceCategory, ChurnStatus
ORDER BY FIELD(DistanceCategory, 'Very Close Distance', 'Close Distance',
               'Moderate Distance', 'Far Distance'),
         ChurnStatus;

-- Q17. Order details of customers who are married, live in City Tier-1, and
--      whose order count is more than the average order count of all customers
SELECT *
FROM customer_churn
WHERE MaritalStatus = 'Married'
  AND CityTier = 1
  AND OrderCount > (SELECT AVG(OrderCount) FROM customer_churn);


-- =====================================================================
-- PART 4: customer_returns TABLE
-- =====================================================================

-- a) Create the table and insert the data
CREATE TABLE customer_returns (
    ReturnID     INT PRIMARY KEY,
    CustomerID   INT,
    ReturnDate   DATE,
    RefundAmount INT
);

INSERT INTO customer_returns (ReturnID, CustomerID, ReturnDate, RefundAmount) VALUES
(1001, 50022, '2023-01-01', 2130),
(1002, 50316, '2023-01-23', 2000),
(1003, 51099, '2023-02-14', 2290),
(1004, 52321, '2023-03-08', 2510),
(1005, 52928, '2023-03-20', 3000),
(1006, 53749, '2023-04-17', 1740),
(1007, 54206, '2023-04-21', 3250),
(1008, 54838, '2023-04-30', 1990);

-- b) Return details along with customer details of customers who have
--    churned and have made complaints
SELECT r.ReturnID, r.ReturnDate, r.RefundAmount, c.*
FROM customer_returns AS r
INNER JOIN customer_churn AS c
        ON r.CustomerID = c.CustomerID
WHERE c.ChurnStatus = 'Churned'
  AND c.ComplaintReceived = 'Yes';
