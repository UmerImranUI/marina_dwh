-- mrt_executive_kpis.sql
--
-- Executive KPI mart. Grain: one row per (metric_group, dimension_type, dimension_value, metric_name).
--
-- Why a long/tall format instead of one wide table: the three required metrics live at
-- different natural grains (company-wide revenue vs. per-vendor utilization vs. per-vendor
-- response time). Forcing them into a single wide row would mean fanning out revenue across
-- every vendor row or padding nulls. A metric-fact table keeps one clean grain, lets BI tools
-- (Looker/Tableau/Metabase) filter by metric_group and pivot as needed, and avoids adding
-- extra mart models.
--
-- Assumes staging models: stg_stripe__subscriptions, stg_vendor_orders__work_orders
-- (naming mirrors the existing stg_marina_pms__bookings convention). Update the ref() calls
-- below if your staging model names differ.

{{
    config(
        materialized='table',
        cluster_by=['metric_group', 'dimension_type']
    )
}}

with

------------------------------------------------------------------------------
-- 1. MRR & ARR
------------------------------------------------------------------------------

stripe_subs as (

    select
        sub_id,
        customer_email,
        plan_name,
        mrr_amount,
        event_type,
        event_timestamp

    from {{ source('raw','raw_stripe_subscriptions') }}

),

-- collapse each subscription down to its most recent lifecycle event so a sub
-- that later churned/downgraded isn't double-counted as still active
latest_sub_event as (

    select
        *,
        row_number() over (
            partition by sub_id
            order by event_timestamp desc
        ) as rn
    from stripe_subs

),

active_subs as (

    select
        sub_id,
        customer_email,
        plan_name,
        mrr_amount
    from latest_sub_event
    where rn = 1
        -- keep anything that isn't an explicit cancellation/churn event
        and lower(event_type) not in ('canceled', 'cancelled', 'churn', 'churned')

),

-- attach resolved owner identity so revenue can be sliced by a clean customer
-- entity rather than a raw, possibly-duplicated Stripe email
active_subs_resolved as (

    select
        s.sub_id,
        s.plan_name,
        s.mrr_amount,
        o.owner_id,
        o.owner_name
    from active_subs s
    left join {{ ref('int_owners') }} o
        on lower(s.customer_email) = lower(o.owner_email)

),

revenue_metrics as (

    -- company-wide headline numbers
    select
        'REVENUE' as metric_group,
        'COMPANY' as dimension_type,
        'ALL' as dimension_value,
        'ACTIVE_MRR' as metric_name,
        cast(round(sum(mrr_amount), 2) as float64) as metric_value,
        'USD' as unit
    from active_subs_resolved

    union all

    select
        'REVENUE',
        'COMPANY',
        'ALL',
        'ARR',
        cast(round(sum(mrr_amount) * 12, 2) as float64),
        'USD'
    from active_subs_resolved

    -- metric_group	dimension_type	dimension_value	metric_name	metric_value	unit
    -- REVENUE	COMPANY	ALL	ACTIVE_MRR	5000	USD
    -- REVENUE	COMPANY	ALL	ARR	60000	USD

    union all

    -- per-owner breakdown
    select
        'REVENUE',
        'OWNER',
        coalesce(owner_id, 'UNMATCHED'),
        'ACTIVE_MRR',
        cast(round(sum(mrr_amount), 2) as float64),
        'USD'
    from active_subs_resolved
    group by owner_id

    -- dimension_value	metric_name	metric_value
    -- ID_A123	ACTIVE_MRR	300
    -- ID_B456	ACTIVE_MRR	50

    union all

    select
        'REVENUE',
        'OWNER',
        coalesce(owner_id, 'UNMATCHED'),
        'ARR',
        cast(round(sum(mrr_amount) * 12, 2) as float64),
        'USD'
    from active_subs_resolved
    group by owner_id

),

------------------------------------------------------------------------------
-- 2. Captain / Vendor Utilization
------------------------------------------------------------------------------

vendor_orders as (

    select
        work_order_id,
        vendor_name,
        hours_spent
    from {{ ref('stg_vendor_orders__work_orders') }}

),

