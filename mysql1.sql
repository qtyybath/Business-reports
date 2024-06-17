
#Визначення цільового індикатора для  лояльних клієнтів. 
#Перший індикатор — кількість прокатів: чим більше прокатів у клієнта, 
#тим він лояльніший, тому треба залучити схожих клієнтів, для цього:
# рахуємо кількість прокатів, зроблених кожним клієнтом, 
#і статистику за мінімальною, 
#максимальною та середньою кількістю прокатів на клієнта.

SELECT 
	MIN(rental_count) AS rentals_count_min,
	ROUND(AVG(rental_count), 0) AS rentals_count_avg,
    MAX(rental_count) AS rentals_count_max
FROM 
	(SELECT
	customer_id,
	COUNT(*) AS rental_count
FROM sakila.rental
GROUP BY
	customer_id) as rc;
    


#Додаємо статистику за сумою платежів (payment_amount_sum) на клієнта.
#який розраховуватиме кількість прокатів на клієнта. Поєднання двох запитів на основі спільного стовпця customer_id.

SELECT
    MIN(r.rental_count) AS rentals_count_min,
	ROUND(AVG(r.rental_count), 0) AS rentals_count_avg,
    MAX(r.rental_count) AS rentals_count_max,
    MIN(p.payment_amount_sum) AS payment_amount_sum_min,
	ROUND(AVG(p.payment_amount_sum), 2) AS payment_amount_sum_avg,
    MAX(p.payment_amount_sum) AS rpayment_amount_sum_max
FROM
    (SELECT
        customer_id,
        COUNT(rental_id) AS rental_count
    FROM
        sakila.rental
    GROUP BY
        customer_id) AS r
JOIN (SELECT
        customer_id,
        SUM(amount) AS payment_amount_sum
    FROM
        sakila.payment
    GROUP BY
        customer_id) AS p ON r.customer_id = p.customer_id;
    

#Витгуються клієнти, які згенерували доходів більше за середнє
#на який також можуть орієнтуватись алгоритми маркетингових каналів.
#список всіх лояльних клієнтів (customer_id) та їхньої payment_amount_sum.

SELECT
customer_id,
payment_amount_sum
FROM 
(SELECT
	customer_id,
	SUM(amount) AS payment_amount_sum
FROM sakila.payment 
GROUP BY
	customer_id) AS p
    WHERE payment_amount_sum > (SELECT 
	ROUND(AVG(payment_amount_sum), 2) AS avg_payment_sum_per_customer
FROM 
	(SELECT
	customer_id,
	SUM(amount) AS payment_amount_sum
FROM sakila.payment
GROUP BY
	customer_id) as pa)
ORDER BY
	payment_amount_sum DESC;
    


#Розраховується сума платежів (payment_amount_sum) для кожного клієнта з таблиці sakila.payment. 
#Додається підзапит в частині SELECT, який рахуватиме середню різницю між 
#датою оренди (rental_date) і датою повернення (return_date) з таблиці sakila.rental для кожного клієнта. 
#Поєднуються два запити за допомогою корельованої умови customer_id. 


SELECT 
	customer_id,
    SUM(amount) AS payment_amount_sum
FROM 
 sakila.payment
GROUP BY
	customer_id
HAVING
	payment_amount_sum > (SELECT 
    ROUND(AVG(p.payment_amount_sum), 2) AS avg_payment_sum_per_customer #середнє оплат
FROM 
 (SELECT 
 customer_id,
    SUM(amount) AS payment_amount_sum
FROM 
 sakila.payment
GROUP BY
   customer_id) AS p)
ORDER BY 
     payment_amount_sum DESC;
    



#Чи впливає фактор довжини прокату на цільовий індикатор дохідності клієнта. 
#Сума платежів (payment_amount_sum) для кожного клієнта з таблиці sakila.payment. 
#Додається підзапит в частині SELECT, який рахуватиме середню різницю між датою оренди (rental_date) 
#і датою повернення (return_date) з таблиці sakila.rental для кожного клієнта. 


#відносно кореляції між частотою оренди та загальною сумою платежів за оренду клієнтів: 
# якщо відфільтрувати суми payment_amount_sum більше за середнє (ми знайшли середнє в 2 Завданні),
# та додати фільтр avg_rental_duration та відібрати більше за середнє (середне = 5 ), 
#то загальна кількість таких клієнтів буде 57
# і навтпаки, відфільтрувати меньше за середнє avg_rental_duration , 
#то загальна кількість таких клієнтів буде 43, тобто 75% від тих хто мав оплати вище середнього
#на мою думку кореляції немає. краще це показати в бульбашковій діаграмі


 	SELECT
    ROUND(SUM(DATEDIFF(return_date, rental_date))/COUNT(rental_id), 0) AS avg_avg_rental_duration
FROM 
	sakila.rental;  #середнє частоти оренди  
   
SELECT 
    p.customer_id,
    (SELECT ROUND(SUM(DATEDIFF(return_date, rental_date))/COUNT(rental_id), 0)
     FROM sakila.rental r 
     WHERE r.customer_id = p.customer_id) AS avg_rental_duration,
    FLOOR(SUM(p.amount)) AS payment_amount_sum
FROM 
    sakila.payment p
GROUP BY 
    p.customer_id
HAVING 
	 payment_amount_sum > 112.53 AND avg_rental_duration > 5 # фільтрація оплат вище середнього та частоти оренд вище середнього 
ORDER BY 
     payment_amount_sum DESC;
    


SELECT 
    p.customer_id,
    (SELECT ROUND(SUM(DATEDIFF(return_date, rental_date))/COUNT(rental_id), 0)
     FROM sakila.rental r 
     WHERE r.customer_id = p.customer_id) AS avg_rental_duration,
    FLOOR(SUM(p.amount)) AS payment_amount_sum
FROM 
    sakila.payment p
GROUP BY 
    p.customer_id
HAVING 
	 payment_amount_sum < 112.53 AND avg_rental_duration > 5 #фільтрація оплат нище середнього та частоти оренд вище середнього 
ORDER BY 
     payment_amount_sum DESC;




#За допомогою підзапитів розраховується кількість клієнтів та середню суму платежів на клієнта 
#за кожним значенням середньої довжини прокату. Так можна згенерувати розподіл кількості 
#клієнтів та середньої суми платежів залежно від середньої довжини прокату. 

 SELECT
	COUNT(pr.customer_id) AS customer_count,
	pr.avg_rental_duration,
    ROUND(AVG(pr.payment_amount_sum), 0) AS avg_payment_sum_per_customer
FROM(
SELECT 
    p.customer_id,
    (SELECT ROUND(SUM(DATEDIFF(return_date, rental_date))/COUNT(rental_id), 0)
     FROM sakila.rental r 
     WHERE r.customer_id = p.customer_id) AS avg_rental_duration,
    FLOOR(SUM(p.amount)) AS payment_amount_sum
FROM 
    sakila.payment p
GROUP BY 
    p.customer_id
ORDER BY 
     payment_amount_sum DESC) AS pr
GROUP BY 
    pr.avg_rental_duration
ORDER BY 
	avg_rental_duration;