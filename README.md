# terradart-cookbook

Real-world recipes for [terradart](https://github.com/nozomi-koborinai/terradart), the Dart-first IaC library for Google Cloud.

Each recipe is a self-contained Dart project under `recipes/<name>/` that depends on terradart via pub.dev and ships a working Stack you can `terraform plan + apply` against a real GCP project.

## Recipes

| Recipe | Pattern | Status | Barrels |
|---|---|---|---|
| [`single-project-app`](recipes/single-project-app/README.md) | Single GCP project, end-to-end app surface (Cloud Run + Cloud SQL + Pub/Sub + Monitoring + Secret Manager + IAM) | ✅ v0.11.0 verified | 8 |
| [`remote-backend`](recipes/remote-backend/README.md) | GCS-backed Terraform remote state (Stage 0 bootstrap + state migration) | ✅ v0.11.0 verified | 1 |
| [`firestore-seeded-data`](recipes/firestore-seeded-data/README.md) | Cloud Firestore master-data seeding (11 docs across 4 collections + composite index + daily backup) via `GoogleFirestoreDocument` + `FirestoreFields.encode` | ✅ v0.11.0 verified | 3 |

(Coming in future iterations: `multi-env-dev-prod` for env separation, `dynamic-iam-for-each` for `locals`/`for_each` patterns, full-stack composites linking Flutter + Firebase Functions + terradart infra.)

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

All recipes pin to `^0.11.0` across `terradart_core` and `terradart_google`. Updates flow in lockstep with terradart's release tags. v1.0 semver lock is deferred until more recipes + real-apply cycles validate the surface.

## How recipes feed back into terradart

Each recipe's `FRICTIONS.md` is the canonical log of "things the recipe author hit that should be cleaner in terradart core / cookbook docs". Each friction entry is classified (P0 / P1 / P2 / P3) and consolidated into upstream issues on the [terradart repo](https://github.com/nozomi-koborinai/terradart). The cookbook is the dogfood vehicle: the more real-world recipes we ship, the more strategic input lands on terradart's roadmap.