vendor_utilization_agg as (

    select
        vendor_name,
        sum(hours_spent) as total_billable_hours,
        count(distinct work_order_id) as total_jobs
    from vendor_orders
    group by vendor_name

),
    -- work_order_id	vendor_name	hours_spent
    -- WO-1	Vendor A	2
    -- WO-2	Vendor A	3
    -- WO-3	Vendor A	5
    -- WO-4	Vendor B	4

vendor_utilization_metrics as (

    select
        'VENDOR_UTILIZATION' as metric_group,
        'VENDOR' as dimension_type,
        vendor_name as dimension_value,
        'TOTAL_BILLABLE_HOURS' as metric_name,
        cast(round(total_billable_hours, 2) as float64) as metric_value,
        'HOURS' as unit
    from vendor_utilization_agg

    union all

    select
        'VENDOR_UTILIZATION',
        'VENDOR',
        vendor_name,
        'TOTAL_JOBS',
        cast(total_jobs as float64),
        'COUNT'
    from vendor_utilization_agg

    union all

    -- billable hours delivered per logged job = utilization rate per the case study definition
    select
        'VENDOR_UTILIZATION',
        'VENDOR',
        vendor_name,
        'UTILIZATION_HOURS_PER_JOB',
        cast(round(safe_divide(total_billable_hours, total_jobs), 2) as float64),
        'HOURS_PER_JOB'
    from vendor_utilization_agg

    -- dimension_value	metric_name	metric_value	unit
    -- Vendor A	TOTAL_BILLABLE_HOURS	10	HOURS
    -- Vendor A	TOTAL_JOBS	3	COUNT
    -- Vendor A	UTILIZATION_HOURS_PER_JOB	3.33	HOURS_PER_JOB

),

------------------------------------------------------------------------------
-- 3. Vendor Response Time
------------------------------------------------------------------------------

completed_orders as (

    select
        work_order_id,
        vendor_name,
        created_at_utc,
        completed_at_utc,
        timestamp_diff(completed_at_utc, created_at_utc, minute) / 60.0 as turnaround_hours
    from {{ ref('stg_vendor_orders__work_orders') }}
    where upper(status) = 'COMPLETED'
        and completed_at_utc is not null

),
    -- work_order_id	created_at_utc	completed_at_utc	turnaround_hours
    -- WO-1	08:00	10:00	2
    -- WO-2	09:00	12:30	3.5
    -- WO-3	10:00	11:30	1.5

vendor_response_agg as (

    select
        vendor_name,
        avg(turnaround_hours) as avg_response_hours,
        count(work_order_id) as completed_job_count
    from completed_orders
    group by vendor_name

),

    -- vendor_name	avg_response_hours	completed_job_count
    -- Vendor A	2.33	3
vendor_response_metrics as (

    select
        'VENDOR_RESPONSE_TIME' as metric_group,
        'VENDOR' as dimension_type,
        vendor_name as dimension_value,
        'AVG_RESPONSE_TIME_HOURS' as metric_name,
        cast(round(avg_response_hours, 2) as float64) as metric_value,
        'HOURS' as unit
    from vendor_response_agg

    union all

    select
        'VENDOR_RESPONSE_TIME',
        'VENDOR',
        vendor_name,
        'COMPLETED_JOB_COUNT',
        cast(completed_job_count as float64),
        'COUNT'
    from vendor_response_agg

    union all

    -- company-wide rollup so the exec dashboard can show one headline number
    -- alongside the per-vendor breakdown, without a separate model
    select
        'VENDOR_RESPONSE_TIME',
        'COMPANY',
        'ALL',
        'AVG_RESPONSE_TIME_HOURS',
        cast(round(avg(turnaround_hours), 2) as float64),
        'HOURS'
    from completed_orders

),

------------------------------------------------------------------------------
-- Final union
------------------------------------------------------------------------------

final as (

    select * from revenue_metrics
    union all
    select * from vendor_utilization_metrics
    union all
    select * from vendor_response_metrics

)

select
    {{ generate_surrogate_key(['metric_group', 'dimension_type', 'dimension_value', 'metric_name']) }} as metric_id,
    metric_group,
    dimension_type,
    dimension_value,
    metric_name,
    metric_value,
    unit,
    current_timestamp() as calculated_at
from final