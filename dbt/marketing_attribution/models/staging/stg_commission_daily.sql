with source as (

    select *
    from {{ source('finance', 'commission_google_sheet') }}

),

renamed as (

    select
        commission_date,
        firm_id,
        firm_name,
        sales_amount,
        commission_amount

    from source

),

final as (

    select
        commission_date,
        firm_id,
        firm_name,
        sales_amount,
        commission_amount

    from renamed

)

select *
from final