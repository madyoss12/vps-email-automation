#!/bin/bash
# Enhanced VPS Email Automation - One Line Command System
# Usage: curl -sSL https://raw.githubusercontent.com/madyoss12/vps-email-automation/main/deploy.sh | bash -s -- --domains="domain1.com,domain2.org" --provider="digitalocean" --do-token="your_token"

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Default values
DOMAINS=""
PROVIDER="digitalocean"
DO_TOKEN=""
CF_TOKEN=""
CF_ZONE_ID=""
SSH_KEY_ID=""
REGION="fra1"
SIZE="s-2vcpu-4gb"
ADMIN_EMAIL=""
WEBHOOK_URL=""
SKIP_DNS="false"
SKIP_TESTS="false"
VERBOSE="false"
CHECK_DNS="true"
FORCE_DNS="false"
LOCAL_INSTALL="false"

# Function to print colored output
log() {
    echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')] $1${NC}"
}

error() {
    echo -e "${RED}[ERROR] $1${NC}" >&2
}

warn() {
    echo -e "${YELLOW}[WARNING] $1${NC}"
}

info() {
    echo -e "${BLUE}[INFO] $1${NC}"
}

# Help function
show_help() {
    cat << EOF
Enhanced VPS Email Automation - One Line Deployment

USAGE:
    curl -sSL https://raw.githubusercontent.com/madyoss12/vps-email-automation/main/deploy.sh | bash -s -- [OPTIONS]

DEPLOYMENT MODES:
    --local-install           Install on current server (no VPS provisioning)
    --provider=PROVIDER       Provision new VPS: digitalocean, vultr, linode

REQUIRED OPTIONS:
    --domains=DOMAINS         Comma-separated list of domains (e.g., "domain1.com,domain2.org")
    --do-token=TOKEN         DigitalOcean API token (if provisioning VPS)

DNS OPTIONS:
    --check-dns              Check DNS configuration and conflicts (default: true)
    --skip-dns               Skip DNS configuration entirely
    --force-dns              Force DNS configuration without checks
    --cf-token=TOKEN         Cloudflare API token for automatic DNS
    --cf-zone-id=ID          Cloudflare Zone ID

OPTIONAL:
    --ssh-key-id=ID          SSH key ID (will create if not provided)
    --region=REGION          VPS region (default: fra1)
    --size=SIZE              VPS size (default: s-2vcpu-4gb)
    --admin-email=EMAIL      Admin email for Let's Encrypt
    --webhook-url=URL        Webhook URL for notifications
    --skip-tests             Skip connectivity tests
    --verbose                Enable verbose output
    --help                   Show this help

EXAMPLES:
    # Install on current server (recommended for existing VPS)
    curl -sSL https://raw.githubusercontent.com/madyoss12/vps-email-automation/main/deploy.sh | bash -s -- \\
        --local-install \\
        --domains="hostnodal.cloud" \\
        --admin-email="admin@hostnodal.cloud"

    # Provision new VPS with DigitalOcean
    curl -sSL https://raw.githubusercontent.com/madyoss12/vps-email-automation/main/deploy.sh | bash -s -- \\
        --domains="example.com" \\
        --provider="digitalocean" \\
        --do-token="your_do_token"

    # Full deployment with automatic DNS (Cloudflare)
    curl -sSL https://raw.githubusercontent.com/madyoss12/vps-email-automation/main/deploy.sh | bash -s -- \\
        --local-install \\
        --domains="example.com" \\
        --cf-token="your_cf_token" \\
        --cf-zone-id="your_zone_id" \\
        --admin-email="admin@example.com"

    # Check DNS conflicts only
    curl -sSL https://raw.githubusercontent.com/madyoss12/vps-email-automation/main/deploy.sh | bash -s -- \\
        --local-install \\
        --domains="example.com" \\
        --check-dns \\
        --skip-tests

EOF
}

