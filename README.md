# Marina Data Warehouse POC

A production-style cloud data warehouse proof of concept designed to demonstrate an end-to-end modern data engineering architecture for a marina business.

The platform combines data ingestion, orchestration, ELT transformation, dimensional modeling, data quality, warehouse optimization, and BI reporting.

## Architecture

```text
Operational Sources
        │
        ▼
     Airbyte
        │
        ▼
   BigQuery Raw
        │
        ▼
     dbt Models
        │
        ├── Staging
        ├── Intermediate
        └── Data Marts
                 │
                 ▼
        Dimensional / Star Schema
                 │
                 ▼
             BigQuery
                 │
                 ▼
          Looker Studio
```

Apache Airflow orchestrates the pipeline and manages task dependencies and data quality validation.

---

## Technology Stack

| Component | Technology | Purpose |
|---|---|---|
| Data Ingestion | Airbyte | Synchronize source data into BigQuery |
| Orchestration | Apache Airflow | Schedule and orchestrate pipeline execution |
| Data Warehouse | Google BigQuery | Cloud analytical warehouse |
| Transformation | dbt | SQL-based ELT transformations |
| Data Modeling | Dimensional / Star Schema | Analytics-ready data structures |
| Data Quality | dbt Tests | Validate transformed datasets |
| BI / Reporting | Looker Studio | Business reporting and visualization |

---

## Data Pipeline

The platform follows a layered ELT architecture.

### 1. Data Ingestion

Airbyte synchronizes operational source data into the BigQuery raw layer.

The ingestion layer is separated from transformation logic so that source synchronization and analytical transformations can evolve independently.

```text
Operational Sources
        │
        ▼
     Airbyte
        │
        ▼
   BigQuery Raw
```

---

### 2. Data Transformation

dbt transforms raw source data through three logical layers:

```text
Raw
 │
 ▼
Staging
 │
 ▼
Intermediate
 │
 ▼
Data Marts
```

### Staging

The staging layer is responsible for source-level preparation, including:

- Data type casting
- Column standardization
- Data cleaning
- Normalization
- Basic source transformations

### Intermediate

The intermediate layer contains reusable business logic and entity-level transformations, including:

- Entity resolution
- Deduplication
- Business rules
- Combining related source entities

### Data Marts

The mart layer provides analytics-ready datasets for reporting and business analysis.

Examples include:

- Business metrics
- Aggregated KPIs
- Reporting-ready entities
- Analytical fact and dimension models

---

## Dimensional Modeling

The analytical layer follows a dimensional modeling approach using fact and dimension structures.

### Example Dimensions

- Owners
- Boats
- Vendors

### Example Facts / Metrics

- Work Orders
- Revenue
- Vendor Utilization
- Response Time

The purpose of the dimensional layer is to provide a consistent analytical model while keeping complex source-system logic away from downstream reporting users.

---

## Orchestration

Apache Airflow is used to orchestrate the pipeline and enforce dependencies between ingestion, transformation, and validation steps.

The intended execution flow is:

```text
Airbyte Sync
     │
     ▼
dbt Staging
     │
     ▼
Staging Tests
     │
     ▼
dbt Intermediate
     │
     ▼
Intermediate Tests
     │
     ▼
dbt Marts
     │
     ▼
Mart Tests
```

This dependency-driven approach allows individual stages to fail independently and prevents downstream transformations from executing when upstream validation fails.

---

## Data Quality

Data quality validation is integrated into the transformation workflow.

```text
Transform
    │
    ▼
  Test
    │
    ▼
Continue
```

dbt tests can be used to validate:

- Not-null constraints
- Uniqueness
- Referential integrity
- Accepted values
- Relationships between models

The objective is to prevent invalid or inconsistent data from reaching downstream analytical models.

---

## BigQuery Optimization

The warehouse architecture is designed with scalability and cost efficiency in mind.

The project uses or considers techniques such as:

- Incremental processing
- Partitioning
- Clustering
- Appropriate dbt materializations
- Selective data processing
- Query optimization

These techniques help reduce unnecessary processing and improve warehouse performance as data volume increases.

---

## Analytics & Reporting

The curated BigQuery data marts serve as the reporting layer for Looker Studio.

The goal is to centralize business logic within the data warehouse rather than duplicating complex calculations across individual dashboards.

Example analytical outputs include:

- Executive KPIs
- Revenue analysis
- Work-order performance
- Vendor performance
- Utilization metrics
- Response-time analysis

### Looker Studio

_Add dashboard screenshot here._

```text
BigQuery Data Marts
        │
        ▼
  Looker Studio
        │
        ▼
 Business Reporting
```

---

## Project Structure

```text
marina_dwh/
│
├── airflow/
│   └── dags/
│
├── models/
│   ├── staging/
│   ├── intermediate/
│   └── marts/
│
├── macros/
├── seeds/
├── tests/
├── dbt_project.yml
├── packages.yml
└── README.md
```

---

# Setup

## 1. Clone the repository

```bash
git clone <repository-url>
cd <project-directory>
```

## 2. Install dbt with BigQuery adapter

Install the required dbt adapter:

```bash
pip install dbt-bigquery
```

## 3. Configure BigQuery credentials

Configure your Google Cloud / BigQuery credentials and ensure the required permissions are available.

Do not commit credentials, service-account keys, or other secrets to the repository.

## 4. Configure dbt profile

Configure `profiles.yml` with the appropriate:

- BigQuery project
- Dataset
- Location
- Authentication settings

## 5. Install dbt packages

This project uses dbt packages defined in `packages.yml`.

Install them with:

```bash
dbt deps
```

## 6. Load seed data

```bash
dbt seed
```

## 7. Build the dbt models

```bash
dbt run
```

## 8. Run data quality tests

```bash
dbt test
```

### Complete execution

For a fresh environment:

```bash
dbt deps
dbt seed
dbt run
dbt test
```

> **Note:** `dbt deps` installs the packages specified in `packages.yml`. The `dbt_packages/` directory itself is not required to be committed to the repository.

---

## Key Engineering Principles

This project demonstrates the following data engineering practices:

- Separation of ingestion and transformation
- Layered dbt architecture
- Dimensional data modeling
- Centralized business logic
- Automated data quality validation
- Incremental data processing
- BigQuery performance optimization
- Dependency-driven orchestration
- Analytics-ready data marts
- Separation of warehouse and BI responsibilities

---

## Project Disclaimer

This repository is a **portfolio / proof-of-concept implementation**.

The project uses sanitized or synthetic data and does not contain confidential credentials, proprietary production data, or sensitive client information.

The architecture is designed to demonstrate production-style data engineering patterns, scalability considerations, and analytical modeling practices.
