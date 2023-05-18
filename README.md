# Retail-case-study-analytical-sql

Developed case study using analytical sql to answer some business questions for business team

# description: 
Customers has purchasing transaction that we shall be monitoring to get intuition behind each
customer behavior to target the customers in the most efficient and proactive way, to increase
sales/revenue , improve customer retention and decrease churn.


implement a Monetary model for customers behavior for product purchasing and segment each customer based on the below
groups

Champions - Loyal Customers - Potential Loyalists – Recent Customers – Promising -
Customers Needing Attention - At Risk - Cant Lose Them – Hibernating – Lost

The customers will be grouped based on 3 main values
• Recency => how recent the last transaction is (Hint: choose a reference date, which is
the most recent purchase in the dataset )
• Frequency => how many times the customer has bought from our store
• Monetary => how much each customer has paid for our products
As there are many groups for each of the R, F, and M features, there are also many potential
permutations, this number is too much to manage in terms of marketing strategies.
For this, we would decrease the permutations by getting the average scores of the
frequency and monetary (as both of them are indicative to purchase volume anyway)
