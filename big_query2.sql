
#Визначення, як  статистики продукту впливають на його рейтинг у майбутніх замовленнях.
#рахуються впливові змінні на рівні товару в кожному замовленні. 

SELECT
  COUNT(*) OVER () AS order_items_coun,
  COUNT(DISTINCT(it.order_id)) OVER () AS distinct_order_count,
  COUNT(DISTINCT(it.product_id)) OVER () AS distinct_product_count,
  COUNT(DISTINCT CONCAT(it.order_id, '-', it.product_id))  OVER () AS distinct_order_product_count,
  COUNT(DISTINCT(it.order_item_id)) OVER () AS distinct_item_count,
  COUNT(DISTINCT CONCAT(it.order_id, '-', it.order_item_id))  OVER () AS distinct_order_item_count

FROM `rdcc-sql-v2.olist_store.order_items` as it
LIMIT 1;


#Унікальний рядок таблиці distinct_order_item_count. Оскільки order_item_id ідентифікує кожен 
#предмет в заказі. В той час як продуктів може бути декілька однакових. order_id ідентифікує одну покупку. 


#Завдання 2 
#Через віконну функцію ROW_NUMBER порахуємо порядковий номер замовленого 
#товару кожного продукту на момент кожного замовлення. 


SELECT
*,
ROW_NUMBER() OVER (PARTITION BY product_id ORDER BY shipping_limit_date,  order_item_id) AS order_number
FROM `rdcc-sql-v2.olist_store.order_items` 
LIMIT 100;


#Додаемо ще кілька колонок, порахованих за допомогою віконних функцій:
#* first_date — перше значення shipping_limit_date в межах вікна по product_id, впорядкованого за 
#shipping_limit_date та order_item_id. Зазначена колонка показуватиме першу дату відправлення 
#товарів цього продукту для кожного товару в таблиці;
#* previous_date — попереднє значення shipping_limit_date в межах вікна по product_id, 
#впорядкованого за shipping_limit_date та order_item_id. Вказана колонка показуватиме
#попередню дату відправлення товару цього продукту для кожного товару в таблиці.


SELECT
  *,
ROW_NUMBER() OVER (PARTITION BY product_id ORDER BY shipping_limit_date,  order_item_id) AS order_number,
FIRST_VALUE(shipping_limit_date) OVER (PARTITION BY product_id ORDER BY shipping_limit_date, order_item_id) AS first_date,
LAG(shipping_limit_date) OVER (PARTITION BY product_id ORDER BY shipping_limit_date, order_item_id) AS previous_date
FROM `rdcc-sql-v2.olist_store.order_items` 
LIMIT 100;


#Ще дві колонки, порахованих за допомогою віконних функцій з обмеженим вікном:
#кількість попередніх замовлених товарів цього продукту для кожного товару в таблиці


SELECT
  *,
ROW_NUMBER() OVER (PARTITION BY product_id ORDER BY shipping_limit_date,  order_item_id) AS order_number,
FIRST_VALUE(shipping_limit_date) OVER (PARTITION BY product_id ORDER BY shipping_limit_date, order_item_id) AS first_date,
LAG(shipping_limit_date) OVER (PARTITION BY product_id ORDER BY shipping_limit_date, order_item_id) AS previous_date,
COUNT(order_id) OVER (PARTITION BY product_id ORDER BY shipping_limit_date, order_item_id  ROWS BETWEEN 1 PRECEDING AND 1 PRECEDING ) AS previous_order_count,
SUM(price) OVER (PARTITION BY product_id ORDER BY shipping_limit_date, order_item_id  ROWS BETWEEN 1 PRECEDING AND 1 PRECEDING  ) AS previous_order_price_sum
FROM `rdcc-sql-v2.olist_store.order_items` 
LIMIT 100;


#Середні та максимальні значення нових колонок.


