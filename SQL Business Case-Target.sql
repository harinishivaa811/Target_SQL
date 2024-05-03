/*SQL BUSINESS CASE: TARGET*/

/*Usual exploratory analysis steps like checking the structure & characteristics of the dataset:*/
*/1A. Data type of all columns in the "customers" table.*/

SELECT column_name, data_type
FROM 'ecommerce-413008.target.INFORMATION_SCHEMA.COLUMNS'           /*Observation: Data type of each column in customers table has been displayed.*/
WHERE table_name = 'customers'


*/1B. Get the time range between which the orders were placed.*/

SELECT MIN(order_purchase_timestamp) AS FIRST_ORDER_DATE,	    /*Observation: The orders were placed between 4th September, 2016 to 17th October, 2018.*/
MAX(order_purchase_timestamp) AS LAST_ORDER_DATE
FROM 'target.orders'

/*1C.Count the Cities & States of customers who ordered during the given period.*/

SELECT COUNT(DISTINCT customer_city) AS CITY_COUNT,
COUNT(DISTINCT customer_state) AS STATE_COUNT
FROM 'ecommerce-413008.target.customers'			    /*Observation: Customers have ordered from 27 States and 4119 Cities.*/
RIGHT JOIN 'target.orders' AS o 				    
ON c.customer_id = o.customer_id				    
WHERE order_purchase_timestamp is not null


/*In-depth Exploration:*/

/*2A. Is there a growing trend in the no. of orders placed over the past years?*/

SELECT EXTRACT(year FROM order_purchase_timestamp) AS Year,
COUNT(DISTINCT order_id) AS order_count						
FROM 'target.orders'						/*Observation: There is a growing trend in the no. of orders placed from 2016 to 2018 as shown below.
group by Year							/*Even though there is an increase and decrease during the months of a year, */
order by Year ASC					        /*the no. of orders placed is increasing on yearly basis.*/


/*2B.Can we see some kind of monthly seasonality in terms of the no. of orders being placed?*/

SELECT *,
RANK()over(partition by tb.year order by order_count DESC) AS PEAK_COUNT_IN_RANK
FROM
(
SELECT EXTRACT(year FROM order_purchase_timestamp) AS Year,	
FORMAT_DATE("%B",order_purchase_timestamp) AS Month,
COUNT(DISTINCT order_id) AS order_count
FROM 'target.orders'					/*Observation: As observed Peak count with 1 has the highest order count in a month of a year.*/
group by Year,Month
order by Year,Month ASC
)tb
order by Year,Month ASC
LIMIT 10


/*2C.During what time of the day, do the Brazilian customers mostly place their orders? (Dawn, Morning, Afternoon or Night)*/
0-6 hrs : Dawn
7-12 hrs : Mornings
13-18 hrs : Afternoon
19-23 hrs : Night


SELECT 
CASE 
WHEN CAST(tb.hour AS INT64) BETWEEN 0 AND 6 THEN "Dawn"
WHEN CAST(tb.hour AS INT64) BETWEEN 7 AND 12 THEN "Mornings"
WHEN CAST(tb.hour AS INT64) BETWEEN 13 AND 18 THEN "Afternoon"
WHEN CAST(tb.hour AS INT64) BETWEEN 19 AND 23 THEN "Night"
END AS NAME_OF_THE_HOUR,						
count(*) AS Count_IN_BRASILIA
FROM								     /*Observation: Brazilian customers mostly place their orders at Afternoon.*/
(								     /*Less orders are placed during the Dawn.*/
  SELECT *,							
  EXTRACT(hour from order_purchase_timestamp) AS Hour
  FROM `ecommerce-413008.target.orders` as o
  JOIN `target.customers` as c 
  ON c.customer_id = o.customer_id
  WHERE customer_city = "brasilia"
)tb
group by NAME_OF_THE_HOUR


/*Evolution of E-commerce orders in the Brazil region:*/

/*3A.Get the month on month no. of orders placed in each state.*/

