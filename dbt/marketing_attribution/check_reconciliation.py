import duckdb

DB_PATH = r"local\pfm_local.duckdb"

con = duckdb.connect(DB_PATH)

print("\n=== Reconciliation status ===")

print(
    con.sql("""
        SELECT
            reconciliation_status,
            COUNT(*) AS rows
        FROM main.f_commission_reconciliation
        GROUP BY reconciliation_status
        ORDER BY rows DESC
    """).df().to_string(index=False)
)

print("\n=== Reconciliation detail ===")

print(
    con.sql("""
        SELECT
            commission_date,
            firm_id,
            firm_name,
            tracknow_commission,
            quickbooks_commission,
            variance,
            variance_pct,
            reconciliation_status
        FROM main.f_commission_reconciliation
        ORDER BY commission_date DESC, firm_id
    """).df().to_string(index=False)
)

con.close()