# Terraform AWS Data Infrastructure

Infrastructure as Code (IaC) project for provisioning separate **staging** and **production** Amazon S3 ingestion buckets with **Terraform**, using an **Amazon S3 remote backend** for state storage and lockfile-based state locking.

This implementation adapts the [Core Data Engineers (CDE) data infrastructure exercise](https://github.com/coredataengineers/cde-data-infrastructure) for **Group 21** in AWS **Europe (Paris), `eu-west-3`**.

## Project overview

The project demonstrates how to:

- Define and provision AWS resources declaratively with Terraform.
- Isolate staging and production deployments using separate Terraform working directories and state keys.
- Store Terraform state remotely in Amazon S3, with encryption and S3 lockfile-based locking.
- Apply consistent group and environment naming conventions.
- Validate, plan, apply, and verify cloud infrastructure changes.
- Keep generated local Terraform files and potential secrets out of Git.

**Scope:** The Terraform configuration in this repository creates **one S3 ingestion bucket per environment**. It does **not** provision Apache Airflow itself, a complete data lake, IAM roles, networking, or ETL pipelines. The `Service = "Airflow"` production tag is metadata only.

## Architecture

```text
                        AWS | eu-west-3 (Paris)
                                  |
                  S3 Terraform State Bucket
                         (Group 21)
                                  |
                  +---------------+---------------+
                  |                               |
       staging/staging.tfstate      production/production.tfstate
                  |                               |
       Staging Terraform                 Production Terraform
                  |                               |
       S3 ingestion bucket               S3 ingestion bucket
       group-21-staging-                 group-21-production-
       data-ingestion                    data-ingestion
```

The backend bucket stores Terraform state; the two ingestion buckets are the application resources. State is isolated by S3 object key, not by separate AWS accounts.

## Deployed configuration

| Setting | Staging | Production |
| --- | --- | --- |
| AWS region | `eu-west-3` | `eu-west-3` |
| Terraform resource address | `aws_s3_bucket.ingestion` | `aws_s3_bucket.example` |
| S3 ingestion bucket | `group-21-staging-data-ingestion` | `group-21-production-data-ingestion` |
| Remote state key | `staging/staging.tfstate` | `production/production.tfstate` |
| State locking | S3 lockfile | S3 lockfile |
| AWS provider requirement | `hashicorp/aws ~> 6.0` | `hashicorp/aws ~> 6.0` |

Both configurations use the same pre-created Group 21 S3 backend bucket. The bucket's actual name is configured in each `backend.tf` file. Provider dependency lock files pin the selected provider version for reproducibility.

### Resource naming

- **S3 bucket names:** `group-21-...` (lowercase with hyphens).
- **Names used in tags:** `group_21_...` (underscores).
- The `Environment` and `Group` tags identify each deployment.
- Production also has `Team` and `Service` tags.

## Repository layout

```text
terraform-aws-data-infrastructure/
├── .gitignore
├── README.md
├── staging/
│   ├── backend.tf
│   ├── data_lake.tf
│   ├── providers.tf
│   └── .terraform.lock.hcl
└── production/
    ├── backend.tf
    ├── data_lake.tf
    ├── providers.tf
    └── .terraform.lock.hcl
```

| File | Purpose |
| --- | --- |
| `providers.tf` | Defines the AWS provider requirement and region. |
| `backend.tf` | Configures remote S3 state and lockfile-based locking. |
| `data_lake.tf` | Declares the environment's S3 ingestion bucket and resource tags. |
| `.terraform.lock.hcl` | Records provider selections and checksums; committed to Git. |
| `.gitignore` | Excludes local provider downloads, state files, sensitive variables, and logs. |

## Prerequisites

- Terraform CLI installed and on `PATH` (the project was exercised using Terraform **1.17.1**).
- AWS CLI v2 installed.
- An IAM identity authorized to use the required S3 resources and state backend.
- Git and a terminal (the exercise used **PowerShell on Windows**).
- A pre-existing S3 backend bucket in `eu-west-3`, with versioning and public access blocking enabled.

Verify your tools and AWS identity:

```powershell
terraform version
aws --version
aws sts get-caller-identity
aws configure get region
```

If needed, set your assigned region:

```powershell
aws configure set region eu-west-3
```

**Never put AWS access keys in `.tf` files, commits, screenshots, or README examples.** Terraform's AWS provider can use credentials from your configured AWS CLI profile or another supported AWS credential source.

## Run the project

> **Important:** This repository contains deployment-specific S3 bucket names and backend settings. If you are replicating it in another AWS account, update both environment backends and the ingestion bucket names before running `terraform init` or `apply`. S3 bucket names are globally unique.

### 1. Clone

```powershell
git clone https://github.com/ietimfon/terraform-aws-data-infrastructure.git
cd terraform-aws-data-infrastructure
```

### 2. Confirm backend setup

Each environment's `backend.tf` should reference a bucket that **already exists** and that you are authorized to access. The backend bucket is created outside the Terraform configurations in this repository.

Example backend shape (replace the placeholder with your own existing state bucket):

```hcl
terraform {
  backend "s3" {
    bucket       = "YOUR-EXISTING-TERRAFORM-STATE-BUCKET"
    key          = "staging/staging.tfstate"
    region       = "eu-west-3"
    encrypt      = true
    use_lockfile = true
  }
}
```

Production uses `production/production.tfstate` as its state key. Do not point two independent environments at the same state key.

### 3. Deploy staging

```powershell
cd staging
terraform init
terraform fmt -check
terraform validate
terraform plan
terraform apply
```

Review the execution plan before entering `yes` to approve the apply. For an empty state with no pre-existing ingestion bucket, the initial staging plan should show **1 to add, 0 to change, 0 to destroy**.

Verify:

```powershell
aws s3api head-bucket --bucket group-21-staging-data-ingestion --region eu-west-3
terraform state list
terraform plan
```

The state list should include `aws_s3_bucket.ingestion`. A subsequent plan should show no changes when the deployed infrastructure matches the configuration.

### 4. Deploy production

From the repository root:

```powershell
cd production
terraform init
terraform fmt -check
terraform validate
terraform plan
terraform apply
```

For an empty production state, the initial plan should show **1 to add, 0 to change, 0 to destroy**. Verify:

```powershell
aws s3api head-bucket --bucket group-21-production-data-ingestion --region eu-west-3
terraform state list
terraform plan
```

The production state list should include `aws_s3_bucket.example`.

## Validation results

The Group 21 exercise was completed on **16 November 2026**:

| Check | Observed result |
| --- | --- |
| Staging ingestion bucket | Present in `eu-west-3` |
| Production ingestion bucket | Created successfully in `eu-west-3` |
| Staging Terraform state | Tracks `aws_s3_bucket.ingestion` |
| Production Terraform state | Tracks `aws_s3_bucket.example` |
| Terraform validation | Passed in both environments |
| Post-deployment plans | No changes reported in both environments |

The production apply reported `1 added, 0 changed, 0 destroyed`. A later staging apply reported no changes because its bucket was already deployed.

## Troubleshooting notes

### `terraform init`: not enough disk space

The AWS provider download initially failed on Windows because there wasn't enough free storage to extract the provider executable. After resolving the storage issue, initialization completed successfully. Check available space with:

```powershell
Get-PSDrive C
```

Terraform stores downloaded providers in local `.terraform/` directories. These directories should not be committed to Git.

### S3 state locking: `412 PreconditionFailed`

A staging `terraform plan` encountered a pre-existing `staging/staging.tfstate.tflock` file. Before unlocking, confirm **no other local process, team member, or CI workflow** is using the state. For a verified stale lock, use the lock ID returned in the error:

```powershell
terraform force-unlock LOCK_ID_FROM_ERROR
```

Do not routinely use `-lock=false` or manually delete lockfiles. After the stale lock was cleared, the staging plan succeeded.

### `AccessDenied` when setting S3 public access blocks

An IAM guardrail explicitly denied `s3:PutBucketPublicAccessBlock` for the backend bucket. However, the existing settings were verified using:

```powershell
aws s3api get-public-access-block --bucket YOUR-EXISTING-TERRAFORM-STATE-BUCKET
```

All four public access block settings were enabled. A denied attempt to **change** a setting does not necessarily imply that the setting is disabled.

## Security and operational considerations

- Keep AWS credentials out of source control; use AWS CLI profiles, roles, or another approved credential source.
- Restrict read/write access to the state bucket: Terraform state can contain sensitive values.
- Protect the state bucket with public access blocking and versioning; the exercise's backend bucket has both.
- `encrypt = true` enables S3 server-side encryption for Terraform backend objects. The ingestion bucket attributes observed in staging included SSE-S3 (`AES256`), but the repository does not explicitly manage bucket encryption settings as separate Terraform resources.
- S3 lockfiles require sufficient S3 object permissions to create and delete the `.tflock` object.
- The ingestion buckets' public access settings, versioning, lifecycle rules, and access policies are **not explicitly managed** by the current Terraform configuration. Assess those requirements before using this example for real production workloads.
- Avoid committing `.terraform/`, `*.tfstate`, `.tfvars` containing secrets, execution plans, or debug logs.
- Use `terraform plan` before every `terraform apply`, especially in production.
- Do not run `terraform destroy` on infrastructure that must be retained.

## Future improvements

Potential extensions, **not implemented in this repository**:

1. Introduce reusable Terraform modules and input variables.
2. Add explicit S3 security controls and bucket versioning requirements for ingestion buckets.
3. Add automated `terraform fmt -check`, `terraform validate`, and plan checks through GitHub Actions.
4. Add IAM roles and least-privilege policies for data ingestion workloads.
5. Expand the project into a full ingestion and processing architecture.

## Acknowledgment

Based on the [Core Data Engineers `cde-data-infrastructure` repository](https://github.com/coredataengineers/cde-data-infrastructure), adapted and deployed for Group 21 as a hands-on Terraform and AWS infrastructure exercise.

## Maintainer

[ietimfon](https://github.com/ietimfon)
