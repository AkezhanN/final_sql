#1)
WITH monthly_activity AS (
    SELECT
        t.id_client,
        DATE_FORMAT(t.date_new, '%Y-%m') AS ym,
        COUNT(*) AS ops_in_month,
        SUM(t.sum_payment) AS month_sum
    FROM transactions t
    WHERE t.date_new >= '2015-06-01'
      AND t.date_new <  '2016-06-01'
    GROUP BY t.id_client, ym
),


clients_with_full_year AS (
    SELECT
        id_client
    FROM monthly_activity
    GROUP BY id_client
    HAVING COUNT(DISTINCT ym) = 12
)

SELECT
    c.id_client,
    COUNT(t.id_check) AS total_operations,
    AVG(t.sum_payment) AS avg_check,
    SUM(t.sum_payment) / 12 AS avg_monthly_spend
FROM clients_with_full_year fy
JOIN transactions t
    ON fy.id_client = t.id_client
JOIN customers c
    ON c.id_client = t.id_client
WHERE t.date_new >= '2015-06-01'
  AND t.date_new <  '2016-06-01'
GROUP BY c.id_client
ORDER BY c.id_client;
#2)
WITH base AS (
    SELECT
        DATE_FORMAT(t.date_new, '%Y-%m') AS ym,
        t.id_client,
        t.id_check,
        t.sum_payment,
        COALESCE(c.gender, 'NA') AS gender
    FROM transactions t
    LEFT JOIN customers c
        ON t.id_client = c.id_client
    WHERE t.date_new >= '2015-06-01'
      AND t.date_new <  '2016-06-01'
),

year_totals AS (
    SELECT
        COUNT(*) AS total_ops_year,
        SUM(sum_payment) AS total_sum_year
    FROM base
),

monthly_base AS (
    SELECT
        ym,
        COUNT(*) AS month_ops,
        COUNT(DISTINCT id_client) AS month_clients,
        AVG(sum_payment) AS avg_check_month,
        SUM(sum_payment) AS month_sum
    FROM base
    GROUP BY ym
),

gender_monthly AS (
    SELECT
        ym,
        gender,
        COUNT(*) AS gender_ops,
        SUM(sum_payment) AS gender_sum
    FROM base
    GROUP BY ym, gender
)
SELECT
    m.ym AS month,

    ROUND(m.avg_check_month, 2) AS avg_check,
    ROUND(m.month_ops / m.month_clients, 2) AS avg_ops_per_client,
    m.month_clients AS active_clients,

    ROUND(100 * m.month_ops / y.total_ops_year, 2) AS `ops_%_of_year`,
    ROUND(100 * m.month_sum / y.total_sum_year, 2) AS `revenue_%_of_year`,

    ROUND(100 * SUM(CASE WHEN g.gender = 'M'  THEN g.gender_ops ELSE 0 END) / m.month_ops, 2) AS `ops_M_%`,
    ROUND(100 * SUM(CASE WHEN g.gender = 'F'  THEN g.gender_ops ELSE 0 END) / m.month_ops, 2) AS `ops_F_%`,
    ROUND(100 * SUM(CASE WHEN g.gender = 'NA' THEN g.gender_ops ELSE 0 END) / m.month_ops, 2) AS `ops_NA_%`,

    ROUND(100 * SUM(CASE WHEN g.gender = 'M'  THEN g.gender_sum ELSE 0 END) / m.month_sum, 2) AS `revenue_M_%`,
    ROUND(100 * SUM(CASE WHEN g.gender = 'F'  THEN g.gender_sum ELSE 0 END) / m.month_sum, 2) AS `revenue_F_%`,
    ROUND(100 * SUM(CASE WHEN g.gender = 'NA' THEN g.gender_sum ELSE 0 END) / m.month_sum, 2) AS `revenue_NA_%`

FROM monthly_base m
JOIN year_totals y
JOIN gender_monthly g
    ON m.ym = g.ym
GROUP BY
    m.ym,
    m.avg_check_month,
    m.month_ops,
    m.month_clients,
    m.month_sum,
    y.total_ops_year,
    y.total_sum_year
ORDER BY m.ym;
#3)
WITH base AS (
    SELECT
        t.id_check,
        t.sum_payment,
        t.date_new,

        CASE
            WHEN c.age IS NULL THEN 'NA'
            ELSE CONCAT(FLOOR(c.age / 10) * 10, '-', FLOOR(c.age / 10) * 10 + 9)
        END AS age_group,

        CONCAT(YEAR(t.date_new), '-Q', QUARTER(t.date_new)) AS year_quarter
    FROM transactions t
    LEFT JOIN customers c
        ON t.id_client = c.id_client
    WHERE t.date_new >= '2015-06-01'
      AND t.date_new <  '2016-06-01'
)
, total_by_age AS (
    SELECT
        age_group,
        COUNT(*) AS ops_total,
        SUM(sum_payment) AS revenue_total
    FROM base
    GROUP BY age_group
)
, quarterly_by_age AS (
    SELECT
        age_group,
        year_quarter,
        COUNT(*) AS ops_q,
        SUM(sum_payment) AS revenue_q,
        AVG(sum_payment) AS avg_check_q
    FROM base
    GROUP BY age_group, year_quarter
)
SELECT
    q.age_group,
    q.year_quarter,

    -- квартальные абсолюты
    q.ops_q AS operations_q,
    ROUND(q.avg_check_q, 2) AS avg_check_q,
    ROUND(q.revenue_q, 2) AS revenue_q,

    -- доли квартала (%)
    ROUND(100 * q.ops_q / SUM(q.ops_q) OVER (PARTITION BY q.year_quarter), 2) AS `ops_%_in_quarter`,
    ROUND(100 * q.revenue_q / SUM(q.revenue_q) OVER (PARTITION BY q.year_quarter), 2) AS `revenue_%_in_quarter`

FROM quarterly_by_age q
ORDER BY q.year_quarter, q.age_group;






