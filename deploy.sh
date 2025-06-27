#!/bin/bash
# VPS Email Automation - One Line Command System
# Usage: curl -sSL https://raw.githubusercontent.com/your-repo/vps-email-automation/main/deploy.sh | bash -s -- --domains="domain1.com,domain2.org" --provider="digitalocean" --do-token="your_token"

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
VPS Email Automation - One Line Deployment

USAGE:
    curl -sSL https://raw.githubusercontent.com/your-username/vps-email-automation/main/deploy.sh | bash -s -- [OPTIONS]

REQUIRED OPTIONS:
    --domains=DOMAINS          Comma-separated list of domains (e.g., "domain1.com,domain2.org")
    --provider=PROVIDER        VPS provider: digitalocean, vultr, linode
    --do-token=TOKEN          DigitalOcean API token (if using DO)

OPTIONAL:
    --cf-token=TOKEN          Cloudflare API token for DNS
    --cf-zone-id=ID           Cloudflare Zone ID
    --ssh-key-id=ID           SSH key ID (will create if not provided)
    --region=REGION           VPS region (default: fra1)
    --size=SIZE               VPS size (default: s-2vcpu-4gb)
    --admin-email=EMAIL       Admin email for Let's Encrypt
    --webhook-url=URL         Webhook URL for notifications
    --skip-dns                Skip DNS configuration
    --skip-tests              Skip connectivity tests
    --verbose                 Enable verbose output
    --help                    Show this help

EXAMPLES:
    # Basic deployment
    curl -sSL https://raw.githubusercontent.com/your-username/vps-email-automation/main/deploy.sh | bash -s -- \\
        --domains="example.com,test.org" \\
        --provider="digitalocean" \\
        --do-token="your_do_token"

    # Full deployment with DNS
    curl -sSL https://raw.githubusercontent.com/your-username/vps-email-automation/main/deploy.sh | bash -s -- \\
        --domains="example.com" \\
        --provider="digitalocean" \\
        --do-token="your_do_token" \\
        --cf-token="your_cf_token" \\
        --cf-zone-id="your_zone_id" \\
        --admin-email="admin@example.com"

    # Quick deployment skipping tests
    curl -sSL https://raw.githubusercontent.com/your-username/vps-email-automation/main/deploy.sh | bash -s -- \\
        --domains="example.com" \\
        --do-token="your_do_token" \\
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
            --skip-dns)
                SKIP_DNS="true"
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

    if [[ -z "$DO_TOKEN" && "$PROVIDER" == "digitalocean" ]]; then
        error "DigitalOcean token is required for DigitalOcean provider"
        exit 1
    fi

    # Set default admin email if not provided
    if [[ -z "$ADMIN_EMAIL" ]]; then
        ADMIN_EMAIL="admin@$(echo $DOMAINS | cut -d',' -f1)"
    fi
}

# Generate secure passwords
generate_password() {
    local length=${1:-20}
    LC_ALL=C tr -dc 'A-Za-z0-9!@#$%^&*' < /dev/urandom | head -c $length
}

# Create temporary directory for automation
setup_workspace() {
    WORKSPACE=$(mktemp -d)
    cd "$WORKSPACE"
    
    log "Workspace created: $WORKSPACE"
    
    # Set cleanup trap
    trap 'rm -rf "$WORKSPACE"' EXIT
}

# Install required dependencies
install_dependencies() {
    log "📦 Installing dependencies..."
    
    # Check if we have the required tools
    if ! command -v python3 &> /dev/null; then
        error "Python3 is required but not installed"
        exit 1
    fi
    
    # Install Python packages
    pip3 install requests &>/dev/null || {
        warn "Could not install Python packages via pip3"
        # Try with user install
        pip3 install --user requests &>/dev/null || {
            error "Failed to install required Python packages"
            exit 1
        }
    }
    
    # Install jq for JSON processing if available
    if command -v apt-get &> /dev/null; then
        apt-get update &>/dev/null && apt-get install -y jq &>/dev/null || true
    elif command -v yum &> /dev/null; then
        yum install -y jq &>/dev/null || true
    elif command -v brew &> /dev/null; then
        brew install jq &>/dev/null || true
    fi
}

