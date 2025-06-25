#!/bin/bash
# PostgreSQL Backup Decryption Test Script
#
# This script decrypts and validates PostgreSQL backup files that were encrypted
# using the pg_backup system's OpenSSL encryption (AES-256-CBC).
#
# USAGE:
#   1. Set the backup password:
#      export BACKUP_PASSWORD="your-encryption-password"
#      
#   2. Run the script:
#      ./decrypt_backups_test.sh
#
# PREREQUISITES:
#   - OpenSSL (for decryption)
#   - PostgreSQL client tools (pg_restore) for validation (optional but recommended)
#   - xxd (for hex analysis)
#   - Encrypted backup files in ../backups/ directory with .enc extension
#
# DIRECTORY STRUCTURE:
#   ../backups/           - Directory containing encrypted backup files (*.enc)
#   ../decrypted_backups/ - Output directory for decrypted files (created automatically)
#
# ENVIRONMENT VARIABLES:
#   BACKUP_PASSWORD       - The encryption password used during backup creation
#   BACKUPS_DIR          - Override default backup directory (default: ../backups)
#   OUTPUT_DIR           - Override default output directory (default: ../decrypted_backups)
#
# EXAMPLES:
#   # Basic usage with environment variable
#   export BACKUP_PASSWORD="my-secret-password"
#   ./decrypt_backups_test.sh
#
#   # Using custom directories
#   export BACKUP_PASSWORD="my-secret-password"
#   export BACKUPS_DIR="/path/to/encrypted/backups"
#   export OUTPUT_DIR="/path/to/output"
#   ./decrypt_backups_test.sh
#
#   # One-liner for testing
#   BACKUP_PASSWORD="my-secret-password" ./decrypt_backups_test.sh
#
# FEATURES:
#   - Automatically finds all .enc files in the backup directory
#   - Decrypts files using OpenSSL AES-256-CBC
#   - Validates PostgreSQL dump format and structure
#   - Performs integrity checks (checksums, file format validation)
#   - Extracts detailed database schema information
#   - Provides restore instructions for decrypted files
#   - Generates comprehensive summary reports
#
# OUTPUT:
#   - Decrypted backup files in the output directory
#   - Detailed validation reports for each file
#   - Database schema analysis (tables, indexes, constraints, etc.)
#   - File integrity verification results
#   - Summary statistics and restore instructions

set -e

# Configuration - can be overridden by environment variables
BACKUPS_DIR="${BACKUPS_DIR:-../backups}"
OUTPUT_DIR="${OUTPUT_DIR:-../decrypted_backups}"
BACKUP_PASSWORD="${BACKUP_PASSWORD:-}"  # Set via environment variable: export BACKUP_PASSWORD="your-password"

# Validate that password is set
if [ -z "$BACKUP_PASSWORD" ]; then
    echo "ERROR: BACKUP_PASSWORD environment variable is not set."
    echo ""
    echo "Please set the backup password using one of these methods:"
    echo "  export BACKUP_PASSWORD=\"your-encryption-password\""
    echo "  BACKUP_PASSWORD=\"your-password\" ./decrypt_backups_test.sh"
    echo ""
    echo "The password should match the 'encrypt_password' value used during backup creation."
    exit 1
fi

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo "=== PostgreSQL Backup Decryption Test Script ==="
echo "Backup directory: $BACKUPS_DIR"
echo "Output directory: $OUTPUT_DIR"
echo ""

# Create output directory if it doesn't exist
mkdir -p "$OUTPUT_DIR"

