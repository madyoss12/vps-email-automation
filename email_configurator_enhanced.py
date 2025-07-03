#!/usr/bin/env python3
"""
Enhanced Email Configurator with DNS Management
Handles DNS detection, conflict resolution, and automatic configuration
"""

import json
import random
import string
import subprocess
import sys
import os
import requests
import time
from datetime import datetime
from pathlib import Path

class DNSManager:
    def __init__(self, domain):
        """Initialize DNS manager for a domain"""
        self.domain = domain
        self.current_mx = []
        self.dns_provider = None
        self.conflicts = []
        
    def analyze_dns(self):
        """Analyze current DNS configuration"""
        log("🔍 Analyzing DNS configuration for " + self.domain)
        
        # Check current MX records
        self.current_mx = self.get_mx_records()
        
        # Detect DNS provider
        self.dns_provider = self.detect_dns_provider()
        
        # Check for conflicts
        self.check_conflicts()
        
        return {
            'mx_records': self.current_mx,
            'dns_provider': self.dns_provider,
            'conflicts': self.conflicts,
            'needs_configuration': len(self.current_mx) == 0 or self.has_conflicts()
        }
    
    def get_mx_records(self):
        """Get current MX records for domain"""
        try:
            result = subprocess.run(['dig', '+short', 'MX', self.domain], 
                                  capture_output=True, text=True, timeout=10)
            mx_records = []
            for line in result.stdout.strip().split('\n'):
                if line and line.strip():
                    parts = line.strip().split()
                    if len(parts) >= 2:
                        priority = parts[0]
                        server = parts[1].rstrip('.')
                        mx_records.append({'priority': int(priority), 'server': server})
            return sorted(mx_records, key=lambda x: x['priority'])
        except Exception as e:
            warn(f"Could not get MX records: {e}")
            return []
    
    def detect_dns_provider(self):
        """Detect DNS provider from nameservers"""
        try:
            result = subprocess.run(['dig', '+short', 'NS', self.domain], 
                                  capture_output=True, text=True, timeout=10)
            nameservers = [ns.strip().rstrip('.') for ns in result.stdout.strip().split('\n') if ns.strip()]
            
            for ns in nameservers:
                if 'ovh.net' in ns:
                    return 'ovh'
                elif 'cloudflare.com' in ns:
                    return 'cloudflare'
                elif 'digitalocean.com' in ns:
                    return 'digitalocean'
                elif 'route53' in ns or 'amazonaws.com' in ns:
                    return 'route53'
                elif 'namecheap.com' in ns:
                    return 'namecheap'
            
            return 'unknown'
        except Exception as e:
            warn(f"Could not detect DNS provider: {e}")
            return 'unknown'
    
    def check_conflicts(self):
        """Check for common DNS conflicts"""
        conflicts = []
        
        # Check for OVH MX Plan
        for mx in self.current_mx:
            if 'mail.ovh.net' in mx['server']:
                conflicts.append({
                    'type': 'ovh_mx_plan',
                    'description': 'OVH MX Plan service detected',
                    'record': mx,
                    'solution': 'Delete OVH MX records or suspend MX Plan service'
                })
        
        # Check for Google Workspace
        for mx in self.current_mx:
            if 'google.com' in mx['server'] or 'googlemail.com' in mx['server']:
                conflicts.append({
                    'type': 'google_workspace',
                    'description': 'Google Workspace detected',
                    'record': mx,
                    'solution': 'Disable Google Workspace or use subdomain'
                })
        
        # Check for Microsoft 365
        for mx in self.current_mx:
            if 'outlook.com' in mx['server'] or 'protection.outlook.com' in mx['server']:
                conflicts.append({
                    'type': 'microsoft_365',
                    'description': 'Microsoft 365 detected',
                    'record': mx,
                    'solution': 'Disable Microsoft 365 or use subdomain'
                })
        
        self.conflicts = conflicts
        return conflicts
    
    def has_conflicts(self):
        """Check if there are any conflicts"""
        return len(self.conflicts) > 0
    
    def suggest_dns_configuration(self, server_ip):
        """Suggest DNS configuration based on provider"""
        suggestions = {
            'required_records': [
                {
                    'type': 'A',
                    'name': 'mail',
                    'value': server_ip,
                    'ttl': 3600
                },
                {
                    'type': 'MX',
                    'name': '@',
                    'value': f'mail.{self.domain}',
                    'priority': 10,
                    'ttl': 3600
                },
                {
                    'type': 'TXT',
                    'name': '@', 
                    'value': f'v=spf1 mx a ip4:{server_ip} ~all',
                    'ttl': 3600
                }
            ],
            'optional_records': [
                {
                    'type': 'TXT',
                    'name': '_dmarc',
                    'value': f'v=DMARC1; p=quarantine; rua=mailto:dmarc@{self.domain}',
                    'ttl': 3600
                },
                {
                    'type': 'CNAME',
                    'name': 'autoconfig',
                    'value': f'mail.{self.domain}',
                    'ttl': 3600
                },
                {
                    'type': 'CNAME',
                    'name': 'autodiscover', 
                    'value': f'mail.{self.domain}',
                    'ttl': 3600
                }
            ]
        }
        
        return suggestions

