{{
    config(
        materialized='incremental',
        unique_key='booking_id',
        incremental_strategy='merge',
        partition_by={'field': '_loaded_at', 'data_type': 'timestamp', 'granularity': 'day'},
        cluster_by=['marina_code']
    )
}}
SELECT

    CAST(booking_id AS STRING) AS booking_id,

    TRIM(customer_full_name) AS customer_full_name,

    CASE
        WHEN REGEXP_CONTAINS(
            TRIM(raw_contact),
            r'^[^@\s]+@[^@\s]+\.[^@\s]+$'
        )
        THEN {{ normalize_email('raw_contact') }}
        ELSE NULL
    END AS customer_email,

    CASE
        WHEN NOT REGEXP_CONTAINS(
            TRIM(raw_contact),
            r'^[^@\s]+@[^@\s]+\.[^@\s]+$'
        )
        THEN {{ normalize_phone('raw_contact') }}
        ELSE NULL
    END AS customer_phone,

    TRIM(boat_name) AS boat_name,

    {{ normalize_hull_id('hull_id') }} AS hull_id,

    CAST(
        {{ clean_currency('slip_fee') }}
        AS NUMERIC
    ) AS slip_fee,

    UPPER(TRIM(marina_code)) AS marina_code,

    CURRENT_TIMESTAMP() AS _loaded_at

FROM {{ source('marina_pms', 'raw_marina_pms') }}

{% if is_incremental() %}

WHERE booking_id NOT IN (
    SELECT booking_id
    FROM {{ this }}
)

{% endif %}