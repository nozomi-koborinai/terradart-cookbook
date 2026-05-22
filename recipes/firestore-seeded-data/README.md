# firestore-seeded-data

> **Status (2026-05-22):** Recipe scaffolded against terradart v0.10.0-dev (PR #60 merged). End-to-end dogfood against `terradart-validate` and CHANGELOG status badge pending (Tasks 6-8 of Plan B).

A Cloud Firestore master-data seeding recipe. Demonstrates how to manage **small fixed master-data sets** (feature flags, pricing tiers, lookup tables, regional config) via IaC, with the new `GoogleFirestoreDocument` resource + `FirestoreFields.encode(Map)` helper introduced in terradart v0.10.0.

## What this recipe demonstrates

- `google_firestore_database` — the singleton `(default)` Native-mode database in `asia-northeast1`.
- `google_firestore_document` × 11 across 4 collections:
  - **feature_flags** (3) — `dark_mode`, `new_checkout`, `beta_invites`. Booleans + integers + lists + nested maps.
  - **pricing_tiers** (3) — `free`, `pro`, `enterprise`. Strings + integers + lists. `enterprise` includes a `FirestoreReference` to a `billing_profiles/annual` document (note: that doc is referenced but not created here — the helper does not validate target existence).
  - **i18n** (3) — `en`, `ja`, `ko`. Unicode strings + nested maps.
  - **regions** (2) — `us`, `jp`. `FirestoreGeoPoint` lat/lon for office locations.
- `google_firestore_index` — composite index on `pricing_tiers` (`monthly_usd ASC, label ASC`).
- `google_firestore_backup_schedule` — daily backups, 7-day retention.

## Why master data in IaC

- **Reproducibility**: spin up `dev` / `staging` / `prod` projects with identical master data via `terraform apply`.
- **Audit-via-PR**: master-data changes go through code review, not manual console clicks.
- **Env parity**: when you rebuild a project for any reason, master data is recreated by Terraform alongside the database.

## When NOT to use this pattern

For **production-scale** Firestore collections (1000s of documents, frequent app-side writes, transactional data), prefer a separate seed script using the Firebase Admin SDK. IaC ownership of frequently-mutating collections causes Terraform state to diverge from Firestore reality.

This recipe demonstrates the **opposite** end of the spectrum: a small fixed set of documents, infrequently changed via PR review, naturally fitting IaC.

See [terradart_google CHANGELOG `0.10.0` § Supersedes 0.3.0-dev note](https://pub.dev/packages/terradart_google/changelog#0100) for the rationale behind v0.10.0 reversing the original "not curated" decision.

## Prerequisites

- Terraform 1.11+
- `gcloud auth application-default login` with `roles/datastore.owner` on the target project
- A GCP project (e.g., `terradart-validate`). The default `(default)` Firestore database must NOT already exist (Firestore creates one automatically the first time the API is enabled — if `(default)` already exists, see "Recovery" below).

## Run

```bash
export GCP_PROJECT_ID=my-project-id
dart pub get
dart run bin/infra.dart        # → tf-out/main.tf.json
cd tf-out
terraform init
terraform plan -out=tfplan
terraform apply tfplan
```

Expected apply duration: 1-3 minutes (the `(default)` database takes ~1-2 minutes to provision; documents create in seconds each in parallel).

## Smoke test

After apply, verify documents exist via gcloud:

```bash
gcloud firestore documents list \
  --database='(default)' \
  --collection-id=feature_flags \
  --project="$GCP_PROJECT_ID"
```

Expected: 3 documents (`dark_mode`, `new_checkout`, `beta_invites`).

Or via the Firebase / Firestore console: open the project, switch to Firestore Data, confirm the 4 collections with their documents and field types (e.g., `enabled` is `boolean`, `rollout_pct` is `number`, `office_location` is `geopoint`).

## Destroy

```bash
cd tf-out
terraform destroy
```

**Caveat**: `(default)` database deletion takes **1-5 minutes**. Terraform polls until the deletion completes. If `terraform destroy` appears to hang, it's almost certainly the database resource transitioning through the `DELETING` state — not stuck.

If `terraform destroy` fails partway through, the recovery is to manually delete remaining resources via `gcloud` and re-run.

## Recovery: `(default)` database already exists

If the project's `(default)` database was created previously (e.g., by manually enabling the Firestore API), `terraform apply` will fail with "already exists" on the `google_firestore_database` resource. Recovery:

```bash
cd tf-out
terraform import google_firestore_database.default \
  "projects/$GCP_PROJECT_ID/databases/(default)"
terraform apply tfplan
```

Subsequent applies will reconcile cleanly.

## See also

- `FRICTIONS.md` — dogfood findings during the 2026-05-22 cycle.
- `terradart-cookbook/recipes/single-project-app/` — the larger end-to-end pattern (Cloud Run + Cloud SQL + Pub/Sub + Monitoring).
- `terradart/examples/firestore_document_quickstart/` — a simpler 2-document quickstart inside the terradart repo.
