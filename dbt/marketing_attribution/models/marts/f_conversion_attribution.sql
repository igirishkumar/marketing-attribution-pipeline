with attributed_conversions as (

    select *
    from {{ ref('int_conversion_attribution') }}

),

firms as (

    select
        id as firm_id,
        name as firm_name
    from {{ source('firms', 'firms') }}

),

final as (

    select
        c.tracknow_order_id,
        c.created_at as conversion_at,

        c.firm_id,
        f.firm_name,

        c.click_id,
        c.affiliate_session_id,
        c.tracknow_user_id,

        c.posthog_session_id,
        c.posthog_distinct_id,

        c.channel,
        c.gclid,
        c.fbclid,

        c.utm_source,
        c.utm_medium,
        c.utm_campaign,
        c.utm_content as ad_id,

        c.order_price,
        c.referral_bonus as commission_gbp,

        c.status as conversion_status,
        c.attribution_status,
        c.match_method as attribution_method

    from attributed_conversions c

    left join firms f
        on c.firm_id = f.firm_id

)

select *
from final