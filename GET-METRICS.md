# Accessing Backup Metrics in Prometheus

The backup system pushes metrics to the Prometheus Pushgateway service, which is later scraped by Prometheus. These metrics can be accessed in several ways:

## Option 1: Port-forward the Prometheus Pushgateway

1. First, identify the Pushgateway service:
   ```bash
   kubectl get svc -n prometheus
   ```

2. Port-forward the Pushgateway service to access it locally:
   ```bash
   kubectl port-forward svc/pushgateway-prometheus-pushgateway -n prometheus 9091:9091
   ```

3. Access the metrics in your browser at:
   ```
   http://localhost:9091/metrics
   ```

4. You can filter for pg_backup metrics:
   ```
   http://localhost:9091/metrics | grep pg_backup
   ```

## Option 2: Port-forward Prometheus and use its interface

1. Port-forward the Prometheus service:
   ```bash
   kubectl port-forward svc/prometheus-server -n prometheus 9090:9090
   ```

2. Access the Prometheus UI in your browser at:
   ```
   http://localhost:9090/graph
   ```

3. In the "Expression" field, enter one of these queries:
   - `pg_backup_success` - Shows backup success status (1 = success, 0 = failure)
   - `pg_backup_duration_seconds` - Shows backup duration
   - `pg_backup_encrypted_size_bytes` - Shows backup size
   - `pg_backup_error` - Shows error details if any
   - `pg_backup_connection_error` - Shows connection errors if any

## Option 3: Access via Grafana (if deployed)

If Grafana is deployed in your cluster:

1. Port-forward the Grafana service:
   ```bash
   kubectl port-forward svc/grafana -n monitoring 3000:3000
   ```

2. Access Grafana in your browser at:
   ```
   http://localhost:3000
   ```

3. Create a new dashboard with panels for each of the backup metrics:
   - Add a Stat panel for `pg_backup_success`
   - Add a Graph panel for `pg_backup_duration_seconds`
   - Add a Graph panel for `pg_backup_encrypted_size_bytes`
   - Add a Table panel for `pg_backup_error` and `pg_backup_connection_error`

## Debugging Pushgateway Connectivity

If you're having trouble accessing the metrics, you can debug by:

1. Check if Pushgateway pod is running:
   ```bash
   kubectl get pods -n prometheus | grep pushgateway
   ```

2. Check Pushgateway logs:
   ```bash
   kubectl logs -n prometheus $(kubectl get pods -n prometheus | grep pushgateway | awk '{print $1}')
   ```

3. Check backup pod logs for Pushgateway-related messages:
   ```bash
   kubectl logs -n <namespace> <backup-pod-name>
   ```

4. You can temporarily modify the backup pod to test connectivity to Pushgateway:
   ```bash
   kubectl exec -it <backup-pod-name> -n <namespace> -- curl -v http://pushgateway-prometheus-pushgateway.prometheus.svc.cluster.local:9091/metrics
   ```

## Common Issues

1. **Empty query result in Prometheus/Pushgateway**:
   - The metrics might not have been pushed successfully
   - Check the backup job logs for connectivity issues
   - Verify the PUSHGATEWAY_URL in the ConfigMap is correct
   - Ensure the Pushgateway service is running and accessible from the backup pod

2. **Unable to access port-forwarded services locally**:
   - Ensure the port isn't already in use on your local machine
   - Check that you have the correct namespace and service name
   - Verify you have permissions to perform port-forwarding

3. **Metrics exist but quickly disappear**:
   - By default, Prometheus Pushgateway retains metrics until they are scraped. Ensure Prometheus is configured to scrape the Pushgateway.

## Debugging Pushgateway Connectivity

  1. Check Metrics in Prometheus:

  First, let's port-forward the Pushgateway service to access it locally:

  # Port-forward the Pushgateway service
  kubectl port-forward svc/pushgateway-prometheus-pushgateway -n prometheus
  9091:9091

  Then, you can access the raw metrics directly from Pushgateway at:
  http://localhost:9091/metrics

  2. Set up Prometheus Queries:

  If you have Prometheus running, you can set up port-forwarding to access it:

  # Port-forward the Prometheus service
  kubectl port-forward svc/prometheus-server -n prometheus 9090:9090

  Then visit http://localhost:9090/graph and query these metrics:

  - Backup success: pg_backup_success
  - Backup duration: pg_backup_duration_seconds
  - Backup size: pg_backup_encrypted_size_bytes
  - Backup errors: pg_backup_error
  - Connection errors: pg_backup_connection_error

  3. Create a Grafana Dashboard:

  If you have Grafana, you can create a dashboard with panels showing:

  - Backup success rate (as a stat or gauge)
  - Backup duration over time (as a graph)
  - Backup size over time (as a graph)
  - Recent error messages (as a table)

  The key metrics you should monitor are:
  - pg_backup_success{database="chat",environment="dev"} - Value of 1 indicates
  successful backup
  - pg_backup_duration_seconds{database="chat",environment="dev"} - How long the
  backup took
  - pg_backup_encrypted_size_bytes{database="chat",environment="dev"} - Size of the
  encrypted backup

  For any failures, check:
  - pg_backup_error{database="chat",environment="dev"} - General backup errors
  - pg_backup_connection_error{database="chat",environment="dev"} -
  Connection-specific errors

  These metrics include labels for the database name and environment, allowing you
  to filter and compare metrics across different databases and environments.