def log(message):
    """Enhanced logging function"""
    timestamp = datetime.now().strftime("%H:%M:%S")
    print(f"[{timestamp}] {message}")

def warn(message):
    """Warning logging function"""
    timestamp = datetime.now().strftime("%H:%M:%S")
    print(f"[{timestamp}] ⚠️  {message}")

class EnhancedEmailConfigurator:
    def __init__(self, config_file="email_config.json"):
        """Initialize enhanced email configurator"""
        self.config_file = config_file
        self.domains = []
        self.smtp_configs = {}
        self.email_accounts = []
        self.dns_managers = {}
        self.server_ip = None
        
    def get_server_ip(self):
        """Get server public IP"""
        try:
            # Try multiple services to get IP
            services = [
                'https://ipinfo.io/ip',
                'https://icanhazip.com',
                'https://ifconfig.me/ip'
            ]
            
            for service in services:
                try:
                    response = requests.get(service, timeout=5)
                    if response.status_code == 200:
                        ip = response.text.strip()
                        if self.is_valid_ip(ip):
                            self.server_ip = ip
                            return ip
                except:
                    continue
            
            # Fallback to dig
            result = subprocess.run(['dig', '+short', 'myip.opendns.com', '@resolver1.opendns.com'], 
                                  capture_output=True, text=True, timeout=10)
            if result.returncode == 0:
                ip = result.stdout.strip()
                if self.is_valid_ip(ip):
                    self.server_ip = ip
                    return ip
                    
            raise Exception("Could not determine server IP")
            
        except Exception as e:
            warn(f"Could not get server IP: {e}")
            return None
    
    def is_valid_ip(self, ip):
        """Validate IP address format"""
        parts = ip.split('.')
        return len(parts) == 4 and all(part.isdigit() and 0 <= int(part) <= 255 for part in parts)
    
    def analyze_all_domains(self):
        """Analyze DNS for all domains"""
        log("🔍 Analyzing DNS configuration for all domains...")
        
        analysis_results = {}
        
        for domain in self.domains:
            dns_manager = DNSManager(domain)
            analysis = dns_manager.analyze_dns()
            self.dns_managers[domain] = dns_manager
            analysis_results[domain] = analysis
            
            log(f"📧 Domain: {domain}")
            log(f"  DNS Provider: {analysis['dns_provider']}")
            log(f"  Current MX: {len(analysis['mx_records'])} records")
            
            if analysis['conflicts']:
                warn(f"  ⚠️  Found {len(analysis['conflicts'])} conflicts:")
                for conflict in analysis['conflicts']:
                    warn(f"    - {conflict['description']}")
                    warn(f"      Solution: {conflict['solution']}")
        
        return analysis_results
    
    def generate_dns_instructions(self):
        """Generate DNS configuration instructions"""
        if not self.server_ip:
            self.server_ip = self.get_server_ip()
        
        if not self.server_ip:
            error("Cannot generate DNS instructions without server IP")
            return
        
        log("📋 DNS Configuration Instructions")
        log("=" * 50)
        
        for domain in self.domains:
            dns_manager = self.dns_managers.get(domain)
            if not dns_manager:
                continue
                
            log(f"\n📧 Domain: {domain}")
            log(f"DNS Provider: {dns_manager.dns_provider}")
            
            # Check conflicts
            if dns_manager.has_conflicts():
                warn("⚠️  CONFLICTS DETECTED - Resolve these first:")
                for conflict in dns_manager.conflicts:
                    warn(f"  - {conflict['description']}")
                    warn(f"    Solution: {conflict['solution']}")
                log("")
            
            # Generate suggestions
            suggestions = dns_manager.suggest_dns_configuration(self.server_ip)
            
            log("Required DNS Records:")
            for record in suggestions['required_records']:
                if record['type'] == 'MX':
                    log(f"  {record['type']:4} {record['name']:15} → {record['value']} (priority {record['priority']})")
                else:
                    log(f"  {record['type']:4} {record['name']:15} → {record['value']}")
            
            log("\nOptional DNS Records (recommended):")
            for record in suggestions['optional_records']:
                log(f"  {record['type']:4} {record['name']:15} → {record['value']}")
            
            # Provider-specific instructions
            self.generate_provider_instructions(domain, dns_manager.dns_provider)
    
    def generate_provider_instructions(self, domain, provider):
        """Generate provider-specific DNS instructions"""
        log(f"\n🔧 {provider.upper()} Specific Instructions:")
        
        if provider == 'ovh':
            log("1. Go to https://www.ovh.com/manager/")
            log("2. Web Cloud → Domain names → " + domain)
            log("3. DNS Zone tab")
            log("4. Delete existing MX records (mail.ovh.net entries)")
            log("5. Add the required records above")
            log("6. Click 'Apply Configuration' if prompted")
            
        elif provider == 'cloudflare':
            log("1. Go to https://dash.cloudflare.com/")
            log("2. Select " + domain)
            log("3. DNS → Records")
            log("4. Add the required records above")
            log("5. Set Proxy status to 'DNS only' for mail records")
            
        elif provider == 'digitalocean':
            log("1. Go to https://cloud.digitalocean.com/networking/domains")
            log("2. Select " + domain)
            log("3. Add the required records above")
            
        else:
            log("1. Access your DNS provider's control panel")
            log("2. Navigate to DNS management for " + domain)
            log("3. Add the required records listed above")
            log("4. Save/Apply changes")
        
        log("⏰ DNS propagation time: 15 minutes to 24 hours")
    
    def wait_for_dns_propagation(self, domain, timeout=1800):
        """Wait for DNS propagation with progress"""
        log(f"⏳ Waiting for DNS propagation for {domain}...")
        
        start_time = time.time()
        while time.time() - start_time < timeout:
            try:
                result = subprocess.run(['dig', '+short', 'MX', domain], 
                                      capture_output=True, text=True, timeout=10)
                
                if result.stdout.strip():
                    mx_records = result.stdout.strip().split('\n')
                    for mx in mx_records:
                        if f'mail.{domain}' in mx:
                            log(f"✅ DNS propagated for {domain}")
                            return True
                
                # Show progress every 2 minutes
                elapsed = int(time.time() - start_time)
                if elapsed % 120 == 0 and elapsed > 0:
                    log(f"⏳ Still waiting... ({elapsed//60} minutes elapsed)")
                
                time.sleep(30)
                
            except Exception as e:
                warn(f"DNS check failed: {e}")
                time.sleep(60)
        
        warn(f"⏰ DNS propagation timeout for {domain}")
        return False
    
    def load_config(self):
        """Load configuration from JSON file"""
        try:
            with open(self.config_file, 'r') as f:
                config = json.load(f)
                self.domains = config.get('domains', [])
                self.smtp_configs = config.get('smtp_configs', {})
                log(f"✓ Configuration loaded: {len(self.domains)} domains found")
                return True
        except FileNotFoundError:
            log(f"⚠ Configuration file {self.config_file} not found. Creating default...")
            self.create_default_config()
            return False
        except json.JSONDecodeError:
            error(f"✗ Error parsing {self.config_file}")
            return False
    
    def create_default_config(self):
        """Create a default configuration file"""
        default_config = {
            "domains": [
                "example.com",
                "test-domain.org"
            ],
            "smtp_configs": {
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
                "use_random_names": True,
                "check_dns": True,
                "wait_for_dns": True
            }
        }
        
        with open(self.config_file, 'w') as f:
            json.dump(default_config, f, indent=2)
        
        log(f"✓ Default configuration created: {self.config_file}")
        log("Please edit the configuration file with your domains and run again.")
    
    def generate_random_name(self):
        """Generate a random name for email accounts"""
        first_names = [
            'alex', 'jordan', 'morgan', 'casey', 'taylor', 'riley', 'sage',
            'quinn', 'blake', 'jamie', 'drew', 'cameron', 'avery', 'logan',
            'harper', 'emerson', 'phoenix', 'river', 'dakota', 'skyler'
        ]
        
        last_names = [
            'smith', 'johnson', 'williams', 'brown', 'jones', 'garcia',
            'miller', 'davis', 'rodriguez', 'martinez', 'hernandez',
            'lopez', 'gonzalez', 'wilson', 'anderson', 'thomas', 'taylor',
            'moore', 'jackson', 'martin'
        ]
        
        return f"{random.choice(first_names)}.{random.choice(last_names)}"
    
    def generate_password(self, length=16):
        """Generate a secure random password"""
        characters = string.ascii_letters + string.digits + "!@#$%^&*"
        password = ''.join(random.choice(characters) for _ in range(length))
        
        # Ensure at least one of each type
        password = (
            random.choice(string.ascii_lowercase) +
            random.choice(string.ascii_uppercase) +
            random.choice(string.digits) +
            random.choice("!@#$%^&*") +
            password[4:]
        )
        
        return ''.join(random.sample(password, len(password)))
    
    def create_email_accounts(self):
        """Create email accounts for each domain"""
        log("\n🔧 Creating email accounts...")
        
        for domain in self.domains:
            log(f"\n📧 Processing domain: {domain}")
            
            domain_accounts = []
            
            # Get SMTP configuration for this domain
            smtp_config = self.smtp_configs.get(domain, self.smtp_configs.get('default', {}))
            
            for i in range(3):  # 3 emails per domain
                # Generate account details
                username = self.generate_random_name()
                email = f"{username}@{domain}"
                password = self.generate_password()
                
                # Format SMTP settings
                smtp_host = smtp_config.get('smtp_host', 'mail.{domain}').format(domain=domain)
                smtp_port = smtp_config.get('smtp_port', 587)
                imap_host = smtp_config.get('imap_host', 'mail.{domain}').format(domain=domain)
                imap_port = smtp_config.get('imap_port', 993)
                
                account = {
                    'email': email,
                    'username': username,
                    'password': password,
                    'domain': domain,
                    'smtp_settings': {
                        'host': smtp_host,
                        'port': smtp_port,
                        'security': smtp_config.get('smtp_security', 'STARTTLS'),
                        'username': email,
                        'password': password
                    },
                    'imap_settings': {
                        'host': imap_host,
                        'port': imap_port,
                        'security': smtp_config.get('imap_security', 'SSL'),
                        'username': email,
                        'password': password
                    }
                }
                
                domain_accounts.append(account)
                self.email_accounts.append(account)
                
                log(f"  ✓ Created: {email}")
        
        return self.email_accounts
    
    def generate_output_files(self):
        """Generate output files with all credentials and configurations"""
        timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
        
        # Create output directory
        output_dir = Path(f"email_credentials_{timestamp}")
        output_dir.mkdir(exist_ok=True)
        
        # Generate JSON output
        json_output = {
            'timestamp': timestamp,
            'server_ip': self.server_ip,
            'total_accounts': len(self.email_accounts),
            'domains': len(self.domains),
            'accounts': self.email_accounts,
            'dns_analysis': {
                domain: {
                    'provider': self.dns_managers[domain].dns_provider,
                    'conflicts': self.dns_managers[domain].conflicts,
                    'current_mx': self.dns_managers[domain].current_mx
                }
                for domain in self.domains if domain in self.dns_managers
            }
        }
        
        json_file = output_dir / "email_credentials.json"
        with open(json_file, 'w') as f:
            json.dump(json_output, f, indent=2)
        
        # Generate CSV output
        csv_file = output_dir / "email_credentials.csv"
        with open(csv_file, 'w') as f:
            f.write("Domain,Email,Username,Password,SMTP_Host,SMTP_Port,SMTP_Security,IMAP_Host,IMAP_Port,IMAP_Security\n")
            for account in self.email_accounts:
                f.write(f"{account['domain']},{account['email']},{account['username']},{account['password']},"
                       f"{account['smtp_settings']['host']},{account['smtp_settings']['port']},{account['smtp_settings']['security']},"
                       f"{account['imap_settings']['host']},{account['imap_settings']['port']},{account['imap_settings']['security']}\n")
        
        # Generate DNS instructions file
        dns_file = output_dir / "dns_instructions.txt"
        with open(dns_file, 'w') as f:
            f.write("DNS CONFIGURATION INSTRUCTIONS\n")
            f.write("=" * 50 + "\n\n")
            f.write(f"Server IP: {self.server_ip}\n")
            f.write(f"Generated: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}\n\n")
            
            for domain in self.domains:
                dns_manager = self.dns_managers.get(domain)
                if not dns_manager:
                    continue
                    
                f.write(f"\nDOMAIN: {domain}\n")
                f.write("-" * 30 + "\n")
                f.write(f"DNS Provider: {dns_manager.dns_provider}\n")
                
                if dns_manager.conflicts:
                    f.write(f"\n⚠️  CONFLICTS DETECTED:\n")
                    for conflict in dns_manager.conflicts:
                        f.write(f"  - {conflict['description']}\n")
                        f.write(f"    Solution: {conflict['solution']}\n")
                
                f.write(f"\nRequired DNS Records:\n")
                suggestions = dns_manager.suggest_dns_configuration(self.server_ip)
                for record in suggestions['required_records']:
                    if record['type'] == 'MX':
                        f.write(f"  {record['type']} {record['name']} → {record['value']} (priority {record['priority']})\n")
                    else:
                        f.write(f"  {record['type']} {record['name']} → {record['value']}\n")
        
        log(f"\n📄 Output files generated in: {output_dir}")
        log(f"  - JSON: {json_file}")
        log(f"  - CSV: {csv_file}")
        log(f"  - DNS Instructions: {dns_file}")
        
        return output_dir
    
    def run(self):
        """Main execution method with DNS analysis"""
        log("🚀 Enhanced Email Configuration Script Starting...")
        log("=" * 50)
        
        # Load configuration
        if not self.load_config():
            return
        
        if not self.domains:
            log("⚠ No domains configured. Please update the configuration file.")
            return
        
        # Get server IP
        self.server_ip = self.get_server_ip()
        if self.server_ip:
            log(f"🌐 Server IP: {self.server_ip}")
        
        # Analyze DNS for all domains
        self.analyze_all_domains()
        
        # Generate DNS instructions
        self.generate_dns_instructions()
        
        # Ask user if they want to continue
        response = input("\nDo you want to continue with email account creation? (y/N): ")
        if response.lower() not in ['y', 'yes']:
            log("👋 Exiting. Configure DNS first, then run again.")
            return
        
        # Create email accounts
        self.create_email_accounts()
        
        # Generate output files
        output_dir = self.generate_output_files()
        
        # Print summary
        self.print_summary()
        
        log(f"\n✅ Email configuration completed successfully!")
        log(f"📁 All credentials and instructions saved to: {output_dir}")
        log("\n💡 Next steps:")
        log("  1. Configure DNS records as instructed")
        log("  2. Wait for DNS propagation (15 minutes - 24 hours)")
        log("  3. Test SMTP connections using the generated credentials")
    
    def print_summary(self):
        """Print a summary of created accounts and DNS status"""
        log("\n" + "=" * 60)
        log("EMAIL CONFIGURATION SUMMARY")
        log("=" * 60)
        
        for domain in self.domains:
            log(f"\n📧 Domain: {domain}")
            
            # DNS status
            dns_manager = self.dns_managers.get(domain)
            if dns_manager:
                log(f"  DNS Provider: {dns_manager.dns_provider}")
                if dns_manager.conflicts:
                    warn(f"  ⚠️  {len(dns_manager.conflicts)} conflicts detected")
                else:
                    log(f"  ✅ No conflicts detected")
            
            # Email accounts
            domain_accounts = [acc for acc in self.email_accounts if acc['domain'] == domain]
            for account in domain_accounts:
                log(f"  ✓ {account['email']} | Password: {account['password']}")
                log(f"    SMTP: {account['smtp_settings']['host']}:{account['smtp_settings']['port']}")

def main():
    """Main function"""
    if len(sys.argv) > 1:
        config_file = sys.argv[1]
    else:
        config_file = "email_config.json"
    
    configurator = EnhancedEmailConfigurator(config_file)
    configurator.run()

def error(message):
    """Error logging function"""
    timestamp = datetime.now().strftime("%H:%M:%S")
    print(f"[{timestamp}] ❌ {message}")

if __name__ == "__main__":
    main()