# Parse command line arguments
parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            --domains=*)
                DOMAINS="${1#*=}"
                shift
                ;;
            --provider=*)
                PROVIDER="${1#*=}"
                shift
                ;;
            --do-token=*)
                DO_TOKEN="${1#*=}"
                shift
                ;;
            --cf-token=*)
                CF_TOKEN="${1#*=}"
                shift
                ;;
            --cf-zone-id=*)
                CF_ZONE_ID="${1#*=}"
                shift
                ;;
            --ssh-key-id=*)
                SSH_KEY_ID="${1#*=}"
                shift
                ;;
            --region=*)
                REGION="${1#*=}"
                shift
                ;;
            --size=*)
                SIZE="${1#*=}"
                shift
                ;;
            --admin-email=*)
                ADMIN_EMAIL="${1#*=}"
                shift
                ;;
            --webhook-url=*)
                WEBHOOK_URL="${1#*=}"
                shift
                ;;
            --local-install)
                LOCAL_INSTALL="true"
                shift
                ;;
            --check-dns)
                CHECK_DNS="true"
                shift
                ;;
            --skip-dns)
                SKIP_DNS="true"
                CHECK_DNS="false"
                shift
                ;;
            --force-dns)
                FORCE_DNS="true"
                shift
                ;;
            --skip-tests)
                SKIP_TESTS="true"
                shift
                ;;
            --verbose)
                VERBOSE="true"
                shift
                ;;
            --help)
                show_help
                exit 0
                ;;
            *)
                error "Unknown option: $1"
                show_help
                exit 1
                ;;
        esac
    done
}

# Validate required parameters
validate_params() {
    if [[ -z "$DOMAINS" ]]; then
        error "Domains are required. Use --domains=\"domain1.com,domain2.org\""
        exit 1
    fi

    if [[ "$LOCAL_INSTALL" == "false" && -z "$DO_TOKEN" && "$PROVIDER" == "digitalocean" ]]; then
        error "DigitalOcean token is required for VPS provisioning. Use --local-install for current server."
        exit 1
    fi

    # Set default admin email if not provided
    if [[ -z "$ADMIN_EMAIL" ]]; then
        ADMIN_EMAIL="admin@$(echo $DOMAINS | cut -d',' -f1)"
    fi
}

