WITH cleaned_transactions AS (
    SELECT
        ID_client,
        STR_TO_DATE(date_new, '%Y-%m-%d') AS order_date,
        Sum_payment
    FROM transactions
    WHERE STR_TO_DATE(date_new, '%Y-%m-%d') >= '2015-06-01'
      AND STR_TO_DATE(date_new, '%Y-%m-%d') < '2016-06-01'
),

monthly_activity AS (
    SELECT
        ID_client,
        DATE_FORMAT(order_date, '%Y-%m') AS month
    FROM cleaned_transactions
    GROUP BY ID_client, DATE_FORMAT(order_date, '%Y-%m')
),

active_clients AS (
    SELECT ID_client
    FROM monthly_activity
    GROUP BY ID_client
    HAVING COUNT(DISTINCT month) = 12
),

aggregated_metrics AS (
    SELECT
        t.ID_client,
        COUNT(*) AS total_operations,
        SUM(t.Sum_payment) AS total_amount,
        AVG(t.Sum_payment) AS avg_check,
        SUM(t.Sum_payment) / 12.0 AS avg_monthly_amount
    FROM cleaned_transactions t
    JOIN active_clients ac ON t.ID_client = ac.ID_client
    GROUP BY t.ID_client
)

SELECT
    a.*,
    c.Gender,
    c.Age,
    c.Count_city,
    c.Response_communcation,
    c.Communication_3month,
    c.Tenure
FROM aggregated_metrics a
JOIN customer_info_final c ON a.ID_client = c.Id_client
ORDER BY avg_monthly_amount DESC;




WITH cleaned_transactions AS (
    SELECT
        t.ID_client,
        STR_TO_DATE(t.date_new, '%Y-%m-%d') AS order_date,
        t.Sum_payment,
        DATE_FORMAT(STR_TO_DATE(t.date_new, '%Y-%m-%d'), '%Y-%m') AS month,
        c.Gender
    FROM transactions t
    JOIN customer_info_final c ON t.ID_client = c.Id_client
    WHERE STR_TO_DATE(t.date_new, '%Y-%m-%d') >= '2015-06-01'
      AND STR_TO_DATE(t.date_new, '%Y-%m-%d') < '2016-06-01'
),

monthly_stats AS (
    SELECT
        month,
        COUNT(*) AS total_ops,
        SUM(Sum_payment) AS total_sum,
        AVG(Sum_payment) AS avg_check,
        COUNT(DISTINCT ID_client) AS unique_clients
    FROM cleaned_transactions
    GROUP BY month
),

gender_stats AS (
    SELECT
        month,
        Gender,
        COUNT(*) AS ops_by_gender,
        SUM(Sum_payment) AS sum_by_gender
    FROM cleaned_transactions
    GROUP BY month, Gender
),

year_totals AS (
    SELECT
        COUNT(*) AS year_ops,
        SUM(Sum_payment) AS year_sum
    FROM cleaned_transactions
)

SELECT
    m.month,
    ROUND(m.avg_check, 2) AS avg_check,
    m.total_ops AS ops_in_month,
    m.unique_clients AS clients_in_month,
    ROUND(m.total_ops / yt.year_ops * 100, 2) AS ops_share_pct,
    ROUND(m.total_sum / yt.year_sum * 100, 2) AS sum_share_pct,
    
    -- Gender breakdowns
    ROUND(SUM(CASE WHEN g.Gender = 'M' THEN g.ops_by_gender ELSE 0 END) / m.total_ops * 100, 2) AS pct_male_ops,
    ROUND(SUM(CASE WHEN g.Gender = 'F' THEN g.ops_by_gender ELSE 0 END) / m.total_ops * 100, 2) AS pct_female_ops,
    ROUND(SUM(CASE WHEN g.Gender NOT IN ('M','F') OR g.Gender IS NULL THEN g.ops_by_gender ELSE 0 END) / m.total_ops * 100, 2) AS pct_na_ops,

    ROUND(SUM(CASE WHEN g.Gender = 'M' THEN g.sum_by_gender ELSE 0 END) / m.total_sum * 100, 2) AS pct_male_spend,
    ROUND(SUM(CASE WHEN g.Gender = 'F' THEN g.sum_by_gender ELSE 0 END) / m.total_sum * 100, 2) AS pct_female_spend,
    ROUND(SUM(CASE WHEN g.Gender NOT IN ('M','F') OR g.Gender IS NULL THEN g.sum_by_gender ELSE 0 END) / m.total_sum * 100, 2) AS pct_na_spend

FROM monthly_stats m
JOIN year_totals yt
LEFT JOIN gender_stats g ON m.month = g.month
GROUP BY m.month, m.total_ops, m.total_sum, m.avg_check, m.unique_clients, yt.year_ops, yt.year_sum
ORDER BY m.month;




WITH cleaned_transactions AS (
    SELECT
        t.ID_client,
        STR_TO_DATE(t.date_new, '%Y-%m-%d') AS order_date,
        t.Sum_payment,
        c.Age
    FROM transactions t
    JOIN customer_info_final c ON t.ID_client = c.Id_client
    WHERE STR_TO_DATE(t.date_new, '%Y-%m-%d') >= '2015-06-01'
      AND STR_TO_DATE(t.date_new, '%Y-%m-%d') < '2016-06-01'
),

age_groups AS (
    SELECT
        ID_client,
        CASE
            WHEN Age IS NULL THEN 'NA'
            WHEN Age < 10 THEN '0-9'
            WHEN Age BETWEEN 10 AND 19 THEN '10-19'
            WHEN Age BETWEEN 20 AND 29 THEN '20-29'
            WHEN Age BETWEEN 30 AND 39 THEN '30-39'
            WHEN Age BETWEEN 40 AND 49 THEN '40-49'
            WHEN Age BETWEEN 50 AND 59 THEN '50-59'
            WHEN Age BETWEEN 60 AND 69 THEN '60-69'
            WHEN Age BETWEEN 70 AND 79 THEN '70-79'
            WHEN Age >= 80 THEN '80+'
            ELSE 'NA'
        END AS age_group
    FROM customer_info_final
),

joined_data AS (
    SELECT
        ct.ID_client,
        ct.order_date,
        ct.Sum_payment,
        ag.age_group,
        CONCAT(YEAR(ct.order_date), '-Q', QUARTER(ct.order_date)) AS quarter
    FROM cleaned_transactions ct
    JOIN age_groups ag ON ct.ID_client = ag.ID_client
),

year_totals AS (
    SELECT
        age_group,
        COUNT(*) AS total_ops,
        SUM(Sum_payment) AS total_sum
    FROM joined_data
    GROUP BY age_group
),

quarterly_stats AS (
    SELECT
        age_group,
        quarter,
        COUNT(*) AS ops_in_quarter,
        SUM(Sum_payment) AS sum_in_quarter,
        AVG(Sum_payment) AS avg_check
    FROM joined_data
    GROUP BY age_group, quarter
)

SELECT
    q.age_group,
    q.quarter,
    q.ops_in_quarter,
    q.sum_in_quarter,
    ROUND(q.avg_check, 2) AS avg_check,
    yt.total_ops,
    yt.total_sum,
    ROUND(q.ops_in_quarter / yt.total_ops * 100, 2) AS ops_pct,
    ROUND(q.sum_in_quarter / yt.total_sum * 100, 2) AS sum_pct
FROM quarterly_stats q
JOIN year_totals yt ON q.age_group = yt.age_group
ORDER BY q.age_group, q.quarter;
