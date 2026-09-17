with source as (

    select *
    from {{ source('tracknow', 'checkouts') }}

),

renamed as (

    select
        id as tracknow_order_id,
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
        user_id as tracknow_user_id

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

        case
            when status = 'active' then true
            else false
        end as is_active_conversion

    from renamed

)

select *
from final