from google.cloud import bigquery
from google.oauth2 import service_account
import pandas as pd

# ==============================
# Configuration
# ==============================

SERVICE_ACCOUNT_FILE = "marina-sa.json"

PROJECT_ID = "general-analytics-504713"
DATASET_ID = "marina_project"

FILES = {
    # "seeds/raw_marina_pms.csv": "raw_marina_pms",
    "seeds/raw_stripe_subscriptions.csv": "raw_stripe_subscriptions",
    # "seeds/raw_vendor_work_orders.csv": "raw_vendor_work_orders"
}

# ==============================
# Authenticate
# ==============================

credentials = service_account.Credentials.from_service_account_file(
    SERVICE_ACCOUNT_FILE
)

client = bigquery.Client(
    credentials=credentials,
    project=PROJECT_ID
)

# ==============================
# Upload Function
# ==============================

def upload_csv(csv_file, table_name):

    # Read everything as string
    df = pd.read_csv(
        csv_file,
        dtype=str,
        keep_default_na=False
    )

    # Ensure all columns remain strings
    df = df.astype(str)

    table_id = f"{PROJECT_ID}.{DATASET_ID}.{table_name}"

    schema = [
        bigquery.SchemaField(col, "STRING")
        for col in df.columns
    ]

    job_config = bigquery.LoadJobConfig(
        schema=schema,
        write_disposition="WRITE_TRUNCATE"
    )

    job = client.load_table_from_dataframe(
        dataframe=df,
        destination=table_id,
        job_config=job_config
    )

    job.result()

    print(f"Uploaded {csv_file} -> {table_id}")
    print(f"Rows Loaded : {len(df)}")


# ==============================
# Main
# ==============================

for file_name, table_name in FILES.items():
    upload_csv(file_name, table_name)

print("\nFinished!")