WITH shipping_limit AS (
  SELECT
  *,
ROW_NUMBER() OVER (PARTITION BY product_id ORDER BY shipping_limit_date,  order_item_id) AS order_number,
FIRST_VALUE(shipping_limit_date) OVER (PARTITION BY product_id ORDER BY shipping_limit_date, order_item_id) AS first_date,
LAG(shipping_limit_date) OVER (PARTITION BY product_id ORDER BY shipping_limit_date, order_item_id) AS previous_date,
COUNT(order_id) OVER (PARTITION BY product_id ORDER BY shipping_limit_date, order_item_id  ROWS BETWEEN 1 PRECEDING AND 1 PRECEDING ) AS previous_order_count,
SUM(price) OVER (PARTITION BY product_id ORDER BY shipping_limit_date, order_item_id  ROWS BETWEEN 1 PRECEDING AND 1 PRECEDING  ) AS previous_order_price_sum
FROM `rdcc-sql-v2.olist_store.order_items` 
),
limit_date AS 
(
SELECT
MAX(first_date) AS first_date_MAX,
MIN(first_date) AS first_date_MIN,
DATE_DIFF(MAX(first_date), MIN(first_date), DAY) / 2 AS days_difference, 

MAX(previous_date) AS previous_date_MAX,
MIN(previous_date) AS previous_date_MIN,
DATE_DIFF(MAX(previous_date), MIN(previous_date), DAY) / 2 AS days_difference_previous,

MAX(previous_order_count) AS previous_order_count_MAX,
ROUND(AVG(previous_order_count), 2) AS previous_order_count_AVG,
MAX(previous_order_price_sum) AS previous_order_price_sum_MAX,
MIN(previous_order_price_sum) AS previous_order_price_sum_MIN,
ROUND(AVG(previous_order_price_sum), 2) AS previous_order_price_sum_AVG
FROM shipping_limit)

SELECT
-- days_difference, чомусь в функції DATE_ADD не вдалося застосувати змінну days_difference, прийшлося ї витягнути та вставити число в формулу. можливо справа в типі даних
-- days_difference_previous, 
DATE_ADD(first_date_MIN, INTERVAL 616 DAY) AS average_first_date, #середина між макс та мін датами показника first_date
first_date_MAX,
DATE_ADD(first_date_MIN, INTERVAL 649 DAY) AS average_previous_date, #середина між макс та мін датами показника previous_date
previous_date_MAX,
previous_order_count_AVG,
previous_order_count_MAX,
previous_order_price_sum_MIN,
previous_order_price_sum_AVG,
previous_order_price_sum_MAX
FROM limit_date;

#середні та максимальні зачення доданих колонок. 
#previous_order_price_sum_MAX та MIN - дуже схоже на викид тому середнє значення не зовсім 
#точне, як мені здається 



#Завдання 5 
#Потрібно вдосконалити запит, сформований вище, щоб отримати такі колонки.
#* order_id, order_number, previous_order_count, previous_order_price_sum — без змін;
#* total_price — price + freight_value до кожного товару замовлення, без віконних функцій;
#* days_since_first_date — кількість днів між first_date та shipping_limit_date;
#* days_since_previous_date — кількість днів між previous_date та shipping_limit_date;
#* previous_order_total_price_sum — те саме, що і previous_order_price_sum, але враховуючи #freight_value додатково до price (freight_value + price).


WITH shipping_limit AS (
  SELECT
  order_id,
  order_item_id,
  product_id,
  seller_id,
  shipping_limit_date,
  price,
  freight_value,
ROW_NUMBER() OVER (PARTITION BY product_id ORDER BY shipping_limit_date,  order_item_id) AS order_number,
FIRST_VALUE(shipping_limit_date) OVER (PARTITION BY product_id ORDER BY shipping_limit_date, order_item_id) AS first_date,
LAG(shipping_limit_date) OVER (PARTITION BY product_id ORDER BY shipping_limit_date,     order_item_id) AS previous_date,
COUNT(order_id) OVER (PARTITION BY product_id ORDER BY shipping_limit_date, order_item_id  ROWS BETWEEN 1 PRECEDING AND 1 PRECEDING  ) AS previous_order_count,
SUM(price) OVER (PARTITION BY product_id ORDER BY shipping_limit_date, order_item_id  ROWS BETWEEN 1 PRECEDING AND 1 PRECEDING  ) AS previous_order_price_sum,
SUM(freight_value + price) OVER (PARTITION BY product_id ORDER BY shipping_limit_date, order_item_id  ROWS BETWEEN 1 PRECEDING AND 1 PRECEDING ) AS previous_order_total_price_sum               #тотал у віконній функції для цього значення

FROM `rdcc-sql-v2.olist_store.order_items` 
)
SELECT
order_id, 
order_number, 
previous_order_count,
previous_order_price_sum,
ROUND((price + freight_value), 2) AS total_price,            # тотал без  віконної функції для цього значення 
DATE_DIFF(shipping_limit_date, first_date, DAY)  AS days_since_first_date,
DATE_DIFF(shipping_limit_date, previous_date, DAY)  AS days_since_previous_date,
ROUND((previous_order_total_price_sum), 2) AS previous_order_total_price_sum
FROM shipping_limit;



