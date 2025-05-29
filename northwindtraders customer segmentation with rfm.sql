#NORTHWINDTRADERS CUSTOMER SEGMENTATION
select * from northwindtraders.customers;

#MOST OF OUR CUSTOMERS ARE FROM
select country,
count(*) as count
from northwindtraders.customers
group by 1
order by 2 desc;

#REVENUE CONTRIBUTION BY COMPANY
select c.country,
round(100.0*sum(od.sales)/(select sum(sales) from northwindtraders.order_details), 2) as sales_contrib
from northwindtraders.customers c
join northwindtraders.orders o on c.customerid = o.customerid
join northwindtraders.order_details od on o.orderID = od.orderid
group by 1
order by 2 desc;

#YOY GROWTH IN NO OF CUSTOMERS
with cte as (
	select year(o.orderdate) as yr,
    count(c.customerid) as cnt,
    lag(count(c.customerid)) over (order by year(o.orderdate) desc) as prev_cnt
    from northwindtraders.customers c
    join northwindtraders.orders o on c.customerid = o.customerid
    group by 1
)
select yr,
round(100.0*(cnt-prev_cnt)/cnt, 2) as YoY
from cte;

select max(orderdate) from northwindtraders.orders;

#RFM ANALYSIS

create table northwindtraders.rfm_analysis (
    customerid TEXT,
    recency INT,
    frequency INT,
    monetary DOUBLE,
    recency_score INT,
    freq_score INT,
    monetary_score INT
);


insert into northwindtraders.rfm_analysis
with calculating_rfm as (
	select c.customerid,
    datediff((select max(orderdate) from northwindtraders.orders), max(o.orderdate)) as recency,
    count(o.orderid) as frequency,
    round(sum(od.sales), 2) as monetary
    from northwindtraders.customers c
    join northwindtraders.orders o on c.customerID = o.customerID
    join northwindtraders.order_details od on o.orderid = od.orderid
    group by 1
),
rfm_score as (
	select customerid,
    recency,
    frequency,
    monetary,
    ntile(5) over (order by recency desc) as recency_score,
    ntile(5) over (order by frequency) as freq_score,
    ntile(5) over (order by monetary) as monetary_score
    from calculating_rfm
)
select * from rfm_score;

select * from northwindtraders.rfm_analysis;
select max(monetary), min(monetary) from northwindtraders.rfm_analysis where monetary_score = 5;

select c.customerid
from northwindtraders.customers c
left join northwindtraders.rfm_analysis r
on c.customerid = r.customerid
where recency is null and frequency is null;

select * from northwindtraders.orders where customerID in ('FISSA', 'PARIS');
#FISSA AND PARIS HAVE EITHER NOT ORDERED ANYTHING OR THEIR ORDER HISTORY IS LOST

#FIVE SEGMENTS OF CUSTOMERS
# 1- CHAMPIONS (HIGHLY PROFITABLE CUSTOMERS WHO ARE DEVOTED TO THE BRAND)
select count(*) from northwindtraders.rfm_analysis
where recency_score >= 4 and freq_score >= 4 and monetary_score >= 4;

# 2- LOYALISTS (VISTS THE STORE FREQUNETLY BUT DONT SPEND A LOT)
select count(*) from northwindtraders.rfm_analysis
where recency_score >= 4 and freq_score >= 4 and monetary_score <= 3;

# 3 - NEW CUSTOMERS (HIGH SPENDING NEW CUSTOMERS WHO HAVE THE POTENTIAL TO BE RETAINED)
select count(*) from northwindtraders.rfm_analysis
where recency_score >= 4 and freq_score <= 2 and monetary_score >= 4;

# 4 - AT RISK (SPENT A LOT IN THE PAST BUT IS NO LONGER VISITING THE STORE AS FREQUENTLY)
select count(*) from northwindtraders.rfm_analysis
where recency_score <= 2 and freq_score >= 3 and monetary_score >= 4;

#5 - LOST CUSTOMERS (CUSTOMERS WHO NO LONGER VISIT THE STORE)
select * from northwindtraders.rfm_analysis
where recency_score <= 2 and freq_score <= 2;

alter table northwindtraders.rfm_analysis
add customer_segment TEXT;

-- Segment 1: Champions
update northwindtraders.rfm_analysis
set customer_segment = 'Champions'
where recency_score >= 4 and freq_score >= 4 and monetary_score >= 4;

-- Segment 2: Loyalists
update northwindtraders.rfm_analysis
set customer_segment = 'Loyalists'
where recency_score >= 4 and freq_score >= 4 and monetary_score <= 3;

-- Segment 3: New Customers
update northwindtraders.rfm_analysis
set customer_segment = 'New Customers'
where recency_score >= 4 and freq_score <= 2 and monetary_score >= 4;

-- Segment 4: At Risk
update northwindtraders.rfm_analysis
set customer_segment = 'At Risk'
where recency_score <= 3 and freq_score >= 3 and monetary_score >= 4;

-- Segment 5: Lost Customers
update northwindtraders.rfm_analysis
set customer_segment = 'Lost Customers'
where recency_score <= 2 and freq_score <= 2;

-- Catch-All Segment: Regulars
update northwindtraders.rfm_analysis
set customer_segment = 'Regular'
where customer_segment is null;