# Function to stream validate PostgreSQL dump
stream_validate_dump() {
    local dump_file="$1"
    local filename=$(basename "$dump_file")
    
    echo -e "${BLUE}Stream validating $filename...${NC}"
    
    # Check file size
    local size=$(stat -f%z "$dump_file" 2>/dev/null || stat -c%s "$dump_file" 2>/dev/null)
    echo "  → File size: $(numfmt --to=iec --suffix=B $size)"
    
    # Read first few bytes to identify format
    local header=$(head -c 16 "$dump_file" | xxd -p)
    echo "  → Header (hex): ${header:0:32}..."
    
    # Check for PostgreSQL custom format magic bytes
    if head -c 8 "$dump_file" | grep -q "PGDMP"; then
        echo -e "  → ${GREEN}PostgreSQL custom format detected${NC}"
        
        # Stream through and count objects without loading entire file
        if command -v pg_restore >/dev/null 2>&1; then
            local object_count=$(pg_restore --list "$dump_file" 2>/dev/null | wc -l | tr -d ' ')
            echo "  → Database objects: $object_count"
            
            # Sample first few objects
            echo "  → Sample objects:"
            pg_restore --list "$dump_file" 2>/dev/null | head -3 | sed 's/^/    /'
            
            # Check for specific PostgreSQL structures
            local table_count=$(pg_restore --list "$dump_file" 2>/dev/null | grep -c "TABLE" || echo "0")
            local index_count=$(pg_restore --list "$dump_file" 2>/dev/null | grep -c "INDEX" || echo "0")
            local sequence_count=$(pg_restore --list "$dump_file" 2>/dev/null | grep -c "SEQUENCE" || echo "0")
            
            echo "  → Tables: $table_count, Indexes: $index_count, Sequences: $sequence_count"
            
            # List actual table names
            echo "  → Table list:"
            pg_restore --list "$dump_file" 2>/dev/null | grep "TABLE DATA" | head -10 | sed 's/.*TABLE DATA \([^ ]*\) \([^ ]*\).*/    \2/' | sort
            if [ "$table_count" -gt 10 ]; then
                echo "    ... and $((table_count - 10)) more tables"
            fi
        fi
        return 0
        
    # Check for plain SQL format
    elif head -n 5 "$dump_file" | grep -q "PostgreSQL database dump"; then
        echo -e "  → ${GREEN}PostgreSQL plain SQL format detected${NC}"
        
        # Stream through first part of file to get info
        echo "  → SQL dump header:"
        head -n 10 "$dump_file" | grep "^--" | head -5 | sed 's/^/    /'
        
        # Count SQL statements by streaming
        local create_count=$(head -n 1000 "$dump_file" | grep -c "^CREATE" || echo "0")
        local insert_count=$(head -n 1000 "$dump_file" | grep -c "^INSERT" || echo "0")
        echo "  → Sample counts (first 1000 lines): CREATE statements: $create_count, INSERT statements: $insert_count"
        return 0
        
    # Check if it might be compressed
    elif file "$dump_file" | grep -q "gzip"; then
        echo -e "  → ${YELLOW}Gzipped file detected - checking contents${NC}"
        
        # Stream decompress and check
        if zcat "$dump_file" | head -c 8 | grep -q "PGDMP"; then
            echo -e "  → ${GREEN}Compressed PostgreSQL custom format${NC}"
        elif zcat "$dump_file" | head -n 5 | grep -q "PostgreSQL database dump"; then
            echo -e "  → ${GREEN}Compressed PostgreSQL SQL dump${NC}"
        else
            echo -e "  → ${YELLOW}Compressed but unknown format${NC}"
        fi
        return 0
        
    else
        echo -e "  → ${YELLOW}Unknown format - streaming content analysis${NC}"
        
        # Stream analyze content
        local first_line=$(head -n 1 "$dump_file")
        echo "  → First line: ${first_line:0:80}..."
        
        # Check for common SQL patterns
        if head -n 20 "$dump_file" | grep -qi "CREATE\|INSERT\|SELECT\|DROP"; then
            echo -e "  → ${GREEN}Contains SQL statements${NC}"
        else
            echo -e "  → ${RED}No SQL patterns detected${NC}"
        fi
        
        # Check for binary data
        if head -c 1024 "$dump_file" | grep -q "[^[:print:][:space:]]"; then
            echo -e "  → ${YELLOW}Binary data detected${NC}"
        else
            echo -e "  → ${GREEN}Text format detected${NC}"
        fi
        return 1
    fi
}

