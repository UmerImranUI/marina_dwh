
with source as (

    select *
    from {{ source('vendor_orders', 'raw_vendor_work_orders') }}

),

cleaned as (

    select

        upper(trim(work_order_id)) as work_order_id,

        initcap(trim(vendor_name)) as vendor_name,

        lower(trim(raw_service_type)) as raw_service_type,

        cast(hours_spent as numeric) as hours_spent,

        upper(trim(status)) as status,

        safe_cast(nullif(created_at, '') as timestamp) as created_at_utc,

        safe_cast(nullif(completed_at, '') as timestamp) as completed_at_utc

    from source

),

mapped as (

    select

        c.*,

        coalesce(
            m.standard_category,
            'Unknown'
        ) as service_category

    from cleaned c

    left join {{ ref('service_category_mapping') }} m
        on lower(trim(c.raw_service_type)) = lower(trim(m.raw_service_type))

)

select *
from mapped



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

