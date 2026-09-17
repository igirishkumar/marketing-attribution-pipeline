with source as (

    select *
    from {{ source('posthog', 'sessions') }}

),

renamed as (

    select
        session_id,
        distinct_id as posthog_distinct_id,
        session_date,
        session_start_at,
        session_duration_seconds,
        click_id_from_url,
        fbclid,
        gclid,
        utm_source,
        utm_medium,
        utm_campaign,
        utm_content,
        country_code,
        session_entry_pathname,
        has_checkout_started,
        has_tracknow_conversion,
        events_in_session

    from source

),

final as (

    select
        *,
        
        case
            when gclid is not null then 'google'
            when fbclid is not null then 'meta'
            when lower(utm_source) = 'bing' then 'bing'
            else lower(utm_source)
        end as channel

    from renamed

)

select *
from final