# Function to extract and display table information
extract_table_info() {
    local dump_file="$1"
    local filename=$(basename "$dump_file")
    
    echo -e "${BLUE}Extracting detailed table information from $filename...${NC}"
    
    if command -v pg_restore >/dev/null 2>&1; then
        # Get all tables with their schemas
        echo "  → All tables in database:"
        pg_restore --list "$dump_file" 2>/dev/null | grep "TABLE DATA" | \
        sed 's/.*TABLE DATA \([^ ]*\) \([^ ]*\).*/    \1.\2/' | sort
        
        echo ""
        echo "  → Schema breakdown:"
        pg_restore --list "$dump_file" 2>/dev/null | grep "TABLE DATA" | \
        sed 's/.*TABLE DATA \([^ ]*\) \([^ ]*\).*/\1/' | sort | uniq -c | \
        while read count schema; do
            echo "    - Schema '$schema': $count tables"
        done
        
        echo ""
        echo "  → Table creation statements (first 5):"
        pg_restore --list "$dump_file" 2>/dev/null | grep "TABLE" | grep -v "TABLE DATA" | head -5 | \
        sed 's/^/    /'
        
        # Check for foreign key constraints
        local fk_count=$(pg_restore --list "$dump_file" 2>/dev/null | grep -c "FK CONSTRAINT" || echo "0")
        echo "  → Foreign key constraints: $fk_count"
        
        # Check for triggers
        local trigger_count=$(pg_restore --list "$dump_file" 2>/dev/null | grep -c "TRIGGER" || echo "0")
        echo "  → Triggers: $trigger_count"
        
        # Check for functions/procedures
        local function_count=$(pg_restore --list "$dump_file" 2>/dev/null | grep -c "FUNCTION" || echo "0")
        echo "  → Functions: $function_count"
        
    else
        echo -e "  → ${YELLOW}pg_restore not available - cannot extract table details${NC}"
    fi
}

# Function to stream check data integrity
stream_integrity_check() {
    local dump_file="$1"
    local filename=$(basename "$dump_file")
    
    echo -e "${BLUE}Checking data integrity for $filename...${NC}"
    
    # Calculate MD5 checksum while streaming
    local md5_hash=$(md5sum "$dump_file" 2>/dev/null | cut -d' ' -f1 || md5 "$dump_file" 2>/dev/null | cut -d'=' -f2 | tr -d ' ')
    echo "  → MD5 checksum: $md5_hash"
    
    # Check for truncation or corruption signs
    local tail_content=$(tail -c 100 "$dump_file" | tr -d '\0')
    if [ -z "$tail_content" ]; then
        echo -e "  → ${RED}Warning: File appears to end with null bytes${NC}"
        return 1
    fi
    
    # For PostgreSQL custom format, check end marker
    if head -c 8 "$dump_file" | grep -q "PGDMP"; then
        # Custom format should end properly
        local end_bytes=$(tail -c 8 "$dump_file" | xxd -p)
        echo "  → End bytes (hex): $end_bytes"
    fi
    
    echo -e "  → ${GREEN}File appears intact${NC}"
    return 0
}

# Function to decrypt a single file with streaming validation
decrypt_file() {
    local encrypted_file="$1"
    local filename=$(basename "$encrypted_file")
    local output_file="$OUTPUT_DIR/${filename%.enc}"
    
    echo -n "Decrypting $filename... "
    
    if openssl enc -d -aes-256-cbc -in "$encrypted_file" -out "$output_file" -pass pass:"$BACKUP_PASSWORD" 2>/dev/null; then
        echo -e "${GREEN}SUCCESS${NC}"
        
        # Get file size for verification
        local size=$(stat -f%z "$output_file" 2>/dev/null || stat -c%s "$output_file" 2>/dev/null)
        echo "  → Output: $output_file ($(numfmt --to=iec --suffix=B $size))"
        
        # Stream validate the decrypted content
        if stream_validate_dump "$output_file"; then
            echo -e "  → ${GREEN}Validation: PASSED${NC}"
        else
            echo -e "  → ${YELLOW}Validation: WARNING${NC}"
        fi
        
        # Extract detailed table information
        extract_table_info "$output_file"
        
        # Check data integrity
        stream_integrity_check "$output_file"
        
        return 0
    else
        echo -e "${RED}FAILED${NC}"
        echo "  → Error: Failed to decrypt $filename"
        return 1
    fi
}

