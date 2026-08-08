with owners as (

    select
        booking_id,
        customer_full_name,
        customer_email,
        customer_phone,
        hull_id
    from {{ ref('stg_marina_pms__bookings') }}

),

-- hull_id is a unique physical vessel identifier, so it's the primary key for
-- clustering duplicate owner records — more reliable than email/phone, which
-- vary per row depending on which contact channel was captured (e.g. "John Doe"
-- logged with a phone, "J. Doe" logged with an email, same hull_id).
clustered as (

    select
        *,
        coalesce(hull_id, customer_email, customer_phone) as owner_cluster_key
    from owners

),

-- resolve contact fields per cluster, independent of which row's name wins —
-- Stripe subscriptions join to owners by email, so a non-null email must
-- survive resolution even if the row with the "best" name lacks one
resolved_contact as (

    select
        owner_cluster_key,
        max(customer_email) as owner_email,
        max(customer_phone) as owner_phone,
        max(hull_id) as hull_id
    from clustered
    group by owner_cluster_key

),

best_name as (

    select
        owner_cluster_key,
        customer_full_name,
        row_number() over (
            partition by owner_cluster_key
            order by length(customer_full_name) desc, booking_id
        ) as rn
    from clustered

)

select

    -- int_owners.sql
    {{ generate_surrogate_key(["'owner'", "rc.owner_cluster_key"]) }} as owner_id,
    bn.customer_full_name as owner_name,
    rc.owner_email,
    rc.owner_phone,
    rc.hull_id

from resolved_contact rc
join best_name bn
    on bn.owner_cluster_key = rc.owner_cluster_key
    and bn.rn = 1



    