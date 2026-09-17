with reconciliation_check as (

    select
        'quickbooks_reconciliation' as check_name,
        current_timestamp as check_run_at,

        case
            when reconciliation_status = 'mismatch'
                then 'P1'
            else 'P3'
        end as severity,

        abs(variance_pct) as observed_value,
        0.02 as threshold,

        case
            when reconciliation_status = 'mismatch'
                then 'FAIL'
            else 'PASS'
        end as status,

        concat(
            'Firm: ', cast(firm_id as string),
            ', date: ', cast(commission_date as string),
            ', variance: ', cast(variance as string)
        ) as details

    from {{ ref('f_commission_reconciliation') }}

)

select *
from reconciliation_check