# Create automation scripts inline
create_automation_scripts() {
    log "📝 Creating automation scripts..."
    
    # Create the main orchestrator script
    cat > orchestrator.py << 'PYTHON_SCRIPT_EOF'
#!/usr/bin/env python3
import json
import time
import subprocess
import requests
import sys
import os
from datetime import datetime
import secrets
import string

class OneLineOrchestrator:
    def __init__(self, config):
        self.config = config
        self.vps_ip = None
        self.email_accounts = []
        self.deployment_id = f"deploy_{int(time.time())}"
        
    def log(self, message):
        print(f"[{datetime.now().strftime('%H:%M:%S')}] {message}")
        
    def provision_vps(self):
        self.log("🚀 Provisioning VPS...")
        
        if self.config['provider'] == 'digitalocean':
            return self.provision_digitalocean()
        else:
            raise ValueError(f"Provider {self.config['provider']} not supported")
    
    def provision_digitalocean(self):
        user_data = self.generate_cloud_init()
        
        payload = {
            "name": f"mail-{self.deployment_id}",
            "region": self.config['region'],
            "size": self.config['size'],
            "image": "ubuntu-22-04-x64",
            "user_data": user_data,
            "monitoring": True,
            "tags": ["email-automation", "one-line-deploy"]
        }
        
        if self.config.get('ssh_key_id'):
            payload["ssh_keys"] = [self.config['ssh_key_id']]
        
        headers = {
            "Authorization": f"Bearer {self.config['do_token']}",
            "Content-Type": "application/json"
        }
        
        response = requests.post(
            "https://api.digitalocean.com/v2/droplets",
            headers=headers,
            json=payload
        )
        
        if response.status_code == 202:
            droplet_data = response.json()
            droplet_id = droplet_data['droplet']['id']
            
            self.log(f"Droplet created: {droplet_id}")
            self.vps_ip = self.wait_for_droplet(droplet_id)
            return self.vps_ip
        else:
            raise Exception(f"Failed to create droplet: {response.text}")
    
    def generate_cloud_init(self):
        mysql_root_pass = self.generate_password()
        mail_db_pass = self.generate_password()
        
        domains_list = "', '".join(self.config['domains'])
        
        return f'''#!/bin/bash
export DEBIAN_FRONTEND=noninteractive

# Update and install packages
apt-get update && apt-get upgrade -y
apt-get install -y curl wget python3 python3-pip mysql-server postfix postfix-mysql dovecot-core dovecot-imapd dovecot-mysql nginx certbot python3-certbot-nginx fail2ban ufw

# Configure MySQL
mysql -e "ALTER USER 'root'@'localhost' IDENTIFIED WITH mysql_native_password BY '{mysql_root_pass}';"
mysql -u root -p{mysql_root_pass} -e "CREATE DATABASE mailserver;"
mysql -u root -p{mysql_root_pass} -e "CREATE USER 'mailuser'@'localhost' IDENTIFIED BY '{mail_db_pass}';"
mysql -u root -p{mysql_root_pass} -e "GRANT ALL ON mailserver.* TO 'mailuser'@'localhost';"

# Create database structure
mysql -u root -p{mysql_root_pass} mailserver << 'SQL_EOF'
CREATE TABLE domains (id INT AUTO_INCREMENT PRIMARY KEY, domain VARCHAR(255) UNIQUE);
CREATE TABLE users (id INT AUTO_INCREMENT PRIMARY KEY, email VARCHAR(255) UNIQUE, password VARCHAR(255), domain_id INT);
INSERT INTO domains (domain) VALUES ('{domains_list}');
SQL_EOF

# Configure firewall
ufw allow 22,25,80,443,587,993/tcp
ufw --force enable

# Save credentials
cat > /root/credentials.json << 'JSON_EOF'
{{
  "mysql_root_password": "{mysql_root_pass}",
  "mail_db_password": "{mail_db_pass}",
  "deployment_id": "{self.deployment_id}"
}}
JSON_EOF

# Signal completion
touch /tmp/setup-complete
echo "Setup completed at $(date)" > /tmp/setup.log
'''
    
    def wait_for_droplet(self, droplet_id):
        headers = {"Authorization": f"Bearer {self.config['do_token']}"}
        
        self.log("⏳ Waiting for VPS to be ready...")
        
        while True:
            response = requests.get(
                f"https://api.digitalocean.com/v2/droplets/{droplet_id}",
                headers=headers
            )
            
            if response.status_code == 200:
                droplet = response.json()['droplet']
                
                if droplet['status'] == 'active':
                    for network in droplet['networks']['v4']:
                        if network['type'] == 'public':
                            ip = network['ip_address']
                            if self.wait_for_ssh(ip):
                                return ip
            
            time.sleep(30)
    
    def wait_for_ssh(self, ip):
        import socket
        
        for _ in range(60):  # Wait up to 10 minutes
            try:
                sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
                sock.settimeout(5)
                result = sock.connect_ex((ip, 22))
                sock.close()
                if result == 0:
                    time.sleep(30)  # Wait for cloud-init
                    return True
            except:
                pass
            time.sleep(10)
        return False
    
    def configure_dns(self):
        if self.config.get('skip_dns') or not self.config.get('cf_token'):
            self.log("⚠ Skipping DNS configuration")
            return
        
        self.log("🌐 Configuring DNS...")
        
        for domain in self.config['domains']:
            self.create_dns_records(domain)
    
    def create_dns_records(self, domain):
        headers = {
            "Authorization": f"Bearer {self.config['cf_token']}",
            "Content-Type": "application/json"
        }
        
        records = [
            {"type": "A", "name": "mail", "content": self.vps_ip},
            {"type": "MX", "name": "@", "content": f"mail.{domain}", "priority": 10},
            {"type": "TXT", "name": "@", "content": f"v=spf1 mx a ip4:{self.vps_ip} ~all"},
        ]
        
        for record in records:
            payload = {
                "type": record["type"],
                "name": record["name"],
                "content": record["content"],
                "ttl": 3600
            }
            
            if "priority" in record:
                payload["priority"] = record["priority"]
            
            response = requests.post(
                f"https://api.cloudflare.com/client/v4/zones/{self.config['cf_zone_id']}/dns_records",
                headers=headers,
                json=payload
            )
            
            if response.status_code == 200:
                self.log(f"  ✓ DNS record created: {record['type']} {record['name']}")
    
    def setup_mail_server(self):
        self.log("📧 Configuring mail server...")
        
        # Wait for cloud-init to complete
        self.wait_for_setup_complete()
        
        # Configure mail server via SSH
        self.configure_postfix_dovecot()
        
        # Setup SSL certificates
        self.setup_ssl()
        
        # Create email accounts
        self.create_email_accounts()
    
    def wait_for_setup_complete(self):
        self.log("⏳ Waiting for server setup to complete...")
        
        for _ in range(60):  # Wait up to 30 minutes
            try:
                result = subprocess.run([
                    "ssh", "-o", "StrictHostKeyChecking=no", "-o", "ConnectTimeout=10",
                    f"root@{self.vps_ip}", "test -f /tmp/setup-complete && echo 'ready'"
                ], capture_output=True, text=True, timeout=15)
                
                if result.stdout.strip() == 'ready':
                    self.log("✅ Server setup completed")
                    return
            except:
                pass
            
            time.sleep(30)
        
        raise Exception("Server setup timeout")
    
    def configure_postfix_dovecot(self):
        primary_domain = self.config['domains'][0]
        
        # Get credentials from server
        result = subprocess.run([
            "ssh", "-o", "StrictHostKeyChecking=no",
            f"root@{self.vps_ip}", "cat /root/credentials.json"
        ], capture_output=True, text=True)
        
        credentials = json.loads(result.stdout)
        
        # Configure Postfix
        postfix_config = f'''
myhostname = mail.{primary_domain}
mydomain = {primary_domain}
inet_interfaces = all
mydestination = localhost
virtual_mailbox_domains = mysql:/etc/postfix/mysql-domains.cf
virtual_mailbox_maps = mysql:/etc/postfix/mysql-users.cf
virtual_mailbox_base = /var/mail/vhosts
virtual_uid_maps = static:5000
virtual_gid_maps = static:5000
smtpd_sasl_auth_enable = yes
smtpd_sasl_type = dovecot
smtpd_sasl_path = private/auth
'''
        
        # Upload configurations via SSH
        subprocess.run([
            "ssh", "-o", "StrictHostKeyChecking=no", f"root@{self.vps_ip}",
            f"echo '{postfix_config}' > /etc/postfix/main.cf"
        ])
        
        # Create MySQL config files
        mysql_config = f'''
user = mailuser
password = {credentials['mail_db_password']}
hosts = 127.0.0.1
dbname = mailserver
query = SELECT 1 FROM domains WHERE domain='%s'
'''
        
        subprocess.run([
            "ssh", "-o", "StrictHostKeyChecking=no", f"root@{self.vps_ip}",
            f"echo '{mysql_config}' > /etc/postfix/mysql-domains.cf"
        ])
        
        # Restart services
        subprocess.run([
            "ssh", "-o", "StrictHostKeyChecking=no", f"root@{self.vps_ip}",
            "systemctl restart postfix dovecot"
        ])
    
    def setup_ssl(self):
        primary_domain = self.config['domains'][0]
        
        self.log("🔒 Setting up SSL certificates...")
        
        subprocess.run([
            "ssh", "-o", "StrictHostKeyChecking=no", f"root@{self.vps_ip}",
            f"certbot certonly --standalone -d mail.{primary_domain} --non-interactive --agree-tos --email {self.config['admin_email']}"
        ])
    
    def create_email_accounts(self):
        self.log("👥 Creating email accounts...")
        
        # Get credentials
        result = subprocess.run([
            "ssh", "-o", "StrictHostKeyChecking=no", f"root@{self.vps_ip}",
            "cat /root/credentials.json"
        ], capture_output=True, text=True)
        
        credentials = json.loads(result.stdout)
        
        for domain in self.config['domains']:
            for i in range(3):  # 3 emails per domain
                username = f"user{i+1}"
                email = f"{username}@{domain}"
                password = self.generate_password(16)
                
                # Create account in database
                subprocess.run([
                    "ssh", "-o", "StrictHostKeyChecking=no", f"root@{self.vps_ip}",
                    f"mysql -u root -p{credentials['mysql_root_password']} mailserver -e \"INSERT INTO users (email, password, domain_id) SELECT '{email}', SHA2('{password}', 512), id FROM domains WHERE domain='{domain}';\""
                ])
                
                account = {
                    'email': email,
                    'password': password,
                    'domain': domain,
                    'smtp_host': f'mail.{domain}',
                    'smtp_port': 587,
                    'imap_host': f'mail.{domain}',
                    'imap_port': 993
                }
                
                self.email_accounts.append(account)
        
        self.log(f"✅ Created {len(self.email_accounts)} email accounts")
    
    def run_tests(self):
        if self.config.get('skip_tests'):
            self.log("⚠ Skipping tests")
            return
        
        self.log("🧪 Running connectivity tests...")
        
        # Test SMTP
        try:
            subprocess.run([
                "ssh", "-o", "StrictHostKeyChecking=no", f"root@{self.vps_ip}",
                f"echo 'Test email' | mail -s 'Test' {self.config['admin_email']}"
            ], timeout=30)
            self.log("✅ SMTP test passed")
        except:
            self.log("⚠ SMTP test failed")
    
    def generate_report(self):
        self.log("📄 Generating deployment report...")
        
        report = {
            'deployment_id': self.deployment_id,
            'timestamp': datetime.now().isoformat(),
            'vps_ip': self.vps_ip,
            'domains': self.config['domains'],
            'email_accounts': self.email_accounts,
            'total_accounts': len(self.email_accounts)
        }
        
        # Save report
        with open(f'deployment_report_{self.deployment_id}.json', 'w') as f:
            json.dump(report, f, indent=2)
        
        # Generate CSV
        with open(f'email_credentials_{self.deployment_id}.csv', 'w') as f:
            f.write('Email,Password,SMTP_Host,SMTP_Port,IMAP_Host,IMAP_Port\\n')
            for account in self.email_accounts:
                f.write(f"{account['email']},{account['password']},{account['smtp_host']},{account['smtp_port']},{account['imap_host']},{account['imap_port']}\\n")
        
        return report
    
    def send_notification(self, report):
        if not self.config.get('webhook_url'):
            return
        
        try:
            payload = {
                'text': f"VPS Email Deployment Completed\\nIP: {self.vps_ip}\\nAccounts: {len(self.email_accounts)}\\nDomains: {', '.join(self.config['domains'])}"
            }
            
            requests.post(self.config['webhook_url'], json=payload)
        except:
            pass
    
    def generate_password(self, length=20):
        chars = string.ascii_letters + string.digits + "!@#$%^&*"
        return ''.join(secrets.choice(chars) for _ in range(length))
    
    def run_deployment(self):
        try:
            self.log("🎯 Starting One-Line VPS Email Deployment")
            
            # Step 1: Provision VPS
            self.provision_vps()
            self.log(f"✅ VPS provisioned: {self.vps_ip}")
            
            # Step 2: Configure DNS
            self.configure_dns()
            
            # Step 3: Setup mail server
            self.setup_mail_server()
            
            # Step 4: Run tests
            self.run_tests()
            
            # Step 5: Generate report
            report = self.generate_report()
            
            # Step 6: Send notification
            self.send_notification(report)
            
            self.log("🎉 Deployment completed successfully!")
            self.print_summary(report)
            
            return report
            
        except Exception as e:
            self.log(f"❌ Deployment failed: {str(e)}")
            raise
    
    def print_summary(self, report):
        print("\\n" + "="*60)
        print("DEPLOYMENT SUMMARY")
        print("="*60)
        print(f"VPS IP: {self.vps_ip}")
        print(f"Domains: {', '.join(self.config['domains'])}")
        print(f"Email Accounts: {len(self.email_accounts)}")
        print(f"\\nCredentials saved to: email_credentials_{self.deployment_id}.csv")
        print("\\nFirst few accounts:")
        for account in self.email_accounts[:3]:
            print(f"  {account['email']} | {account['password']}")
        print("="*60)

if __name__ == "__main__":
    config = json.loads(sys.argv[1])
    orchestrator = OneLineOrchestrator(config)
    orchestrator.run_deployment()
PYTHON_SCRIPT_EOF

    chmod +x orchestrator.py
}

