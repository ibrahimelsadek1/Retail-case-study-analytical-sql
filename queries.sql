
question 1: 

Query (1-1):

-- annul sales report

-- firstly we extracted month,quarter and year from invoice date and put all data in subquery 
-- after that by sum the product of price and quantity partitioned by month we have got the total monthly sales
-- and by repeating this calc for each quarter and year 

SELECT DISTINCT  year,  Quarter, month,
         SUM (price * quantity) OVER (PARTITION BY year, month)  AS monthly_total_sales,
         SUM (price *quantity) OVER(PARTITION BY year,Quarter) AS Quarterly_total_sales,
         SUM (price * quantity) OVER (PARTITION BY year) AS yearly_total_sales
    FROM (SELECT invoice, stockcode, quantity,
                 TO_DATE (invoicedate, 'MM/DD/yyyy HH24:MI') AS invDate,
                 price,
                 TO_CHAR (TO_DATE (invoicedate, 'MM/DD/yyyy HH24:MI'), 'MM') Month,
                 TO_CHAR (TO_DATE (invoicedate, 'MM/DD/yyyy HH24:MI'), 'Q') AS Quarter,
                 TO_CHAR (TO_DATE (invoicedate, 'MM/DD/yyyy HH24:MI'), 'YYYY') AS year,
                 customer_id, country
            FROM tableretail)
ORDER BY year, month;
-----------------------------------------------------


Query (1-2):

 -- most requested product in our retail
 select stockcode , count(distinct invoice ) as invoices_include_product
 from tableretail
 group by stockcode
 order by invoices_include_product desc;

------------------------------------------------------------------------------


Query (1-3):
 --- comparison between number of orders and total payments of each customer
 
with 
    base1 as  (  SELECT DISTINCT
                customer_id,
                SUM (price * quantity) OVER (PARTITION BY customer_id)
                AS total_paid,
                COUNT (DISTINCT invoice) OVER (PARTITION BY customer_id)
                AS num_of_orders
                FROM tableretail
                ORDER BY total_paid DESC)
    -- as base1 table will give us total amount paid and total orders for each customer 
	-- we will add rank to this values to make it more measrable
SELECT customer_id,
       num_of_orders,
       RANK () OVER (ORDER BY num_of_orders DESC) AS num_of_orders_rank,
       total_paid,
       RANK () OVER (ORDER BY total_paid DESC) AS total_paid_rank
 FROM base1;


---------------------------------------------------------------------------------------
Query (1-4):
-- churn rate 


WITH
		-- first we need to get raw data with converted date and month and year
     t1 AS
         (  SELECT year,
                     month, COUNT (DISTINCT customer_id) AS total_customers
                FROM (SELECT invoice,  customer_id,
                             TO_DATE (invoicedate, 'MM/DD/yyyy HH24:MI')  AS invDate,
                             TO_CHAR (   TO_DATE (invoicedate, 'MM/DD/yyyy HH24:MI'),  'MM')  Month,
                             TO_CHAR (  TO_DATE (invoicedate, 'MM/DD/yyyy HH24:MI'),  'YYYY')   AS year
                        FROM tableretail)
            GROUP BY year, month),
         
		-- now to know number of new cutomers every month we could consider first order data as customer joining DATE
			-- so we will count first order dates grouped by month to know number of new customers per month
			-- new_customers column is the result count for every month
     t2 AS 
        (  SELECT year, month, COUNT (customer_id) new_customers
                FROM (SELECT TO_CHAR (first_order_date, 'YYYY') AS year,
                             TO_CHAR (first_order_date, 'MM') AS month,
                             customer_id
                        FROM (  SELECT customer_id,
                                       MIN (  TO_DATE (invoicedate,  'MM/DD/yyyy HH24:MI')) AS first_order_date
                                  FROM tableretail
                              GROUP BY customer_id))
            GROUP BY year, month),
		
		-- then we need to get how many customer in the begining and at the end of every month 
		-- using lag to get the previous month new customers
		--- now we have : number of new customers per month (new_customers) , period_end_total_customers , period_start_total_customers
     t3 AS 
        (SELECT t1.year,
                   t1.month, total_customers AS period_end_total_customers,
                   LAG (total_customers, 1, total_customers)  OVER (ORDER BY t1.year, t1.month)  period_start_total_customers,
                   new_customers
              FROM    t1
                   LEFT JOIN  t2
                   ON t1.year = t2.year AND t1.month = t2.month)
                   
    -- this is the final step , applying formula to calculate churn rate per month   
	-- (period_end_total_customers - new_customers)/ period_start_total_customers)
