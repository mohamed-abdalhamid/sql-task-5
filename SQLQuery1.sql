use StoreDB

go

SELECT product_name, list_price,
  CASE 
    WHEN list_price < 300 THEN 'Economy'
    WHEN list_price BETWEEN 300 AND 999 THEN 'Standard'
    WHEN list_price BETWEEN 1000 AND 2499 THEN 'Premium'
    ELSE 'Luxury'
  END AS price_category
FROM production.products;


go


SELECT order_id, order_date,
  CASE order_status
    WHEN 1 THEN 'Order Received'
    WHEN 2 THEN 'In Preparation'
    WHEN 3 THEN 'Order Cancelled'
    WHEN 4 THEN 'Order Delivered'
  END AS status,
  CASE 
    WHEN order_status = 1 AND DATEDIFF(DAY, order_date, GETDATE()) > 5 THEN 'URGENT'
    WHEN order_status = 2 AND DATEDIFF(DAY, order_date, GETDATE()) > 3 THEN 'HIGH'
    ELSE 'NORMAL'
  END AS priority
FROM sales.orders;


go


SELECT s.staff_id, s.first_name + ' ' + s.last_name AS staff_name,
  COUNT(o.order_id) AS order_count,
  CASE 
    WHEN COUNT(o.order_id) = 0 THEN 'New Staff'
    WHEN COUNT(o.order_id) BETWEEN 1 AND 10 THEN 'Junior Staff'
    WHEN COUNT(o.order_id) BETWEEN 11 AND 25 THEN 'Senior Staff'
    ELSE 'Expert Staff'
  END AS staff_level
FROM sales.staffs s
LEFT JOIN sales.orders o ON s.staff_id = o.staff_id
GROUP BY s.staff_id, s.first_name, s.last_name;


go


SELECT *, 
  ISNULL(phone, 'Phone Not Available') AS safe_phone,
  COALESCE(phone, email, 'No Contact Method') AS preferred_contact
FROM sales.customers;


go


SELECT p.product_name, s.store_id, stk.quantity,
  ISNULL(CAST(list_price / NULLIF(stk.quantity, 0) AS DECIMAL(10,2)), 0) AS price_per_unit,
  CASE 
    WHEN stk.quantity IS NULL OR stk.quantity = 0 THEN 'Out of Stock'
    ELSE 'In Stock'
  END AS stock_status
FROM production.products p
JOIN production.stocks stk ON p.product_id = stk.product_id
JOIN sales.stores s ON s.store_id = stk.store_id
WHERE stk.store_id = 1;


go


SELECT customer_id,
  COALESCE(street, '') + ', ' + COALESCE(city, '') + ', ' +
  COALESCE(state, '') + ' ' + COALESCE(zip_code, 'N/A') AS formatted_address
FROM sales.customers;


go


WITH CustomerSpending AS (
  SELECT o.customer_id, SUM(oi.quantity * oi.list_price * (1 - oi.discount)) AS total_spent
  FROM sales.orders o
  JOIN sales.order_items oi ON o.order_id = oi.order_id
  GROUP BY o.customer_id
)
SELECT c.customer_id, c.first_name, c.last_name, cs.total_spent
FROM CustomerSpending cs
JOIN sales.customers c ON c.customer_id = cs.customer_id
WHERE cs.total_spent > 1500
ORDER BY cs.total_spent DESC;


go


WITH CategoryRevenue AS (
  SELECT c.category_id, c.category_name, SUM(oi.quantity * oi.list_price) AS total_revenue
  FROM production.categories c
  JOIN production.products p ON c.category_id = p.category_id
  JOIN sales.order_items oi ON p.product_id = oi.product_id
  GROUP BY c.category_id, c.category_name
),
CategoryAOV AS (
  SELECT c.category_id, AVG(oi.list_price * quantity) AS avg_order_value
  FROM production.categories c
  JOIN production.products p ON c.category_id = p.category_id
  JOIN sales.order_items oi ON p.product_id = oi.product_id
  GROUP BY c.category_id
)
SELECT cr.category_name, cr.total_revenue, ca.avg_order_value,
  CASE 
    WHEN cr.total_revenue > 50000 THEN 'Excellent'
    WHEN cr.total_revenue > 20000 THEN 'Good'
    ELSE 'Needs Improvement'
  END AS performance
FROM CategoryRevenue cr
JOIN CategoryAOV ca ON cr.category_id = ca.category_id;


go


WITH MonthlySales AS (
  SELECT FORMAT(order_date, 'yyyy-MM') AS month, SUM(oi.quantity * oi.list_price) AS revenue
  FROM sales.orders o
  JOIN sales.order_items oi ON o.order_id = oi.order_id
  GROUP BY FORMAT(order_date, 'yyyy-MM')
),
MonthGrowth AS (
  SELECT month, revenue,
         LAG(revenue) OVER (ORDER BY month) AS prev_revenue
  FROM MonthlySales
)
SELECT *, 
  ROUND(100.0 * (revenue - prev_revenue) / NULLIF(prev_revenue, 0), 2) AS growth_percent
FROM MonthGrowth;


go


SELECT * FROM (
  SELECT 
    c.category_name,
    p.product_name,
    p.list_price,
    ROW_NUMBER() OVER (PARTITION BY c.category_id ORDER BY p.list_price DESC) AS row_num,
    RANK() OVER (PARTITION BY c.category_id ORDER BY p.list_price DESC) AS rank,
    DENSE_RANK() OVER (PARTITION BY c.category_id ORDER BY p.list_price DESC) AS dense_rank
  FROM production.products p
  JOIN production.categories c ON p.category_id = c.category_id
) AS ranked
WHERE row_num <= 3;


go


