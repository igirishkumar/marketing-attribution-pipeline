import duckdb

DB_PATH = r"local\pfm_local.duckdb"

con = duckdb.connect(DB_PATH)

query = """
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
    FROM main.f_commission_daily
),

scored AS (
    SELECT
        commission_date,
        firm_id,
        firm_name,
        commission_amount AS commission_today,
        commission_7d_avg,

        CASE
            WHEN commission_7d_avg IS NULL
                OR commission_7d_avg = 0
            THEN NULL
            ELSE
                (commission_amount - commission_7d_avg)
                / commission_7d_avg
        END AS pct_change_vs_7d_avg

    FROM daily
)

SELECT
    commission_date,
    firm_id,
    firm_name,
    commission_today,
    commission_7d_avg,
    pct_change_vs_7d_avg,

    CASE
        WHEN commission_7d_avg IS NULL
            THEN 'normal'

        WHEN ABS(pct_change_vs_7d_avg) > 0.40
            THEN 'anomaly'

        ELSE 'normal'
    END AS anomaly_flag,

    ABS(
        commission_today - commission_7d_avg
    ) AS revenue_impact

FROM scored

WHERE commission_7d_avg IS NOT NULL

  AND commission_date >= (
      SELECT MAX(commission_date) - INTERVAL 30 DAY
      FROM main.f_commission_daily
  )

  AND ABS(pct_change_vs_7d_avg) > 0.40

ORDER BY revenue_impact DESC
"""

result = con.sql(query).df()

print("\n=== Top 10 commission anomalies ===")

if result.empty:
    print("No anomalies found.")
else:
    print(
        result.head(10).to_string(index=False)
    )

print(f"\nTotal anomalies: {len(result)}")

con.close()