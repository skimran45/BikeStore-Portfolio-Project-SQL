-- BikeStore Data Analysis using SQL
-- Solutions of 16 business problems


-- How many staffs are active in each stores?

SELECT s2.store_name      AS StoreName,
       Count(s1.staff_id) AS StaffCount
FROM   sales.staffs s1
       JOIN sales.stores s2
         ON s1.store_id = s2.store_id
WHERE  active = 1
GROUP  BY s2.store_name 


-- Who are managers in each store?

SELECT s2.store_name                      AS StoreName,
       s1.first_name + ' ' + s1.last_name AS ManagerName
FROM   sales.staffs s1
       JOIN sales.stores s2
         ON s1.store_id = s2.store_id
WHERE  s1.staff_id IN
(SELECT DISTINCT manager_id
 FROM   sales.staffs)


-- Calculate the average bike price for each model year

SELECT p.model_year                             AS ModelYear,
       Cast(Avg(p.list_price) AS DECIMAL(6, 2)) AS AvgPrice
FROM   production.products p
GROUP  BY p.model_year  


-- Which state has the most customers and how many?

SELECT TOP 1 c.state              AS State,
             Count(c.customer_id) AS CustCount
FROM   sales.customers c
GROUP  BY c.state
ORDER  BY custcount DESC 


-- Provide the number of available products in stocks in each category

SELECT c.category_name AS CategoryName,
       Sum(s.quantity) AS Quantity
FROM   production.stocks s
       JOIN production.products p
         ON p.product_id = s.product_id
       JOIN production.categories c
         ON c.category_id = p.category_id
GROUP  BY c.category_name
ORDER  BY quantity DESC 


-- Show the total number of orders placed as per their order status
-- order_status: 1 for Payment Validated, 2 for In Progress, 3 for Prepared for Shipping, and 4 for Shipped.

SELECT CASE
         WHEN o.order_status = 1 THEN 'Payment Validated'
         WHEN o.order_status = 2 THEN 'In Progress'
         WHEN o.order_status = 3 THEN 'Prepared for Shipping'
         WHEN o.order_status = 4 THEN 'Shipped'
       END               AS OrderStatus,
       Count(o.order_id) AS OrderCount
FROM   sales.orders o
GROUP  BY o.order_status
ORDER  BY o.order_status 


-- Show the order count for each month in 2016–2018

SELECT Format(o.order_date, 'yyyy/MM') AS Months,
       Count(o.order_id)               AS OrderCount
FROM   sales.orders o
WHERE  o.order_date BETWEEN '01-Jan-2016' AND '31-Dec-2018'
GROUP  BY Format(o.order_date, 'yyyy/MM')
ORDER  BY months 


-- List products with low stock in each store
-- Criteria for a product to be low is that its quantity <=2

SELECT st.store_name  AS StoreName,
       p.product_name AS ProductName
FROM   production.stocks s
       JOIN production.products p
         ON p.product_id = s.product_id
       JOIN sales.stores st
         ON st.store_id = s.store_id
WHERE  s.quantity <= 2 


-- Which store has the most late-shipped orders?

SELECT TOP 1 s.store_name      AS StoreName,
             Count(o.store_id) AS LateOrderCount
FROM   sales.orders o
       JOIN sales.stores s
         ON s.store_id = o.store_id
WHERE  o.required_date < o.shipped_date
GROUP  BY s.store_name
ORDER  BY lateordercount ASC 


-- Calculate the total revenue generated from each product category

SELECT c.category_name                                        AS Category,
       Sum(( 1 - ot.discount ) * ot.list_price * ot.quantity) AS Revenue
FROM   sales.order_items ot
       JOIN production.products p
         ON p.product_id = ot.product_id
       JOIN production.categories c
         ON c.category_id = p.category_id
GROUP  BY c.category_name
ORDER  BY revenue 


-- Determine the average time between order placement and shipment for each city

SELECT c.city                                           AS City,
       Avg(Datediff(day, o.order_date, o.shipped_date)) AS AvgShipmentDays
FROM   sales.orders o
       JOIN sales.customers c
         ON c.customer_id = o.customer_id
WHERE  o.shipped_date IS NOT NULL --removes the orders which has not been shipped yet
GROUP  BY c.city
ORDER  BY avgshipmentdays 


-- Segment customers based on their purchase history
-- Frequent Customers are customers who generate significant revenue through large (spending > $5,000) or frequent purchases (orders > 2).
-- Infrequent Customers: Customers who contribute less revenue, making occasional (spending < $4,999) or low-priced purchases (orders < 3).