#Маючи попередні статистики за кожним продуктом, знаходимо їхній зв’язок з рейтингом 
#замовлень. 
#наступний CTE order_reviews_grouped, який групуватиме рейтинг за кожним замовленням. 
#Він має витягувати такі колонки з таблиці order_reviews, згрупованої за order_id:
#* order_id
#* review_score — середній review_score за кожним order_id. 
#Об’єднання CTE order_reviews_grouped та order_items_product_derived_features, групування за 
#review_score та розрахунок середніх значень за кожною змінною, вплив якої хочемо зрозуміти. 
#В результаті маєте отримати такі колонки :
#* review_score
#* order_count — кількість замовлень за кожним значенням рейтингу, щоб розуміти статистичну 
#значимість результатів.
#* avg_total_price — середнє загальної ціни замовлення.
#* avg_order_number — середній номер товару.
#* avg_previous_order_number_count — середня кількість попередніх замовлень продукту.
#* avg_previous_order_price_sum — середня сума цін попередніх замовлень продукту.
#* avg_previous_order_total_price_sum — середня сума цін включно з комісією за доставку 
#попередніх замовлень продукту.
#* avg_days_since_first_date — середня кількість днів від першої дати доставки продукту.
#* avg_days_since_previous_date — середня кількість днів від попередньої дати доставки продукту.
#Можна побачити, чи кожна змінна зростає чи спадає зі зростанням рейтингу.


WITH shipping_limit AS (
  SELECT
 *,
ROW_NUMBER() OVER (PARTITION BY product_id ORDER BY shipping_limit_date,  order_item_id) AS order_number,
FIRST_VALUE (shipping_limit_date) OVER (PARTITION BY product_id ORDER BY shipping_limit_date, order_item_id) AS first_date,
LAG(shipping_limit_date) OVER (PARTITION BY product_id ORDER BY shipping_limit_date,     order_item_id) AS previous_date,
COUNT(order_id) OVER (PARTITION BY product_id ORDER BY shipping_limit_date, order_item_id  ROWS BETWEEN 1 PRECEDING AND 1 PRECEDING) AS previous_order_count,
SUM(price) OVER (PARTITION BY product_id ORDER BY shipping_limit_date, order_item_id  ROWS BETWEEN 1 PRECEDING AND 1 PRECEDING ) AS previous_order_price_sum,
SUM(freight_value + price) OVER (PARTITION BY product_id ORDER BY shipping_limit_date, order_item_id  ROWS BETWEEN 1 PRECEDING AND 1 PRECEDING ) AS previous_order_total_price_sum  #змінила тотал у віконній функції для цього значення 

FROM `rdcc-sql-v2.olist_store.order_items` 
),

 order_items_product_derived_features AS (
  SELECT
order_id, 
order_number, 
previous_order_count,
previous_order_price_sum,
ROUND((price + freight_value), 2) AS total_price, #змінила тотал без  віконної функції для цього значення 
DATE_DIFF(shipping_limit_date, first_date, DAY)  AS days_since_first_date,
DATE_DIFF(shipping_limit_date, previous_date, DAY)  AS days_since_previous_date,
ROUND((previous_order_total_price_sum), 2) AS previous_order_total_price_sum
FROM shipping_limit
),

 order_reviews_grouped AS (
  
SELECT
  order_id,
ROUND(AVG(review_score), 0) AS review_score
FROM `rdcc-sql-v2.olist_store.order_reviews`
GROUP BY order_id
 )
 SELECT
  g.review_score,
  COUNT(f.order_id) AS order_count,
  ROUND(AVG(f.total_price), 0) AS avg_total_price,
  ROUND(AVG(f.order_number), 0) AS avg_order_number,
  ROUND(AVG(f.previous_order_count), 2) AS avg_previous_order_number_count,
  ROUND(AVG(f.previous_order_price_sum), 0) AS avg_previous_order_price_sum,
  ROUND(AVG(f.previous_order_total_price_sum), 0) AS avg_previous_order_total_price_sum ,
  ROUND(AVG(f.days_since_first_date), 0) AS avg_days_since_first_date,
  ROUND(AVG(f.days_since_previous_date), 0) AS avg_days_since_previous_date 

 FROM order_items_product_derived_features AS f 
 LEFT JOIN order_reviews_grouped AS g  on f.order_id = g.order_id
 WHERE
  f.total_price IS NOT NULL AND
  f.order_number IS NOT NULL AND
  f.previous_order_count IS NOT NULL AND
  f.previous_order_price_sum IS NOT NULL AND
  f.previous_order_total_price_sum IS NOT NULL AND
  f.days_since_first_date IS NOT NULL AND
  f.days_since_previous_date IS NOT NULL
 GROUP BY review_score
 ORDER BY  g.review_score;


