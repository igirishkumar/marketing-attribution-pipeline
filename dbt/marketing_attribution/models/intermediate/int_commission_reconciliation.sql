with tracknow as (

    select
        commission_date,
        firm_id,
        firm_name,
        commission_amount as tracknow_commission

    from {{ ref('f_commission_daily') }}

),

quickbooks as (

    select
        invoice_date as commission_date,
        firm_id,
        sum(invoice_amount_gbp) as quickbooks_commission

    from {{ ref('stg_quickbooks_invoices') }}

    where status not in ('void', 'cancelled')

    group by 1, 2

),

reconciled as (

    select
        coalesce(t.commission_date, q.commission_date) as commission_date,
        coalesce(t.firm_id, q.firm_id) as firm_id,
        t.firm_name,

        coalesce(t.tracknow_commission, 0) as tracknow_commission,
        coalesce(q.quickbooks_commission, 0) as quickbooks_commission,

        coalesce(q.quickbooks_commission, 0)
            - coalesce(t.tracknow_commission, 0) as variance

    from tracknow t

    full outer join quickbooks q
        on t.commission_date = q.commission_date
       and t.firm_id = q.firm_id

)

select
    *,
    {{ safe_divide(
        'variance',
        'nullif(tracknow_commission, 0)'
    ) }} as variance_pct,

    case
        when tracknow_commission = 0
             and quickbooks_commission = 0
            then 'matched'

        when abs(variance) <= 0.01
            then 'matched'

        when abs(
            {{ safe_divide(
                'variance',
                'nullif(tracknow_commission, 0)'
            ) }}
        ) <= 0.02
            then 'within_tolerance'

        else 'mismatch'
    end as reconciliation_status

from reconciled