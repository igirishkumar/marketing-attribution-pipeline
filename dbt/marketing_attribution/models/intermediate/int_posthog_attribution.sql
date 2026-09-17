with sessions as (

    select *
    from {{ ref('stg_posthog_sessions') }}

),

final as (

    select
        session_id as posthog_session_id,
        posthog_distinct_id,
        session_date,
        session_start_at,

        channel,

        gclid,
        fbclid,

        utm_source,
        utm_medium,
        utm_campaign,
        utm_content,

        country_code,
        session_entry_pathname,

        has_checkout_started,
        has_tracknow_conversion,
        events_in_session

    from sessions

)

select *
from final