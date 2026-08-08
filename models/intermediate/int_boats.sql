with owners as (

    select
        booking_id,
        customer_full_name,
        customer_email,
        customer_phone,
        hull_id,

        lower(trim(customer_email)) as normalized_email,

        regexp_replace(customer_phone, r'[^0-9]', '') as normalized_phone,

        lower(
            regexp_replace(
                trim(customer_full_name),
                r'[^a-z0-9]',
                ''
            )
        ) as normalized_name

    from {{ ref('stg_marina_pms__bookings') }}

),

/*
1. Records with the same normalized phone belong to the same owner.
2. Records with the same normalized email belong to the same owner.
3. If contact information is missing, records with the same hull_id
   and normalized name belong to the same owner.
*/
match_keys as (

    select
        booking_id,
        customer_full_name,
        customer_email,
        customer_phone,
        hull_id,
        normalized_email,
        normalized_phone,
        normalized_name,

        case
            when normalized_phone is not null
                and normalized_phone != ''
            then concat('PHONE:', normalized_phone)

            when normalized_email is not null
                and normalized_email != ''
            then concat('EMAIL:', normalized_email)

            when hull_id is not null
                and normalized_name is not null
                and normalized_name != ''
            then concat(
                'HULL_NAME:',
                upper(trim(hull_id)),
                ':',
                normalized_name
            )
        end as match_key

    from owners

),

/*
Use the resolved matching key to create the owner entity.
*/
resolved_owner as (

    select
        *,
        match_key as owner_cluster_key
    from match_keys
    where match_key is not null

),

resolved_contact as (

    select
        owner_cluster_key,

        max(customer_email) as owner_email,

        max(customer_phone) as owner_phone,

        max(hull_id) as hull_id

    from resolved_owner

    group by owner_cluster_key

),

best_name as (

    select
        owner_cluster_key,
        customer_full_name,

        row_number() over (
            partition by owner_cluster_key
            order by
                length(customer_full_name) desc,
                booking_id
        ) as rn

    from resolved_owner

)

select

    {{ generate_surrogate_key([
        "'owner'",
        "rc.owner_cluster_key"
    ]) }} as owner_id,

    bn.customer_full_name as owner_name,

    rc.owner_email,

    rc.owner_phone,

    rc.hull_id

from resolved_contact rc

join best_name bn
    on bn.owner_cluster_key = rc.owner_cluster_key

    and bn.rn = 1