WITH CustomerSpend AS (
  SELECT o.customer_id, SUM(oi.quantity * oi.list_price * (1 - oi.discount)) AS total_spent
  FROM sales.orders o
  JOIN sales.order_items oi ON o.order_id = oi.order_id
  GROUP BY o.customer_id
)
SELECT c.customer_id, c.first_name, total_spent,
  RANK() OVER (ORDER BY total_spent DESC) AS spending_rank,
  NTILE(5) OVER (ORDER BY total_spent DESC) AS spending_group,
  CASE 
    WHEN NTILE(5) OVER (ORDER BY total_spent DESC) = 1 THEN 'VIP'
    WHEN NTILE(5) OVER (ORDER BY total_spent DESC) = 2 THEN 'Gold'
    WHEN NTILE(5) OVER (ORDER BY total_spent DESC) = 3 THEN 'Silver'
    WHEN NTILE(5) OVER (ORDER BY total_spent DESC) = 4 THEN 'Bronze'
    ELSE 'Standard'
  END AS tier
FROM CustomerSpend cs
JOIN sales.customers c ON c.customer_id = cs.customer_id;


go


WITH StorePerf AS (
  SELECT s.store_id, s.store_name, 
         COUNT(DISTINCT o.order_id) AS total_orders,
         SUM(oi.quantity * oi.list_price) AS total_revenue
  FROM sales.stores s
  JOIN sales.orders o ON s.store_id = o.store_id
  JOIN sales.order_items oi ON o.order_id = oi.order_id
  GROUP BY s.store_id, s.store_name
)
SELECT *, 
  RANK() OVER (ORDER BY total_revenue DESC) AS revenue_rank,
  RANK() OVER (ORDER BY total_orders DESC) AS order_rank,
  PERCENT_RANK() OVER (ORDER BY total_revenue) AS revenue_percentile
FROM StorePerf;


go

SELECT category_name, [Electra], [Haro], [Trek], [Surly]
FROM (
  SELECT c.category_name, b.brand_name, p.product_id
  FROM production.products p
  JOIN production.categories c ON p.category_id = c.category_id
  JOIN production.brands b ON p.brand_id = b.brand_id
  WHERE b.brand_name IN ('Electra', 'Haro', 'Trek', 'Surly')
) AS src
PIVOT (
  COUNT(product_id) FOR brand_name IN ([Electra], [Haro], [Trek], [Surly])
) AS pvt;


go


SELECT * FROM (
  SELECT s.store_name, MONTH(o.order_date) AS sale_month, oi.quantity * oi.list_price AS revenue
  FROM sales.orders o
  JOIN sales.stores s ON o.store_id = s.store_id
  JOIN sales.order_items oi ON o.order_id = oi.order_id
) AS src
PIVOT (
  SUM(revenue) FOR sale_month IN ([1], [2], [3], [4], [5], [6], [7], [8], [9], [10], [11], [12])
) AS pvt;


go


SELECT * FROM (
  SELECT s.store_name,
         CASE o.order_status
           WHEN 1 THEN 'Pending'
           WHEN 2 THEN 'Processing'
           WHEN 3 THEN 'Completed'
           WHEN 4 THEN 'Rejected'
         END AS status
  FROM sales.orders o
  JOIN sales.stores s ON o.store_id = s.store_id
) AS src
PIVOT (
  COUNT(status) FOR status IN ([Pending], [Processing], [Completed], [Rejected])
) AS pvt;


go

WITH YearlyRevenue AS (
  SELECT b.brand_name, YEAR(o.order_date) AS year, SUM(oi.quantity * oi.list_price) AS revenue
  FROM sales.order_items oi
  JOIN sales.orders o ON o.order_id = oi.order_id
  JOIN production.products p ON oi.product_id = p.product_id
  JOIN production.brands b ON p.brand_id = b.brand_id
  GROUP BY b.brand_name, YEAR(o.order_date)
)
SELECT * FROM (
  SELECT brand_name, year, revenue FROM YearlyRevenue
) AS src
PIVOT (
  SUM(revenue) FOR year IN ([2016], [2017], [2018])
) AS pvt;


go


SELECT 'In Stock' AS status, product_id FROM production.stocks WHERE quantity > 0
UNION
SELECT 'Out of Stock', product_id FROM production.stocks WHERE quantity = 0 OR quantity IS NULL
UNION
SELECT 'Discontinued', product_id FROM production.products 
WHERE product_id NOT IN (SELECT product_id FROM production.stocks);


go


SELECT customer_id FROM sales.orders WHERE YEAR(order_date) = 2017
INTERSECT
SELECT customer_id FROM sales.orders WHERE YEAR(order_date) = 2018;


go


SELECT 'All Stores' AS label, product_id FROM production.stocks WHERE store_id = 1
INTERSECT SELECT product_id FROM production.stocks WHERE store_id = 2
INTERSECT SELECT product_id FROM production.stocks WHERE store_id = 3
UNION
SELECT 'Only in Store 1', product_id FROM production.stocks 
WHERE store_id = 1 AND product_id NOT IN (SELECT product_id FROM production.stocks WHERE store_id = 2);


go


SELECT 'Lost' AS status, customer_id FROM sales.orders WHERE YEAR(order_date) = 2016
EXCEPT
SELECT customer_id FROM sales.orders WHERE YEAR(order_date) = 2017
UNION ALL
SELECT 'New', customer_id FROM sales.orders WHERE YEAR(order_date) = 2017
EXCEPT
SELECT customer_id FROM sales.orders WHERE YEAR(order_date) = 2016
UNION ALL
SELECT 'Retained', customer_id FROM sales.orders WHERE YEAR(order_date) = 2016
INTERSECT
SELECT customer_id FROM sales.orders WHERE YEAR(order_date) = 2017;
