# coffee-shop

Webhook-driven coffee order tracker. Demonstrates terradart end-to-end with a real-world stack on Google Cloud.

## Architecture

- Cloud Run v2 service receives webhook POSTs at `/order`.
- Cloud SQL (Postgres, private IP) persists orders.
- Secret Manager stores the DB password.
- Pub/Sub topic emits `order.created` events; a Pub/Sub push subscription invokes the same Cloud Run service.
- Cloud Monitoring covers an uptime check + alert policy + email notification channel.

~30 resources across 8 terradart barrels: `project`, `iam`, `service_networking`, `compute`, `cloud_sql`, `secret_manager`, `cloud_run`, `pubsub`, `monitoring`.

## Run

Prerequisites: `gcloud auth application-default login` for an account with Owner on the target project. Terraform 1.5+.

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
