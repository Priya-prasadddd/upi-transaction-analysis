USE upi_project;
--   bank_stats was loaded with the Table Data Import Wizard from bank_stats_dec2024.csv.

LOAD DATA LOCAL INFILE 'C:/path/to/Downloads/transactions_clean.csv'
INTO TABLE transactions
FIELDS TERMINATED BY ',' ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 LINES;

select count(*) from Transactions;

/*-- Query 1: Busiest hours of the day Question: At which hours do people make the most UPI payments?
Finding: Busiest hour is 7 PM (21,232 txns, Rs 28.22 Mn). Two peaks:  lunch (~12 PM) and evening (5 PM to 8 PM, about 24% of all
transations for 6 to 8 PM). Quietest hour is 4 AM (1,247 txns*/

SELECT hour_of_day,
       COUNT(*) AS txn_count,
       ROUND(SUM(amount) / 1000000, 2) AS total_value_mn
FROM transactions
GROUP BY hour_of_day
ORDER BY hour_of_day desc;

/*-- Query 2: Synthetic vs real failure rate by bank (JOIN)
Question: Does the synthetic data match real bank performance?
Finding: Synthetic failure rate is flat (~5%) for all 8 banks.Real NPCI failure rate (Dec 2024) ranges from 4.83% (ICICI) to 16.35% (Yes Bank), so synthetic data cannot
how bank-level reliability.
Note: real_fail_pct = 100 - approved_pct (business + technical declines combined).*/

SELECT t.sender_bank,
       COUNT(*) AS synthetic_txns,
       ROUND(100 * SUM(t.status = 'FAILED') / COUNT(*), 2) AS synthetic_fail_pct,
       ROUND(100 - b.approved_pct, 2) AS real_fail_pct
FROM transactions t
JOIN bank_stats b ON t.sender_bank = b.bank
GROUP BY t.sender_bank, b.approved_pct
ORDER BY real_fail_pct DESC;

SELECT DISTINCT sender_bank FROM transactions;

/*-- Query 3: Transaction types (P2P, P2M and others)
Question: How do transaction types compare in count, share,total value and average amount?
Technique: window function SUM(COUNT(*)) OVER () to get each type's share of all transactions.
-- Finding: P2P is the largest type (44.98% of txns, Rs 147.15 Mn), followed by P2M (35.06%), Bill Payment (14.95%) and Recharge (5.01%). Average
amount is nearly identical across types (Rs 1,291 to Rs 1,320),which reflects the synthetic nature of the data.*/

SELECT txn_type,
       COUNT(*) AS txn_count,
       ROUND(100 * COUNT(*) / SUM(COUNT(*)) OVER (), 2) AS pct_of_txns,
       ROUND(SUM(amount) / 1000000, 2) AS total_value_mn,
       ROUND(AVG(amount), 0) AS avg_amount
FROM transactions
GROUP BY txn_type
ORDER BY txn_count DESC;

/*-- Query 4: Spend by merchant category
-- Question: Which categories drive the most transaction value?
Finding: Shopping leads by value (Rs 76.86 Mn), then Grocery (Rs 58.28 Mn)and Utilities (Rs 52.74 Mn); these three make up about 57% of all
value. Grocery has the most transactions (49,966). Education has the highest average ticket (Rs 5,094) and Transport the lowest (Rs 308).*/

SELECT merchant_category,
       COUNT(*) AS txn_count,
       ROUND(SUM(amount) / 1000000, 2) AS total_value_mn,
       ROUND(AVG(amount), 0) AS avg_amount
FROM transactions
GROUP BY merchant_category
ORDER BY total_value_mn DESC;
 
/* Query 5: Top states by transaction value
-- Question: Which states generate the most UPI value?
Technique: RANK() window function
Finding: Maharashtra leads (Rs 49.04 Mn, about 15% of value), followed by Uttar Pradesh (Rs 40.04 Mn) and Karnataka (Rs 38.45 Mn). The top 5  states make up about 59% of total value. States ranked 7 to 10 are
nearly identical (~20,000 txns each), reflecting the synthetic data.*/
SELECT sender_state,
       COUNT(*) AS txn_count,
       ROUND(SUM(amount) / 1000000, 2) AS total_value_mn,
       RANK() OVER (ORDER BY SUM(amount) DESC) AS value_rank
FROM transactions
GROUP BY sender_state
ORDER BY value_rank;

/*Query 6: Failure rate by amount band
-- Question: Are larger payments more likely to fail?
Technique: CASE to group amounts into bands
Finding: Failure rate rises slightly with amount, from 4.87% (under Rs 500)to 5.76% (Rs 10,000 and above). The gap is under 1 percentage
point and the top band has only 1,805 txns, so this is a weak trend, not strong evidence that large payments fail more.*/
SELECT CASE WHEN amount < 500 THEN '1. Under 500'
            WHEN amount < 2000 THEN '2. 500 to 1,999'
            WHEN amount < 5000 THEN '3. 2,000 to 4,999'
            WHEN amount < 10000 THEN '4. 5,000 to 9,999'
            ELSE '5. 10,000 and above' END AS amount_band,
       COUNT(*) AS txn_count,
       ROUND(100 * SUM(status = 'FAILED') / COUNT(*), 2) AS fail_pct
FROM transactions
GROUP BY amount_band
ORDER BY amount_band;

/*- Query 7: Behaviour by sender age group
-- Question: How do transaction volume, size and failure rate differ by age group?
-- Finding: Ages 26-35 are the largest group (87,432 txns, about 35% of value).Ages 18 to 35 together make up about 60% of all transactions.Ages 36-45 have the highest average ticket (Rs 1,424); 56+ has the
lowest (Rs 1,188). Failure rates are flat across age groups(4.84% to 5.13%).*/

SELECT sender_age_group,
       COUNT(*) AS txn_count,
       ROUND(SUM(amount) / 1000000, 2) AS total_value_mn,
       ROUND(AVG(amount), 0) AS avg_amount,
       ROUND(100 * SUM(status = 'FAILED') / COUNT(*), 2) AS fail_pct
FROM transactions
GROUP BY sender_age_group
ORDER BY sender_age_group;

/*Query 8: Weekday vs weekend activity
 Question: Do people transact more on weekends?
Technique: compare per-day averages, because weekdays have more days than weekends (a fair comparison)
Finding: No weekend effect. Average transactions per day are almost identical (weekday 685 vs weekend 686) and so is average ticket size
(Rs 1,313 vs Rs 1,310). Total counts differ only because there are 261 weekday dates against 104 weekend dates.*/
SELECT CASE WHEN is_weekend = 1 THEN 'Weekend' ELSE 'Weekday' END AS day_type,
       COUNT(*) AS txn_count,
       COUNT(DISTINCT DATE(txn_timestamp)) AS num_days,
       ROUND(COUNT(*) / COUNT(DISTINCT DATE(txn_timestamp)), 0) AS avg_txns_per_day,
       ROUND(AVG(amount), 0) AS avg_amount
FROM transactions
GROUP BY day_type;

-- Data coverage: 1 Jan 2024 to 30 Dec 2024 (31 Dec not present in the source file)
SELECT MIN(DATE(txn_timestamp)), MAX(DATE(txn_timestamp)) FROM transactions;