#можна виділити три показника, які впливають на рейтинг:
#частота покупок товару - avg_order_number. В якісь мірі можна сказати, що вище рейтинг в 
#товарів які купляють частіше. Також залежність від ціни. Чим дорожче товар  тим нижче рейтинг. 
#Можливо дешевші покупки одного того самого товару робили в акції, тому більша лояльність. 
#також є залежність між середньою кількість днів від першої дати доставки продукту: 
#avg_days_since_first_date - чим більша різниця тим вище рейтинг – хоче має бути навпаки.   
#avg_days_since_pre - теж обернено пропорційна величина. Можливо в мене щось не так в розрахунках. 
#Мені здається ці показники має бути прямо пропорційними. Виходить, що ті 
#продукти, які купляють частіше не є у високих рейтингах. Але якщо розрахунки вірні, то можна 
#допустити гіпотезу, що рейтинг замовлення не має явної залежності від частоти та популярності продукту.  


#Тут аналіз впливу між рейтингом замовлення та 1. різницею днів між датою оплати 
#замовлення та датою доставки, та 2. різницею днів між датою планової доставки та датою 
#фактичної доставки. В розрахунках можна побачити кореляцію. Чим менше днів на доставку тим 
#вище рейтинг. Також чим більший розрив між плановою доставкою та фактичною доставкою, тобто 
#товар доставлявся раніше ніж заплановано, тим вище рейтинг. Тому швидкість доставки має 
#ключове значення в оцінці замовлення. 


WITH delivery AS (

SELECT
    order_id,
    DATE(order_purchase_timestamp) AS purchase_date,
    DATE(order_delivered_customer_date) AS delivery_date,
    ROW_NUMBER() OVER (PARTITION BY order_id ORDER BY order_purchase_timestamp) AS row_num,
  
    DATE(order_estimated_delivery_date) AS estimated_date,
    ROW_NUMBER() OVER (PARTITION BY order_id ORDER BY order_estimated_delivery_date) AS row_num_1
  FROM
    `rdcc-sql-v2.olist_store.orders`
   WHERE order_delivered_customer_date IS NOT NULL

    ),
 order_reviews_grouped AS ( 

SELECT
order_id,
ROUND(AVG(review_score), 0) AS review_score
FROM `rdcc-sql-v2.olist_store.order_reviews`
GROUP BY order_id),

delivery_days AS (

SELECT
  order_id,
  DATE_DIFF(delivery_date, purchase_date, DAY) AS days_difference_purchase,
  DATE_DIFF(delivery_date, estimated_date, DAY) AS days_difference_estimated
FROM
  delivery
WHERE
  row_num = 1 and row_num_1 = 1)

   SELECT
  g.review_score,
  ROUND(AVG(days_difference_purchase), 0) AS days_difference_purchase,
  ROUND(AVG(days_difference_estimated), 0) AS days_difference_estimated

FROM delivery_days AS f 
LEFT JOIN order_reviews_grouped AS g  on f.order_id = g.order_id
GROUP BY review_score
ORDER BY  g.review_score;


