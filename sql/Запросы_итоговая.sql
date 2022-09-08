SET SEARCH_PATH = bookings, postgres


-- Задание 1

SELECT a.city , count(a.airport_code) 
FROM airports a  
GROUP BY a.city 
HAVING count(a.airport_code) > 1


-- Задание 2

SELECT departure_airport AS "airport"
FROM (SELECT    f.departure_airport , f.aircraft_code
FROM flights f 
UNION 
SELECT f2.arrival_airport, f2.aircraft_code
FROM flights f2 ) AS t2
JOIN (
SELECT a.aircraft_code , a."range"
FROM aircrafts a 
ORDER BY a."range" desc
LIMIT 1) AS t using(aircraft_code)


-- Задание 3

SELECT f.flight_id ,f.scheduled_departure , f.actual_departure , f.status ,
		CASE 
	    	WHEN f.actual_arrival IS NULL AND f.status = 'Delayed'
	    	THEN bookings.now() - f.scheduled_departure
		WHEN f.actual_arrival  IS NOT NULL
	    	THEN f.actual_departure - f.scheduled_departure
	    	END AS "flight_lag"
FROM flights f 
WHERE f.status ='Arrived' OR f.status ='Delayed'
ORDER BY flight_lag DESC
LIMIT 10

другой вариант:

SELECT f.flight_id ,f.scheduled_departure , f.actual_departure , 
	   f.actual_departure - f.scheduled_departure AS "flight_lag"
FROM flights f 
WHERE f.actual_departure IS NOT null
ORDER BY flight_lag DESC
LIMIT 10


-- Задание 4

SELECT b.book_ref ,bp.boarding_no , row_number() OVER()
FROM bookings b 
LEFT OUTER JOIN tickets t ON t.book_ref = b.book_ref 
left OUTER JOIN boarding_passes bp ON t.ticket_no = bp.ticket_no 
WHERE bp.boarding_no IS NULL


-- Задание 5

SELECT 
	flight_date, departure_airport, flight_id, free_seats_total, free_seats_percent,
	sum(c) over(PARTITION BY departure_airport, flight_date::date ORDER BY flight_date) "sum_by_date_n_port"
FROM 
(SELECT DISTINCT 
	f.actual_departure AS "flight_date",f.flight_id ,t.aircraft_code, f.departure_airport , 
	count(bp.ticket_no) OVER (PARTITION BY f.flight_id) AS "c",
	number_of_seats-count(bp.ticket_no) OVER (PARTITION BY f.flight_id) AS "free_seats_total",
	round(((number_of_seats::numeric-count(bp.ticket_no) OVER (PARTITION BY f.flight_id))::numeric*100/number_of_seats::NUMERIC),2) AS "free_seats_percent"
FROM 
	(SELECT  s.aircraft_code , count(s.seat_no) AS "number_of_seats"
	FROM seats s 
	GROUP BY s.aircraft_code 
	) AS t
INNER JOIN flights f ON t.aircraft_code = f.aircraft_code 
INNER JOIN boarding_passes bp ON f.flight_id =bp.flight_id 
ORDER BY f.flight_id ) AS t2
ORDER BY flight_date


-- Задание 6

SELECT a.aircraft_code , a.model , round(t.model_flights*100/t.sum,2) AS "flights_per"
FROM aircrafts a 
JOIN (SELECT  DISTINCT 
		f.aircraft_code, count(f.flight_id),
		COUNT(f.flight_id) OVER (PARTITION BY f.aircraft_code) AS "model_flights",
		SUM(count(f.flight_id)) OVER()
	FROM flights f 
	GROUP BY f.flight_id ) AS t USING (aircraft_code)
ORDER BY flights_per desc


-- Задание 7

WITH busy_t AS
(SELECT tf.flight_id , tf.fare_conditions , tf.amount 
FROM ticket_flights tf 
WHERE tf.fare_conditions = 'Business'), 
	econ_t as(
		SELECT tf.flight_id , tf.fare_conditions , tf.amount 
		FROM ticket_flights tf 
		WHERE tf.fare_conditions = 'Economy')
SELECT a.city , f.flight_id, busy_t.amount AS "bus_amnt", econ_t.amount AS "econ_amnt"
FROM airports a
INNER JOIN flights f ON f.arrival_airport = a.airport_code 
INNER JOIN busy_t USING (flight_id)
INNER JOIN econ_t USING (flight_id)
WHERE econ_t.amount>busy_t.amount


-- Задание 8

CREATE VIEW no_rout_v AS 
		SELECT a3.city AS  "city1",a3.airport_code AS "code1", 
			a4.city AS "city2" , a4.airport_code AS "code2"
		from
		(
		SELECT  a.airport_code AS "c1",  a2.airport_code AS "c2"
		FROM airports a , airports a2 
	        EXCEPT SELECT f.departure_airport , f.arrival_airport 
		FROM flights f) AS t
		JOIN airports a3 ON t.c1 = a3.airport_code 
		JOIN airports a4 ON t.c2 = a4.airport_code 


другой вариант:


CREATE VIEW no_rout_v_2 AS 
SELECT c, c2
from
(
SELECT   a.city AS c,  a2.city AS c2
FROM airports a , airports a2 
EXCEPT SELECT r.departure_city , r.arrival_city
FROM routes r) AS t3

Верный вариант от Николая Хащанова:

CREATE VIEW route AS (
SELECT  a.city AS "depart_city", a2.city AS "arriv_city",
	a.city ||'-'|| a2.city AS "route"
FROM airports a, airports a2 
WHERE a.city != a2.city
ORDER BY route)

CREATE VIEW direct_flight AS(
SELECT  DISTINCT a.city AS "depart_city", a2.city AS "arriv_city",
	a.city ||'-'|| a2.city AS "route"
FROM flights f 
INNER JOIN airports a ON f.departure_airport = a.airport_code 
INNER JOIN airports a2 ON f.arrival_airport = a2.airport_code
ORDER BY route)

SELECT r.*
FROM route AS r
EXCEPT 
SELECT df.*
FROM direct_flight AS df
ORDER BY route


-- Задание 9

WITH t1 AS (
SELECT DISTINCT  
			f.departure_airport  , f.arrival_airport , 
			a.aircraft_code , a."range" 
FROM flights f 
JOIN aircrafts a ON f.aircraft_code = a.aircraft_code 
), t2 as(
		SELECT	a2.airport_code , a2.longitude , a2.latitude 
		FROM airports a2 
		),t3 as(
		SELECT	a3.airport_code , a3.longitude , a3.latitude 
		FROM airports a3
		)
SELECT departure_airport , arrival_airport ,
	round(6371*acos(sind(t2.latitude)*sind(t3.latitude) + cosd(t2.latitude)*cosd(t3.latitude)*cosd(t2.longitude - t3.longitude))) AS "km",
	CASE 
		WHEN t1.RANGE > round(6371*acos(sind(t2.latitude)*sind(t3.latitude) + cosd(t2.latitude)*cosd(t3.latitude)*cosd(t2.longitude - t3.longitude)))
			THEN 'enough_range'
		ELSE 'not_enough_range'
	END "range_check"
FROM t1
INNER JOIN t2 ON t1.departure_airport = t2.airport_code
INNER JOIN t3 ON t1.arrival_airport = t3.airport_code