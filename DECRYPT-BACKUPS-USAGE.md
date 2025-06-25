# PostgreSQL Backup Decryption Script Usage

This script (`decrypt_backups_test.sh`) decrypts and validates PostgreSQL backup files that were encrypted using the pg_backup system's OpenSSL encryption (AES-256-CBC).

## Quick Start

1. **Set the backup password**:
   ```bash
   export BACKUP_PASSWORD="your-encryption-password"
   ```

2. **Run the script**:
   ```bash
   ./decrypt_backups_test.sh
   ```

## Prerequisites

- **OpenSSL** - For decryption operations
- **PostgreSQL client tools** (`pg_restore`) - For validation (optional but recommended)
- **xxd** - For hex analysis of file headers
- **Encrypted backup files** - Files with `.enc` extension in the backup directory

## Directory Structure

```
pg_backup/
├── decrypt_backups_test.sh          # This script
├── ../backups/                      # Input: encrypted backup files (*.enc)
└── ../decrypted_backups/           # Output: decrypted files (created automatically)
```

## Environment Variables

| Variable | Description | Default | Required |
|----------|-------------|---------|----------|
| `BACKUP_PASSWORD` | Encryption password used during backup creation | - | **Yes** |
| `BACKUPS_DIR` | Directory containing encrypted backup files | `../backups` | No |
| `OUTPUT_DIR` | Directory for decrypted output files | `../decrypted_backups` | No |

## Usage Examples

### Basic Usage
```bash
# Set password and run
export BACKUP_PASSWORD="my-secret-password"
./decrypt_backups_test.sh
```

### One-liner
```bash
# Run with password in single command
BACKUP_PASSWORD="my-secret-password" ./decrypt_backups_test.sh
```

### Custom Directories
```bash
# Use custom input/output directories
export BACKUP_PASSWORD="my-secret-password"
export BACKUPS_DIR="/path/to/encrypted/backups"
export OUTPUT_DIR="/path/to/output"
./decrypt_backups_test.sh
```

### Secure Password Input
```bash
# Prompt for password (doesn't show in terminal)
read -s -p "Enter backup password: " BACKUP_PASSWORD
export BACKUP_PASSWORD
./decrypt_backups_test.sh
```

## Script Features

### 🔓 **Decryption**
- Automatically discovers all `.enc` files in the backup directory
- Uses OpenSSL AES-256-CBC decryption (matching the backup encryption method)
- Handles multiple files in batch

### ✅ **Validation**
- **Format Detection**: Identifies PostgreSQL custom format vs. plain SQL dumps
- **Magic Bytes Check**: Verifies proper PostgreSQL dump headers
- **Compression Support**: Handles gzipped backup files
- **Integrity Verification**: MD5 checksums and file completeness checks

### 📊 **Database Analysis**
- **Schema Information**: Lists all tables, indexes, sequences
- **Object Counts**: Shows database objects by type
- **Table Details**: Schema breakdown and foreign key constraints
- **Function Analysis**: Identifies stored procedures and triggers

### 📈 **Reporting**
- **Progress Tracking**: Real-time status for each file
- **Summary Statistics**: Success/failure counts and file sizes
- **Restore Instructions**: Commands for importing decrypted backups
- **Color-coded Output**: Visual indicators for success/failure/warnings

## Expected Output

```
=== PostgreSQL Backup Decryption Test Script ===
Backup directory: ../backups
Output directory: ../decrypted_backups

Found 2 encrypted backup file(s):
  - chat_backup_2024-01-15.sql.enc (45.2MB)
  - chat_backup_2024-01-16.sql.enc (46.1MB)

Decrypting chat_backup_2024-01-15.sql.enc... SUCCESS
  → Output: ../decrypted_backups/chat_backup_2024-01-15.sql (156.7MB)
  → PostgreSQL custom format detected
  → Database objects: 847
  → Tables: 23, Indexes: 45, Sequences: 12
  → Validation: PASSED
  → File appears intact

=== Decryption Summary ===
Total files: 2
Successful: 2
Failed: 0

=== Instructions for Restoring ===
To restore a decrypted backup to a database:

1. For custom format dumps:
   pg_restore -d your_database_name -U your_username /path/to/decrypted_file

2. For plain SQL dumps:
   psql -d your_database_name -U your_username < /path/to/decrypted_file.sql
```

## Troubleshooting

### Password Issues
```bash
# Error: Wrong password
ERROR: BACKUP_PASSWORD environment variable is not set.
# Solution: Set the correct encryption password

# Error: Decryption failed
Decrypting file.sql.enc... FAILED
# Solution: Verify password matches the one used during backup creation
```

### File Issues
```bash
# Error: No encrypted files found
No encrypted files (*.enc) found in ../backups
# Solution: Ensure backup files have .enc extension and are in correct directory

# Error: Backup directory doesn't exist
Error: Backup directory '../backups' does not exist
# Solution: Create directory or set BACKUPS_DIR to correct path
```

### Validation Warnings
```bash
# Warning: Unknown format
Unknown format - streaming content analysis
# Note: File may still be valid but not in standard PostgreSQL format
```

## Security Notes

- **Password Handling**: The script validates that `BACKUP_PASSWORD` is set before proceeding
- **No Hardcoding**: Passwords are never stored in the script itself
- **Environment Variables**: Use environment variables for secure password handling
- **Temporary Files**: Script automatically cleans up temporary files on completion

## Integration with pg_backup System

This script is designed to work with backups created by the pg_backup Kubernetes system:

- **Encryption Method**: Matches OpenSSL AES-256-CBC used by backup.sh
- **File Extensions**: Expects `.enc` extension used by the backup system
- **Password Source**: Uses same `encrypt_password` from the secrets configuration

The `BACKUP_PASSWORD` should match the `encrypt_password` value from your pg_backup secrets:
```yaml
# From kustomize/overlays/*/secrets.yaml
stringData:
  encrypt_password: your-strong-password  # Use this value
```

## Related Files

- `kustomize/base/scripts-configmap.yaml` - Contains the backup.sh script that creates encrypted files
- `kustomize/overlays/*/secrets.yaml` - Contains the encrypt_password used for encryption
- `README.md` - Main project documentation
- `CLAUDE.md` - Development guidance and architecture overview 