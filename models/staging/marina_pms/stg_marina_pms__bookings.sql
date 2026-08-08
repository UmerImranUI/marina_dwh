SELECT

    booking_id,

    TRIM(customer_full_name) AS customer_full_name,

    CASE
        WHEN raw_contact LIKE '%@%'
        THEN {{ normalize_email('raw_contact') }}
        ELSE NULL
    END AS customer_email,

    CASE
        WHEN raw_contact NOT LIKE '%@%'
        THEN {{ normalize_phone('raw_contact') }}
        ELSE NULL
    END AS customer_phone,

    TRIM(boat_name) AS boat_name,

    {{ normalize_hull_id('hull_id') }} AS hull_id,

    {{ clean_currency('slip_fee') }} AS slip_fee,

    UPPER(TRIM(marina_code)) AS marina_code

FROM {{ source('marina_pms','raw_marina_pms') }}