SELECT b.custcategory,
       Count(b.custid) AS CustCategoryCount
FROM   (SELECT a.custid,
               CASE
                 WHEN a.custrevenue >= 5000
                       OR a.ordercount >= 3 THEN 'Frequent Customers'
                 WHEN a.custrevenue < 5000
                       OR a.ordercount < 3 THEN 'Infrequent Customers'
               END AS CustCategory
        FROM   (SELECT o.customer_id                                          AS CustId,
                       Sum(( 1 - ot.discount ) * ot.list_price * ot.quantity) AS CustRevenue,
                       Count(o.order_id)                                      AS OrderCount
                FROM   sales.order_items ot
                       JOIN sales.orders o
                         ON o.order_id = ot.order_id
                GROUP  BY o.customer_id) a) b
GROUP  BY b.custcategory  


-- Who are the top 3 customers(name, phone, email, total spending) with highest purchases in each state?

SELECT *
FROM   (SELECT c.customer_id                          AS CustomerId,
               c.first_name + ' ' + c.last_name       CustomerName,
               c.phone                                AS Phone,
               c.email                                AS [E-Mail],
               c.state                                AS [State],
               ot2.custorderamount                    AS TotalSpending,
               Dense_rank()
                 OVER (
                   partition BY c.state
                   ORDER BY ot2.custorderamount DESC) AS RankNum
        FROM   sales.customers c
               JOIN (SELECT o.customer_id        AS CustId,
                            Sum(ot1.orderamount) AS CustOrderAmount
                     FROM   sales.orders o
                            JOIN (SELECT ot.order_id
                                         AS
                                         OrderId,
       Sum(( 1 - ot.discount ) * ot.list_price * ot.quantity)
       AS
                              OrderAmount
       FROM   sales.order_items ot
       GROUP  BY ot.order_id) ot1
       ON ot1.orderid = o.order_id
       GROUP  BY o.customer_id) ot2
       ON ot2.custid = c.customer_id) rt
WHERE  rt.ranknum <= 3


-- Rank lowest 2 products of each brands on basis of revenue generated by their products.

SELECT b.*
FROM  (SELECT a.*,
              Dense_rank()
                OVER(
                  partition BY a.brand
                  ORDER BY a.productrevenue ASC) AS Ranking
       FROM   (SELECT b.brand_name                                           AS Brand,
                      p.product_name                                         AS Product,
                      Sum(( 1 - ot.discount ) * ot.list_price * ot.quantity) AS ProductRevenue
               FROM   sales.order_items ot
                      JOIN production.products p
                        ON p.product_id = ot.product_id
                      JOIN production.brands b
                        ON b.brand_id = p.brand_id
               GROUP  BY p.product_name,
                         b.brand_name) a) b
WHERE  b.ranking <= 2  


-- Determine top 2 staffs in each store who generated the most revenue.


SELECT b.*
FROM  (SELECT st.store_name                      AS StoreName,
              a.staffid,
              s1.first_name + ' ' + s1.last_name AS StaffName,
              a.staffrevenue,
              Dense_rank()
                OVER(
                  partition BY st.store_name
                  ORDER BY a.staffrevenue DESC)  AS Ranking
       FROM   (SELECT o.staff_id                                             AS StaffId,
                      s.store_id                                             AS StoreId,
                      Sum(( 1 - ot.discount ) * ot.list_price * ot.quantity) AS StaffRevenue
               FROM   sales.order_items ot
                      JOIN sales.orders o
                        ON o.order_id = ot.order_id
                      JOIN sales.staffs s
                        ON s.staff_id = o.staff_id
               GROUP  BY o.staff_id,
                         s.store_id) a
              JOIN sales.staffs s1
                ON s1.staff_id = a.staffid
              JOIN sales.stores st
                ON st.store_id = a.storeid) b
WHERE  b.ranking <= 2 


-- Which products are sold out in one store but available in others?
-- And also provide quantity of the product in each store?


SELECT product_name AS Product,
       [1]          AS 'Santa Cruz Bikes',
       [2]          AS 'Baldwin Bikes',
       [3]          AS 'Rowlett Bikes'
FROM   (SELECT st.store_id,
               p.product_name,
               st.quantity
        FROM   production.stocks st
               JOIN production.products p
                 ON p.product_id = st.product_id) src
       PIVOT( Sum(src.quantity)
            FOR src.store_id IN ([1],
                                 [2],
                                 [3])) AS piv1
WHERE  piv1.[1] = 0
        OR piv1.[2] = 0
        OR piv1.[3] = 0
ORDER  BY piv1.product_name 

-- End of reports
