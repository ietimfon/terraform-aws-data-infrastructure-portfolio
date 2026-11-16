# Terraform AWS Data Infrastructure

[![Terraform](https://img.shields.io/badge/Terraform-IaC-844FBA?logo=terraform&logoColor=white)](https://developer.hashicorp.com/terraform)
[![AWS](https://img.shields.io/badge/AWS-S3-FF9900?logo=amazonaws&logoColor=white)](https://aws.amazon.com/s3/)
[![Environment](https://img.shields.io/badge/Region-eu--west--3-blue)](https://docs.aws.amazon.com/general/latest/gr/rande.html)

A hands-on **Infrastructure as Code (IaC)** project that uses **Terraform and Amazon Web Services (AWS)** to provision separate **staging** and **production** S3 ingestion buckets. Terraform state is stored remotely in Amazon S3, with encryption and S3 lockfile-based locking.

This implementation adapts the [Core Data Engineers (CDE) data infrastructure exercise](https://github.com/coredataengineers/cde-data-infrastructure) for **Group 21**, deployed in AWS Europe (Paris), **`eu-west-3`**.

> **Project scope:** This repository provisions one S3 ingestion bucket per environment. It does **not** deploy Apache Airflow, ETL pipelines, IAM roles, VPCs, or a full data lake. The production `Service = "Airflow"` tag is descriptive metadata, not an Airflow deployment.

## Architecture

```text
                         AWS account | eu-west-3 (Paris)
                                      |
                     Pre-existing S3 Terraform state bucket
                       (name configured locally, not in Git)
                                      |
                  +-------------------+-------------------+
                  |                                       |
        staging/staging.tfstate              production/production.tfstate
                  |                                       |
           Terraform staging                       Terraform production
                  |                                       |
       S3 staging ingestion bucket             S3 production ingestion bucket
       group-21-staging-data-ingestion         group-21-production-data-ingestion
```

The **backend bucket** stores Terraform state, while the **ingestion buckets** are managed application resources. Staging and production use separate working directories and separate state object keys within the same backend bucket. They are **not** separate AWS accounts.

## Deployed infrastructure

| Setting | Staging | Production |
| --- | --- | --- |
| AWS region | `eu-west-3` | `eu-west-3` |
| Terraform resource | `aws_s3_bucket.ingestion` | `aws_s3_bucket.example` |
| S3 ingestion bucket | `group-21-staging-data-ingestion` | `group-21-production-data-ingestion` |
| Remote state key | `staging/staging.tfstate` | `production/production.tfstate` |
| Locking | S3 `.tflock` object | S3 `.tflock` object |
| AWS provider constraint | `hashicorp/aws ~> 6.0` | `hashicorp/aws ~> 6.0` |

Both environments use the Group 21 naming convention: S3 bucket names start with `group-21-`, and the resource `Name` tags use `group_21_` prefixes. The production bucket also includes `Team` and `Service` tags.

## Repository structure

```text
terraform-aws-data-infrastructure-portfolio/
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
| `providers.tf` | Declares the AWS provider and sets its region. |
| `backend.tf` | Defines a **partial** S3 remote backend, its environment-specific state key, encryption, and locking. |
| `data_lake.tf` | Declares the environment's S3 ingestion bucket and tags. |
| `.terraform.lock.hcl` | Records selected provider dependencies and checksums; tracked by Git. |
| `.gitignore` | Excludes local provider files, Terraform state, debug logs, and private backend configuration. |

Each environment also requires a **local `backend.hcl` file**. That file is deliberately **not included** in the repository and is ignored by Git.

## Prerequisites

- Terraform CLI installed and accessible in `PATH` (exercise performed using Terraform **1.17.1**).
- AWS CLI configured for an AWS identity with sufficient permissions to access the backend bucket and manage ingestion buckets.
- Git and a terminal. Examples use **Windows PowerShell**.
- A **pre-existing S3 state bucket** in `eu-west-3` with appropriate access controls, versioning, and public access blocking.
- Enough available disk space to install the AWS provider plugin.

Check your environment:

```powershell
terraform version
aws --version
aws sts get-caller-identity
aws configure get region
```

If required, set the AWS CLI's default region:

```powershell
aws configure set region eu-west-3
```

Do **not** include AWS credentials in Terraform files or Git history. The AWS provider can use your configured CLI credentials, profiles, or supported role-based authentication.

## Getting started

### 1. Clone the portfolio repository

```powershell
git clone https://github.com/ietimfon/terraform-aws-data-infrastructure-portfolio.git
cd terraform-aws-data-infrastructure-portfolio
```

### 2. Configure the private remote backend

The committed `backend.tf` files intentionally **omit the S3 state bucket name**. For example, `staging/backend.tf` contains:

```hcl
terraform {
  backend "s3" {
    key          = "staging/staging.tfstate"
    region       = "eu-west-3"
    encrypt      = true
    use_lockfile = true
  }
}
```

Production uses the same structure but sets the state key to `production/production.tfstate`.

Create a `backend.hcl` file **inside each environment directory** with the name of **your own existing state bucket**:

```hcl
bucket = "YOUR-EXISTING-TERRAFORM-STATE-BUCKET"
```

The two `backend.hcl` files can refer to the same backend bucket because their `backend.tf` files use different state keys. The actual backend bucket name is **not committed to Git**. The root `.gitignore` includes:

```gitignore
**/backend.hcl
```

Before initializing, make sure the referenced state bucket already exists, you can access it, and its policies support object reads/writes and lockfile operations. **A bucket used for Terraform state is distinct from the ingestion buckets created by this project.**

> **If replicating this project in another AWS account:** S3 bucket names are globally unique. Change the ingestion bucket names in both `data_lake.tf` files to names available in your account, while following your own naming conventions. Do not try to create buckets using names already owned by another account.

### 3. Initialize and deploy staging

From the repository root:

```powershell
cd .\staging
terraform init "-backend-config=.\backend.hcl"
terraform fmt -check
terraform validate
terraform plan
```

Review the plan before running:

```powershell
terraform apply
```

Enter `yes` only when the plan matches the resources you intend to create. On a new state with no corresponding existing ingestion bucket, the intended initial plan creates **one** S3 bucket.

Verify the deployed resource:

```powershell
aws s3api head-bucket --bucket group-21-staging-data-ingestion --region eu-west-3
terraform state list
terraform plan
```

The Terraform state should list `aws_s3_bucket.ingestion`. If AWS matches the configuration, a follow-up plan should report **no changes**.

### 4. Initialize and deploy production

From the staging directory:

```powershell
cd ..\production
terraform init "-backend-config=.\backend.hcl"
terraform fmt -check
terraform validate
terraform plan
```

Review the plan and, only if appropriate, deploy:

```powershell
terraform apply
```

Verify:

```powershell
aws s3api head-bucket --bucket group-21-production-data-ingestion --region eu-west-3
terraform state list
terraform plan
```

The Terraform state should list `aws_s3_bucket.example`. The expected post-deployment plan is **no changes**.

### Reconfigure an existing environment

If you change the backend configuration of an already initialized working directory, reinitialize it using the **same existing state bucket and key**:

```powershell
terraform init -reconfigure "-backend-config=.\backend.hcl"
terraform validate
terraform plan
```

Do not choose a different empty state bucket or state key unless you intend to perform a carefully planned state migration. `-reconfigure` does not automatically migrate the old state.

## Deployment results

The Group 21 exercise was completed on **16 November 2026**. Observed results from AWS CLI and Terraform commands:

| Validation | Result |
| --- | --- |
| Staging S3 ingestion bucket | Exists in `eu-west-3` |
| Production S3 ingestion bucket | Created in `eu-west-3` |
| Staging Terraform state | Tracks `aws_s3_bucket.ingestion` |
| Production Terraform state | Tracks `aws_s3_bucket.example` |
| `terraform validate` | Passed in both environments |
| Post-deployment `terraform plan` | No changes in both environments |
| Production `terraform apply` | `1 added, 0 changed, 0 destroyed` |
| Reinitialization with private `backend.hcl` | Successful in both environments |

These are **observed results from the exercise**, not automated CI checks. Deployed infrastructure may change after the date above.

## Troubleshooting

### Not enough disk space during `terraform init`

An initial AWS provider installation failed when Windows lacked sufficient space to extract the provider executable. After storage was available, initialization succeeded.

```powershell
Get-PSDrive C
```

Terraform downloads providers into local `.terraform/` directories; they should not be tracked in Git.

### `412 PreconditionFailed` acquiring the S3 state lock

A staging plan encountered an existing `.tflock` object. Check whether another terminal, teammate, or CI workflow is using the same state before taking action. For a **confirmed stale lock**, use the lock ID from the Terraform error:

```powershell
terraform force-unlock LOCK_ID_FROM_ERROR
```

Do not routinely use `-lock=false` and do not delete lock objects without confirming they are stale.

### IAM `AccessDenied` when setting public access blocks

An AWS IAM guardrail prevented modification of the backend bucket's public-access-block configuration. The settings were already enabled, as verified with:

```powershell
aws s3api get-public-access-block --bucket YOUR-EXISTING-TERRAFORM-STATE-BUCKET
```

A denied change request does not imply the security setting is disabled.

### `No positional arguments are expected` during initialization

When using PowerShell, pass the backend configuration flag and path as one quoted argument:

```powershell
terraform init -reconfigure "-backend-config=.\backend.hcl"
```

## Security and operational notes

- **Private backend values:** `backend.hcl` is local and excluded through `.gitignore`. Never commit it or other files that reveal account-specific deployment settings you intend to keep private.
- **State confidentiality:** Terraform state may contain sensitive resource data. Restrict access to the backend bucket and retain versioning and public access protection.
- **State locking:** `use_lockfile = true` uses S3 lockfiles. The IAM identity needs sufficient permissions for state objects and lock objects.
- **State encryption:** `encrypt = true` configures encryption for S3 backend state objects. Observed staging bucket attributes included SSE-S3 (`AES256`), but the Terraform project does not declare separate ingestion-bucket encryption resources.
- **Production readiness:** Ingestion bucket policies, versioning, lifecycle settings, and explicit public access blocking are **not** fully managed in this example. Add suitable controls before using this configuration for operational production workloads.
- **Source control:** Do not commit `.terraform/`, `.tfstate`, credentials, sensitive `.tfvars`, execution plans, local logs, or the private backend file. Commit `.terraform.lock.hcl`.
- **Avoid accidental destruction:** Inspect every `terraform plan` before approving an apply, especially in production. Do not destroy resources that must remain deployed.

## Future improvements

These are possible extensions, **not features implemented in this repository**:

1. Refactor duplicated environment settings into reusable Terraform modules and variables.
2. Explicitly manage ingestion-bucket versioning, encryption, lifecycle, and access-control resources.
3. Add GitHub Actions checks for formatting and validation, with a protected production deployment workflow.
4. Introduce IAM roles and least-privilege policies for data ingestion services.
5. Extend the infrastructure to support an end-to-end data ingestion and processing platform.

## Acknowledgment

Adapted from the [Core Data Engineers (CDE) `cde-data-infrastructure` repository](https://github.com/coredataengineers/cde-data-infrastructure) as a hands-on Terraform and AWS infrastructure exercise. The deployment and portfolio documentation reflect the Group 21 implementation.

## Maintainer

[ietimfon](https://github.com/ietimfon)