SELECT year,  month,  period_end_total_customers,
       period_start_total_customers,   new_customers,
       ROUND (((period_end_total_customers - new_customers)/ period_start_total_customers)* 100,  2)   AS churn_rate
  FROM t3;




Query (1-5):
----- average discount rate for each product 


-- by taking max price for every product as a fair price
-- other values of price will be considered as price after discount
-- we have got three values by applying functions according to every product
-- also we will exclude 'M' code because it's a random entry
with 
    base1 as (
                SELECT DISTINCT stockcode AS product,
                    SUM (quantity) OVER (PARTITION BY stockcode) total_sold_quantity,
                    MAX (price) OVER (PARTITION BY stockcode) actual_price,
                    SUM (price * quantity) OVER (PARTITION BY stockcode)  AS total_sales_after_discount
                  FROM tableretail
                  WHERE stockcode != 'M')
    -- after getting measures for each product it's time to calculate discount on each product
	-- by this formula (total before discount -total after discount /total before discount *100)
	-- we will get  Avg_discount_percentage
	
SELECT product,   total_sold_quantity, actual_price,  total_sales_after_discount,
         actual_price * total_sold_quantity AS total_sales_bf_discount,
         ROUND ( ( (actual_price * total_sold_quantity) - total_sales_after_discount)
            / (actual_price * total_sold_quantity),  3)* 100  AS Avg_discount_percentage
FROM base1
ORDER BY Avg_discount_percentage DESC;






Query (1-6):
-- most frequent combination of purchased products 
SELECT a.stockcode AS product , b.stockcode AS bought_with, count(*) as times_bought_together
FROM tableretail  a
INNER JOIN tableretail b
ON a.invoice = b.invoice
AND a.stockcode != b.stockcode
GROUP BY a.stockcode, b.stockcode
order by times_bought_together desc;




-------------------------------------------------------------------------------------------
question 2: 


Query (2-1):
-----
with
    -- base1 table for get data with converted date from string to date format , calculating total price 
     base1 as (
            select invoice , stockcode,quantity ,
            TO_DATE(invoicedate, 'MM/DD/yyyy HH24:MI') as invDate, price,
             (price*quantity) as prod_total_price  , customer_id , country
            from tableretail),
    -- now it's time to get last date of purchase for every customer, and count invoices per customer to get frequency
    -- also sum total price for each customer to get monetary
     base2 as (
            select distinct customer_id , max(invDate) over() as max_date,
            last_value(invDate) over(partition by customer_id order by invDate
                                  rows between unbounded preceding and unbounded following) as last_purchase,
            count(distinct invoice) over (partition by customer_id) as Frequency,
            sum(prod_total_price) over (partition by customer_id) as monetary
            from base1
            order by customer_id ),
	-- let's divide every indicator to 5 groups based on their values 
	-- and average FM_score will be calculated by sum f_score and m_score and divide them by 2
    base3 as (
            select  customer_id , round(max_date-last_purchase) as recency, 
            Frequency, monetary,
            ntile(5) over(order by round(max_date-last_purchase) desc) as r_score,
            ntile(5) over(order by Frequency asc) as f_score,
            ntile(5) over (order by monetary asc) m_score,
            ceil(( ntile(5) over(order by Frequency asc)+ ntile(5) over (order by monetary asc))/2) as fm_score,
			ntile(5) over(order by round(sysdate-last_purchase) desc)||ceil(( ntile(5) 
                        over(order by Frequency asc)+ ntile(5) over (order by monetary asc))/2) as conc
            from base2
            order by customer_id )
	-- now we have all needed groups with labeld numbers from 1 to 5 
	-- we added a column called (conc) which hold concatenation of f_score and FM_score as string 
	-- this column will help us reduce number of case statements to make code more efficient 
