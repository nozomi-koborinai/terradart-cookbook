# terradart-cookbook

Real-world recipes for [terradart](https://github.com/nozomi-koborinai/terradart), the Dart-first IaC library for Google Cloud.

Each recipe is a self-contained Dart project under `recipes/<name>/` that depends on terradart via pub.dev and ships a working Stack you can `terraform plan + apply` against a real GCP project.

## Recipes

| Recipe | What it demonstrates | terradart barrels used |
|---|---|---|
| [`coffee-shop`](recipes/coffee-shop/README.md) | Webhook on Cloud Run + private Cloud SQL + Pub/Sub + Monitoring + Secret Manager + IAM | 8 |

## Usage

```bash
cd recipes/<name>
dart pub get
dart run bin/infra.dart    # synth to tf-out/
cd tf-out
terraform init
terraform plan
terraform apply
# ...smoke test...
terraform destroy
```

Each recipe's README documents required env vars (e.g. `GCP_PROJECT_ID`, secrets).

## Versions

Recipes pin to a specific terradart minor (`^0.8.0-dev` at writing). Updates flow in lockstep with terradart's release tags.
