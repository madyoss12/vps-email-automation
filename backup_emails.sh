#!/bin/bash
# Email Backup Automation Script
# Creates automated backups of email data and configurations

set -euo pipefail

# Configuration
BACKUP_DIR="/opt/email-backups"
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
BACKUP_NAME="email_backup_${TIMESTAMP}"
RETENTION_DAYS=30

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

log() {
    echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')] $1${NC}"
}

warn() {
    echo -e "${YELLOW}[WARNING] $1${NC}"
}

error() {
    echo -e "${RED}[ERROR] $1${NC}"
}

# Create backup directory
create_backup_dir() {
    mkdir -p "${BACKUP_DIR}/${BACKUP_NAME}"
    cd "${BACKUP_DIR}/${BACKUP_NAME}"
    log "Created backup directory: ${BACKUP_DIR}/${BACKUP_NAME}"
}

# Backup MySQL database
backup_database() {
    log "Backing up MySQL database..."
    
    # Read MySQL credentials
    if [[ -f "/root/credentials.json" ]]; then
        MYSQL_PASS=$(grep -o '"mysql_root_password": "[^"]*"' /root/credentials.json | cut -d'"' -f4)
        
        mysqldump -u root -p"${MYSQL_PASS}" mailserver > mailserver_backup.sql
        
        # Compress the SQL dump
        gzip mailserver_backup.sql
        
        log "Database backup completed: mailserver_backup.sql.gz"
    else
        error "MySQL credentials not found"
        return 1
    fi
}

# Backup mail directories
backup_mail_directories() {
    log "Backing up mail directories..."
    
    if [[ -d "/var/mail/vhosts" ]]; then
        tar -czf mail_directories.tar.gz -C /var/mail vhosts/
        log "Mail directories backup completed: mail_directories.tar.gz"
    else
        warn "Mail directories not found at /var/mail/vhosts"
    fi
}

# Backup configuration files
backup_configurations() {
    log "Backing up configuration files..."
    
    mkdir -p configs
    
    # Postfix configurations
    if [[ -d "/etc/postfix" ]]; then
        cp -r /etc/postfix configs/
        log "Postfix configuration backed up"
    fi
    
    # Dovecot configurations
    if [[ -d "/etc/dovecot" ]]; then
        cp -r /etc/dovecot configs/
        log "Dovecot configuration backed up"
    fi
    
    # Nginx configurations
    if [[ -d "/etc/nginx" ]]; then
        cp -r /etc/nginx configs/
        log "Nginx configuration backed up"
    fi
    
    # SSL certificates
    if [[ -d "/etc/letsencrypt" ]]; then
        cp -r /etc/letsencrypt configs/
        log "SSL certificates backed up"
    fi
    
    # System credentials
    if [[ -f "/root/credentials.json" ]]; then
        cp /root/credentials.json configs/
        log "System credentials backed up"
    fi
    
    # Compress configurations
    tar -czf configurations.tar.gz configs/
    rm -rf configs/
    
    log "Configuration backup completed: configurations.tar.gz"
}

# Create backup manifest
create_manifest() {
    log "Creating backup manifest..."
    
    cat > backup_manifest.json << EOF
{
  "backup_name": "${BACKUP_NAME}",
  "timestamp": "${TIMESTAMP}",
  "created_at": "$(date -Iseconds)",
  "hostname": "$(hostname)",
  "ip_address": "$(curl -s ipinfo.io/ip || echo 'unknown')",
  "files": [
    $(find . -type f -name "*.tar.gz" -o -name "*.sql.gz" -o -name "*.json" | sed 's/^/    "/' | sed 's/$/"/' | paste -sd,)
  ],
  "total_size": "$(du -sh . | cut -f1)",
  "backup_type": "full"
}
EOF
    
    log "Backup manifest created: backup_manifest.json"
}

# Cleanup old backups
cleanup_old_backups() {
    log "Cleaning up backups older than ${RETENTION_DAYS} days..."
    
    find "${BACKUP_DIR}" -type d -name "email_backup_*" -mtime +${RETENTION_DAYS} -exec rm -rf {} \; 2>/dev/null || true
    
    log "Old backup cleanup completed"
}

# Upload to remote storage (optional)
upload_to_remote() {
    if [[ -n "${REMOTE_BACKUP_URL:-}" ]]; then
        log "Uploading backup to remote storage..."
        
        # Create final archive
        cd "${BACKUP_DIR}"
        tar -czf "${BACKUP_NAME}.tar.gz" "${BACKUP_NAME}/"
        
        # Upload via rsync, scp, or cloud storage
        # Example for rsync:
        # rsync -avz "${BACKUP_NAME}.tar.gz" "${REMOTE_BACKUP_URL}/"
        
        # Example for AWS S3:
        # aws s3 cp "${BACKUP_NAME}.tar.gz" "s3://your-backup-bucket/email-backups/"
        
        log "Remote backup upload completed"
        
        # Remove local archive after successful upload
        rm -f "${BACKUP_NAME}.tar.gz"
    else
        log "No remote backup configured"
    fi
}

# Send notification
send_notification() {
    local status="$1"
    local message="$2"
    
    if [[ -n "${WEBHOOK_URL:-}" ]]; then
        curl -X POST -H "Content-Type: application/json" \
             -d "{\"text\":\"Email Backup ${status}: ${message}\"}" \
             "${WEBHOOK_URL}" &>/dev/null || true
    fi
}

# Main backup function
main() {
    log "🗄️ Starting email backup process..."
    
    # Check if running as root
    if [[ $EUID -ne 0 ]]; then
        error "This script must be run as root"
        exit 1
    fi
    
    # Create backup directory
    create_backup_dir
    
    # Perform backups
    backup_database || {
        error "Database backup failed"
        send_notification "FAILED" "Database backup failed"
        exit 1
    }
    
    backup_mail_directories
    backup_configurations
    create_manifest
    
    # Calculate final backup size
    BACKUP_SIZE=$(du -sh "${BACKUP_DIR}/${BACKUP_NAME}" | cut -f1)
    
    log "📦 Backup completed successfully"
    log "   Location: ${BACKUP_DIR}/${BACKUP_NAME}"
    log "   Size: ${BACKUP_SIZE}"
    
    # Upload to remote storage
    upload_to_remote
    
    # Cleanup old backups
    cleanup_old_backups
    
    # Send success notification
    send_notification "SUCCESS" "Backup completed (${BACKUP_SIZE})"
    
    log "🎉 Email backup process completed successfully!"
}

# Handle script arguments
case "${1:-}" in
    --help|-h)
        cat << EOF
Email Backup Automation Script

Usage:
    $0                    # Run full backup
    $0 --help            # Show this help
    $0 --cron            # Run in cron mode (quiet)

Environment Variables:
    REMOTE_BACKUP_URL    # Remote storage URL for backups
    WEBHOOK_URL          # Webhook URL for notifications
    RETENTION_DAYS       # Days to keep backups (default: 30)

Examples:
    # Manual backup
    sudo $0
    
    # Cron job (daily at 2 AM)
    0 2 * * * /opt/email-automation/backup_emails.sh --cron
    
    # With remote backup
    REMOTE_BACKUP_URL="user@backup-server:/backups/" sudo $0
EOF
        exit 0
        ;;
    --cron)
        # Cron mode - suppress non-error output
        exec > /var/log/email-backup.log 2>&1
        ;;
esac

# Run main function
main "$@"
