> Part of [terradart-cookbook](../../README.md). Library: [terradart](https://github.com/nozomi-koborinai/terradart).

# coffee-shop

Webhook-driven coffee order tracker. Demonstrates terradart end-to-end with a real-world stack on Google Cloud.

## Architecture

- Cloud Run v2 service receives webhook POSTs at `/order`.
- Cloud SQL (Postgres, private IP) persists orders.
- Secret Manager stores the DB password.
- Pub/Sub topic emits `order.created` events; a Pub/Sub push subscription invokes the same Cloud Run service.
- Cloud Monitoring covers an uptime check + alert policy + email notification channel.

~30 resources across 8 terradart barrels: `project`, `iam`, `service_networking`, `compute`, `cloud_sql`, `secret_manager`, `cloud_run`, `pubsub`, `monitoring`.

## Required APIs

The recipe enables the following APIs via `google_project_service` resources — you do not need to enable them manually first:

- `compute.googleapis.com` (Compute Engine — VPC, addresses)
- `iam.googleapis.com` (IAM)
- `monitoring.googleapis.com` (Cloud Monitoring)
- `pubsub.googleapis.com` (Pub/Sub)
- `run.googleapis.com` (Cloud Run)
- `secretmanager.googleapis.com` (Secret Manager)
- `servicenetworking.googleapis.com` (Service Networking — Cloud SQL private peering)
- `sqladmin.googleapis.com` (Cloud SQL)

Storage is typically already enabled on a fresh GCP project. If any of the above are missing on first apply, `terraform plan` will surface a clear 403 error pointing to the missing API.

## Cost notes

This recipe provisions billable resources. Rough estimates if left running 24h in `asia-northeast1`:

- Cloud SQL `db-f1-micro` (Postgres): ~$8-12 / day
- Cloud Run v2 (min-instances=0, idle): negligible until traffic arrives
- Reserved /16 private services range + VPC peering: free
- Pub/Sub + Monitoring + Secret Manager: negligible at this volume

**Always end your dogfood session with `terraform destroy`**. The recipe is structured so destroy fully cleans up — including the SQL instance (`deletion_protection = false` is explicit in the Stack).

## Run

Prerequisites: `gcloud auth application-default login` for an account with Owner on the target project. Terraform 1.11+ (terradart synth currently hardcodes `required_version: ">= 1.11.0"`; see [FRICTIONS.md](./FRICTIONS.md)).

```bash
export GCP_PROJECT_ID=terradart-validate
export DB_PASSWORD=$(openssl rand -base64 24)
export ALERT_EMAIL=kobofender@gmail.com

dart pub get
dart run bin/infra.dart           # synth -> tf-out/main.tf.json

cd tf-out
terraform init
terraform plan
terraform apply -auto-approve

# Smoke test
SERVICE_URL=$(terraform output -raw coffee_service_uri)
curl -i "$SERVICE_URL"

terraform destroy -auto-approve
```

## D1b — GCS backend

To switch to a GCS-backed state for the second dogfood phase, see [FRICTIONS.md](./FRICTIONS.md) and the `bin/bootstrap.dart` flow.
