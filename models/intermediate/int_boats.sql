-- int_boats.sql
--
-- hull_id is already standardized in staging (stg_marina_pms__bookings), so
-- this model just needs to dedupe bookings down to one canonical row per
-- physical vessel and pick a canonical boat_name.
--
-- Canonical name selection mirrors int_owners' best_name logic: prefer the
-- longer, more fully-written name (e.g. "Sea Breeze" over "Seabreeze") rather
-- than an arbitrary alphabetical pick, since a longer name is more likely to
-- be the properly formatted / most complete version on file. booking_id is
-- the tiebreaker so the choice is deterministic when names tie on length.

with boats as (

    select
        booking_id,
        hull_id,
        boat_name

    from {{ ref('stg_marina_pms__bookings') }}

),

ranked as (

    select
        *,
        row_number() over (
            partition by hull_id
            order by
                length(boat_name) desc,
                booking_id
        ) as rn

    from boats

)

select
    {{ generate_surrogate_key(["'boat'", "hull_id"]) }} as boat_id,
    hull_id,
    boat_name

from ranked
where rn = 1