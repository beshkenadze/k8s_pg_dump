# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository Purpose

This repository contains Kubernetes manifests and Kustomize configuration for deploying a PostgreSQL backup solution. The system:

- Performs PostgreSQL database dumps
- Encrypts the dumps using OpenSSL
- Uploads encrypted dumps to S3-compatible storage using s3cmd
- Pushes metrics to Prometheus Pushgateway for monitoring
- Verifies connections before performing backup operations

## Architecture

The solution follows a Kustomize-based structure with:

1. **Base Layer** (`/kustomize/base/`): Contains common resources and configurations
   - CronJob definition (cronjob.yaml)
   - Scripts ConfigMap with backup and verification scripts (scripts-configmap.yaml)
   - Consolidated config (config.yaml)
   - Consolidated secrets (secrets.yaml)

2. **Environment Overlays** (`/kustomize/overlays/`):
   - `dev/`: Development environment configuration
   - `prod/`: Production environment configuration

Each overlay customizes the base configuration through environment-specific patches for configs, secrets, and schedule.

## Common Commands

### Deploy to Development Environment

```bash
kubectl apply -k kustomize/overlays/dev
```

### Deploy to Production Environment

```bash
kubectl apply -k kustomize/overlays/prod
```

### View CronJob Status

```bash
kubectl get cronjobs -n <namespace>
```

### Check Recent Job Executions

```bash
kubectl get jobs -n <namespace>
```

### View Backup Job Logs

```bash
# Find the most recent job pod
JOB_POD=$(kubectl get pods -n <namespace> -l job-name=pgsql-sql-backup-<job-id> -o jsonpath='{.items[0].metadata.name}')

# View logs
kubectl logs $JOB_POD -n <namespace>
```

## Key Files

- `/kustomize/base/scripts-configmap.yaml`: Contains all scripts including:
  - `backup.sh`: Main backup script
  - `pg-connection-verify.sh`: PostgreSQL connection verification script
  - `s3-connection-verify.sh`: S3 connection verification script (using s3cmd)
- `/kustomize/base/cronjob.yaml`: CronJob definition
- `/kustomize/base/config.yaml`: Consolidated configuration template
- `/kustomize/base/secrets.yaml`: Consolidated secrets template
- `/kustomize/overlays/*/configs.yaml`: Environment-specific configuration
- `/kustomize/overlays/*/secrets.yaml`: Environment-specific secrets
- `/kustomize/overlays/*/schedule-patch.yaml`: Patches for CronJob schedule
- `/kustomize/overlays/*/kustomization.yaml`: Kustomization files for each environment

## Important Parameters

All configuration parameters are consolidated in the environment-specific configs.yaml file with these key parameters:

| Parameter | Description | Example |
|-----------|-------------|---------|
| PG_HOST | PostgreSQL hostname | "postgres-postgresql.dev.svc.cluster.local" |
| PG_DATABASE | Target database name | "chat" |
| S3_BUCKET_PATH | S3 bucket and path for backups | "postgres-backups-242201276690/dev-backups" |
| ENVIRONMENT | Environment name for metrics and manifests | "dev", "prod" |
| MAX_RETRIES | Number of retry attempts for failed operations | "2" for dev, "5" for prod |
| RETRY_WAIT | Seconds to wait between retry attempts | "10" for dev, "60" for prod |
| ENABLE_DEBUG | Enable verbose debugging output | "true" for dev, "false" for prod |
| CREATE_MANIFEST | Create manifest files in S3 | "true", "false" |

The backup job schedule is set in each environment's `schedule-patch.yaml` file.

## S3cmd Usage

The solution uses s3cmd instead of AWS CLI for S3 operations. The key aspects:

1. **Installation**: The backup script automatically installs s3cmd during its execution
2. **Configuration**: s3cmd is configured dynamically using provided AWS credentials
3. **Operations**: 
   - S3 bucket verification: `s3cmd ls s3://$BUCKET_NAME/`
   - File upload: `s3cmd put $FILE s3://$S3_BUCKET_PATH/`
   - File removal: `s3cmd rm s3://$S3_BUCKET_PATH/$FILE`

## Connection Verification

The solution includes verification scripts that test connections before attempting backups:

1. **PostgreSQL Connection Verification**:
   - Validates database connectivity
   - Checks credentials
   - Reports metrics on connection issues

2. **S3 Connection Verification**:
   - Validates S3 bucket access using s3cmd
   - Tests write permissions
   - Reports metrics on connection issues

These verification steps run before any backup operations to prevent partial or failed backups.

## Troubleshooting

If backups are failing, check:

1. Connection error metrics in Prometheus: `pg_backup_connection_error`
2. Backup error metrics in Prometheus: `pg_backup_error`
3. Pod logs for detailed error messages
4. S3 credentials and permissions
5. PostgreSQL connection details
6. Network connectivity between pods and services
7. S3cmd installation issues