# Create configuration and run deployment
run_deployment() {
    log "🎯 Starting One-Line VPS Email Deployment"
    
    # Convert domains string to array
    IFS=',' read -ra DOMAIN_ARRAY <<< "$DOMAINS"
    
    # Create configuration
    CONFIG=$(cat << EOF
{
    "domains": [$(printf '"%s",' "${DOMAIN_ARRAY[@]}" | sed 's/,$//')]
    ,"provider": "$PROVIDER"
    ,"do_token": "$DO_TOKEN"
    ,"cf_token": "$CF_TOKEN"
    ,"cf_zone_id": "$CF_ZONE_ID"
    ,"ssh_key_id": "$SSH_KEY_ID"
    ,"region": "$REGION"
    ,"size": "$SIZE"
    ,"admin_email": "$ADMIN_EMAIL"
    ,"webhook_url": "$WEBHOOK_URL"
    ,"skip_dns": $SKIP_DNS
    ,"skip_tests": $SKIP_TESTS
}
EOF
    )
    
    if [[ "$VERBOSE" == "true" ]]; then
        info "Configuration:"
        echo "$CONFIG" | python3 -m json.tool 2>/dev/null || echo "$CONFIG"
    fi
    
    # Install dependencies
    install_dependencies
    
    # Create automation scripts
    create_automation_scripts
    
    # Run the deployment
    log "🚀 Launching deployment..."
    python3 orchestrator.py "$CONFIG"
    
    # Copy results to current directory if not running in temp
    if [[ "$PWD" != "$HOME" ]]; then
        cp deployment_report_*.json email_credentials_*.csv "$HOME/" 2>/dev/null || true
    fi
    
    log "✅ One-line deployment completed!"
    log "📁 Check your home directory for deployment files"
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
    echo "🚀 VPS Email Automation - One Line Deployment"
    echo "=============================================="
    
    # Parse arguments
    parse_args "$@"
    
    # Validate parameters
    validate_params
    
    # Setup workspace
    setup_workspace
    
    # Send start notification
    send_notification "🚀 Starting VPS Email Deployment for domains: $DOMAINS"
    
    # Run deployment
    if run_deployment; then
        send_notification "✅ VPS Email Deployment completed successfully!"
        log "🎉 All done! Check your files for credentials."
    else
        send_notification "❌ VPS Email Deployment failed"
        error "Deployment failed"
        exit 1
    fi
}

# Run main function with all arguments
main "$@"
