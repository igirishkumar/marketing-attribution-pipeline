/*
PROPOSED PRODUCTION MODEL

The exercise dataset does not contain this source.
This model represents the persisted first-party relationship
between TrackNow affiliate identifiers and PostHog sessions.
*/

with events as (

    select *
    from {{ ref('stg_attribution_events') }}

),

ranked as (

    select
        event_id,
        event_at,

        affiliate_click_id,
        affiliate_session_id,

        posthog_session_id,
        posthog_distinct_id,

        gclid,
        fbclid,

        utm_source,
        utm_medium,
        utm_campaign,
        utm_content,

        case
            when affiliate_click_id is not null
                then 'exact_click_id'

            when affiliate_session_id is not null
                then 'exact_affiliate_session'

            when posthog_distinct_id is not null
                then 'user_fallback'

            else null
        end as match_method,

        case
            when affiliate_click_id is not null then 1
            when affiliate_session_id is not null then 2
            when posthog_distinct_id is not null then 3
            else 99
        end as match_priority,

        row_number() over (
            partition by
                affiliate_click_id,
                posthog_session_id
            order by event_at desc
        ) as row_num

    from events

    where affiliate_click_id is not null
       or affiliate_session_id is not null
       or posthog_distinct_id is not null

)

select
    event_id,
    event_at,

    affiliate_click_id,
    affiliate_session_id,

    posthog_session_id,
    posthog_distinct_id,

    gclid,
    fbclid,

    utm_source,
    utm_medium,
    utm_campaign,
    utm_content,

    match_method,
    match_priority

from ranked

where row_num = 1