{{
    config(
        materialized='incremental',
        incremental_strategy='insert_overwrite',
        partition_by={
            'field': 'created_at_utc',
            'data_type': 'timestamp',
            'granularity': 'day'
        },
        cluster_by=['vendor_name', 'status']
    )
}}

with source as (

    select
        work_order_id,
        vendor_name,
        raw_service_type,
        hours_spent,
        status,
        created_at,
        completed_at
    from {{ source('raw', 'raw_vendor_work_orders') }}

    {% if is_incremental() %}

        where timestamp(created_at) >= timestamp_sub(
            current_timestamp(),
            interval 3 day
        )

    {% endif %}

),

cleaned as (

    select
        s.work_order_id,
        s.vendor_name,
        s.raw_service_type,

        coalesce(
            m.standard_category,
            'Unknown'
        ) as service_category,

        s.hours_spent,

        upper(s.status) as status,

        timestamp(s.created_at) as created_at_utc,

        case
            when s.completed_at is not null
            then timestamp(s.completed_at)
        end as completed_at_utc

    from source s

    left join {{ ref('service_category_mapping') }} m
        on lower(trim(s.raw_service_type))
         = lower(trim(m.raw_service_type))

)

select
    work_order_id,
    vendor_name,
    raw_service_type,
    service_category,
    hours_spent,
    status,
    created_at_utc,
    completed_at_utc,
    CURRENT_TIMESTAMP() AS _loaded_at
from cleaned
