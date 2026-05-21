# terradart-cookbook

Real-world recipes for [terradart](https://github.com/nozomi-koborinai/terradart), the Dart-first IaC library for Google Cloud.

> **Status (2026-05-21):** terradart `v0.9.0` shipped on pub.dev, closing 5 of 6 dogfood frictions (#52-#56; #57 deferred to v1.x). The `single-project-app` recipe was re-dogfooded end-to-end against `terradart-validate` on the v0.9.0 surface (apply → smoke → destroy), confirming `LocalBackend` + `Stack(devMode: true)` + `TfArg.variable` patterns + Plan 3 nested-helper renames all work in real-apply.
>
> Previous milestone (2026-05-20): first dogfood session against v0.8.0-dev validated `single-project-app` + `remote-backend` recipes with local + GCS backend modes; 15 friction findings consolidated into 6 polish issues.

Each recipe is a self-contained Dart project under `recipes/<name>/` that depends on terradart via pub.dev and ships a working Stack you can `terraform plan + apply` against a real GCP project.

## Recipes

| Recipe | Pattern | Status | Barrels |
|---|---|---|---|
| [`single-project-app`](recipes/single-project-app/README.md) | Single GCP project, end-to-end app surface (Cloud Run + Cloud SQL + Pub/Sub + Monitoring + Secret Manager + IAM) | ✅ Dogfooded 2026-05-20 (v0.8.0-dev) + 2026-05-21 (v0.9.0 re-dogfood) | 8 |
| [`remote-backend`](recipes/remote-backend/README.md) | GCS-backed Terraform remote state (Stage 0 bootstrap + state migration) | ✅ Dogfooded 2026-05-20 (v0.8.0-dev) | 1 |

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

Recipes pin to a specific terradart minor (`^0.9.0` at writing). Updates flow in lockstep with terradart's release tags. v1.0 semver lock is deferred until more recipes + real-apply cycles validate the surface.

## How recipes feed back into terradart

Each recipe's `FRICTIONS.md` is the canonical log of "things the recipe author hit that should be cleaner in terradart core / cookbook docs". Each friction entry is classified (P0 / P1 / P2 / P3) and consolidated into upstream issues on the [terradart repo](https://github.com/nozomi-koborinai/terradart). The cookbook is the dogfood vehicle: the more real-world recipes we ship, the more strategic input lands on terradart's roadmap.

For the 2026-05-20 dogfood, the consolidated polish issues are tracked at [terradart issues with label `dogfood-driven`](https://github.com/nozomi-koborinai/terradart/issues?q=is%3Aissue+label%3Adogfood-driven). Five of the six (#52-#56) shipped in terradart v0.9.0 (2026-05-21); the remaining one (#57, `Apis.required` helper) is on the [v1.x roadmap](https://github.com/nozomi-koborinai/terradart/issues?q=is%3Aissue+label%3Av1.x-roadmap).
