# Клієнт, що зробив найбільше замовлень та скільки саме.


  SELECT
    cu.customer_unique_id,
  COUNT(ord.order_id) AS order_count
  FROM `rdcc-sql-v2.olist_store.orders` as ord
  LEFT JOIN `rdcc-sql-v2.olist_store.customers` as cu on ord.customer_id = cu.customer_id
  WHERE order_status != 'canceled' 
  GROUP BY customer_unique_id
  ORDER BY order_count desc
  LIMIT 1;



#Який % скасованих замовлень доставлено логістичному партнеру.


WITH canceled_orders AS (
  SELECT
    COUNT(*) AS canceled_order_count,
    SUM(CASE WHEN order_delivered_carrier_date IS NOT NULL THEN 1 ELSE 0 END) AS canceled_and_delivered_carrier_order_count       #важала за потрібне виключити ділення на 0
  FROM `rdcc-sql-v2.olist_store.orders` AS orders                                                                                   
  WHERE
    order_status = 'canceled'
),

all_orders AS (
  SELECT
    COUNT(*) AS order_count
  FROM `rdcc-sql-v2.olist_store.orders` AS orders
)

SELECT
  all_orders.order_count,
  canceled_orders.canceled_order_count,
  canceled_orders.canceled_and_delivered_carrier_order_count,
  IF(canceled_orders.canceled_order_count > 0, 
     (canceled_orders.canceled_and_delivered_carrier_order_count / canceled_orders.canceled_order_count) * 100, 
     0) AS canceled_and_delivered_carrier_order_percentage
FROM
  canceled_orders, all_orders;



#Який % скасованих замовлень доставлено логістичному партнеру.


WITH all_customer AS (
  SELECT
COUNT(distinct(customer_unique_id)) AS customer_count  #не додавала фільтри, щоб бачити всіх
FROM `rdcc-sql-v2.olist_store.customers`                 #унікальних клієнтів.
),

returning_custome AS (
  SELECT SUM(returning_customer_count) AS returning_customer_count
  FROM(
  SELECT 
COUNT(ord.order_id) AS returning_customer_count ,
cu.customer_unique_id
FROM `rdcc-sql-v2.olist_store.orders` as ord
LEFT JOIN `rdcc-sql-v2.olist_store.customers` as cu on ord.customer_id = cu.customer_id
WHERE order_status = 'delivered' AND cu.customer_unique_id IS NOT NULL  #рахувала тільки тих,
GROUP BY cu.customer_unique_id                            #хто точно мав більше 1 замовлення
HAVING returning_customer_count  > 1) 
)

SELECT
  all_customer.customer_count,
  returning_custome.returning_customer_count,
  ROUND((returning_custome.returning_customer_count/all_customer.customer_count)*100 ,2) AS returning_customer_percentage 
FROM
  all_customer, returning_custome;





#Кількість та який % клієнтів, що мали понад 30 днів між їхнім першим та 
#останнім замовленням, не отримали хоча б одного замовлення.


#Виконано в двох варіантах 


WITH returning_30d AS (
SELECT 
  cu.customer_unique_id ,
TIMESTAMP_DIFF(MAX(order_purchase_timestamp), MIN(order_purchase_timestamp), DAY) AS days_between_orders
FROM `rdcc-sql-v2.olist_store.orders` as ord
LEFT JOIN `rdcc-sql-v2.olist_store.customers` as cu on ord.customer_id = cu.customer_id
GROUP BY cu.customer_unique_id
HAVING days_between_orders > 30
),
  returning_30d_non_delivered AS (
SELECT 
  cu.customer_unique_id,
TIMESTAMP_DIFF(MAX(order_purchase_timestamp), MIN(order_purchase_timestamp), DAY) AS days_between_orders_non_delivered
FROM `rdcc-sql-v2.olist_store.orders` AS ord
LEFT JOIN `rdcc-sql-v2.olist_store.customers` AS cu on ord.customer_id = cu.customer_id
WHERE
    ord.order_status != 'delivered'
GROUP BY cu.customer_unique_id
)

SELECT
COUNT(days_between_orders) AS returning_30d_customer_count ,
COUNT(days_between_orders_non_delivered) AS  returning_30d_non_delivered_customer_count,
ROUND((COUNT(days_between_orders_non_delivered)/COUNT(days_between_orders))*100, 2) as returning_30d_non_delivered_customer_percentage
FROM returning_30d AS re
LEFT JOIN returning_30d_non_delivered AS non on re.customer_unique_id = non.customer_unique_id;


