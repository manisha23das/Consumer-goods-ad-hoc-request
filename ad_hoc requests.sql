USE `gdb023`;
show tables;
select * from dim_customer ;
select * from dim_product;
select * from fact_gross_price;
select * from fact_manufacturing_cost;
select * from fact_pre_invoice_deductions;
select * from fact_sales_monthly;

-- 1. Provide the list of markets in which customer "Atliq Exclusive" operates its business in the APAC region.

select
	distinct market 
from dim_customer
where customer="Atliq Exclusive" and region='APAC';

-- 2. What is the percentage of unique product increase in 2021 vs. 2020? The final output contains these fields:
-- unique_products_2020
-- unique_products_2021
-- percentage_chg

with cte as(
select 
	count(distinct case when fiscal_year=2020 then product_code end) as unique_product_2020 ,
	count(distinct case when fiscal_year=2021 then product_code end) as unique_product_2021
from fact_sales_monthly)

select *,
	round((unique_product_2021 - unique_product_2020 )/unique_product_2020 *100,2) as percentage_increase 
from cte;


-- 3. Provide a report with all the unique product counts for each segment and
-- sort them in descending order of product counts. The final output contains 2 fields, segment, product_count

select 
	segment,
	count(distinct product_code) as product_count
from dim_product
group by segment order by product_count desc;

-- 4. Follow-up: Which segment had the most increase in unique products in 2021 vs 2020? 
-- The final output contains these fields, segment, product_count_2020, product_count_2021, difference

with cte as(
select segment,
	count(distinct case when fiscal_year=2020 then prd.product_code end) as product_count_2020,
	count(distinct case when fiscal_year=2021 then prd.product_code end) as product_count_2021 
from dim_product prd 
join fact_gross_price price 
on 
	prd.product_code=price.product_code
group by segment )

select *, (product_count_2021-product_count_2020) as difference
from cte  order by difference desc ;

-- 5. Get the products that have the highest and lowest manufacturing costs. 
-- The final output should contain these fields: product_code, product, manufacturing_cost

select prd.product_code, 
	product, 
	manufacturing_cost 
from dim_product prd 
join fact_manufacturing_cost cost 
on 
	prd.product_code=cost.product_code
group by prd.product_code, product, manufacturing_cost
having manufacturing_cost=(select min(manufacturing_cost) from fact_manufacturing_cost)
or manufacturing_cost=(select max(manufacturing_cost) from fact_manufacturing_cost);

-- 6.Generate a report which contains the top 5 customers who received 
-- an average high pre_invoice_discount_pct for the fiscal year 2021 and in the Indian market.
-- The final output contains these fields: customer_code, customer, average_discount_percentage

select  cust.customer_code, 
		customer ,
		round(avg(pre_invoice_discount_pct)*100,2) as average_discount_percentage
from dim_customer cust 
join fact_pre_invoice_deductions discount 
on 
		cust.customer_code=discount.customer_code
where market="India" and fiscal_year=2021
group by cust.customer_code, customer
order by average_discount_percentage desc limit 5;

-- 7. Get the complete report of the Gross sales amount for the customer “Atliq Exclusive” for each month. 
-- This analysis helps to get an idea of low and high-performing months and take strategic decisions.
-- The final report contains these columns: Month, Year, Gross sales Amount

select  month(date) as Months, 
		year(date) as years, 
		round(sum(sold_quantity*gross_price),2) as Gross_sales_amount 
from fact_sales_monthly sale 
join dim_customer cust 
on 
		cust.customer_code=sale.customer_code
join fact_gross_price price 
on 
		price.product_code=sale.product_code and price.fiscal_year=sale.fiscal_year
where customer="Atliq Exclusive"
group by years, Months
order by years, Months;

-- 8. In which quarter of 2020, got the maximum total_sold_quantity? The final
-- output contains these fields sorted by the total_sold_quantity, Quarter,total_sold_quantity
with cte as
(select *,case when month(date) in (9,10,11) then 'Q1'
          when month(date) in (12,1,2) then 'Q2'
          when month(date) in (3,4,5) then 'Q3'
          when month(date) in (6,7,8) then 'Q4'   end as Quarter
from fact_sales_monthly
where year(date)=2020)

select 	Quarter, 
		sum(sold_quantity) as total_sold_quantity 
from cte 
group by Quarter
order by total_sold_quantity desc;

-- 9. Which channel helped to bring more gross sales in the fiscal year 2021 and the percentage of contribution? 
-- The final output contains these fields: channel, gross_sales_mln, percentage

with cte as(
select channel,
	sales.fiscal_year,
    sold_quantity,
    gross_price,
    sold_quantity*gross_price as gross_sales
from dim_customer cust 
join fact_sales_monthly sales 
on 
	cust.customer_code=sales.customer_code
join fact_gross_price price 
on 
	price.product_code=sales.product_code and price.fiscal_year=sales.fiscal_year
where sales.fiscal_year=2021)

select  channel,
		round(sum(gross_sales)/1000000,2) as gross_sales_mln,
		(round(sum(gross_sales)/(select sum(gross_sales) from cte)*100,2)) as percentage
from cte group by channel
order by gross_sales_mln desc;

-- 10. Get the Top 3 products in each division that have a high total_sold_quantity in the fiscal_year 2021? 
-- The final output contains these fields:division, product_code, product, total_sold_quantity, rank_order

with cte as(
select  prd.division, 
		prd.product_code, 
        prd.product , 
        sum(sales.sold_quantity) as total_sold_quantity
from dim_product prd 
join fact_sales_monthly sales 
on 
		prd.product_code=sales.product_code where sales.fiscal_year=2021
group by prd.division,prd.product_code,prd.product ),

cte2 as(
select *,
	dense_rank() over(partition by division order by total_sold_quantity desc) as Top_3_rank  
from cte )

select * from cte2 where Top_3_rank<=3;