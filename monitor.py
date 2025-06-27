#!/usr/bin/env python3
"""
Email Server Health Monitoring Script
Monitors email server health and sends alerts
"""

import json
import time
import smtplib
import imaplib
import subprocess
import requests
import socket
from datetime import datetime
from pathlib import Path

class EmailServerMonitor:
    def __init__(self, config_file="/opt/email-automation/monitor_config.json"):
        """Initialize the monitor with configuration"""
        self.config = self.load_config(config_file)
        self.status = {}
        self.alerts = []
        
    def load_config(self, config_file):
        """Load monitoring configuration"""
        default_config = {
            "check_interval": 300,  # 5 minutes
            "webhook_url": "",
            "alert_email": "",
            "thresholds": {
                "disk_usage": 90,
                "memory_usage": 90,
                "load_average": 5.0,
                "queue_size": 100
            },
            "services": ["postfix", "dovecot", "mysql", "nginx"],
            "ports": [25, 587, 993, 443, 80],
            "test_accounts": []
        }
        
        try:
            with open(config_file, 'r') as f:
                config = json.load(f)
                # Merge with defaults
                for key, value in default_config.items():
                    if key not in config:
                        config[key] = value
                return config
        except FileNotFoundError:
            print(f"Config file not found, using defaults: {config_file}")
            return default_config
    
    def log(self, message, level="INFO"):
        """Log a message with timestamp"""
        timestamp = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
        print(f"[{timestamp}] [{level}] {message}")
    
    def check_service_status(self, service):
        """Check if a systemd service is running"""
        try:
            result = subprocess.run(
                ["systemctl", "is-active", service],
                capture_output=True,
                text=True,
                timeout=10
            )
            return result.stdout.strip() == "active"
        except Exception as e:
            self.log(f"Error checking service {service}: {e}", "ERROR")
            return False
    
    def check_port_connectivity(self, port, host="localhost"):
        """Check if a port is accessible"""
        try:
            sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
            sock.settimeout(5)
            result = sock.connect_ex((host, port))
            sock.close()
            return result == 0
        except Exception as e:
            self.log(f"Error checking port {port}: {e}", "ERROR")
            return False
    
    def check_system_resources(self):
        """Check system resource usage"""
        resources = {}
        
        try:
            # Check disk usage
            result = subprocess.run(
                ["df", "-h", "/"],
                capture_output=True,
                text=True
            )
            lines = result.stdout.strip().split('\n')
            if len(lines) > 1:
                parts = lines[1].split()
                if len(parts) >= 5:
                    usage_percent = int(parts[4].rstrip('%'))
                    resources['disk_usage'] = usage_percent
            
            # Check memory usage
            with open('/proc/meminfo', 'r') as f:
                meminfo = f.read()
            
            mem_total = int([line for line in meminfo.split('\n') if 'MemTotal:' in line][0].split()[1])
            mem_available = int([line for line in meminfo.split('\n') if 'MemAvailable:' in line][0].split()[1])
            
            mem_used_percent = int(((mem_total - mem_available) / mem_total) * 100)
            resources['memory_usage'] = mem_used_percent
            
            # Check load average
            with open('/proc/loadavg', 'r') as f:
                load_avg = float(f.read().split()[0])
            resources['load_average'] = load_avg
            
        except Exception as e:
            self.log(f"Error checking system resources: {e}", "ERROR")
        
        return resources
    
    def check_mail_queue(self):
        """Check mail queue size"""
        try:
            result = subprocess.run(
                ["postqueue", "-p"],
                capture_output=True,
                text=True
            )
            
            lines = result.stdout.strip().split('\n')
            if lines and "Mail queue is empty" in lines[-1]:
                return 0
            else:
                # Count queued messages
                queue_count = len([line for line in lines if line and not line.startswith('-') and not line.startswith('Mail')])
                return max(0, queue_count - 1)  # Subtract header line
                
        except Exception as e:
            self.log(f"Error checking mail queue: {e}", "ERROR")
            return -1
    
    def test_smtp_connectivity(self, account):
        """Test SMTP connectivity for an account"""
        try:
            server = smtplib.SMTP(account['smtp_host'], account['smtp_port'])
            server.starttls()
            server.login(account['email'], account['password'])
            server.quit()
            return True
        except Exception as e:
            self.log(f"SMTP test failed for {account['email']}: {e}", "ERROR")
            return False
    
    def test_imap_connectivity(self, account):
        """Test IMAP connectivity for an account"""
        try:
            mail = imaplib.IMAP4_SSL(account['imap_host'], account['imap_port'])
            mail.login(account['email'], account['password'])
            mail.logout()
            return True
        except Exception as e:
            self.log(f"IMAP test failed for {account['email']}: {e}", "ERROR")
            return False
    
    def check_ssl_certificates(self):
        """Check SSL certificate expiration"""
        cert_status = {}
        
        try:
            # Check Let's Encrypt certificates
            result = subprocess.run(
                ["certbot", "certificates"],
                capture_output=True,
                text=True
            )
            
            output = result.stdout
            if "VALID" in output:
                cert_status['ssl_valid'] = True
                # Extract expiration date if needed
                cert_status['ssl_expires'] = "Valid"
            else:
                cert_status['ssl_valid'] = False
                cert_status['ssl_expires'] = "Invalid or Expired"
                
        except Exception as e:
            self.log(f"Error checking SSL certificates: {e}", "ERROR")
            cert_status['ssl_valid'] = False
        
        return cert_status
    
    def run_health_check(self):
        """Run comprehensive health check"""
        self.log("Starting health check...")
        self.status = {
            'timestamp': datetime.now().isoformat(),
            'hostname': subprocess.run(['hostname'], capture_output=True, text=True).stdout.strip(),
            'services': {},
            'ports': {},
            'resources': {},
            'mail_queue': 0,
            'ssl_status': {},
            'email_tests': {},
            'overall_status': 'healthy'
        }
        
        # Check services
        for service in self.config['services']:
            self.status['services'][service] = self.check_service_status(service)
            if not self.status['services'][service]:
                self.alerts.append(f"Service {service} is not running")
        
        # Check ports
        for port in self.config['ports']:
            self.status['ports'][port] = self.check_port_connectivity(port)
            if not self.status['ports'][port]:
                self.alerts.append(f"Port {port} is not accessible")
        
        # Check system resources
        self.status['resources'] = self.check_system_resources()
        
        # Check thresholds
        thresholds = self.config['thresholds']
        resources = self.status['resources']
        
        if resources.get('disk_usage', 0) > thresholds['disk_usage']:
            self.alerts.append(f"High disk usage: {resources['disk_usage']}%")
        
        if resources.get('memory_usage', 0) > thresholds['memory_usage']:
            self.alerts.append(f"High memory usage: {resources['memory_usage']}%")
        
        if resources.get('load_average', 0) > thresholds['load_average']:
            self.alerts.append(f"High load average: {resources['load_average']}")
        
        # Check mail queue
        self.status['mail_queue'] = self.check_mail_queue()
        if self.status['mail_queue'] > thresholds['queue_size']:
            self.alerts.append(f"Large mail queue: {self.status['mail_queue']} messages")
        
        # Check SSL certificates
        self.status['ssl_status'] = self.check_ssl_certificates()
        if not self.status['ssl_status'].get('ssl_valid', False):
            self.alerts.append("SSL certificate issues detected")
        
        # Test email connectivity
        for account in self.config['test_accounts']:
            email = account['email']
            self.status['email_tests'][email] = {
                'smtp': self.test_smtp_connectivity(account),
                'imap': self.test_imap_connectivity(account)
            }
            
            if not self.status['email_tests'][email]['smtp']:
                self.alerts.append(f"SMTP test failed for {email}")
            
            if not self.status['email_tests'][email]['imap']:
                self.alerts.append(f"IMAP test failed for {email}")
        
        # Determine overall status
        if self.alerts:
            self.status['overall_status'] = 'warning' if len(self.alerts) <= 2 else 'critical'
            self.status['alerts'] = self.alerts
        
        self.log(f"Health check completed. Status: {self.status['overall_status']}")
        
        return self.status
    
    def send_webhook_notification(self, status):
        """Send webhook notification"""
        if not self.config.get('webhook_url'):
            return
        
        try:
            status_emoji = {
                'healthy': '✅',
                'warning': '⚠️',
                'critical': '🚨'
            }
            
            emoji = status_emoji.get(status['overall_status'], '❓')
            
            message = f"{emoji} Email Server Status: {status['overall_status'].upper()}"
            
            if status.get('alerts'):
                message += f"\n\nAlerts:\n" + "\n".join(f"• {alert}" for alert in status['alerts'])
            
            # Add system info
            resources = status.get('resources', {})
            message += f"\n\nSystem Info:"
            message += f"\n• Disk Usage: {resources.get('disk_usage', 'N/A')}%"
            message += f"\n• Memory Usage: {resources.get('memory_usage', 'N/A')}%"
            message += f"\n• Load Average: {resources.get('load_average', 'N/A')}"
            message += f"\n• Mail Queue: {status.get('mail_queue', 'N/A')} messages"
            
            payload = {
                'text': message,
                'username': 'Email Monitor',
                'icon_emoji': emoji
            }
            
            response = requests.post(
                self.config['webhook_url'],
                json=payload,
                timeout=10
            )
            
            if response.status_code == 200:
                self.log("Webhook notification sent successfully")
            else:
                self.log(f"Webhook notification failed: {response.status_code}", "ERROR")
                
        except Exception as e:
            self.log(f"Error sending webhook notification: {e}", "ERROR")
    
    def save_status_report(self, status):
        """Save status report to file"""
        try:
            report_dir = Path("/var/log/email-monitoring")
            report_dir.mkdir(exist_ok=True)
            
            timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
            report_file = report_dir / f"health_report_{timestamp}.json"
            
            with open(report_file, 'w') as f:
                json.dump(status, f, indent=2)
            
            # Keep only last 100 reports
            reports = sorted(report_dir.glob("health_report_*.json"))
            if len(reports) > 100:
                for old_report in reports[:-100]:
                    old_report.unlink()
            
            self.log(f"Health report saved: {report_file}")
            
        except Exception as e:
            self.log(f"Error saving health report: {e}", "ERROR")
    
    def run_continuous_monitoring(self):
        """Run continuous monitoring loop"""
        self.log("Starting continuous email server monitoring...")
        
        while True:
            try:
                # Clear alerts from previous run
                self.alerts = []
                
                # Run health check
                status = self.run_health_check()
                
                # Save status report
                self.save_status_report(status)
                
                # Send notifications if there are issues
                if status['overall_status'] != 'healthy':
                    self.send_webhook_notification(status)
                
                # Wait for next check
                time.sleep(self.config['check_interval'])
                
            except KeyboardInterrupt:
                self.log("Monitoring stopped by user")
                break
            except Exception as e:
                self.log(f"Error in monitoring loop: {e}", "ERROR")
                time.sleep(60)  # Wait a minute before retrying


