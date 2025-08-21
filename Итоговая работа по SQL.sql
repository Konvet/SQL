--1. Получите количество проектов, подписанных в 2023 году.
--В результат вывести одно значение количества.

select count(project_id) as count_project
from project 
where date_trunc('year', sign_date::date) = '2023-01-01'


--Получите общий возраст сотрудников, нанятых в 2022 году.
--Результат вывести одним значением в виде "... years ... month ... days"
--Использование более 2х функций для работы с типом данных дата и время будет являться ошибкой.

select sum(age(current_date, p.birthdate)) as total_age
from employee e
join person p using (person_id)
where date_trunc('year', hire_date::date) = '2022-01-01'



--3. Получите сотрудников, у которого фамилия начинается на М, всего в фамилии 8 букв и который работает дольше других.
--Если таких сотрудников несколько, выведите одного случайного.
--В результат выведите два столбца, в первом должны быть имя и фамилия через пробел, во втором дата найма.

select concat(p.last_name, ' ', p.first_name), hire_date
from person p
join employee e using(person_id)
where p.last_name like 'М_______'
order by hire_date 
limit 1 

--4. Получите среднее значение полных лет сотрудников, которые уволены и не задействованы на проектах.
--В результат вывести одно среднее значение. Если получаете null, то в результат нужно вывести 0.

    	
select coalesce(avg(extract(year from age(current_date, p.birthdate))), 0) as avg_age
from employee e 
join person p on p.person_id = e.person_id 
where e.dismissal_date is not null 
	and e.employee_id not in (
    	select unnest(employees_id)
    	from project)
    and e.employee_id not in (
    	select project_manager_id
    	from project)
 


--5. Чему равна сумма полученных платежей от контрагентов из Жуковский, Россия.
--В результат вывести одно значение суммы.


select sum(pp.amount) as total_pay_project
from project p
left join project_payment pp on pp.project_id = p.project_id
join customer c on c.customer_id = p.customer_id
join address a on a.address_id = c.address_id
join city ci on ci.city_id = a.city_id
join country co on co.country_id = ci.country_id
where co.country_name = 'Россия' and ci.city_name = 'Жуковский' 
	and fact_transaction_timestamp is not null




--6. Пусть руководитель проекта получает премию в 1% от стоимости завершенных проектов.
--Если взять завершенные проекты, какой руководитель проекта получит самый большой бонус?
--В результат нужно вывести идентификатор руководителя проекта, его ФИО и размер бонуса.
--Если таких руководителей несколько, предусмотреть вывод всех.


with cte1 as(
	select p.project_manager_id, sum(p.project_cost)*0.01 as bonus
	from project p
	where p.status = 'Завершен'
	group by p.project_manager_id),
	cte2 as (
	select *, max(cte1.bonus) over () as max_bonus
	from cte1)
select cte2.project_manager_id, cte2.bonus, p.full_fio
from cte2 
join employee e on e.employee_id = cte2.project_manager_id
join person p on p.person_id = e.person_id
where cte2.bonus = cte2.max_bonus


--7.Получите накопительный итог планируемых авансовых платежей на каждый месяц в отдельности.
--Выведите в результат те даты планируемых платежей, которые идут после преодаления накопительной 
--суммой значения в 30 000 000


with cte1 as(
	select sum(amount) over (partition by date_trunc('month', plan_payment_date)::date 
	order by plan_payment_date) as month_amount, plan_payment_date
	from project_payment 
	where payment_type = 'Авансовый'),
	cte2 as (
	select *,  row_number() over (partition by date_trunc('month', plan_payment_date)::date   
		order by month_amount ) as rn
	from cte1
	where month_amount >30000000)
select plan_payment_date
from cte2
where rn = 1



-- 8.Используя рекурсию посчитайте сумму фактических окладов сотрудников из структурного подразделения 
--с id равным 17 и всех дочерних подразделений.
--В результат вывести одно значение суммы.

with recursive r as (
	select unit_id
	from company_structure cs 
	where unit_id = 17
	union all
	select cs.unit_id
	from company_structure cs
	join r on cs.parent_id = r.unit_id),
	cte as(
	select position_id, employee_id, salary*rate as fact_salary
	from employee_position)
select sum(cte.fact_salary)
from r
join position p on p.unit_id = r.unit_id
join cte on cte.position_id = p.position_id
join employee e on e.employee_id = cte.employee_id
where e.dismissal_date is null


--9. Задание выполняется одним запросом.

--Сделайте сквозную нумерацию фактических платежей по проектам на каждый год в отдельности 
--в порядке даты платежей.
--Получите платежи, сквозной номер которых кратен 5.
--Выведите скользящее среднее размеров платежей с шагом 2 строки назад и 2 строки вперед от текущей.
--Получите сумму скользящих средних значений.
--Получите сумму проектов на каждый год.
--Выведите в результат значение года (годов) и сумму проектов, где сумма проектов меньше, 
--чем сумма скользящих средних значений.
	
with cte1 as (
	select amount, 
		   fact_transaction_timestamp, 
		   project_payment_id, 
		   plan_payment_date, 
		   row_number() over (partition by 
		   date_trunc('year', fact_transaction_timestamp) order by fact_transaction_timestamp) as rn
	from project_payment
	where fact_transaction_timestamp is not null),
	cte2 as (
	select *, round(avg(amount) over 
		(order by fact_transaction_timestamp 
		rows between 2 preceding and 2 following), 2) as move_avg
	from cte1 
	where rn % 5 = 0),
	cte3 as(
	select sum(move_avg) as sum_move_avg
	from cte2),
	cte4 as(
	select sum (amount) as sum_project, 
		date_trunc('year', plan_payment_date)::date as year_project
	from cte2
	group by date_trunc('year', plan_payment_date)::date)
select cte4.year_project, cte4.sum_project
from cte4
where cte4.sum_project < (select sum_move_avg
						  from cte3)




--10. Создайте материализованное представление, которое будет хранить отчет следующей структуры:
--идентификатор проекта
--название проекта
--дата последней фактической оплаты по проекту
--размер последней фактической оплаты
--ФИО руководителей проектов
--Названия контрагентов
--В виде строки названия типов работ по каждому контрагенту


create materialized view report as
with cte1 as(
	select pp.project_id, pp.amount, pp.fact_transaction_timestamp, p.project_name, p.project_manager_id, 
	c.customer_name, c.customer_id,
	last_value (pp.fact_transaction_timestamp) over 
	(partition by project_id order by fact_transaction_timestamp 
	rows between unbounded preceding and unbounded following) as last_payment
	from project_payment pp
	left join project p using (project_id)
	join customer c on c.customer_id = p.customer_id),
	cte2 as (
	select cte1.*, p.full_fio
	from cte1 
	join employee e on cte1.project_manager_id = e.employee_id
	join person p on p.person_id = e.person_id),
	cte3 as (
	select ctw.customer_id, string_agg(tw.type_of_work_name, ', ' order by tw.type_of_work_id) as work_name 
	from  customer_type_of_work ctw 
	join type_of_work tw on tw.type_of_work_id=ctw.type_of_work_id
	group by ctw.customer_id)
select project_id, project_name, last_payment, amount, full_fio, customer_name, work_name 
from cte2
left join cte3 on cte3.customer_id = cte2.customer_id
where fact_transaction_timestamp = last_payment

refresh materialized view report








	
 