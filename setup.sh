#!/bin/bash
# Quick Setup Script for VPS Email Automation

set -euo pipefail

echo "🚀 VPS Email Automation - Quick Setup"
echo "====================================="

# Check if Python 3 is installed
if ! command -v python3 &> /dev/null; then
    echo "❌ Python 3 is required but not installed"
    echo "Please install Python 3 and try again"
    exit 1
fi

# Create virtual environment
if [[ ! -d "venv" ]]; then
    echo "📦 Creating virtual environment..."
    python3 -m venv venv
fi

# Activate virtual environment
echo "🔧 Activating virtual environment..."
source venv/bin/activate

# Install requirements
echo "📥 Installing Python dependencies..."
pip install --upgrade pip
pip install -r requirements.txt

# Make scripts executable
echo "🔐 Setting script permissions..."
chmod +x *.py *.sh
chmod +x deploy.sh

# Create config from examples
echo "📝 Creating configuration files..."
if [[ ! -f "config/automation_config.json" ]]; then
    cp config/automation_config.json.example config/automation_config.json
    echo "✓ Created automation_config.json"
fi

if [[ ! -f "config/email_config.json" ]]; then
    cp config/email_config.json.example config/email_config.json
    echo "✓ Created email_config.json"
fi

echo ""
echo "✅ Setup completed successfully!"
echo ""
echo "Next steps:"
echo "1. Edit config/automation_config.json with your API tokens and domains"
echo "2. Run the one-line deployment:"
echo "   ./deploy.sh --domains=\"yourdomain.com\" --do-token=\"your_token\""
echo ""
echo "Or use the Python scripts directly:"
echo "   python3 email_configurator.py"
echo "   python3 vps_orchestrator.py"
echo ""
echo "For help:"
echo "   ./deploy.sh --help"
