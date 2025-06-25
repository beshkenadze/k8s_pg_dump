# PostgreSQL Backup Monitoring Dashboard for Grafana

The `dashboards/` directory contains Grafana dashboard JSON files for monitoring the PostgreSQL backup metrics pushed to Prometheus Pushgateway.

## Dashboard Features

The dashboard provides comprehensive monitoring for PostgreSQL backups:

- **Overview Panels**:
  - Latest backup status indicator
  - Backup duration trends
  - Backup size trends
  - Active backup and connection errors

- **Historical Analysis**:
  - Success rate over time (24h, 7d, 30d averages)
  - Performance trends

- **Template Variables**:
  - Environment selector (dev, prod)
  - Database selector
  - Time range selector
  - Data source selector

## How to Import the Dashboard

1. Access your Grafana instance:
   ```bash
   kubectl port-forward svc/grafana -n monitoring 3000:3000
   ```
   Then open http://localhost:3000 in your browser.

2. Click on the "+" icon in the left sidebar and select "Import".

3. Click "Upload JSON file" and select the `grafana-dashboard.json` file from the `dashboards/` directory, or copy and paste its contents.

4. Configure the dashboard:
   - Select your Prometheus data source
   - Adjust the dashboard name if needed
   - Set the appropriate UID or leave as is for a new dashboard

5. Click "Import" to finish.

## Using the Dashboard

1. Use the top filters to select:
   - Environment (dev/prod)
   - Database
   - Time range

2. The dashboard is organized in sections:
   - **Overview**: Quick status and trends
   - **Error Tracking**: Tables showing any errors
   - **Historical Success Rate**: Long-term success metrics

3. For troubleshooting:
   - Check the "Backup Errors" and "Connection Errors" tables first
   - Review success rate trends to identify patterns
   - Examine backup duration and size for performance issues

## Metrics Monitored

The dashboard visualizes these metrics:

| Metric | Description | Panel Type |
|--------|-------------|------------|
| `pg_backup_success` | Backup success (1) or failure (0) | Stat + Graph |
| `pg_backup_duration_seconds` | Time taken to complete backup | Graph |
| `pg_backup_encrypted_size_bytes` | Size of the encrypted backup file | Graph |
| `pg_backup_error` | Detailed backup errors with step information | Table |
| `pg_backup_connection_error` | Connection errors (PostgreSQL and S3) | Table |

## Dashboard Maintenance

To update the dashboard:

1. Make changes in the Grafana UI
2. Use the "Share" button and select "Export"
3. Choose "Export for sharing externally"
4. Save the JSON and replace the existing file

## Additional Notes

- The dashboard auto-refreshes every minute by default
- Template variables are configured to pull available environments and databases dynamically
- Error panels only show when errors are present
- Historical success rate is calculated using Prometheus time functions