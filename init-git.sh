#!/bin/bash
# Git Initialization Script for VPS Email Automation

echo "🔧 Initializing Git repository for VPS Email Automation..."

# Initialize git repository
git init

# Add all files
git add .

# Initial commit
git commit -m "Initial commit: VPS Email Automation complete system

Features:
- One-line deployment script (deploy.sh)
- Complete VPS orchestration (vps_orchestrator.py)
- Email configuration management (email_configurator.py)
- SMTP testing utilities (test_smtp.py)
- Automated backup system (backup_emails.sh)
- Health monitoring (monitor.py)
- Configuration templates
- Comprehensive documentation

Ready for production deployment!"

echo "✅ Git repository initialized successfully!"
echo ""
echo "Next steps to push to GitHub:"
echo "1. Create a new repository on GitHub"
echo "2. git remote add origin https://github.com/yourusername/vps-email-automation.git"
echo "3. git branch -M main"
echo "4. git push -u origin main"
echo ""
echo "Or use GitHub CLI:"
echo "gh repo create vps-email-automation --private --source=. --remote=origin --push"
