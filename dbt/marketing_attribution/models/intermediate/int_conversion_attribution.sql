/*
PROPOSED PRODUCTION ATTRIBUTION MODEL

The supplied exercise dataset does not contain the first-party
attribution-events source required for a deterministic TrackNow-to-PostHog
bridge. The model below shows the intended production implementation.
*/


with conversions as (

    select *
    from {{ ref('int_tracknow_conversions') }}

),

bridge as (

    select *
    from {{ ref('int_attribution_bridge') }}

),

posthog as (

    select *
    from {{ ref('int_posthog_attribution') }}

),

candidate_matches as (

    select
        c.tracknow_order_id,
        c.created_at,
        c.firm_id,
        c.status,
        c.order_price,
        c.referral_bonus,

        c.click_id,
        c.affiliate_session_id,
        c.tracknow_user_id,

        p.posthog_session_id,
        p.posthog_distinct_id,

        p.channel,
        p.gclid,
        p.fbclid,

        p.utm_source,
        p.utm_medium,
        p.utm_campaign,
        p.utm_content,

        case
            when b.affiliate_click_id = c.click_id
                then 'exact_click_id'

            when b.affiliate_session_id = c.affiliate_session_id
                then 'exact_affiliate_session'

            else null
        end as match_method,

        case
            when b.affiliate_click_id = c.click_id
                then 1

            when b.affiliate_session_id = c.affiliate_session_id
                then 2

            else 99
        end as match_priority

    from conversions c

    left join bridge b
        on (
            b.affiliate_click_id = c.click_id
            or b.affiliate_session_id = c.affiliate_session_id
        )

    left join posthog p
        on b.posthog_session_id = p.posthog_session_id

),

ranked as (

    select
        *,
        row_number() over (
            partition by tracknow_order_id
            order by match_priority
        ) as attribution_rank

    from candidate_matches

),

final as (

    select
        tracknow_order_id,
        created_at,
        firm_id,
        status,
        order_price,
        referral_bonus,

        click_id,
        affiliate_session_id,
        tracknow_user_id,

        posthog_session_id,
        posthog_distinct_id,

        channel,
        gclid,
        fbclid,

        utm_source,
        utm_medium,
        utm_campaign,
        utm_content,

        match_method,

        case
            when match_method is not null then 'attributed'
            else 'unattributed'
        end as attribution_status

    from ranked

    where attribution_rank = 1

)

select *
from final