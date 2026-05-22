# firestore-seeded-data — FRICTIONS

Findings from dogfooding the recipe against `terradart-validate` GCP project.

Cycle 1: **2026-05-22 — initial validation against terradart v0.10.0-dev** (PR #60 merged at 6a70623). Apply → smoke → destroy against `terradart-validate`. Path-overridden to terradart's main checkout.

Summary: **4 frictions found**. P0 destroy bug is the most significant — Terraform reports the `(default)` database as destroyed but the resource survives in GCP. Other frictions are documentation / plan accuracy issues.

---

## Format

Each entry follows the cookbook template:

- **Context**: what was being done when the friction surfaced.
- **Friction**: what was unexpected / painful.
- **Proposed fix**: what would prevent the friction next time. May be a terradart change, a doc change, or a process change.
- **Tracked**: GitHub issue link if filed, or `none` if a memo-only.

---

## P0 — `terraform destroy` reports success but `(default)` database survives in GCP

- **Context**: After successful `terraform apply` (15 resources), ran `terraform destroy -auto-approve` from `tf-out/`. The destroy completed in seconds with `Destroy complete! Resources: 15 destroyed.`
- **Friction**: The `google_firestore_database.default` resource line reported `Destruction complete after 0s`, but `gcloud firestore databases list --project=terradart-validate` STILL showed the `(default)` database afterwards. Tested with the `deletion_policy = "DELETE"` (Terraform's default) and `delete_protection_state = DELETE_PROTECTION_DISABLED` (set by our Stack). Both are in place — destroy is silent-no-op on GCP. Manual `gcloud firestore databases delete --database='(default)' --project=terradart-validate --quiet` succeeded immediately and cleanly. So GCP does support deletion via API; the Terraform provider is just not invoking it. Smells like a `hashicorp/google` provider issue with `(default)` databases specifically (the special `(default)` name may take a different code path).
- **Proposed fix**:
  1. **Immediate**: document the manual `gcloud firestore databases delete` step in this recipe's README destroy section, marked as a current workaround. Cookbook readers should not be surprised when destroy "succeeds" but their GCP project still bills for an unused database.
  2. **Upstream**: file an issue on [hashicorp/terraform-provider-google](https://github.com/hashicorp/terraform-provider-google/issues) — minimal repro = 1 `google_firestore_database` with `delete_protection_state = DELETE_PROTECTION_DISABLED` + `deletion_policy = "DELETE"`, apply, destroy, observe `gcloud firestore databases list` still has it.
  3. **Long-term**: when the upstream fix lands, drop the recipe README's manual cleanup note.
- **Tracked**: `none` (upstream issue filing pending).

---

## P1 — `gcloud firestore documents` subcommand does not exist

- **Context**: Plan B Task 7 (smoke verification) called for `gcloud firestore documents list --database='(default)' --collection-id=feature_flags ...` to count seeded documents per collection.
- **Friction**: `gcloud firestore documents` is not a valid subcommand. `gcloud firestore` only exposes `databases`, `backups`, `locations`, `operations`, `user-creds`. There is no document-level CRUD via gcloud. To verify documents you need:
  - Firestore REST API via `curl` + ADC access token (used here: `curl -H "Authorization: Bearer $(gcloud auth application-default print-access-token)" "https://firestore.googleapis.com/v1/projects/<p>/databases/(default)/documents/<col>"`), OR
  - Firebase CLI (`firebase firestore:get`) — separate tool with its own auth, OR
  - Firestore client libraries — for programmatic checks
- **Proposed fix**: this recipe's README + the upstream `firestore_document_quickstart` README in terradart should both show the REST-API smoke pattern (it's the lowest-dependency option — gcloud is already in scope for ADC anyway). Plan templates that follow this recipe should also use the REST pattern, not the imaginary gcloud subcommand.
- **Tracked**: `none` (doc-only change captured inline in the README update for this cycle).

---

## P2 — Composite index creation takes ~6 minutes (vs documents <1s each)

- **Context**: `terraform apply` for the 15-resource Stack. Most resources created in seconds; the database took 12s, then 11 documents created in parallel in ~13s each. The composite index `pricing_tiers_by_price` (2 fields: `monthly_usd ASC, label ASC`) was the long pole — `Creation complete after 5m57s`.
- **Friction**: A first-time user reading the apply log will see "Still creating... 5m00s elapsed" and reasonably worry something is stuck. The 6-minute composite-index creation time is normal Firestore behavior (indexes provision asynchronously on a separate Firestore worker pool) but the recipe README claims "1-3 minutes" for total apply.
- **Proposed fix**: update README's `## Run` section to set expectations: total apply 5-10 minutes dominated by the composite index. Note that documents themselves complete in seconds; the long wait is just the index. Optionally add a recipe variant with `skip_wait: true` on the index resource — Terraform returns immediately while the index continues to build in the background. That changes the post-apply state somewhat (index queries fail until the index is READY) but is appropriate for many CI-driven workflows.
- **Tracked**: `none` (doc-only update planned for this recipe's README in this cycle).

---

## P3 — Plan's database destroy timing estimate ("1-5 minutes") was pessimistic

- **Context**: README + Plan B Task 8 warned that `google_firestore_database` destruction takes 1-5 minutes and Terraform polls until done.
- **Friction**: Actual destroy was `Destruction complete after 0s` (which is itself a separate issue per P0 — Terraform isn't actually issuing the delete). When done manually via `gcloud firestore databases delete --database='(default)'`, the operation also completed in ~1-2 seconds. The "1-5 minutes" estimate was probably from older Firestore behavior or speculative — current GCP behavior for `(default)` Native-mode deletion is near-instant.
- **Proposed fix**: drop the "1-5 minute" warning from the README. After P0 is fixed and Terraform actually deletes, expect <30s. Until P0 fixes, document the manual gcloud delete step.
- **Tracked**: `none` (folded into the same README rewrite as P0).

---

## What worked well (positive signals for v0.10.0)

These are not frictions but worth recording as positive validation of Plan A:

- **`FirestoreFields.encode` end-to-end correctness**: every type round-tripped correctly through the wire format → Firestore storage → REST API read-back. `booleanValue: true`, `integerValue: "100"` (string-encoded for 64-bit precision per spec), `timestampValue: "2026-05-22T00:00:00Z"` (UTC ISO 8601), `geoPointValue: {latitude: 37.7749, longitude: -122.4194}`, `referenceValue: projects/.../billing_profiles/annual`, Unicode `stringValue: "こんにちは"` + nested `mapValue.fields.subscribe.stringValue: "登録"` all confirmed via REST.
- **11 documents create in parallel**: Terraform's default parallelism naturally fanned out the document creates; total document-creation wall time was ~13s for all 11 (dominated by the slowest single document, not the sum).
- **`FirestoreReference` to non-existent target accepted silently**: as designed — the helper does not validate target existence; Firestore stores the path verbatim and lets the application decide. This is the right design for IaC-seeded master data that may reference documents created elsewhere.
- **Composite index READY after creation**: index reached `READY` state immediately after the create operation returned (no separate polling needed in this Stack — Terraform's index resource waits for READY by default).
- **`Stack(devMode: true)` did NOT inject `deletion_protection: false` on Firestore resources**: confirmed expected — the devMode injection only targets the 6 Plan-1 resources (Cloud Run v2 service+job, Cloud SQL, Secret Manager standard+regional, BigQuery table). Firestore database uses `delete_protection_state` (not `deletion_protection`) and the user-supplied `DeleteProtectionState.disabled` in the Stack already covered it.
