# 🚀 VPS Email Automation

Automated VPS email server deployment with one-line command execution. Complete solution for provisioning VPS, configuring mail servers, and generating SMTP/IMAP credentials automatically.

## ⚡ Quick Start

Deploy a complete email server in 30-60 minutes with one command:

```bash
curl -sSL https://raw.githubusercontent.com/your-username/vps-email-automation/main/deploy.sh | bash -s -- --domains="yourdomain.com" --do-token="your_digitalocean_token"
```

## 🎯 What You Get

- **VPS Ubuntu 22.04** automatically provisioned
- **Postfix + Dovecot** mail server configured
- **MySQL database** with email structure
- **SSL certificates** from Let's Encrypt
- **3 email accounts** per domain with secure passwords
- **Complete SMTP/IMAP credentials** ready to use
- **Firewall configured** for security
- **DNS records** automatically created (optional)

## 📋 Usage Examples

### Basic Deployment
```bash
curl -sSL https://raw.githubusercontent.com/your-username/vps-email-automation/main/deploy.sh | bash -s -- \
  --domains="example.com" \
  --do-token="your_digitalocean_token"
```

### Multiple Domains with DNS
```bash
curl -sSL https://raw.githubusercontent.com/your-username/vps-email-automation/main/deploy.sh | bash -s -- \
  --domains="domain1.com,domain2.org,domain3.net" \
  --do-token="your_do_token" \
  --cf-token="your_cloudflare_token" \
  --cf-zone-id="your_zone_id" \
  --admin-email="admin@domain1.com"
```

### With Slack Notifications
```bash
curl -sSL https://raw.githubusercontent.com/your-username/vps-email-automation/main/deploy.sh | bash -s -- \
  --domains="example.com" \
  --do-token="your_token" \
  --webhook-url="https://hooks.slack.com/your-webhook"
```

## 🛠️ Parameters

| Parameter | Description | Required | Example |
|-----------|-------------|----------|---------|
| `--domains` | Domains (comma-separated) | ✅ | `"domain1.com,domain2.org"` |
| `--do-token` | DigitalOcean API token | ✅ | `"dop_v1_abc123..."` |
| `--cf-token` | Cloudflare API token | ⚪ | `"abc123..."` |
| `--cf-zone-id` | Cloudflare Zone ID | ⚪ | `"def456..."` |
| `--admin-email` | Admin email for SSL | ⚪ | `"admin@domain.com"` |
| `--webhook-url` | Webhook for notifications | ⚪ | `"https://hooks.slack.com/..."` |
| `--region` | VPS region | ⚪ | `"fra1"` (default) |
| `--size` | VPS size | ⚪ | `"s-2vcpu-4gb"` (default) |
| `--skip-dns` | Skip DNS configuration | ⚪ | (flag) |
| `--skip-tests` | Skip connectivity tests | ⚪ | (flag) |
| `--verbose` | Verbose output | ⚪ | (flag) |

## 📦 What's Included

### Core Scripts
- `deploy.sh` - Main one-line deployment script
- `email_configurator.py` - Email account management
- `vps_orchestrator.py` - Complete VPS automation
- `config/` - Configuration templates

### Templates
- Postfix configuration
- Dovecot configuration  
- MySQL database structure
- Nginx proxy configuration
- Firewall rules

### Utilities
- `test_smtp.py` - SMTP connectivity testing
- `backup_emails.sh` - Email backup automation
- `monitor.py` - Health monitoring

## 🔧 Manual Installation

If you prefer to run locally:

```bash
git clone https://github.com/your-username/vps-email-automation.git
cd vps-email-automation
chmod +x deploy.sh

# Edit configuration
cp config/automation_config.json.example config/automation_config.json
nano config/automation_config.json

# Run deployment
./deploy.sh --domains="example.com" --do-token="your_token"
```

## 📊 Output Files

After deployment, you'll find:

```
deployment_report_TIMESTAMP.json    # Complete deployment details
email_credentials_TIMESTAMP.csv     # SMTP/IMAP credentials
test_connections.sh                  # Connection testing script
backup_TIMESTAMP.tar.gz              # Configuration backup
```

## 🔐 Security Features

- **Secure password generation** (20+ characters)
- **Firewall automatically configured**
- **SSL/TLS encryption** for all connections
- **SASL authentication** for SMTP
- **Fail2ban** protection against brute force
- **Regular security updates** via unattended-upgrades

## 🌍 Supported Providers

### VPS Providers
- ✅ DigitalOcean
- ✅ Vultr  
- ✅ Linode
- 🚧 AWS EC2 (coming soon)
- 🚧 Google Cloud (coming soon)

### DNS Providers
- ✅ Cloudflare
- 🚧 Route53 (coming soon)
- 🚧 Namecheap (coming soon)

## 📈 Performance

- **Deployment time**: 30-60 minutes
- **Resource usage**: 2GB RAM minimum
- **Email throughput**: 1000+ emails/hour
- **Storage**: 50GB+ recommended

## 🐛 Troubleshooting

### Common Issues

**VPS not accessible via SSH**
```bash
# Check if VPS is ready
curl -sSL https://ipinfo.io/YOUR_VPS_IP

# Test SSH manually
ssh -o ConnectTimeout=10 root@YOUR_VPS_IP
```

**DNS not propagating**
```bash
# Check DNS records
dig MX yourdomain.com
dig TXT yourdomain.com
```

**Email not sending**
```bash
# Check mail logs on VPS
ssh root@YOUR_VPS_IP "tail -f /var/log/mail.log"
```

### Debug Mode
```bash
curl -sSL https://raw.githubusercontent.com/your-username/vps-email-automation/main/deploy.sh | bash -s -- \
  --domains="example.com" \
  --do-token="your_token" \
  --verbose
```

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Test thoroughly
5. Submit a pull request

## 📄 License

MIT License - see [LICENSE](LICENSE) file for details.

## 🆘 Support

- 📧 Email: support@your-domain.com
- 💬 Discord: [Join our server](https://discord.gg/your-invite)
- 📖 Wiki: [Detailed documentation](https://github.com/your-username/vps-email-automation/wiki)

## 🎉 Acknowledgments

- Postfix team for the robust mail server
- Dovecot team for IMAP/POP3 implementation
- Let's Encrypt for free SSL certificates
- DigitalOcean for reliable VPS hosting

---

**⚡ Deploy your email server in 30 seconds of setup, 30-60 minutes of automation!**
