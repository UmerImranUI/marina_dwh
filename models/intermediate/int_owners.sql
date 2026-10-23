-- int_owners.sql

WITH owners AS (
    SELECT
        booking_id,
        customer_full_name,
        NULLIF(TRIM(customer_email), '') AS customer_email,
        NULLIF(REGEXP_REPLACE(customer_phone, r'[^0-9]', ''), '') AS customer_phone,
        hull_id
    FROM {{ ref('stg_marina_pms__bookings') }}
),

-- cleaning
normalized AS (
    SELECT
        *,
        LOWER(customer_email) AS email_norm,

        -- Name key used ONLY for the hull_id fallback (rule 3)
        -- Collapses "John Doe" / "J. Doe" to the same
        -- last-name + first-initial signature
        LOWER(
            REGEXP_EXTRACT(
                TRIM(customer_full_name),
                r'(\S+)$'
            )
        )
        || '_'
        || LOWER(LEFT(TRIM(customer_full_name), 1)) AS name_key

    FROM owners
),

-- Rules 1 & 2: phone/email are the primary, authoritative match signals
-- match by email or phone
primary_matched AS (
    SELECT
        *,
        MIN(booking_id) OVER (
            PARTITION BY customer_phone
        ) AS phone_group,

        MIN(booking_id) OVER (
            PARTITION BY email_norm
        ) AS email_group

    FROM normalized
),

-- A row could link to one owner via phone and another via email,
-- so this is a connected-components problem, not a plain group-by
edges AS (
    SELECT
        booking_id,
        phone_group AS group_key
    FROM primary_matched
    WHERE customer_phone IS NOT NULL

    UNION ALL

    SELECT
        booking_id,
        email_group AS group_key
    FROM primary_matched
    WHERE email_norm IS NOT NULL
),
-- booking_id	group_key	Relationship
-- BK-101	BK-101	Phone
-- BK-102	BK-101	Phone
-- BK-101	BK-101	Email
-- BK-102	BK-101	Email

-- create relationships of how they're intented to be joined together
components AS (
    SELECT
        booking_id,
        MIN(group_key) OVER (
            PARTITION BY group_key
        ) AS component_id

    FROM edges
),

-- booking_id	Intended component_id
-- BK-101	BK-101
-- BK-102	BK-101
-- BK-103	BK-101

primary_clusters AS (
    SELECT
        p.*,
        COALESCE(
            c.component_id,
            p.booking_id
        ) AS primary_cluster_id,

        -- Did this row actually find a phone/email match with another row?
        COUNT(*) OVER (
            PARTITION BY COALESCE(
                c.component_id,
                p.booking_id
            )
        ) > 1 AS matched_by_primary

    FROM primary_matched p

    LEFT JOIN components c
        USING (booking_id)
),

-- Rule 3: only rows that found NO phone/email match
-- fall back to hull_id + name
final_keyed AS (
    SELECT
        *,
        CASE
            WHEN matched_by_primary
                THEN CAST(primary_cluster_id AS STRING)
            ELSE hull_id || '|' || name_key
        END AS owner_cluster_key

    FROM primary_clusters
),

-- booking_id	hull_id	name_key	matched_by_primary	owner_cluster_key
-- BK-101	BOAT-1	doe_j	TRUE	BK-101
-- BK-102	BOAT-1	doe_j	TRUE	BK-101
-- BK-103	BOAT-1	doe_j	FALSE	BOAT-1\|doe_j
-- BK-104	BOAT-2	lee_s	FALSE	BOAT-2\|lee_s

resolved_contact AS (
    SELECT
        owner_cluster_key,
        MAX(customer_email) AS owner_email,
        MAX(customer_phone) AS owner_phone,
        MAX(hull_id) AS hull_id

    FROM final_keyed

    GROUP BY owner_cluster_key
),

-- deduplication:
-- owner_cluster_key	customer_email	customer_phone
-- BK-101	john@email.com	5551234567
-- BK-101	john.alt@email.com	5551234567

best_name AS (
    SELECT
        owner_cluster_key,
        customer_full_name,

        ROW_NUMBER() OVER (
            PARTITION BY owner_cluster_key
            ORDER BY
                LENGTH(customer_full_name) DESC,
                booking_id
        ) AS rn

    FROM final_keyed
)

-- owner_cluster_key	customer_full_name	Length	rn
-- BK-101	John Doe	8	1
-- BK-101	J. Doe	6	2

SELECT
    {{ dbt_utils.generate_surrogate_key(['rc.owner_cluster_key']) }} AS owner_id,
    bn.customer_full_name AS owner_name,
    rc.owner_email,
    rc.owner_phone,
    rc.hull_id

FROM resolved_contact rc

JOIN best_name bn
    ON bn.owner_cluster_key = rc.owner_cluster_key
    AND bn.rn = 1