# Get server IP
get_server_ip() {
    log "🌐 Detecting server IP..."
    
    # Try multiple services
    for service in "https://ipinfo.io/ip" "https://icanhazip.com" "https://ifconfig.me/ip"; do
        if SERVER_IP=$(curl -s --max-time 5 "$service" 2>/dev/null); then
            if [[ $SERVER_IP =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
                log "✅ Server IP: $SERVER_IP"
                return 0
            fi
        fi
    done
    
    # Fallback to dig
    if command -v dig &> /dev/null; then
        if SERVER_IP=$(dig +short myip.opendns.com @resolver1.opendns.com 2>/dev/null); then
            if [[ $SERVER_IP =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
                log "✅ Server IP: $SERVER_IP"
                return 0
            fi
        fi
    fi
    
    error "Could not detect server IP"
    return 1
}

# Check DNS configuration
check_dns_configuration() {
    if [[ "$CHECK_DNS" == "false" ]]; then
        return 0
    fi
    
    log "🔍 Checking DNS configuration..."
    
    IFS=',' read -ra DOMAIN_ARRAY <<< "$DOMAINS"
    DNS_ISSUES=false
    
    for domain in "${DOMAIN_ARRAY[@]}"; do
        log "📧 Analyzing $domain..."
        
        # Check current MX records
        MX_RECORDS=$(dig +short MX "$domain" 2>/dev/null || echo "")
        
        if [[ -z "$MX_RECORDS" ]]; then
            warn "  No MX records found for $domain"
        else
            log "  Current MX records:"
            while IFS= read -r mx; do
                if [[ -n "$mx" ]]; then
                    log "    $mx"
                    
                    # Check for common conflicts
                    if [[ "$mx" == *"mail.ovh.net"* ]]; then
                        warn "  ⚠️  OVH MX Plan detected - may conflict with custom mail server"
                        warn "     Solution: Remove OVH MX records or suspend MX Plan service"
                        DNS_ISSUES=true
                    elif [[ "$mx" == *"google.com"* ]] || [[ "$mx" == *"googlemail.com"* ]]; then
                        warn "  ⚠️  Google Workspace detected - may conflict with custom mail server"
                        DNS_ISSUES=true
                    elif [[ "$mx" == *"outlook.com"* ]] || [[ "$mx" == *"protection.outlook.com"* ]]; then
                        warn "  ⚠️  Microsoft 365 detected - may conflict with custom mail server"
                        DNS_ISSUES=true
                    fi
                fi
            done <<< "$MX_RECORDS"
        fi
        
        # Check if mail subdomain exists
        MAIL_RECORD=$(dig +short A "mail.$domain" 2>/dev/null || echo "")
        if [[ -n "$MAIL_RECORD" ]]; then
            log "  ✅ mail.$domain → $MAIL_RECORD"
        else
            warn "  ⚠️  No A record for mail.$domain"
            DNS_ISSUES=true
        fi
        
        # Check SPF record
        SPF_RECORD=$(dig +short TXT "$domain" 2>/dev/null | grep "v=spf1" || echo "")
        if [[ -n "$SPF_RECORD" ]]; then
            log "  ✅ SPF record found"
        else
            warn "  ⚠️  No SPF record found"
        fi
    done
    
    if [[ "$DNS_ISSUES" == "true" && "$FORCE_DNS" == "false" ]]; then
        warn "⚠️  DNS configuration issues detected!"
        log "Required DNS records for each domain:"
        log "  A    mail.DOMAIN     → $SERVER_IP"
        log "  MX   DOMAIN          → mail.DOMAIN (priority 10)"
        log "  TXT  DOMAIN          → v=spf1 mx a ip4:$SERVER_IP ~all"
        log ""
        read -p "Continue anyway? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            log "👋 Exiting. Configure DNS first, then run again with --force-dns to skip checks."
            exit 0
        fi
    fi
}

# Install dependencies
install_dependencies() {
    log "📦 Installing dependencies..."
    
    # Update package list
    if command -v apt-get &> /dev/null; then
        sudo apt-get update -qq
    elif command -v yum &> /dev/null; then
        sudo yum update -y -q
    fi
    
    # Install required packages
    PACKAGES="python3 python3-pip curl wget dig"
    
    if command -v apt-get &> /dev/null; then
        sudo apt-get install -y $PACKAGES dnsutils
    elif command -v yum &> /dev/null; then
        sudo yum install -y $PACKAGES bind-utils
    elif command -v pacman &> /dev/null; then
        sudo pacman -S --noconfirm $PACKAGES bind
    fi
    
    # Install Python packages
    if ! python3 -c "import requests" &>/dev/null; then
        pip3 install --user requests &>/dev/null || sudo pip3 install requests &>/dev/null
    fi
}

# Configure automatic DNS (Cloudflare)
configure_cloudflare_dns() {
    if [[ -z "$CF_TOKEN" || -z "$CF_ZONE_ID" ]]; then
        return 0
    fi
    
    log "🌐 Configuring Cloudflare DNS automatically..."
    
    IFS=',' read -ra DOMAIN_ARRAY <<< "$DOMAINS"
    
    for domain in "${DOMAIN_ARRAY[@]}"; do
        log "📧 Configuring DNS for $domain..."
        
        # Create A record for mail subdomain
        create_cloudflare_record "A" "mail" "$SERVER_IP"
        
        # Create MX record
        create_cloudflare_record "MX" "@" "mail.$domain" "10"
        
        # Create SPF record
        create_cloudflare_record "TXT" "@" "v=spf1 mx a ip4:$SERVER_IP ~all"
        
        # Optional: DMARC record
        create_cloudflare_record "TXT" "_dmarc" "v=DMARC1; p=quarantine; rua=mailto:dmarc@$domain"
    done
}

# Create Cloudflare DNS record
create_cloudflare_record() {
    local type="$1"
    local name="$2"
    local content="$3"
    local priority="${4:-}"
    
    local payload="{\"type\":\"$type\",\"name\":\"$name\",\"content\":\"$content\",\"ttl\":3600"
    
    if [[ -n "$priority" ]]; then
        payload+=",\"priority\":$priority"
    fi
    
    payload+="}"
    
    response=$(curl -s -X POST "https://api.cloudflare.com/client/v4/zones/$CF_ZONE_ID/dns_records" \
        -H "Authorization: Bearer $CF_TOKEN" \
        -H "Content-Type: application/json" \
        -d "$payload")
    
    if echo "$response" | grep -q '"success":true'; then
        log "  ✅ Created $type record: $name → $content"
    else
        warn "  ⚠️  Failed to create $type record: $name"
        if [[ "$VERBOSE" == "true" ]]; then
            echo "$response" | python3 -m json.tool 2>/dev/null || echo "$response"
        fi
    fi
}

# Install mail server
install_mail_server() {
    log "📧 Installing mail server components..."
    
    # Install mail packages
    if command -v apt-get &> /dev/null; then
        sudo DEBIAN_FRONTEND=noninteractive apt-get install -y \
            postfix postfix-mysql \
            dovecot-core dovecot-imapd dovecot-pop3d dovecot-lmtpd dovecot-mysql \
            mysql-server \
            nginx \
            certbot python3-certbot-nginx \
            fail2ban \
            ufw
    elif command -v yum &> /dev/null; then
        sudo yum install -y \
            postfix \
            dovecot dovecot-mysql \
            mariadb-server \
            nginx \
            certbot python3-certbot-nginx \
            fail2ban
    fi
    
    # Configure firewall
    if command -v ufw &> /dev/null; then
        sudo ufw allow 22,25,80,443,587,993/tcp
        sudo ufw --force enable
    elif command -v firewall-cmd &> /dev/null; then
        sudo firewall-cmd --permanent --add-port=22/tcp
        sudo firewall-cmd --permanent --add-port=25/tcp
        sudo firewall-cmd --permanent --add-port=80/tcp
        sudo firewall-cmd --permanent --add-port=443/tcp
        sudo firewall-cmd --permanent --add-port=587/tcp
        sudo firewall-cmd --permanent --add-port=993/tcp
        sudo firewall-cmd --reload
    fi
    
    log "✅ Mail server packages installed"
}

# Configure mail server
configure_mail_server() {
    log "🔧 Configuring mail server..."
    
    # Generate secure passwords
    MYSQL_ROOT_PASS=$(openssl rand -base64 32)
    MAIL_DB_PASS=$(openssl rand -base64 32)
    
    # Configure MySQL
    if command -v mysql &> /dev/null; then
        sudo mysql -e "ALTER USER 'root'@'localhost' IDENTIFIED WITH mysql_native_password BY '$MYSQL_ROOT_PASS';" 2>/dev/null || true
        sudo mysql -u root -p"$MYSQL_ROOT_PASS" -e "CREATE DATABASE IF NOT EXISTS mailserver;"
        sudo mysql -u root -p"$MYSQL_ROOT_PASS" -e "CREATE USER IF NOT EXISTS 'mailuser'@'localhost' IDENTIFIED BY '$MAIL_DB_PASS';"
        sudo mysql -u root -p"$MYSQL_ROOT_PASS" -e "GRANT ALL ON mailserver.* TO 'mailuser'@'localhost';"
        sudo mysql -u root -p"$MYSQL_ROOT_PASS" -e "FLUSH PRIVILEGES;"
    elif command -v mariadb &> /dev/null; then
        sudo mariadb -e "CREATE DATABASE IF NOT EXISTS mailserver;"
        sudo mariadb -e "CREATE USER IF NOT EXISTS 'mailuser'@'localhost' IDENTIFIED BY '$MAIL_DB_PASS';"
        sudo mariadb -e "GRANT ALL ON mailserver.* TO 'mailuser'@'localhost';"
    fi
    
    # Save credentials
    echo "MySQL Root Password: $MYSQL_ROOT_PASS" | sudo tee /root/mail_credentials.txt > /dev/null
    echo "Mail DB Password: $MAIL_DB_PASS" | sudo tee -a /root/mail_credentials.txt > /dev/null
    
    # Create database structure
    sudo mysql -u root -p"$MYSQL_ROOT_PASS" mailserver << 'EOF' 2>/dev/null || sudo mariadb mailserver << 'EOF'
CREATE TABLE IF NOT EXISTS domains (
  id INT AUTO_INCREMENT PRIMARY KEY,
  domain VARCHAR(255) NOT NULL UNIQUE,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS users (
  id INT AUTO_INCREMENT PRIMARY KEY,
  domain_id INT,
  email VARCHAR(255) NOT NULL UNIQUE,
  password VARCHAR(255) NOT NULL,
  quota INT DEFAULT 1024,
  enabled BOOLEAN DEFAULT TRUE,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (domain_id) REFERENCES domains(id) ON DELETE CASCADE
);
EOF
    
    log "✅ Mail server configured"
}

# Generate email accounts
generate_email_accounts() {
    log "👥 Generating email accounts..."
    
    # Create temporary config file
    IFS=',' read -ra DOMAIN_ARRAY <<< "$DOMAINS"
    
    cat > /tmp/email_config.json << EOF
{
  "domains": [$(printf '"%s",' "${DOMAIN_ARRAY[@]}" | sed 's/,$//')]
  ,"smtp_configs": {
    "default": {
      "smtp_host": "mail.{domain}",
      "smtp_port": 587,
      "smtp_security": "STARTTLS",
      "imap_host": "mail.{domain}",
      "imap_port": 993,
      "imap_security": "SSL"
    }
  },
  "email_settings": {
    "emails_per_domain": 3,
    "password_length": 16,
    "check_dns": true
  }
}
EOF
    
    # Run enhanced email configurator
    if [[ -f "email_configurator_enhanced.py" ]]; then
        python3 email_configurator_enhanced.py /tmp/email_config.json
    else
        # Download the enhanced configurator
        curl -sSL "https://raw.githubusercontent.com/madyoss12/vps-email-automation/main/email_configurator_enhanced.py" > email_configurator_enhanced.py
        python3 email_configurator_enhanced.py /tmp/email_config.json
    fi
    
    # Cleanup
    rm -f /tmp/email_config.json
}

# Run tests
run_tests() {
    if [[ "$SKIP_TESTS" == "true" ]]; then
        log "⚠️ Skipping tests"
        return 0
    fi
    
    log "🧪 Running connectivity tests..."
    
    # Test mail server ports
    for port in 25 587 993; do
        if netstat -tlnp 2>/dev/null | grep -q ":$port "; then
            log "✅ Port $port is listening"
        else
            warn "⚠️ Port $port is not listening"
        fi
    done
    
    # Test DNS resolution
    IFS=',' read -ra DOMAIN_ARRAY <<< "$DOMAINS"
    for domain in "${DOMAIN_ARRAY[@]}"; do
        if dig +short MX "$domain" | grep -q "mail.$domain"; then
            log "✅ MX record found for $domain"
        else
            warn "⚠️ MX record not found for $domain"
        fi
    done
}

# Send notification
send_notification() {
    local message="$1"
    
    if [[ -n "$WEBHOOK_URL" ]]; then
        curl -X POST -H "Content-Type: application/json" \
             -d "{\"text\":\"$message\"}" \
             "$WEBHOOK_URL" &>/dev/null || true
    fi
}

# Main execution
main() {
    echo "🚀 Enhanced VPS Email Automation"
    echo "================================="
    
    # Parse arguments
    parse_args "$@"
    
    # Validate parameters
    validate_params
    
    # Get server IP
    get_server_ip
    
    # Install dependencies
    install_dependencies
    
    # Check DNS configuration
    check_dns_configuration
    
    # Send start notification
    send_notification "🚀 Starting Enhanced VPS Email Deployment for domains: $DOMAINS"
    
    # Configure DNS automatically if tokens provided
    configure_cloudflare_dns
    
    # Install mail server
    install_mail_server
    
    # Configure mail server
    configure_mail_server
    
    # Generate email accounts
    generate_email_accounts
    
    # Run tests
    run_tests
    
    # Send completion notification
    send_notification "✅ VPS Email Deployment completed successfully!"
    
    log "🎉 Enhanced VPS Email Automation completed!"
    log "📁 Check the generated email_credentials_* directory for all files"
    log ""
    log "💡 Next steps:"
    log "  1. Configure DNS records if not done automatically"
    log "  2. Wait for DNS propagation (15 minutes - 24 hours)"
    log "  3. Test email connectivity using the generated credentials"
    log "  4. Configure SSL certificates for mail.yourdomain.com"
}

# Run main function with all arguments
main "$@"