SELECT tb.customer_state,
tb.Month,
tb.order_count
FROM
(
  SELECT c.customer_state,
  EXTRACT(month from order_purchase_timestamp) AS Month,
  COUNT(o.order_id) as order_count
  FROM `ecommerce-413008.target.orders` AS o
  JOIN `ecommerce-413008.target.customers` AS c 
  ON o.customer_id = c.customer_id					/*Observation: Customers have been distributed widely in many States.*/
  group by c.customer_state,Month					/*Count has been mentioned for 10 States in Ascending order.*/
)tb
order by tb.customer_state, tb.Month ASC

/*3B.How are the customers distributed across all the states?*/

SELECT customer_state AS State,
COUNT(DISTINCT customer_ID) AS Customer_Count
FROM `target.customers` 
GROUP BY customer_state
ORDER BY customer_state
LIMIT 10



/*Impact on Economy: Analyze the money movement by e-commerce by looking at order prices, freight and others.*/

/*4A. Get the % increase in the cost of orders from year 2017 to 2018 (include months between Jan to Aug only).
You can use the "payment_value" column in the payments table to get the cost of orders.*/


SELECT 
YEAR,
round(SUM(payment_value),2) AS Cost_of_Orders,
 COALESCE(
    round(
      (
        round(SUM(payment_value),2) - LAG(round(SUM(payment_value),2)) over(order by YEAR)
      ) / 
      (LAG(round(SUM(payment_value),2)) over(order by YEAR asc)) * 100
    , 2)
  , 0) as Percentage_Increase
 FROM									/*Observation: There is a 136.98% Increase in the cost of orders from/*
(											/*year 2017 to 2018 as shown below.*/
SELECT *,
EXTRACT(year from order_purchase_timestamp) AS YEAR,
EXTRACT(month from order_purchase_timestamp) AS MONTH
FROM `target.orders` 
WHERE EXTRACT(year from order_purchase_timestamp) IN (2017,2018) AND EXTRACT(month from order_purchase_timestamp) NOT IN (9,10,11,12)
)o
JOIN `target.payments` AS p 
ON o.order_id = p.order_id 
GROUP BY YEAR
order by YEAR 


/*4B. Calculate the Total & Average value of order price for each state.*/

SELECT customer_state as State,
ROUND(SUM(payment_value),2) AS Total_Price ,
ROUND(AVG(payment_value),2) AS Average_Price			/*Observation: State "AC" has the lowest Total Price and Average Price of 19680.62 and 234.29 respectively.*/
FROM `target.customers`as c 
JOIN `target.orders` as o 
ON c.customer_id = o.customer_id
JOIN `target.payments` as p 
ON o.order_id = p.order_id
group by customer_state 
order by customer_state ASC
LIMIT 10

/*4C. Calculate the Total & Average value of order freight for each state.*/

SELECT customer_state as State,
ROUND(SUM(freight_value),2) AS Total_Freight_Value ,
ROUND(AVG(freight_value),2) AS Average_Freight_Value
FROM `target.customers`as c 
JOIN `target.orders` as o 
ON c.customer_id = o.customer_id
JOIN `target.order_items` as item
ON o.order_id = item.order_id
group by customer_state 
order by customer_state ASC
LIMIT 10


/*Analysis based on sales, freight and delivery time.*/
/*5A.Analysis based on sales, freight and delivery time.
Find the no. of days taken to deliver each order from the order’s purchase date as delivery time.
Also, calculate the difference (in days) between the estimated & actual delivery date of an order.
Do this in a single query.*/

SELECT order_id,
TIMESTAMP_DIFF(order_delivered_customer_date, order_purchase_timestamp,day) as DELIVERY_TIME,
TIMESTAMP_DIFF(order_estimated_delivery_date , order_delivered_customer_date,day) as DELIVERY_DIFFERENCE,
FROM `target.orders` 
order by order_id ASC 
LIMIT 10


