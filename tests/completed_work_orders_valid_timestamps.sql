select
    work_order_id
from {{ ref('stg_vendor_orders__work_orders') }}
where upper(status) = 'COMPLETED'
  and (
      completed_at_utc is null
      or created_at_utc is null
      or completed_at_utc < created_at_utc
  )