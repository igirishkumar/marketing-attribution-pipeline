from pathlib import Path

import duckdb
import pandas as pd


# ---------------------------------------------------------------------
# Paths
# ---------------------------------------------------------------------

PROJECT_DIR = Path(__file__).resolve().parent

EXCEL_FILE = (
    PROJECT_DIR.parent.parent
    / "data"
    / "04_data_engineer_data.xlsx"
)

DB_FILE = PROJECT_DIR / "local" / "pfm_local.duckdb"


# ---------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------

def main() -> None:

    if not EXCEL_FILE.exists():
        raise FileNotFoundError(
            f"Excel file not found: {EXCEL_FILE}"
        )

    DB_FILE.parent.mkdir(
        parents=True,
        exist_ok=True,
    )

    # -----------------------------------------------------------------
    # Load assessment data from Excel
    # -----------------------------------------------------------------

    tracknow = pd.read_excel(
        EXCEL_FILE,
        sheet_name="Sample TrackNow Checkouts",
    )

    posthog = pd.read_excel(
        EXCEL_FILE,
        sheet_name="Sample PostHog Sessions",
    )

    # -----------------------------------------------------------------
    # Adapt exercise column names to the warehouse/raw schema
    # expected by the dbt staging models.
    # -----------------------------------------------------------------

    tracknow = tracknow.rename(
        columns={
            "tracknow_order_id": "id",
            "created_date": "created_at",
            "tracknow_user_id": "user_id",
            "order_price_gbp": "order_price",
            "referral_bonus_gbp": "referral_bonus",
        }
    )

    posthog = posthog.rename(
        columns={
            "posthog_distinct_id": "distinct_id",
        }
    )

    # -----------------------------------------------------------------
    # Connect to DuckDB
    # -----------------------------------------------------------------

    con = duckdb.connect(str(DB_FILE))

    try:

        # =============================================================
        # Create schemas
        # =============================================================

        con.execute(
            "CREATE SCHEMA IF NOT EXISTS firms_tracknow"
        )

        con.execute(
            "CREATE SCHEMA IF NOT EXISTS analytics"
        )

        con.execute(
            "CREATE SCHEMA IF NOT EXISTS analytics_tracking"
        )

        con.execute(
            "CREATE SCHEMA IF NOT EXISTS airbyte_raw"
        )

        con.execute(
            "CREATE SCHEMA IF NOT EXISTS raw"
        )

        # =============================================================
        # Raw TrackNow source
        # =============================================================

        con.register(
            "tracknow_df",
            tracknow,
        )

        con.execute(
            """
            CREATE OR REPLACE TABLE firms_tracknow.checkouts AS
            SELECT *
            FROM tracknow_df
            """
        )

        # =============================================================
        # Raw PostHog source
        # =============================================================

        con.register(
            "posthog_df",
            posthog,
        )

        con.execute(
            """
            CREATE OR REPLACE TABLE analytics.sessions AS
            SELECT *
            FROM posthog_df
            """
        )

        # =============================================================
        # Synthetic Firms reference source
        #
        # The assessment dataset does not contain the firm master table.
        # This is created only to test the dbt mart locally.
        # =============================================================

        firms = (
            tracknow[["firm_id"]]
            .drop_duplicates()
            .rename(columns={"firm_id": "id"})
        )

        firms["name"] = firms["id"].apply(
            lambda value: (
                f"Test Firm {str(value)[:6]}"
                if pd.notna(value)
                else "Test Firm Unknown"
            )
        )

        con.register(
            "firms_df",
            firms,
        )

        con.execute(
            """
            CREATE OR REPLACE TABLE airbyte_raw.firms AS
            SELECT *
            FROM firms_df
            """
        )

        # =============================================================
        # Synthetic Finance source
        #
        # The assessment dataset does not contain the Finance Google
        # Sheet. This table is derived from TrackNow only to validate
        # the dbt finance models locally.
        # =============================================================

        finance = (
            tracknow
            .assign(
                commission_date=pd.to_datetime(
                    tracknow["created_at"]
                ).dt.date
            )
            .groupby(
                ["commission_date", "firm_id"],
                as_index=False,
            )
            .agg(
                sales_amount=(
                    "order_price",
                    "sum",
                ),
                commission_amount=(
                    "referral_bonus",
                    "sum",
                ),
            )
        )

        finance = finance.merge(
            firms,
            left_on="firm_id",
            right_on="id",
            how="left",
        )

        finance = finance.rename(
            columns={
                "name": "firm_name",
            }
        )

        finance = finance[
            [
                "commission_date",
                "firm_id",
                "firm_name",
                "sales_amount",
                "commission_amount",
            ]
        ]

        con.register(
            "finance_df",
            finance,
        )

        con.execute(
            """
            CREATE OR REPLACE TABLE raw.commission_google_sheet AS
            SELECT *
            FROM finance_df
            """
        )



        # =============================================================
        # Synthetic First-Party Attribution source
        #
        # This source is explicitly proposed in the case study and
        # does not exist in the supplied assessment dataset.
        # These rows are only for local dbt pipeline validation.
        # =============================================================

        attribution_events = pd.DataFrame(
            [
                {
                    "event_id": "evt_001",
                    "event_at": "2026-06-07 10:00:00",
                    "event_type": "attribution_captured",
                    "affiliate_click_id": (
                        "f08ff120-d31a-47f5-a0f7-"
                        "cc98907b29c3"
                    ),
                    "affiliate_session_id": (
                        "gva7ctyss55w2dqmihz3ma65"
                    ),
                    "posthog_session_id": "session_001",
                    "posthog_distinct_id": "user_001",
                    "gclid": "gclid_001",
                    "fbclid": None,
                    "utm_source": "google",
                    "utm_medium": "cpc",
                    "utm_campaign": "test_campaign",
                    "utm_content": "test_ad_001",
                },
                {
                    "event_id": "evt_002",
                    "event_at": "2026-06-07 11:00:00",
                    "event_type": "attribution_captured",
                    "affiliate_click_id": None,
                    "affiliate_session_id": (
                        "lvxlj4po0xzh70xvhcy2yi6w"
                    ),
                    "posthog_session_id": "session_002",
                    "posthog_distinct_id": "user_002",
                    "gclid": None,
                    "fbclid": "fbclid_001",
                    "utm_source": "meta",
                    "utm_medium": "cpc",
                    "utm_campaign": "meta_campaign",
                    "utm_content": "ad_002",
                },
                {
                    "event_id": "evt_003",
                    "event_at": "2026-06-07 12:00:00",
                    "event_type": "attribution_captured",
                    "affiliate_click_id": None,
                    "affiliate_session_id": None,
                    "posthog_session_id": "session_003",
                    "posthog_distinct_id": "user_003",
                    "gclid": None,
                    "fbclid": None,
                    "utm_source": "google",
                    "utm_medium": "organic",
                    "utm_campaign": None,
                    "utm_content": None,
                },
            ]
        )

        con.register(
            "attribution_events_df",
            attribution_events,
        )

        con.execute(
            """
            CREATE OR REPLACE TABLE
            analytics_tracking.attribution_events AS
            SELECT *
            FROM attribution_events_df
            """
        )

        # =============================================================
        # Validation output
        # =============================================================

        print()
        print("Local DuckDB setup completed successfully.")
        print(f"TrackNow rows: {len(tracknow)}")
        print(f"PostHog rows: {len(posthog)}")
        print(f"Firms rows: {len(firms)}")
        print(f"Finance rows: {len(finance)}")
        print(
            f"Attribution event rows: "
            f"{len(attribution_events)}"
        )
        print()
        print(f"DuckDB database: {DB_FILE}")

                # =============================================================
        # Synthetic QuickBooks source
        #
        # Derived from the local Finance sample solely to exercise
        # reconciliation logic. These are not source-system facts.
        # =============================================================

        finance_sample = finance.head(4).copy()

        quickbooks_rows = []

        for index, row in finance_sample.iterrows():
            amount = float(row["commission_amount"])

            if index == finance_sample.index[0]:
                # Exact match
                qb_amount = amount

            elif index == finance_sample.index[1]:
                # Small variance: within 2% tolerance
                qb_amount = amount * 1.01

            elif index == finance_sample.index[2]:
                # Large variance: should be mismatch
                qb_amount = amount * 1.25

            else:
                # Another normal match
                qb_amount = amount

            quickbooks_rows.append(
                {
                    "invoice_id": f"qb_{index}",
                    "invoice_date": row["commission_date"],
                    "firm_id": row["firm_id"],
                    "invoice_amount_gbp": qb_amount,
                    "currency": "GBP",
                    "status": "paid",
                    "updated_at": f"{row['commission_date']} 18:00:00",
                }
            )

        # Add one QuickBooks-only record to exercise FULL OUTER JOIN.
        quickbooks_rows.append(
            {
                "invoice_id": "qb_only_001",
                "invoice_date": "2026-06-08",
                "firm_id": firms.iloc[0]["id"],
                "invoice_amount_gbp": 25.00,
                "currency": "GBP",
                "status": "paid",
                "updated_at": "2026-06-08 18:00:00",
            }
        )

        quickbooks = pd.DataFrame(quickbooks_rows)

        con.register(
            "quickbooks_df",
            quickbooks,
        )

        con.execute(
            """
            CREATE OR REPLACE TABLE airbyte_raw.invoices AS
            SELECT *
            FROM quickbooks_df
            """
        )

    finally:
        con.close()


if __name__ == "__main__":
    main()