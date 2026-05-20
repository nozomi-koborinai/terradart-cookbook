> Part of [terradart-cookbook](../../README.md). Library: [terradart](https://github.com/nozomi-koborinai/terradart).

# remote-backend

GCS-backed Terraform remote state pattern. Demonstrates the canonical workflow:

1. Apply this recipe with a **local backend** → creates the GCS bucket that will hold remote state.
2. Migrate this recipe's own state into the new bucket via `terraform init -migrate-state`.
3. Retarget other recipes (e.g. `single-project-app`) at this bucket by switching their `tf-out/terraform.tf` to `backend "gcs"`.

Pattern demonstrated: **introduce GCS remote state to a previously local-backed Terraform project**. The bucket itself is intentionally a separate (minimal) Stack so that destroying app-level resources never touches the state container.

## Run (Stage 0 — create the bucket with local backend)

```bash
export GCP_PROJECT_ID=terradart-validate
# Optional: override default bucket name (default: <GCP_PROJECT_ID>-tfstate)
# export BUCKET_NAME=my-custom-tfstate-name

dart pub get
dart run bin/infra.dart              # synth -> tf-out/main.tf.json

cd tf-out
terraform init                       # local backend (Stage 0)
terraform plan                       # expect: 1 resource to add (google_storage_bucket)
terraform apply -auto-approve

# Confirm the bucket exists
gsutil ls -p terradart-validate | grep tfstate
```

## Migrate Stage 0 state into the new bucket

After the bucket is created, switch this recipe's own state into it:

1. Edit `tf-out/terraform.tf`:

   ```hcl
   terraform {
     backend "gcs" {
       bucket = "terradart-validate-tfstate"   # match BUCKET_NAME from Stage 0
       prefix = "remote-backend"               # path inside the bucket
     }
   }
   ```

2. Run `terraform init -migrate-state`. When prompted, type `yes` to copy local state to GCS.
3. Confirm: `gsutil ls -r gs://terradart-validate-tfstate/remote-backend/` shows `default.tfstate`.

## Migrate `single-project-app` state into the bucket

In `recipes/single-project-app/tf-out/terraform.tf`, switch the backend block:

```hcl
terraform {
  backend "gcs" {
    bucket = "terradart-validate-tfstate"
    prefix = "single-project-app"
  }
}
```

Then `terraform init -migrate-state` in `single-project-app/tf-out/`. The 28-resource state moves into GCS.

## Cost notes

A regional GCS bucket with versioning + a few KB of state files costs essentially zero (~$0.02/month). Safe to leave long-lived.

## When to destroy

The state bucket is long-lived by design. `terraform destroy` on this recipe should be **manual / deliberate** (e.g., when retiring the GCP project entirely). The recipe's `force_destroy = false` ensures versioned objects block accidental deletion.
