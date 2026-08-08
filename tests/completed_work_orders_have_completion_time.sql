select
    work_order_id
from {{ ref('stg_vendor_orders__work_orders') }}
where upper(status) = 'COMPLETED'
  and completed_at_utc is null