## Setup

### 1. Clone the repository

```bash
git clone <repository-url>
cd <project-directory>
```

### 2. Install dbt with BigQuery adapter

Install the required dbt adapter:

```bash
pip install dbt-bigquery
```

### 3. Configure BigQuery credentials

Configure your Google Cloud / BigQuery credentials and ensure the required permissions are available.

### 4. Configure dbt profile

Configure `profiles.yml` with the appropriate BigQuery project, dataset, location, and authentication settings.

### 5. Install dbt packages

This project uses dbt packages defined in `packages.yml`.

Install them with:

```bash
dbt deps
```

### 6. Load seed data

```bash
dbt seed
```

### 7. Build the dbt models

```bash
dbt run
```

### 8. Run data quality tests

```bash
dbt test
```

### Complete execution

For a fresh environment, run:

```bash
dbt deps
dbt seed
dbt run
dbt test
```

> **Note:** `dbt deps` installs the packages specified in `packages.yml`. The `dbt_packages/` directory itself is not required to be committed to the repository.
