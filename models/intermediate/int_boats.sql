
with boats as (

    select

        hull_id,

        boat_name

    from {{ ref('stg_marina_pms__bookings') }}

),

ranked as (

    select *

        ,

        row_number() over (

            partition by hull_id

            order by boat_name

        ) as rn

    from boats

)

select

    -- int_boats.sql
    {{ generate_surrogate_key(["'boat'", "hull_id"]) }} as boat_id,

    hull_id,

    boat_name

from ranked

where rn = 1