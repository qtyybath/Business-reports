

#Створення віртуальної таблиці (View) з кількістю прокатів за кожним фільмом. 
#Для цього витягуються загальна кількість, мінімум, 
#середнє та максимум кількості прокатів за всіма фільмами (глобальні метрики). 
#Це дасть змогу зрозуміти найпростіші основні характеристики статистичного розподілу змінної (rental_count), яку треба пояснити.

#створення  VIEW 

-- CREATE VIEW film_rental AS
SELECT 
	f.film_id,
	COUNT(r.rental_id) AS rental_count
FROM 
	sakila.film AS f
LEFT JOIN 
	sakila.inventory AS i ON f.film_id = i.film_id          # ліве зєднання дає можливість приєднати навіть пусті колонки 
LEFT JOIN 
	sakila.rental AS r ON i.inventory_id = r.inventory_id   # це важливо щоб бачити що є фільми, які не орендувалися 
group by 
	f.film_id
ORDER BY 
	rental_count;

#запит
    
SELECT
	MIN(rental_count) AS min_rentals,
	ROUND(AVG(rental_count), 0) AS avg_rentals,
	MAX(rental_count) AS max_rentals
FROM 
	sakila.film_rental;
    

#Групування фільмів залежно від кількості прокатів — це потрібно для кращого розуміння статистичного розподілу прокатів за наявними фільмами.
#Користуючись оновленим VIEW, рахуються кількість фільмів, які потрапляють до кожної rental_count_group, 
   

-- CREATE OR REPLACE VIEW film_rental AS   
SELECT 
	r.film_id,
    r.rental_count,
CASE
        WHEN r.rental_count > 24 THEN 24
        WHEN r.rental_count > 20 THEN 20
        WHEN r.rental_count > 16 THEN 16
        WHEN r.rental_count > 12 THEN 12
        WHEN r.rental_count > 8 THEN 8
        WHEN r.rental_count > 4 THEN 4
        ELSE 0
    END AS rental_count_group
FROM 
	 (	SELECT 
	f.film_id,
	COUNT(r.rental_id) AS rental_count
FROM 
	sakila.film AS f
LEFT JOIN 
	sakila.inventory AS i ON f.film_id = i.film_id          # ліве зєднання дає можливість приєднати навіть пусті колонки 
LEFT JOIN 
	sakila.rental AS r ON i.inventory_id = r.inventory_id   # це важливо щоб бачити що є фільми, які не орендувалися 
group by 
	f.film_id) AS r;
 
 #запит та ранжування
 
  SELECT
COUNT(*) AS count_films,
rental_count_group
FROM sakila.film_rental
GROUP BY 
	rental_count_group
ORDER BY
	rental_count_group;  
    
#найменьше фільмів у групі  0
#найбільше фільмів у групі 12     


#Тест, чи впливає категорія фільму на кількість прокатів, 
#запит, який поєднає таблиці film, film_category та category та витягне колонки film.film_id та category.name. 



-- CREATE VIEW film_category_name  AS 
SELECT 
    f.film_id,
	ct.name AS category
FROM 
    sakila.film AS f
    JOIN 
		sakila.film_category AS c ON f.film_id = c.film_id
	JOIN  
		sakila.category AS ct ON c.category_id = ct.category_id;
        

#Використовуючи результати створеного VIEW film_category_name, об’єднаємо його з VIEW film_rental 
#та порахуємо кількість фільмів і середню кількість прокатів на фільм за кожною категорією.
#Результати ранжуються - фільми якої категорії мають найменшу середню кількість прокатів, а якої — найбільшу. 


  SELECT
	cn.category,
	COUNT(cn.film_id) AS film_count,
	ROUND(AVG(fr.rental_count), 1) AS avg_rental_count
FROM 
	sakila.film_category_name AS cn
JOIN 
	sakila.film_rental AS fr ON cn.film_id = fr.film_id
GROUP BY
	cn.category
ORDER BY
	avg_rental_count desc;    

#середня кількість прокату найбільша в категорії Sci-Fi, а найменьша в Foreign
#натомість у Foreign досить велика кількість фільмів у категорії
#тобто найнепотулярніша категорія має майже найбільшу кількість фільмів 

#маю гіпотезу, що є кореляція між категорією та популярністю 


#Тестування гіпотези, чи фільми з більш популярними акторами мають більший попит 
#(цей фактор також може вплинути на рішення щодо закупівлі фільмів). 
# CTE, який витягуватиме кількість фільмів, у яких грав кожен з акторів, 
#під назвою actor_film_count з колонками actor_id та film_count.


