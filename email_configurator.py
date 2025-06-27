#!/usr/bin/env python3
"""
Email Configuration Script for Domain-Based Email Setup
Automatically configures email accounts and generates SMTP credentials
"""

import json
import random
import string
import subprocess
import sys
import os
from datetime import datetime
from pathlib import Path

class EmailConfigurator:
    def __init__(self, config_file="email_config.json"):
        """
        Initialize the email configurator
        
        Args:
            config_file (str): Path to configuration file
        """
        self.config_file = config_file
        self.domains = []
        self.smtp_configs = {}
        self.email_accounts = []
        
    def load_config(self):
        """Load configuration from JSON file"""
        try:
            with open(self.config_file, 'r') as f:
                config = json.load(f)
                self.domains = config.get('domains', [])
                self.smtp_configs = config.get('smtp_configs', {})
                print(f"✓ Configuration loaded: {len(self.domains)} domains found")
                return True
        except FileNotFoundError:
            print(f"⚠ Configuration file {self.config_file} not found. Creating default...")
            self.create_default_config()
            return False
        except json.JSONDecodeError:
            print(f"✗ Error parsing {self.config_file}")
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
                "use_random_names": True
            }
        }
        
        with open(self.config_file, 'w') as f:
            json.dump(default_config, f, indent=2)
        
        print(f"✓ Default configuration created: {self.config_file}")
        print("Please edit the configuration file with your domains and run again.")
    
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
        """
        Generate a secure random password
        
        Args:
            length (int): Password length
            
        Returns:
            str: Generated password
        """
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
        print("\n🔧 Creating email accounts...")
        
        for domain in self.domains:
            print(f"\n📧 Processing domain: {domain}")
            
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
                
                print(f"  ✓ Created: {email}")
            
            # Simulate creating accounts on the server (replace with actual implementation)
            self.configure_server_accounts(domain, domain_accounts)
    
    def configure_server_accounts(self, domain, accounts):
        """
        Configure email accounts on the server
        Replace this with actual server configuration commands
        
        Args:
            domain (str): Domain name
            accounts (list): List of email accounts to create
        """
        print(f"  🔧 Configuring server for {domain}...")
        
        for account in accounts:
            # Example commands - replace with your actual server setup
            # These are placeholder commands for different mail servers
            
            # For Postfix/Dovecot setup:
            postfix_cmd = f"# postfix user creation for {account['email']}"
            dovecot_cmd = f"# dovecot mailbox creation for {account['email']}"
            
            # For cPanel/WHM:
            cpanel_cmd = f"# uapi --user={domain} Email add_pop email={account['username']} password={account['password']} domain={domain}"
            
            # For Zimbra:
            zimbra_cmd = f"# zmprov ca {account['email']} {account['password']}"
            
            print(f"    - Account: {account['email']}")
            # Uncomment and modify based on your mail server:
            # subprocess.run(actual_command, shell=True, check=True)
    
    def generate_output_files(self):
        """Generate output files with all credentials and configurations"""
        timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
        
        # Create output directory
        output_dir = Path(f"email_credentials_{timestamp}")
        output_dir.mkdir(exist_ok=True)
        
        # Generate JSON output
        json_output = {
            'timestamp': timestamp,
            'total_accounts': len(self.email_accounts),
            'domains': len(self.domains),
            'accounts': self.email_accounts
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
        
        # Generate formatted text output
        txt_file = output_dir / "email_credentials.txt"
        with open(txt_file, 'w') as f:
            f.write("EMAIL CONFIGURATION REPORT\n")
            f.write("=" * 50 + "\n\n")
            f.write(f"Generated: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}\n")
            f.write(f"Total Domains: {len(self.domains)}\n")
            f.write(f"Total Accounts: {len(self.email_accounts)}\n\n")
            
            for domain in self.domains:
                f.write(f"\nDOMAIN: {domain}\n")
                f.write("-" * 30 + "\n")
                
                domain_accounts = [acc for acc in self.email_accounts if acc['domain'] == domain]
                
                for i, account in enumerate(domain_accounts, 1):
                    f.write(f"\nAccount {i}:\n")
                    f.write(f"  Email: {account['email']}\n")
                    f.write(f"  Password: {account['password']}\n")
                    f.write(f"  \n")
                    f.write(f"  SMTP Configuration:\n")
                    f.write(f"    Host: {account['smtp_settings']['host']}\n")
                    f.write(f"    Port: {account['smtp_settings']['port']}\n")
                    f.write(f"    Security: {account['smtp_settings']['security']}\n")
                    f.write(f"    Username: {account['smtp_settings']['username']}\n")
                    f.write(f"    Password: {account['smtp_settings']['password']}\n")
                    f.write(f"  \n")
                    f.write(f"  IMAP Configuration:\n")
                    f.write(f"    Host: {account['imap_settings']['host']}\n")
                    f.write(f"    Port: {account['imap_settings']['port']}\n")
                    f.write(f"    Security: {account['imap_settings']['security']}\n")
                    f.write(f"    Username: {account['imap_settings']['username']}\n")
                    f.write(f"    Password: {account['imap_settings']['password']}\n")
        
        # Generate shell script for easy testing
        sh_file = output_dir / "test_connections.sh"
        with open(sh_file, 'w') as f:
            f.write("#!/bin/bash\n")
            f.write("# Email Connection Test Script\n\n")
            
            for account in self.email_accounts:
                f.write(f"# Test {account['email']}\n")
                f.write(f"echo 'Testing {account['email']}...'\n")
                f.write(f"# curl --url 'smtps://{account['smtp_settings']['host']}:{account['smtp_settings']['port']}' "
                       f"--ssl-reqd --mail-from '{account['email']}' --mail-rcpt 'test@example.com' "
                       f"--user '{account['email']}:{account['password']}' --upload-file -\n\n")
        
        os.chmod(sh_file, 0o755)
        
        print(f"\n📄 Output files generated in: {output_dir}")
        print(f"  - JSON: {json_file}")
        print(f"  - CSV: {csv_file}")
        print(f"  - Text: {txt_file}")
        print(f"  - Test script: {sh_file}")
        
        return output_dir
    
    def print_summary(self):
        """Print a summary of created accounts"""
        print("\n" + "=" * 60)
        print("EMAIL CONFIGURATION SUMMARY")
        print("=" * 60)
        
        for domain in self.domains:
            print(f"\n📧 Domain: {domain}")
            domain_accounts = [acc for acc in self.email_accounts if acc['domain'] == domain]
            
            for account in domain_accounts:
                print(f"  ✓ {account['email']} | Password: {account['password']}")
                print(f"    SMTP: {account['smtp_settings']['host']}:{account['smtp_settings']['port']}")
    
    def run(self):
        """Main execution method"""
        print("🚀 Email Configuration Script Starting...")
        print("=" * 50)
        
        # Load configuration
        if not self.load_config():
            return
        
        if not self.domains:
            print("⚠ No domains configured. Please update the configuration file.")
            return
        
        # Create email accounts
        self.create_email_accounts()
        
        # Generate output files
        output_dir = self.generate_output_files()
        
        # Print summary
        self.print_summary()
        
        print(f"\n✅ Email configuration completed successfully!")
        print(f"📁 All credentials saved to: {output_dir}")
        print("\n💡 Next steps:")
        print("  1. Review the generated credentials")
        print("  2. Test SMTP connections using the test script")
        print("  3. Configure your applications with the SMTP settings")


def main():
    """Main function"""
    if len(sys.argv) > 1:
        config_file = sys.argv[1]
    else:
        config_file = "email_config.json"
    
    configurator = EmailConfigurator(config_file)
    configurator.run()


if __name__ == "__main__":
    main()