/*5B. Find out the top 5 states with the highest & lowest average freight value.*/
With tb AS (
  SELECT customer_state as State,
  ROUND(AVG(freight_value),2) AS Average_Freight_Value,
  rank()over(order by ROUND(AVG(freight_value),2) DESC) AS High_rank,
  rank()over(order by ROUND(AVG(freight_value),2) ASC) AS Low_rank
  FROM `target.customers`as c 
  JOIN `target.orders` as o 
  ON c.customer_id = o.customer_id
  JOIN `target.order_items` as item
  ON o.order_id = item.order_id
  group by customer_state 
  order by Average_Freight_Value DESC
)
SELECT tb.State,
  Average_Freight_Value,
  'High' AS rank_type
FROM tb
WHERE High_rank <= 5
UNION ALL
SELECT tb.State,
  Average_Freight_Value,
  'Low' AS rank_type
FROM tb
WHERE Low_rank <= 5


/*5C. Find out the top 5 states with the highest & lowest average delivery time.*/
With tb AS 
(
SELECT customer_state as State,
  ROUND(AVG(EXTRACT(day from order_delivered_customer_date)),2) AS Avg_Delivery_time,
  rank()over(order by ROUND(AVG(EXTRACT(day from order_delivered_customer_date)),2) DESC) AS High_rank,
  rank()over(order by ROUND(AVG(EXTRACT(day from order_delivered_customer_date)),2)ASC) AS Low_rank
  FROM `target.customers`as c 
  JOIN `target.orders` as o 
  ON c.customer_id = o.customer_id
  group by customer_state 
  order by Avg_Delivery_time DESC
)
SELECT tb.State,
  Avg_Delivery_time,
  'High' AS rank_type
FROM tb
WHERE High_rank <= 5
UNION ALL
SELECT tb.State,
  Avg_Delivery_time,
  'Low' AS rank_type
FROM tb
WHERE Low_rank <= 5


/*5D.Find out the top 5 states where the order delivery is really fast as compared to the estimated date of delivery.
You can use the difference between the averages of actual & estimated delivery date to figure out how fast the delivery was for each state.*/

With tb as (
SELECT c.customer_state as State,
timestamp_diff(o.order_delivered_customer_date,o.order_estimated_delivery_date,day) as Delivery_Difference 
FROM `target.customers`as c 
JOIN `target.orders` as o 
ON c.customer_id = o.customer_id
WHERE o.order_delivered_customer_date IS NOT NULL
ORDER BY Delivery_Difference ASC 
)

SELECT tb.State,
rank()over(order by Delivery_Difference ASC) AS TOP_Fast_Delivery
FROM tb
LIMIT 5


/*With tb as (
SELECT c.customer_state as State,
ROUND(AVG(EXTRACT(Day FROM o.order_delivered_customer_date)),2) as Average_actual_Delivery,
ROUND(AVG(EXTRACT(Day FROM o.order_estimated_delivery_date)),2) as Average_Estimated_Delivery
FROM `target.customers`as c 
JOIN `target.orders` as o 
ON c.customer_id = o.customer_id
WHERE o.order_delivered_customer_date IS NOT NULL
GROUP BY c.customer_state
)

SELECT tb.State,
 ROUND((Average_actual_Delivery- Average_Estimated_Delivery),2) as Delivery_Difference 
FROM tb
order by Delivery_Difference ASC
LIMIT 5
*/


/*Analysis based on the payments:*/
/*6A. Find the month on month no. of orders placed using different payment types.*/

SELECT
EXTRACT(year from order_purchase_timestamp) AS YEAR,
EXTRACT(month from order_purchase_timestamp) AS MONTH,
count(o.order_id) AS Order_Count,
p.payment_type AS Payment_Type
FROM `target.orders` as o 
JOIN `target.payments` as p
ON o.order_id = p.order_id
group by YEAR, MONTH, payment_type
order by YEAR, MONTH, payment_type ASC
LIMIT 10


/*6B. Find the no. of orders placed on the basis of the payment installments that have been paid.*/

SELECT
p.payment_installments as Payment_installment,
count(o.order_id) AS Order_Count
FROM `target.orders` as o 
JOIN `target.payments` as p
ON o.order_id = p.order_id
WHERE p.payment_installments != 0 AND p.payment_value != 0 
group by Payment_installment
Order by Payment_installment ASC
LIMI 10