WITH actor_film_count AS (
    SELECT 
        actor_id,
        COUNT(*) AS film_count
    FROM 
        sakila.film_actor
    GROUP BY
        actor_id
)
SELECT * 
FROM 
	actor_film_count;
    
#Наступний CTE під назвою avg_actor_popularity, який рахуватиме середню кількість фільмів, 


WITH actor_film_count AS (
    SELECT 
        actor_id,
        COUNT(*) AS film_count
    FROM 
        sakila.film_actor
    GROUP BY
        actor_id
),
avg_actor_popularity AS (
    SELECT
        fa.film_id,
        ROUND(AVG(afc.film_count), 0) AS avg_actor_film_count
    FROM
        sakila.film_actor AS fa
    JOIN
        actor_film_count afc ON fa.actor_id = afc.actor_id
    GROUP BY
        fa.film_id
)
SELECT * 
FROM 
	avg_actor_popularity;
    
#Базуючись на створених CTE actor_film_count, avg_actor_popularity  та VIEW film_rental , оцінюється, 
#як середня популярність акторів у фільмі впливає на середню кількість прокатів цього фільму. 

WITH actor_film_count AS (
    SELECT 
        actor_id,
        COUNT(*) AS film_count
    FROM 
        sakila.film_actor
    GROUP BY
        actor_id
),
avg_actor_popularity AS (
    SELECT
        fa.film_id,
        ROUND(AVG(afc.film_count), 0) AS avg_actor_film_count
    FROM
        sakila.film_actor AS fa
    JOIN
        actor_film_count afc ON fa.actor_id = afc.actor_id
    GROUP BY
        fa.film_id
),
film_rental AS (
    SELECT
        COUNT(fr.film_id) AS film_count_group,
        SUM(fr.rental_count) AS rental_counts_group,
        ROUND(AVG(ap.avg_actor_film_count), 0) AS avg_actor_group,
        CASE
            WHEN ap.avg_actor_film_count >= 31 THEN 'A > 31'
            WHEN ap.avg_actor_film_count >= 29 THEN 'B = 29-30'
            WHEN ap.avg_actor_film_count >= 27 THEN 'C = 27-28'
            WHEN ap.avg_actor_film_count >= 25 THEN 'D = 25-26'
            WHEN ap.avg_actor_film_count < 25 THEN 'E < 25'
            ELSE 'F = 0'
        END AS avg_actor_film_count_group   
    FROM 
        sakila.film_rental AS fr
    LEFT JOIN 
        avg_actor_popularity AS ap ON fr.film_id = ap.film_id
    GROUP BY 
        avg_actor_film_count_group
)

SELECT * 
FROM 
	film_rental
ORDER BY 
	avg_actor_film_count_group;
    
#неможна сказати, що чим більше популярних акторів у фільмах, тим вони частіше беруться в оренду.
#максимальна популярність лежить в групі С, де 28 акторів в середньому у фільмі. Я би сказала що цей розподіл популярності теоритично нагадує нормальний з викидом в дин бік. 


#Визначивши два фактори впливу на популярність фільмів,робиться проста сегментацію, 
#яка дасть змогу виокремити популярні та непопулярні фільми ще оптимальніше.


WITH actor_film_count AS (
    SELECT 
        actor_id,
        COUNT(*) AS film_count
    FROM 
        sakila.film_actor
    GROUP BY
        actor_id
),
avg_actor_popularity AS (
    SELECT
        fa.film_id,
        ROUND(AVG(afc.film_count), 0) AS avg_actor_film_count
    FROM
        sakila.film_actor AS fa
    JOIN
        actor_film_count afc ON fa.actor_id = afc.actor_id
    GROUP BY
        fa.film_id
),
likeli_group AS (
SELECT 
 ap.film_id,
 fc.category,
 fr.rental_count,
 ap.avg_actor_film_count,
  CASE
            WHEN ap.avg_actor_film_count > 28 AND fc.category = 'Sci-Fi' || 'Animation' || 'Action' THEN '5' 
            WHEN ap.avg_actor_film_count > 25 AND fc.category = 'Sci-Fi' || 'Animation' || 'Action' THEN '4'
            WHEN ap.avg_actor_film_count > 28 AND fc.category != 'Foreign' || 'Travel' || 'New' THEN '3'
            WHEN ap.avg_actor_film_count > 25 AND fc.category != 'Foreign' || 'Travel' || 'New' THEN '2'
            ELSE '1'
        END AS rental_likeli_group 
FROM 
	avg_actor_popularity AS ap
RIGHT JOIN sakila.film_rental AS fr ON ap.film_id = fr.film_id  #праве зєднаня щоб не пропустити фільми 
RIGHT JOIN sakila.film_category_name AS fc ON ap.film_id = fc.film_id)
SELECT 
	category,
    sum(rental_count) AS rental_count,
    ROUND(AVG(rental_likeli_group), 2) AS avg_likeli_group
