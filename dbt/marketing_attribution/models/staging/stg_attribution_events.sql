/*
PROPOSED PRODUCTION SOURCE

The exercise dataset does not contain this table.
It represents the first-party tracking instrumentation required
to make attribution deterministic and scalable.
*/

with source as (

    select *
    from {{ source('attribution', 'attribution_events') }}

),

final as (

    select
        event_id,

        event_at,
        event_type,

        posthog_distinct_id,
        posthog_session_id,

        affiliate_click_id,
        affiliate_session_id,

        gclid,
        fbclid,

        utm_source,
        utm_medium,
        utm_campaign,
        utm_content

    from source

)

select *
from final