#2 варіант виконання 

WITH returning_customers AS (
  SELECT
    cu.customer_unique_id ,
MIN(order_purchase_timestamp) AS first_order_timestamp,
  MAX(order_purchase_timestamp) AS last_order_timestamp
FROM `rdcc-sql-v2.olist_store.orders` as ord
LEFT JOIN `rdcc-sql-v2.olist_store.customers` as cu on ord.customer_id = cu.customer_id
GROUP BY cu.customer_unique_id
),

returned_orders AS (
  SELECT
     cu.customer_unique_id,
    COUNT(*) AS returned_order_count
 FROM `rdcc-sql-v2.olist_store.orders` as ord
LEFT JOIN `rdcc-sql-v2.olist_store.customers` as cu on ord.customer_id = cu.customer_id
  WHERE
    order_status != 'delivered'
  GROUP BY
     cu.customer_unique_id
),

returning_customers_with_gap AS (
  SELECT
     customer_unique_id,
    TIMESTAMP_DIFF(last_order_timestamp, first_order_timestamp, DAY) AS days_between_orders
  FROM
    returning_customers
)

SELECT
  COUNTIF(days_between_orders > 30) AS returning_30d_customer_count,
  COUNTIF(returned_order_count > 0 AND days_between_orders > 30) AS returning_30d_non_delivered_customer_count,
  ROUND(IF(COUNTIF(returned_order_count > 0 AND days_between_orders > 30) > 0, 
     (COUNTIF(returned_order_count > 0 AND days_between_orders > 30) / COUNTIF(days_between_orders > 30)) * 100, 
     0), 2) AS returning_30d_percentage
FROM
  returning_customers_with_gap
LEFT JOIN
  returned_orders
USING
  (customer_unique_id);





#% доходів компанії було втрачено через скасування замовлень кожного місяця.

WITH order_payments AS (
SELECT 
  EXTRACT(YEAR FROM order_purchase_timestamp) AS order_year,
  EXTRACT(MONTH FROM order_purchase_timestamp) AS order_month,
  ROUND(SUM(payment_value), 2) AS order_payment_amount,
  ROUND(SUM(CASE 
          WHEN order_status = 'canceled' THEN payment_value ELSE 0 END), 2) #ранжування платежів 
          AS canceled_order_payment_amount
FROM `rdcc-sql-v2.olist_store.orders` as ord
LEFT JOIN `rdcc-sql-v2.olist_store.order_payments` as pa on ord.order_id = pa.order_id
 GROUP BY
    order_year,
    order_month)

SELECT
  FORMAT_DATE('%Y-%m', DATE(order_year, order_month, 1)) AS order_month,   
  order_payment_amount,
  canceled_order_payment_amount,
  ROUND(
    IF(order_payment_amount > 0,                                         #якщо виконується умова та що в CASE
     (canceled_order_payment_amount / order_payment_amount) * 100, 
     0), 2) AS canceled_order_payment_percentage
FROM
  order_payments
ORDER BY
  order_year,
  order_month;
  

#за  2016 та 2018 є якісь неадекватні числа: 2016-09, 2016-12, 2018-09, 2018-10




#Середня оцінку відгуків до замовлень з різними статусами.

SELECT
  order_status,
  COUNT(re.review_score) AS  review_score_count,
  ROUND(AVG(re.review_score), 2) AS review_score_avg
FROM `rdcc-sql-v2.olist_store.orders` as ord
LEFT JOIN `rdcc-sql-v2.olist_store.order_reviews` as re on ord.order_id = re.order_id
  GROUP BY order_status;





#Три міста, які мають найвищу середню вартість замовлення.



SELECT 
  customer_city,
  COUNT(payment_value) AS  order_payment_amount_coun,
  ROUND(SUM(payment_value), 2) AS order_payment_amount_sum,
  ROUND(SUM(payment_value)/COUNT(payment_value), 2) AS order_payment_amount_avg
FROM `rdcc-sql-v2.olist_store.orders` as ord
LEFT JOIN `rdcc-sql-v2.olist_store.order_payments` as pa on  ord.order_id = pa.order_id 
LEFT JOIN `rdcc-sql-v2.olist_store.customers` as cu on  ord.customer_id = cu.customer_id 
GROUP BY customer_city
ORDER BY order_payment_amount_avg desc
LIMIT 3;