select customer_id ,recency,Frequency,monetary,r_score,f_score,m_score,fm_score,
        (case 
                when conc in(55,54,45) then 'Champions' 
                when conc in(52,42,33,43) then 'Potential Loyalisits' 
                when conc in(53,44,35,34) then 'Loyal Customers ' 
                when conc in(51) then 'Recent Customers' 
                when conc in(41,31) then 'Promising' 
                when conc in(32,23,22) then 'Customers Needing attention' 
                when conc in(21) then 'About to Sleep' 
                when conc in(25,24,13) then 'At Risk'
                when conc in(15,14) then 'Cant Lose Them'  
                when conc in(12) then 'Hibernating' 
                when conc in(11) then 'Lost' 
        End ) as cust_segment
 from base3;
 
 
----------------------------------------------------------------------------------------------------------------




question 3: 

-- table for loading data into it
CREATE TABLE transactions 
(
    cust_id    VARCHAR(50),
    Calendar_Dt    VARCHAR(50),
    Amt_LE    FLOAT
);


-------------
Query (3-1):


with
	-- base1 table for get data with converted date from string to date format
    base1 as (
            select cust_id , TO_DATE(Calendar_Dt, 'yyyy/MM/DD') as  Calendar_Dt ,Amt_LE
            from  transactions),
    -- base2 table : get lag of Calendar_Dt to get difference BETWEEN date and it's lag	
	-- so if this diff not equal 1 then it's a start of consecutive series of days    
    base2 as  (
            select cust_id , Calendar_Dt ,  ( case when ( Calendar_Dt - lag(Calendar_Dt,1) over(partition by cust_id order by Calendar_Dt ) ) = 1 then 0 else 1 end) as gap
            from base1
            group by cust_id , Calendar_Dt ),
    -- as we have got from base2 table so every consecutive series of days start with gap value 1 and the other rows in the series has  0 value in gap column 
	-- now it's time to group every consecutive series, by applying sum(gap), the value of this sum will be changed every new series
	-- because every new series has gap value 1 and the remainaig row in the same series has gap value 0
	-- output of this will be like (1,1,1,2,2,3,3,3,3) so 1,2,3 is different series
    base3 as (
            select cust_id , Calendar_Dt, sum(gap) over (partition by cust_id order by Calendar_Dt )  as conseq_rank
            from base2),
	-- now, by GROUPING data with cust_id and and the above rank from base3, counting occurance of data will return the series length
    base4 as (
            select cust_id ,count(*) as  conseq_days
            from base3
            group by cust_id, conseq_rank )    

-- finally, by getting maximum of conseq_days  we will get tha max consecutive series of days for every customer        
select cust_id ,max(conseq_days) as max_Consecutive_days
from base4
group by cust_id
order by cust_id ;





--------------------

Query (3-2):

with 
	-- base1 table for get data with converted date from string to date format
    base1 as  (
           select cust_id , TO_DATE(Calendar_Dt, 'yyyy/MM/DD') as  Calendar_Dt ,Amt_LE
           from  transactions),
    -- base2 table for get (accumulated sum of amount, orderd by date for each customer - start date of each customer)       
    base2 as   (
            select cust_id, sum(amt_le) over (partition by cust_id order by Calendar_Dt )  as accum, Calendar_Dt , min(Calendar_Dt) over(partition by cust_id) as min_date
            from base1) ,
    -- base3 table : 
	-- first : filter data based on accumulated amount >=250 to start ranking from this point
	-- then rank accumulated amount so,first value above 250 will get rank 1
    base3 as  (
            select cust_id ,accum , Calendar_Dt , rank() over (partition by cust_id order by accum ) as rankk ,min_date
            from base2
                where  accum>250)
             
-- now we need only to get rows with rank 1 because it refers to the date that customer reached a spent threshold of 250 L.E	
-- then we get average of difference between start date of customer and threshold date 	 
select  round(avg(Calendar_Dt-min_date)) as avg_threshold_days
from base3
   where rankk=1;
