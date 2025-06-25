# PostgreSQL S3 Backup with Kustomize

This directory contains the Kubernetes manifests and Kustomize configuration for deploying a PostgreSQL backup solution. The solution performs SQL dumps, encrypts them, uploads them to S3-compatible storage using s3cmd, and pushes metrics to Prometheus Pushgateway.

## 📚 Documentation

- **[Main Documentation](#usage)** - Deployment and configuration guide (this document)
- **[Grafana Dashboard Setup](GRAFANA-DASHBOARD.md)** - Complete guide for setting up monitoring dashboards
- **[Backup Decryption Tool](DECRYPT-BACKUPS-USAGE.md)** - How to decrypt and validate backup files locally

## Directory Structure

```
pg_backup/
├── kustomize/
│   ├── base/
│   │   ├── cronjob.yaml                # CronJob definition
│   │   ├── scripts-configmap.yaml      # ConfigMap with all scripts (backup & verification)
│   │   ├── config.yaml                 # Consolidated configuration
│   │   ├── secrets.yaml                # Consolidated secrets 
│   │   ├── validation-cronjob.yaml     # Validation CronJob definition
│   │   └── kustomization.yaml          # Kustomization file for the base
│   └── overlays/
│       ├── dev/
│       │   ├── kustomization.yaml      # Kustomization for the 'dev' environment
│       │   ├── configs.yaml            # Environment-specific configuration
│       │   ├── secrets.yaml            # Environment-specific secrets
│       │   └── schedule-patch.yaml     # CronJob schedule patch
│       └── prod/
│           ├── kustomization.yaml      # Kustomization for the 'prod' environment
│           ├── configs.yaml            # Environment-specific configuration 
│           ├── secrets.yaml            # Environment-specific secrets
│           └── schedule-patch.yaml     # CronJob schedule patch
├── dashboards/
│   ├── grafana-dashboard.json          # Main backup monitoring dashboard
│   ├── grafana-validation-dashboard.json  # Backup validation metrics dashboard
│   └── homepage-dashboard.json         # Overview dashboard
├── decrypt_backups_test.sh             # Backup decryption testing script
├── DECRYPT-BACKUPS-USAGE.md            # Decryption script documentation
├── GET-METRICS.md                      # Metrics documentation
├── GRAFANA-DASHBOARD.md                # Dashboard setup guide
└── README.md                           # This file
```

* **`kustomize/`**: Contains all Kustomize-related configuration files.
  * **`base/`**: Contains the common Kubernetes YAML manifests. These manifests use placeholders for values that are expected to change between environments.
    * `cronjob.yaml`: The CronJob definition
    * `scripts-configmap.yaml`: Contains all scripts including the main backup script and connection verification scripts
    * `config.yaml`: Consolidated template for all configuration parameters
    * `secrets.yaml`: Consolidated template for all secrets
    * `kustomization.yaml`: Defines the resources for the base layer.
  * **`overlays/`**: Contains environment-specific configurations.
    * **`dev/`**: Configurations for the development environment.
        * `configs.yaml`: Consolidated ConfigMap with dev-specific parameters
        * `secrets.yaml`: Consolidated Secret with dev-specific credentials
        * `schedule-patch.yaml`: Patch to set the CronJob schedule
    * **`prod/`**: Configurations for the production environment.
        * `configs.yaml`: Consolidated ConfigMap with production-specific parameters
        * `secrets.yaml`: Consolidated Secret with production-specific credentials
        * `schedule-patch.yaml`: Patch to set the CronJob schedule

## Key Features

### 1. Consolidated Secrets and Config Files

The structure consolidates all secrets into a single `pg-backup-secrets` Secret and all configuration into a single `pg-backup-configs` ConfigMap. This makes it easier to:

- Set up and configure new environments
- Maintain consistency across environments
- Quickly identify and understand available configuration options
- Apply and manage changes through Kustomize

### 2. Connection Verification

The solution includes verification scripts that test connections before attempting backups:

- **PostgreSQL Connection Verification**:
  - Validates database connectivity
  - Checks credentials
  - Ensures the target database is accessible
  - Reports metrics on connection issues

- **S3 Connection Verification**:
  - Validates S3 bucket access
  - Tests write permissions using s3cmd
  - Ensures credentials are valid
  - Reports metrics on connection issues

Both verification steps occur before any backup operations begin, preventing partial or failed backup attempts due to connection issues.

### 3. Using s3cmd for S3 Operations

The solution uses s3cmd instead of AWS CLI for S3 operations, providing several advantages:

- Lightweight alternative to AWS CLI
- Better compatibility with some S3-compatible storage providers
- Simpler configuration for basic S3 operations
- Automatic installation during the backup process

## Backup Process

The backup process is managed by a central shell script stored in a ConfigMap. The process includes:

1. **Installation Phase**:
   - Install required tools (curl, postgresql-client, s3cmd)

2. **Verification Phase**:
   - Verify PostgreSQL connection and credentials
   - Configure s3cmd with AWS credentials
   - Verify S3 bucket access and write permissions

3. **Backup Phase**:
   - Dump the PostgreSQL database using `pg_dump`
   - Encrypt the dump using OpenSSL
   - Upload the encrypted dump to S3 using s3cmd
   - Create a manifest file (if enabled)
   - Send metrics to Prometheus Pushgateway

4. **Retention Policy Phase**:
   - List all existing backups in the S3 bucket
   - Identify backups older than the specified retention period (RETENTION_DAYS)
   - Delete expired backups and their manifests
   - Track and report the number of backups deleted

5. **Error Handling**:
   - Enhanced error handling with configurable retries
   - Detailed error reporting and metrics
   - Automatic cleanup of temporary files

## Configuration Parameters

All parameters are stored in the environment-specific ConfigMap with the following options:

| Parameter | Description | Example |
|-----------|-------------|---------|
| PG_HOST | PostgreSQL hostname | "postgres-postgresql.dev.svc.cluster.local" |
| PG_DATABASE | Target database name | "chat" |
| S3_BUCKET_PATH | S3 bucket and path for backups | "postgres-backups-242201276690/dev-backups" |
| PUSHGATEWAY_URL | URL for Prometheus Pushgateway | "http://pushgateway.prometheus.svc.cluster.local:9091" |
| ENVIRONMENT | Environment name for metrics and manifests | "dev", "prod" |
| MAX_RETRIES | Number of retry attempts for failed operations | "2" for dev, "5" for prod |
| RETRY_WAIT | Seconds to wait between retry attempts | "10" for dev, "60" for prod |
| ENABLE_DEBUG | Enable verbose debugging output | "true" for dev, "false" for prod |
| CREATE_MANIFEST | Create manifest files in S3 | "true", "false" |
| RETENTION_DAYS | Number of days to retain backups before deletion | "14" for dev, "90" for prod |

The CronJob schedule is configured in each environment's `schedule-patch.yaml` file.

## Usage

To deploy the backup solution to a specific environment, use `kubectl apply -k` with the path to the desired overlay.

### Deploying to Development Environment

```bash
kubectl apply -k pg_backup/kustomize/overlays/dev
```

### Deploying to Production Environment

```bash
kubectl apply -k pg_backup/kustomize/overlays/prod
```

## Troubleshooting

If backups are failing, you can check:

1. **Connection Issues**:
   - Check Prometheus metrics for connection errors
   - Look for `pg_backup_connection_error` metrics to identify connection problems

2. **S3cmd Issues**:
   - Check if s3cmd is correctly installed (the script installs it automatically)
   - Verify that S3 credentials are correct
   - Ensure the S3 bucket exists and has the correct permissions
   - Check for s3cmd configuration errors in the pod logs

3. **Backup Process Issues**:
   - Look for `pg_backup_error` metrics for specific backup step failures
   - Pod logs will show detailed error messages

4. **Retention Policy Issues**:
   - Check `pg_backup_expired_count` metrics to verify retention is working
   - Verify `RETENTION_DAYS` is set correctly in your environment config
   - Check `pg_backup_total_size_bytes` and `pg_backup_file_count` to monitor storage

5. **Metrics Issues**:
   - Ensure Pushgateway URL is correct and accessible
   - Check for any error messages related to sending metrics in logs
   - Verify metrics are showing up in Prometheus/Grafana

6. **Common Issues**:
   - S3 credentials incorrect or lacking permissions
   - Database connection details incorrect
   - Network connectivity between pod and services
   - Pushgateway connectivity problems

The script includes verification checks and retry mechanisms but will exit after the configured number of failed attempts to prevent infinite loops.

## 📊 Monitoring and Tools

### Grafana Dashboard
For comprehensive monitoring of your backup system, set up the included Grafana dashboards:

- **[Complete Dashboard Setup Guide](GRAFANA-DASHBOARD.md)** - Step-by-step instructions for importing and configuring Grafana dashboards
- **Dashboard Files** (in `dashboards/` directory):
  - `dashboards/grafana-dashboard.json` - Main backup monitoring dashboard
  - `dashboards/grafana-validation-dashboard.json` - Backup validation metrics dashboard  
  - `dashboards/homepage-dashboard.json` - Overview dashboard for multiple systems

The dashboards provide real-time monitoring of:
- Backup success/failure status
- Backup duration and performance trends
- Storage usage and retention metrics
- Error tracking and alerting
- Historical success rates

### Backup Decryption Tool
For testing and validating encrypted backups locally:

- **[Backup Decryption Usage Guide](DECRYPT-BACKUPS-USAGE.md)** - Complete documentation for the `decrypt_backups_test.sh` script
- **Script File**: `decrypt_backups_test.sh` - Decrypt and validate backup files

The decryption tool provides:
- Secure decryption of backup files using environment variables
- PostgreSQL dump format validation and analysis
- Database schema inspection (tables, indexes, constraints)
- File integrity verification and checksums
- Detailed restore instructions

## Metrics

The following metrics are sent to Prometheus Pushgateway:

- `pg_backup_success`: 1 if backup succeeded, 0 if failed
- `pg_backup_duration_seconds`: Total backup duration in seconds
- `pg_backup_encrypted_size_bytes`: Size of the encrypted backup file
- `pg_backup_error`: Details about errors with step and message labels
- `pg_backup_connection_error`: Connection-specific errors for PostgreSQL and S3
- `pg_backup_expired_count`: Number of expired backups deleted by the retention policy
- `pg_backup_file_size_bytes`: Size of individual backup files with filename and timestamp labels
- `pg_backup_total_size_bytes`: Total size of all retained backups in bytes
- `pg_backup_file_count`: Total count of backup files within the retention period