# Function to generate summary report
generate_summary() {
    echo ""
    echo -e "${BLUE}=== Detailed Analysis Summary ===${NC}"
    
    if [ -d "$OUTPUT_DIR" ]; then
        local total_size=$(find "$OUTPUT_DIR" -type f -exec stat -f%z {} \; 2>/dev/null | awk '{sum+=$1} END {print sum}' || \
                          find "$OUTPUT_DIR" -type f -exec stat -c%s {} \; 2>/dev/null | awk '{sum+=$1} END {print sum}')
        
        if [ -n "$total_size" ] && [ "$total_size" -gt 0 ]; then
            echo "  → Total decrypted data: $(numfmt --to=iec --suffix=B $total_size)"
        fi
        
        local file_count=$(find "$OUTPUT_DIR" -type f | wc -l | tr -d ' ')
        echo "  → Total files processed: $file_count"
        
        # List all decrypted files with sizes
        echo "  → Decrypted files:"
        find "$OUTPUT_DIR" -type f | while read -r file; do
            local size=$(stat -f%z "$file" 2>/dev/null || stat -c%s "$file" 2>/dev/null)
            echo "    - $(basename "$file"): $(numfmt --to=iec --suffix=B $size)"
        done
    fi
}

# Check if backups directory exists
if [ ! -d "$BACKUPS_DIR" ]; then
    echo -e "${RED}Error: Backup directory '$BACKUPS_DIR' does not exist${NC}"
    echo "Please create the directory and place your encrypted backup files there."
    exit 1
fi

# Find all encrypted backup files
encrypted_files=($(find "$BACKUPS_DIR" -name "*.enc" -type f))

if [ ${#encrypted_files[@]} -eq 0 ]; then
    echo -e "${YELLOW}No encrypted files (*.enc) found in $BACKUPS_DIR${NC}"
    echo "Looking for any files that might be backups..."
    
    # Look for any files that might be backups
    all_files=($(find "$BACKUPS_DIR" -type f))
    if [ ${#all_files[@]} -eq 0 ]; then
        echo -e "${RED}No files found in backup directory${NC}"
        exit 1
    else
        echo "Found files:"
        for file in "${all_files[@]}"; do
            size=$(stat -f%z "$file" 2>/dev/null || stat -c%s "$file" 2>/dev/null)
            echo "  - $(basename "$file") ($(numfmt --to=iec --suffix=B $size))"
        done
        echo ""
        echo "If these are encrypted backups, they should have .enc extension"
    fi
    exit 1
fi

echo "Found ${#encrypted_files[@]} encrypted backup file(s):"
for file in "${encrypted_files[@]}"; do
    size=$(stat -f%z "$file" 2>/dev/null || stat -c%s "$file" 2>/dev/null)
    echo "  - $(basename "$file") ($(numfmt --to=iec --suffix=B $size))"
done
echo ""

# Decrypt all files with streaming validation
success_count=0
total_count=${#encrypted_files[@]}

for encrypted_file in "${encrypted_files[@]}"; do
    if decrypt_file "$encrypted_file"; then
        ((success_count++))
    fi
    echo ""
done

echo "=== Decryption Summary ==="
echo "Total files: $total_count"
echo -e "Successful: ${GREEN}$success_count${NC}"
echo -e "Failed: ${RED}$((total_count - success_count))${NC}"

# Generate detailed summary
generate_summary

echo ""
echo "=== Instructions for Restoring ==="
echo "To restore a decrypted backup to a database:"
echo ""
echo "1. For custom format dumps:"
echo "   pg_restore -d your_database_name -U your_username /path/to/decrypted_file"
echo ""
echo "2. For plain SQL dumps:"
echo "   psql -d your_database_name -U your_username < /path/to/decrypted_file.sql"
echo ""
echo "3. To stream restore large files without loading into memory:"
echo "   pg_restore -d your_database_name -U your_username --single-transaction /path/to/decrypted_file"
echo ""
echo "Decrypted files are available in: $OUTPUT_DIR"

if [ $success_count -eq $total_count ]; then
    echo -e "${GREEN}All files decrypted and validated successfully!${NC}"
    exit 0
else
    echo -e "${RED}Some files failed to decrypt. Check the password and file integrity.${NC}"
    exit 1
fi