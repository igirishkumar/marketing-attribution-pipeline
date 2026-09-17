with source as (

    select *
    from {{ source('quickbooks', 'invoices') }}

),

renamed as (

    select
        invoice_id,
        invoice_date,
        firm_id,
        invoice_amount_gbp,
        currency,
        status,
        updated_at

    from source

),

final as (

    select
        invoice_id,
        cast(invoice_date as date) as invoice_date,
        firm_id,
        cast(invoice_amount_gbp as numeric) as invoice_amount_gbp,
        upper(currency) as currency,
        lower(status) as status,
        updated_at

    from renamed

)

select *
from final