select
    commission_date,
    firm_id,
    firm_name,
    tracknow_commission,
    quickbooks_commission,
    variance,
    variance_pct,
    reconciliation_status

from {{ ref('int_commission_reconciliation') }}