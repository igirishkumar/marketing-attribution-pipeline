/*
Purpose:
Identify firm-level commission anomalies over the last 30 days.

Definitions:
- commission_today = daily commission_amount
- commission_7d_avg = average of the prior 7 days, excluding current day
- anomaly threshold = absolute percentage change > 40%
- first dates without a valid 7-day baseline are not flagged
- 37 days are scanned so the first reporting day has a complete lookback
*/


WITH daily AS (

    SELECT
        commission_date,
        firm_id,
        firm_name,
        commission_amount,

        AVG(commission_amount) OVER (
            PARTITION BY firm_id
            ORDER BY commission_date
            ROWS BETWEEN 7 PRECEDING AND 1 PRECEDING
        ) AS commission_7d_avg

    FROM `analytics_core.f_commission_daily`

    WHERE commission_date >= DATE_SUB(CURRENT_DATE(), INTERVAL 37 DAY)
),

scored AS (

    SELECT
        commission_date,
        firm_id,
        firm_name,
        commission_amount AS commission_today,
        commission_7d_avg,

        SAFE_DIVIDE(
            commission_amount - commission_7d_avg,
            commission_7d_avg
        ) AS pct_change_vs_7d_avg,

        CASE
            WHEN commission_7d_avg IS NULL THEN 'normal'

            WHEN ABS(
                SAFE_DIVIDE(
                    commission_amount - commission_7d_avg,
                    commission_7d_avg
                )
            ) > 0.40
                THEN 'anomaly'

            ELSE 'normal'
        END AS anomaly_flag

    FROM daily
)

SELECT
    commission_date,
    firm_id,
    firm_name,
    commission_today,
    commission_7d_avg,
    pct_change_vs_7d_avg,
    anomaly_flag,

    ABS(commission_today - commission_7d_avg) AS revenue_impact

FROM scored

WHERE commission_date >= DATE_SUB(CURRENT_DATE(), INTERVAL 30 DAY)
  AND anomaly_flag = 'anomaly'

ORDER BY revenue_impact DESC;