select * from northwindtraders.rfm_analysis;

select distinct customer_segment,
count(*) as cnt_of_customers,
round(100.0*count(*)/(select count(*) from northwindtraders.rfm_analysis), 2) as percent_of_total
from northwindtraders.rfm_analysis
group by customer_segment
order by 3 desc;

#SALES CONTRIB BY SEGMENT
select r.customer_segment,
round(sum(od.sales), 2) as sales,
round(100.0*sum(od.sales)/(select sum(sales) from northwindtraders.order_details), 2) as sales_contrib
from northwindtraders.rfm_analysis r
join northwindtraders.orders o on r.customerid = o.customerid
join northwindtraders.order_details od on o.orderid = od.orderid
group by 1
order by 3 desc;

#CATEGORIES BOUGHT BY CUSTOMER SEGMENTS
with cte as (
	select cat.categoryname,
    SUM(CASE WHEN r.customer_segment = 'Champions' THEN 1 ELSE 0 END) AS Champions_count,
    SUM(CASE WHEN r.customer_segment = 'Loyalists' THEN 1 ELSE 0 END) AS Loyalists_count,
    SUM(CASE WHEN r.customer_segment = 'New Customers' THEN 1 ELSE 0 END) AS New_Customers_count,
    SUM(CASE WHEN r.customer_segment = 'At Risk' THEN 1 ELSE 0 END) AS At_Risk_count,
    SUM(CASE WHEN r.customer_segment = 'Lost Customers' THEN 1 ELSE 0 END) AS Lost_Customers_count,
    SUM(CASE WHEN r.customer_segment = 'Regular' THEN 1 ELSE 0 END) AS Regular_count
	FROM northwindtraders.rfm_analysis r 
	join northwindtraders.orders o on r.customerid = o.customerid
	join northwindtraders.order_details od on o.orderid = od.orderid
	join northwindtraders.products p on od.productID = p.productID
	join northwindtraders.categories cat on p.categoryID = cat.categoryID
	JOIN northwindtraders.customers c ON r.customerid = c.customerid
	GROUP BY cat.categoryname
)
select * from cte;

#GEOGRAPHIC DEMOGRAPHY OF CUSTOMER SEGMENTS
SELECT 
    c.country,
    SUM(CASE WHEN r.customer_segment = 'Champions' THEN 1 ELSE 0 END) AS Champions_count,
    SUM(CASE WHEN r.customer_segment = 'Loyalists' THEN 1 ELSE 0 END) AS Loyalists_count,
    SUM(CASE WHEN r.customer_segment = 'New Customers' THEN 1 ELSE 0 END) AS New_Customers_count,
    SUM(CASE WHEN r.customer_segment = 'At Risk' THEN 1 ELSE 0 END) AS At_Risk_count,
    SUM(CASE WHEN r.customer_segment = 'Lost Customers' THEN 1 ELSE 0 END) AS Lost_Customers_count,
    SUM(CASE WHEN r.customer_segment = 'Regular' THEN 1 ELSE 0 END) AS Regular_count
FROM northwindtraders.rfm_analysis r
JOIN northwindtraders.customers c ON r.customerid = c.customerid
GROUP BY c.country;


#SHIPPING COMPANIES BY CUSTOMER SEGMENTS
with cte as (
	select s.companyname,
    SUM(CASE WHEN r.customer_segment = 'Champions' THEN 1 ELSE 0 END) AS Champions_count,
    SUM(CASE WHEN r.customer_segment = 'Loyalists' THEN 1 ELSE 0 END) AS Loyalists_count,
    SUM(CASE WHEN r.customer_segment = 'New Customers' THEN 1 ELSE 0 END) AS New_Customers_count,
    SUM(CASE WHEN r.customer_segment = 'At Risk' THEN 1 ELSE 0 END) AS At_Risk_count,
    SUM(CASE WHEN r.customer_segment = 'Lost Customers' THEN 1 ELSE 0 END) AS Lost_Customers_count,
    SUM(CASE WHEN r.customer_segment = 'Regular' THEN 1 ELSE 0 END) AS Regular_count
	FROM northwindtraders.rfm_analysis r 
	join northwindtraders.orders o on r.customerid = o.customerid
	join shippers s on o.shipperid = s.shipperid
	GROUP BY s.companyname
)
select * from cte;

#NO OF TIMES SHIPPING HAS BEEN DELAYED BY COMPANY NAME
select s.companyname,
count(case when o.shippeddate > o.requireddate then 1 end) as times_delayed
from northwindtraders.shippers s
join northwindtraders.orders o on s.shipperID = o.shipperid
group by s.companyName
order by 2 desc;

select * from northwindtraders.products;

#DISCONTINUED PRODUCTS MADE WHAT PORTION OF THE SALES BY CUSTOMER SEGMENT
select r.customer_segment,
round(100.0*sum(case when p.discontinued = 1 then od.sales end)/sum(od.sales), 2) as discontinuedpdt_prct_of_sales
from northwindtraders.rfm_analysis r
join northwindtraders.orders o on r.customerid = o.customerid
join northwindtraders.order_details od on o.orderid = od.orderID
join northwindtraders.products p on od.productID = p.productID
group by 1
order by 2 desc;
