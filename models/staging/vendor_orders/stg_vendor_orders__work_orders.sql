

with source as (

    select
        work_order_id,
        vendor_name,
        raw_service_type,
        hours_spent,
        status,
        created_at,
        completed_at
    from {{ source('vendor_orders', 'raw_vendor_work_orders') }}



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

        safe_cast( nullif(trim(cast(s.hours_spent as string)), '') as float64 ) as hours_spent,

        upper(s.status) as status,

        timestamp(s.created_at) as created_at_utc,

        safe_cast(nullif(trim(s.completed_at), '') as timestamp) as completed_at_utc

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
