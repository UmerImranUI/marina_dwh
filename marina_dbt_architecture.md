# Marina Analytics Warehouse — dbt Project Architecture

## Directory structure

```
marina_analytics/
├── dbt_project.yml
├── packages.yml                      # dbt_utils, dbt_expectations
├── profiles.yml                      # (kept out of repo / in ~/.dbt)
├── README.md
│
├── models/
│   ├── staging/
│   │   ├── marina_pms/
│   │   │   ├── _marina_pms__sources.yml
│   │   │   ├── _marina_pms__models.yml     # schema tests: not_null, unique
│   │   │   └── stg_marina_pms__bookings.sql
│   │   ├── vendor_orders/
│   │   │   ├── _vendor_orders__sources.yml
│   │   │   ├── _vendor_orders__models.yml
│   │   │   └── stg_vendor_orders__work_orders.sql
│   │   └── stripe/
│   │       ├── _stripe__sources.yml
│   │       ├── _stripe__models.yml
│   │       └── stg_stripe__subscriptions.sql
│   │
│   ├── intermediate/
│   │   ├── _intermediate__models.yml
│   │   ├── int_owners_deduplicated.sql     # ROW_NUMBER() dedup on normalized contact
│   │   ├── int_owners_surrogate_keys.sql   # generate_surrogate_key(email_norm)
│   │   ├── int_boats_matched.sql           # match on normalized hull_id
│   │   └── int_work_orders_categorized.sql # service-type normalization join
│   │
│   ├── marts/
│   │   ├── core/
│   │   │   ├── _core__models.yml
│   │   │   ├── dim_owners.sql
│   │   │   ├── dim_boats.sql
│   │   │   └── dim_vendors.sql
│   │   └── finance_ops/
│   │       ├── _finance_ops__models.yml
│   │       ├── fct_subscriptions.sql
│   │       ├── fct_work_orders.sql
│   │       └── mrt_executive_kpis.sql      # MRR/ARR, utilization, response time
│   │
│   └── sources.yml                          # (or split per staging folder, as above)
│
├── seeds/
│   └── seed_vendor_service_category_map.csv # raw_service_type → standard category
│
├── macros/
│   ├── generate_surrogate_key.sql           # or use dbt_utils.generate_surrogate_key
│   ├── normalize_phone.sql
│   ├── normalize_email.sql
│   └── clean_currency_string.sql            # "$1,200.00" → 1200.00
│
├── tests/
│   ├── generic/
│   │   └── assert_positive_mrr.sql
│   └── singular/
│       ├── assert_no_duplicate_owner_ids.sql
│       └── assert_completed_at_after_created_at.sql
│
├── analyses/
│   └── ad_hoc_kpi_validation.sql
│
├── snapshots/
│   └── owners_snapshot.sql                  # SCD2 for slip_fee / plan changes over time
│
└── docs/
    └── pipeline_architecture.png            # or .drawio / .excalidraw source
```

## Why this layout maps to the evaluation matrix

**Data modeling (staging → intermediate → mart)**
Raw sources are never queried directly outside `staging/`. `stg_*` models do 1:1 casting/renaming only — no business logic. `int_*` models own entity resolution (this is where `Owner_ID` and `Boat_ID` surrogate keys are generated, deterministically, via `dbt_utils.generate_surrogate_key(['normalized_email'])` or similar hash logic — never a raw autoincrement). `marts/` is the only layer exposed to BI tools.

**SQL & dbt proficiency**
- `seed_vendor_service_category_map.csv` replaces inline `CASE WHEN` sprawl for service-type normalization — one reusable lookup instead of hardcoded mappings duplicated across models.
- `int_owners_deduplicated.sql` uses `ROW_NUMBER() OVER (PARTITION BY normalized_email ORDER BY booking_id)` to pick a canonical record per resolved owner rather than a cursor/loop.
- Currency/phone/email cleaning lives in macros (`macros/`), so the same normalization logic is reused across `stg_marina_pms` and any future source, not copy-pasted.

**Scale & architecture**
- `fct_work_orders.sql` is set up as an **incremental model** (`materialized='incremental'`, `unique_key='work_order_id'`) with `is_incremental()` filtering on `created_at`, so a 100M-row table doesn't get fully rebuilt nightly.
- Model configs (in `dbt_project.yml` or model `config()` blocks) set `partition_by` on `created_at` and `cluster_by` on `marina_code` / `vendor_id` for BigQuery, or clustering keys for Snowflake — pruning scans instead of full-table scans.
- `snapshots/` gives you SCD2 history for slowly-changing dimensions (e.g., plan/price changes) without re-scanning raw history each run.

**Business alignment**
`mrt_executive_kpis.sql` is the single model that computes MRR, ARR, vendor utilization, and response time — each metric traceable back through `fct_*` and `dim_*` to a named business definition, not buried in a BI tool's calculated field.

## Data flow (matches the diagram above)

1. **Raw** (`raw_marina_pms`, `raw_vendor_work_orders`, `raw_stripe_subscriptions`) — untouched source tables/CSVs.
2. **Staging** (`stg_*`) — cast types, standardize timestamps to UTC, clean currency strings, rename columns to consistent snake_case. No joins, no business logic.
3. **Intermediate** (`int_*`) — entity resolution (`Owner_ID`, `Boat_ID` surrogate keys), vendor service-type categorization via the seed lookup.
4. **Marts** (`dim_*`, `fct_*`, `mrt_executive_kpis`) — the presentation layer. This is what the executive dashboard queries.
5. **Tests** run at every layer boundary: `not_null`/`unique` on staging primary keys, relationship tests from `fct_*` to `dim_*`, and custom singular tests (e.g., `completed_at >= created_at`, no duplicate `owner_id`).

## PII / governance note (for your presentation)

Keep raw PII (email, phone) only in `staging` and `intermediate`. In `marts/`, expose `owner_id` (the hashed surrogate key) and, if needed, a masked/tokenized contact field — not raw email/phone — so the BI layer and any downstream consumers never see raw contact info. Column-level security or dynamic data masking (Snowflake) / column-level access policies (BigQuery) can enforce this at the warehouse layer.
