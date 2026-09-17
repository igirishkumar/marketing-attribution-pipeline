with source as (

    select *
    from {{ ref('stg_tracknow_checkouts') }}

),

deduplicated as (

    select
        *,
        row_number() over (
            partition by tracknow_order_id
            order by created_at desc
        ) as row_num

    from source

),

final as (

    select
        tracknow_order_id,
        created_at,
        click_id,
        affiliate_session_id,
        firm_id,
        status,
        order_price,
        referral_bonus,
        coupon_used,
        trading_platform,
        first_order,
        tracknow_user_id,
        is_active_conversion

    from deduplicated
    where row_num = 1

)

select *
from final