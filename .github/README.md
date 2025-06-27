# VPS Email Automation - Git Repository

## 📁 Project Structure

```
vps-email-automation/
├── README.md                              # Main documentation
├── LICENSE                                # MIT License
├── requirements.txt                       # Python dependencies
├── setup.sh                              # Quick setup script
├── deploy.sh                             # One-line deployment script
├── email_configurator.py                 # Email account management
├── vps_orchestrator.py                   # Complete VPS automation
├── test_smtp.py                          # SMTP connectivity testing
├── backup_emails.sh                      # Email backup automation
├── monitor.py                            # Health monitoring script
├── config/
│   ├── automation_config.json.example    # Main configuration template
│   └── email_config.json.example         # Email settings template
└── templates/
    ├── postfix_main.cf                   # Postfix configuration template
    └── dovecot.conf                      # Dovecot configuration template
```

## 🚀 Quick Start

### Option 1: One-Line Deployment (Fastest)
```bash
curl -sSL https://raw.githubusercontent.com/your-username/vps-email-automation/main/deploy.sh | bash -s -- --domains="yourdomain.com" --do-token="your_digitalocean_token"
```

### Option 2: Local Setup
```bash
git clone https://github.com/your-username/vps-email-automation.git
cd vps-email-automation
chmod +x setup.sh
./setup.sh
```

## 📋 What Gets Created

After running the automation, you'll have:

- ✅ **VPS** with Ubuntu 22.04
- ✅ **Postfix** mail server (SMTP)
- ✅ **Dovecot** IMAP/POP3 server
- ✅ **MySQL** database for email accounts
- ✅ **SSL certificates** from Let's Encrypt
- ✅ **3 email accounts** per domain
- ✅ **Complete credentials** in CSV format
- ✅ **Firewall configured** and secured
- ✅ **DNS records** (if Cloudflare tokens provided)

## 🎯 Perfect For

- **Developers** who need quick email servers
- **Agencies** managing multiple client domains
- **Entrepreneurs** launching new services
- **Anyone** who wants email hosting without monthly fees

## 💰 Cost Analysis

**Traditional Email Hosting:**
- Google Workspace: $6/user/month
- Microsoft 365: $5/user/month
- Zoho Mail: $1/user/month

**This Solution:**
- DigitalOcean VPS: $12/month (unlimited emails)
- Domain + DNS: $10-15/year
- **Total**: ~$12/month for unlimited email accounts

## 🔧 Customization

The automation is fully customizable:

- **VPS Providers**: DigitalOcean, Vultr, Linode
- **DNS Providers**: Cloudflare, Route53 (coming soon)
- **Email Accounts**: Configurable number per domain
- **Security**: Built-in firewall and fail2ban
- **Monitoring**: Health checks and alerting
- **Backups**: Automated backup scripts

## 🤝 Contributing

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🆘 Support

- 📧 Email: support@your-domain.com
- 💬 Discord: [Join our server](https://discord.gg/your-invite)
- 🐛 Issues: [GitHub Issues](https://github.com/your-username/vps-email-automation/issues)

---

**⚡ Deploy your email server in 30 seconds of setup, 30-60 minutes of automation!**
