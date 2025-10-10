#!/bin/bash

# Auto-Update Script for TechEazy DevOps Application
# This script checks S3 for new JAR versions every 5 minutes and updates the application

set -euo pipefail

# Configuration
S3_BUCKET="${s3_jar_bucket}"
S3_LOGS_BUCKET="${s3_logs_bucket}"
JAR_NAME="${jar_file_name}"
APP_DIR="/opt/app"
BACKUP_DIR="/opt/app/backups"
CURRENT_JAR="$APP_DIR/current/$JAR_NAME"
VERSION_FILE="$APP_DIR/.current_version"
LOG_FILE="/var/log/app/auto-update.log"
INSTANCE_ID=$(ec2-metadata --instance-id | cut -d " " -f 2)
INSTANCE_INDEX=$(cat /opt/app/.instance_index)

# Logging function
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [$INSTANCE_ID] $1" | tee -a "$LOG_FILE"
}

# Function to get S3 object ETag (version identifier)
get_s3_etag() {
    aws s3api head-object \
        --bucket "$S3_BUCKET" \
        --key "$JAR_NAME" \
        --query 'ETag' \
        --output text 2>/dev/null | tr -d '"'
}

# Function to get current version
get_current_version() {
    if [ -f "$VERSION_FILE" ]; then
        cat "$VERSION_FILE"
    else
        echo "none"
    fi
}

# Function to download JAR from S3
download_jar() {
    local temp_jar="$APP_DIR/temp/$JAR_NAME"
    mkdir -p "$APP_DIR/temp"
    
    log "Downloading new JAR from S3..."
    if aws s3 cp "s3://$S3_BUCKET/$JAR_NAME" "$temp_jar"; then
        log "JAR downloaded successfully"
        echo "$temp_jar"
        return 0
    else
        log "ERROR: Failed to download JAR from S3"
        return 1
    fi
}

# Function to backup current JAR
backup_current_jar() {
    if [ -f "$CURRENT_JAR" ]; then
        mkdir -p "$BACKUP_DIR"
        local backup_file="$BACKUP_DIR/${JAR_NAME}.$(date +%Y%m%d_%H%M%S)"
        cp "$CURRENT_JAR" "$backup_file"
        log "Current JAR backed up to $backup_file"
        
        # Keep only last 3 backups
        ls -t "$BACKUP_DIR"/*.jar 2>/dev/null | tail -n +4 | xargs -r rm
    fi
}

# Function to stop application
stop_application() {
    log "Stopping application..."
    if systemctl is-active --quiet app; then
        systemctl stop app
        sleep 5
        log "Application stopped"
        return 0
    else
        log "Application was not running"
        return 0
    fi
}

# Function to start application
start_application() {
    log "Starting application..."
    systemctl start app
    sleep 10
    
    # Check if application started successfully
    if systemctl is-active --quiet app; then
        log "Application started successfully"
        return 0
    else
        log "ERROR: Application failed to start"
        return 1
    fi
}

# Function to verify application health
verify_health() {
    local max_attempts=12
    local attempt=0
    
    log "Verifying application health..."
    
    while [ $attempt -lt $max_attempts ]; do
        if curl -f -s http://localhost:80/actuator/health > /dev/null 2>&1; then
            log "Health check passed"
            return 0
        fi
        attempt=$((attempt + 1))
        log "Health check attempt $attempt/$max_attempts failed, retrying..."
        sleep 5
    done
    
    log "ERROR: Health check failed after $max_attempts attempts"
    return 1
}

# Function to rollback to previous version
rollback() {
    log "ROLLBACK: Initiating rollback to previous version..."
    
    local latest_backup=$(ls -t "$BACKUP_DIR"/*.jar 2>/dev/null | head -n 1)
    
    if [ -n "$latest_backup" ]; then
        log "ROLLBACK: Found backup at $latest_backup"
        
        # Stop current application
        stop_application
        
        # Restore backup
        cp "$latest_backup" "$CURRENT_JAR"
        log "ROLLBACK: Restored backup JAR"
        
        # Start application
        if start_application && verify_health; then
            log "ROLLBACK: Successful - Application running on previous version"
            
            # Update version file
            local backup_etag=$(md5sum "$latest_backup" | cut -d' ' -f1)
            echo "$backup_etag" > "$VERSION_FILE"
            
            return 0
        else
            log "ROLLBACK: FAILED - Manual intervention required!"
            return 1
        fi
    else
        log "ROLLBACK: FAILED - No backup found!"
        return 1
    fi
}

# Function to upload logs to S3 (instance-specific path)
upload_logs() {
    local log_prefix="instance-$INSTANCE_INDEX"
    local timestamp=$(date +%Y%m%d_%H%M%S)
    
    # Upload auto-update log
    if [ -f "$LOG_FILE" ]; then
        aws s3 cp "$LOG_FILE" \
            "s3://$S3_LOGS_BUCKET/$log_prefix/auto-update-$timestamp.log" \
            --quiet 2>/dev/null || true
    fi
    
    # Upload application log
    if [ -f "/var/log/app/application.log" ]; then
        aws s3 cp "/var/log/app/application.log" \
            "s3://$S3_LOGS_BUCKET/$log_prefix/application-$timestamp.log" \
            --quiet 2>/dev/null || true
    fi
}

# Main update logic
main() {
    log "===== Auto-Update Check Started ====="
    
    # Check if S3 bucket exists
    if ! aws s3 ls "s3://$S3_BUCKET" >/dev/null 2>&1; then
        log "ERROR: Cannot access S3 bucket $S3_BUCKET"
        exit 1
    fi
    
    # Get current version
    current_version=$(get_current_version)
    log "Current version: $current_version"
    
    # Get latest version from S3
    latest_version=$(get_s3_etag)
    
    if [ -z "$latest_version" ]; then
        log "WARNING: No JAR found in S3 bucket"
        exit 0
    fi
    
    log "Latest version in S3: $latest_version"
    
    # Check if update is needed
    if [ "$current_version" = "$latest_version" ]; then
        log "No update needed - versions match"
        exit 0
    fi
    
    log "UPDATE NEEDED: New version detected"
    
    # Download new JAR
    new_jar=$(download_jar)
    if [ $? -ne 0 ]; then
        log "ERROR: Update failed at download stage"
        exit 1
    fi
    
    # Backup current JAR
    backup_current_jar
    
    # Stop application
    if ! stop_application; then
        log "ERROR: Failed to stop application"
        exit 1
    fi
    
    # Replace JAR
    mkdir -p "$(dirname "$CURRENT_JAR")"
    mv "$new_jar" "$CURRENT_JAR"
    chmod +x "$CURRENT_JAR"
    log "New JAR installed"
    
    # Start application
    if ! start_application; then
        log "ERROR: Failed to start application with new version"
        rollback
        exit 1
    fi
    
    # Verify health
    if ! verify_health; then
        log "ERROR: Health check failed for new version"
        rollback
        exit 1
    fi
    
    # Update version file
    echo "$latest_version" > "$VERSION_FILE"
    log "Version file updated"
    
    # Upload logs to S3
    upload_logs
    
    log "===== Update Completed Successfully ====="
    log "Application updated from $current_version to $latest_version"
}

# Run main function
main "$@"
