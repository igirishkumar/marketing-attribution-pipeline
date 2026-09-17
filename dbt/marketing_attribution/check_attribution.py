import duckdb

DB_PATH = r"local\pfm_local.duckdb"

con = duckdb.connect(DB_PATH)

print("\n=== Attribution status ===")
print(
    con.sql("""
        SELECT
            attribution_status,
            COUNT(*) AS conversions
        FROM main.int_conversion_attribution
        GROUP BY attribution_status
        ORDER BY conversions DESC
    """).df().to_string(index=False)
)

print("\n=== Match method ===")
print(
    con.sql("""
        SELECT
            match_method,
            COUNT(*) AS conversions
        FROM main.int_conversion_attribution
        GROUP BY match_method
        ORDER BY conversions DESC
    """).df().to_string(index=False)
)

print("\n=== Attributed conversions ===")
print(
    con.sql("""
        SELECT
            tracknow_order_id,
            attribution_status,
            match_method,
            affiliate_session_id,
            tracknow_user_id
        FROM main.int_conversion_attribution
        WHERE attribution_status = 'attributed'
    """).df().to_string(index=False)
)

con.close()