FROM likeli_group 
GROUP BY
	category
ORDER BY
	avg_likeli_group desc;
    
#за кількістю прокатів немає явних лідерів чи явних аутсайдерів. За оцінкою avg_likeli_group
#категорії в межах показників 2.47 - 2.23, що не має великого відхилення від середнього значення 
#2.36 (порахувала окремо без Sci-Fi і  Foreign, бо вони дали викиди: 3,95 та 1) . 
#Sci-Fi дійсно входить в лідери прокату та має найбільше популярних акторів, але за кількістю 
#прокату має 4 позицію. На це впливає кількість фільмів у категорії. Наприклад, Foreign є наче 
#аутсайдером, але за рахунок найбільшої кількості фільмів у категорії також є по сумі оренд #лідером прокату. 
#популярність фільмів в прокаті, як на мене, має нормальний розподіл з невеликим відхиленням
#від середнього і не залежить від категорій та кількості популярних акторів 



#Пошук факторів впливу на кількість прокатів в таких критеріях як: replacement_cost - вартість фільму, length - час фільму, rating - рейтинг.
#для початку сформувала  VIEW віртуальну таблицю, де згенерувала деякі критерії з деяких таблиць. Їх також можна викоритстовувати надалі. 


-- CREATE VIEW rental_calculation AS
-- SELECT
-- r.rental_id,
-- r.staff_id,
-- f.film_id,
-- f.rental_rate,
-- f.length,
-- f.replacement_cost,
-- f.rating,
-- ct.name
-- FROM sakila.rental as r 
-- JOIN sakila.inventory as i on r.inventory_id = i.inventory_id
-- LEFT JOIN sakila.film as f on i.film_id = f.film_id
-- JOIN sakila.film_category AS c ON f.film_id = c.film_id
-- JOIN  sakila.category AS ct ON c.category_id = ct.category_id;


#ми бачимо що за рейтингами та популярністю є пропорція в розподілу. 
#тобто свівідношеня між кількістю прокатів та кількістю фільмів в групі рейтингу 
# є приблизно однаковим для всіх груп рейтингів. 

SELECT
COUNT(rental_id) AS rental,
COUNT(DISTINCT(film_id)) AS film,
rating,
ROUND(COUNT(DISTINCT(film_id))/COUNT(rental_id), 3) AS coeff #співвідношення кількості фільмів до кількості прокатів у групах за рейтингом
FROM 
	rental_calculation 
GROUP BY 
	rating
ORDER BY 
	rental desc;

#пошук залежності популярності від вартості фільмів. якщо поділити фільми на групи за ціною
#вище середнього та нижче середнього, то суттєвої відмінності немає  (до 4%)
#навіть дорожча група має невелику перевагу, то ж вартість фільму не впливає на попілярність 

SELECT
CASE
        WHEN replacement_cost > 20.1 THEN 1
        WHEN replacement_cost < 20.1 THEN 2
        ELSE 0
    END AS cost_group,
COUNT(rental_id) AS rental
FROM 
	rental_calculation 
GROUP BY 
	cost_group
ORDER BY 
	cost_group;

#пошук залежності популярності від довжини фільмів. якщо поділити фільми на групи за довжиною
#вище середньої та нижче середньої, то група 1 меньша від групи 2 на приблизно 7% . 
#Ми не можемо сказать що чим коротший фільм, тим він популярніший. 

SELECT
CASE
        WHEN length > 115.5 THEN 1
        WHEN length < 115.5 THEN 2
        ELSE 0
    END AS length_group,
count(rental_id) as rental
FROM rental_calculation 
group by length_group;

#за менеджерами - staff кількість прокатів  майже порівну 
SELECT
count(rental_id) as rental,
staff_id
FROM rental_calculation 
GROUP BY staff_id;

#узагальнюючи можна сказати, що поки не найдено критеріїв, які б істотно впливали на кількість прокатів. 
