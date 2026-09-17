# Marketing Attribution & Analytics Pipeline

An end-to-end analytics engineering project that transforms web-session,
affiliate-conversion, finance, and accounting data into trusted,
business-ready models for attribution, revenue reporting, reconciliation,
anomaly detection, and data-quality monitoring.

The project focuses on practical analytics engineering patterns: source standardization, attribution, incremental business logic, reconciliation, anomaly detection, and data-quality monitoring.

## What this project demonstrates

- Data modeling with dbt
- SQL transformations and dimensional/fact-style marts
- Marketing and affiliate attribution
- Conversion-level revenue and commission reporting
- Finance reconciliation between operational and accounting sources
- Data-quality testing and monitoring
- BigQuery-oriented analytical SQL
- Local end-to-end validation with DuckDB

## Architecture

```text
                    Source Systems
                         │
          ┌──────────────┼──────────────┐
          │              │              │
       TrackNow        PostHog       Finance
          │              │              │
          |              |          Quickbooks
          └──────────────┼──────────────┘
                         ↓
                    Staging Layer
                         ↓
                 Intermediate Layer
                         ↓
                     Mart Layer
                         ↓
             Reporting / Monitoring
```

The dbt project is organized into three main transformation layers:

```text
models/
├── staging/
├── intermediate/
└── marts/
```

## Data Flow

### 1. TrackNow

TrackNow provides affiliate conversion and commission information.

The staging model standardizes source fields such as:

- order ID
- conversion timestamp
- affiliate click ID
- affiliate session ID
- firm ID
- order value
- commission
- user ID
- conversion status

### 2. PostHog

PostHog provides web-session and marketing attribution information.

The staging model standardizes:

- PostHog session ID
- anonymous user identifier
- session timestamp
- acquisition channel
- Google / Meta click identifiers
- UTM source, medium, campaign, and content
- checkout and conversion indicators

### 3. Finance

Finance data is modeled at firm/day grain and provides daily sales and commission reporting.

### 4. QuickBooks

QuickBooks data is integrated for accounting reconciliation.

The reconciliation compares operational commission totals against accounting invoices using:

```text
firm_id + business date
```

## dbt Models

### Staging models

| Model | Grain | Purpose |
|---|---|---|
| `stg_tracknow_checkouts` | One row per TrackNow order | Standardize conversion data |
| `stg_posthog_sessions` | One row per PostHog session | Standardize session and marketing data |
| `stg_commission_daily` | One row per firm/day | Standardize finance commission data |
| `stg_attribution_events` | One row per attribution event | Standardize first-party attribution events |
| `stg_quickbooks_invoices` | One row per invoice | Standardize accounting data |

### Intermediate models

| Model | Grain | Purpose |
|---|---|---|
| `int_tracknow_conversions` | One row per conversion | Canonical conversion records |
| `int_posthog_attribution` | One row per session | Normalized attribution data |
| `int_attribution_bridge` | One row per attribution event | Connect affiliate identifiers to web sessions |
| `int_conversion_attribution` | One row per conversion | Resolve conversion attribution |
| `int_commission_reconciliation` | One row per firm/day | Compare operational and accounting commission |

### Mart models

| Model | Grain | Purpose |
|---|---|---|
| `f_conversion_attribution` | One row per conversion | Business-facing conversion and attribution fact |
| `f_commission_daily` | One row per firm/day | Daily commission reporting |
| `f_commission_reconciliation` | One row per firm/day | Accounting reconciliation |
| `f_dq_commission_checks` | One row per check result | Data-quality monitoring |

## Attribution Design

The attribution model separates marketing click identifiers from affiliate identifiers.

The preferred matching hierarchy is:

```text
1. Exact affiliate click ID
2. Exact affiliate session ID
3. Known user identity fallback
4. Unattributed
```

The first-party attribution bridge is designed to persist the relationship between:

- affiliate click ID
- affiliate session ID
- PostHog session ID
- PostHog anonymous identity
- Google click ID
- Meta click ID
- UTM campaign information

This reduces dependence on timestamp-only matching and makes attribution deterministic where identifiers are available.

## Commission Anomaly Detection

The SQL in:

```text
sql/commission_anomalies.sql
```

contains BigQuery-oriented anomaly detection logic.

For each firm/day it calculates:

- current daily commission
- average commission across the previous seven available rows
- percentage change versus that baseline
- anomaly status when absolute change exceeds 40%
- absolute revenue impact

Results are ordered by revenue impact so that the largest financial movements are surfaced first.

## Reconciliation

The accounting reconciliation follows:

```text
QuickBooks
    ↓
Airbyte
    ↓
Raw warehouse table
    ↓
stg_quickbooks_invoices
    ↓
int_commission_reconciliation
    ↓
f_commission_reconciliation
```

The reconciliation uses a `FULL OUTER JOIN` so that records appearing in only one system are visible rather than silently dropped.

Current tolerance rules in the model:

```text
Absolute variance <= £0.01
    → matched

Percentage variance <= 2%
    → within_tolerance

Otherwise
    → mismatch
```

## Data Quality

The project includes data-quality checks around:

- source freshness
- commission completeness
- finance reconciliation variance
- duplicate conversions
- attribution completeness

A typical monitoring flow is:

```text
dbt tests / scheduled SQL
          ↓
DQ results
          ↓
alerting
          ↓
on-call / incident workflow
```

## Local Validation

The project was validated end-to-end with DuckDB as a local development warehouse.

Final local dbt run:

```text
dbt build

PASS = 48
WARN = 0
ERROR = 0
SKIP = 0
```

The successful run included:

```text
10 view models
4 table models
34 data tests
```

The local environment was used to validate:

- model dependencies
- SQL transformations
- dbt tests
- attribution logic
- commission reporting
- reconciliation logic
- data-quality models

Some production-style sources were represented by small synthetic local fixtures where a source system was not available in the development dataset. These fixtures exist only to test the transformation pipeline and are not production records.

## Exploratory Analysis

The notebook:

```text
notebooks/01_data_exploration.ipynb
```

contains exploratory analysis of the source data, including:

- schema and data-quality profiling
- identifier completeness
- TrackNow / PostHog coverage
- attribution gaps
- missing-session investigation
- date coverage
- supporting hypothesis checks

## Repository Structure

```text
marketing-attribution-pipeline/
│
├── README.md
├── .gitignore
│
├── dbt/
│   └── marketing_attribution/
│       ├── dbt_project.yml
│       ├── models/
│       └── macros/
│
├── notebooks/
│   └── 01_data_exploration.ipynb
│
└── sql/
    └── commission_anomalies.sql
```

## Local Development

Create and activate a Python virtual environment, install the required dbt adapters, and configure a local `profiles.yml`.

Example local workflow:

```powershell
# Activate the virtual environment
.\.venv\Scripts\Activate.ps1

# Parse the dbt project
dbt parse --no-partial-parse

# Load local development fixtures
python dbt\marketing_attribution\load_local_data.py

# Run the complete dbt project
cd dbt\marketing_attribution
dbt build
```

The local `profiles.yml`, DuckDB database, generated dbt artifacts, virtual environment, and source data are intentionally excluded from version control.

## Technology Stack

```text
Python
SQL
dbt
DuckDB
BigQuery SQL
Pandas
Jupyter
Git / GitHub
```

## Notes

This repository is a portfolio-oriented version of an analytics engineering workflow.

Source-specific assessment data and other non-public files are intentionally not included in the public repository. The repository focuses on the reusable modeling patterns, SQL, tests, documentation, and engineering approach.

## License

For portfolio and educational use.
