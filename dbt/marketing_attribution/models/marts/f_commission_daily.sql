with source as (

    select *
    from {{ ref('stg_commission_daily') }}

),

final as (

    select
        commission_date,
        firm_id,
        firm_name,
        sales_amount,
        commission_amount

    from source

)

select *
from final