def main():
    """Main function"""
    import sys
    
    if len(sys.argv) > 1:
        if sys.argv[1] == "--once":
            # Run once and exit
            monitor = EmailServerMonitor()
            status = monitor.run_health_check()
            
            print("\n" + "="*60)
            print("EMAIL SERVER HEALTH CHECK RESULTS")
            print("="*60)
            print(f"Overall Status: {status['overall_status'].upper()}")
            print(f"Timestamp: {status['timestamp']}")
            
            # Print service status
            print(f"\nServices:")
            for service, is_active in status['services'].items():
                status_icon = "✅" if is_active else "❌"
                print(f"  {status_icon} {service}")
            
            # Print port status
            print(f"\nPorts:")
            for port, is_open in status['ports'].items():
                status_icon = "✅" if is_open else "❌"
                print(f"  {status_icon} {port}")
            
            # Print resources
            resources = status['resources']
            print(f"\nResources:")
            print(f"  📊 Disk Usage: {resources.get('disk_usage', 'N/A')}%")
            print(f"  🧠 Memory Usage: {resources.get('memory_usage', 'N/A')}%")
            print(f"  ⚡ Load Average: {resources.get('load_average', 'N/A')}")
            print(f"  📬 Mail Queue: {status.get('mail_queue', 'N/A')} messages")
            
            # Print alerts
            if status.get('alerts'):
                print(f"\nAlerts:")
                for alert in status['alerts']:
                    print(f"  ⚠️ {alert}")
            
            print("="*60)
            
            # Send notification
            monitor.send_webhook_notification(status)
            monitor.save_status_report(status)
            
            # Exit with appropriate code
            exit_code = 0 if status['overall_status'] == 'healthy' else 1
            sys.exit(exit_code)
            
        elif sys.argv[1] == "--help":
            print("""
Email Server Health Monitoring Script

Usage:
    python3 monitor.py              # Run continuous monitoring
    python3 monitor.py --once       # Run once and exit
    python3 monitor.py --help       # Show this help

Configuration:
    Edit /opt/email-automation/monitor_config.json to customize monitoring settings.

Exit Codes (--once mode):
    0 = Healthy
    1 = Warning or Critical issues detected
""")
            sys.exit(0)
    
    # Default: run continuous monitoring
    monitor = EmailServerMonitor()
    monitor.run_continuous_monitoring()


if __name__ == "__main__":
    main()
