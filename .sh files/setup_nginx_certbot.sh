#!/bin/bash
# This assumes: domain1 = mastodon.yourdomain.com, domain2 = api.yourdomain.com

set -e

echo "📦 Installing Certbot..."
sudo apt install python3-venv -y
python3 -m venv /opt/certbot
/opt/certbot/bin/pip install --upgrade pip
/opt/certbot/bin/pip install certbot certbot-nginx

echo "🔒 Generating HTTPS certificates via certbot..."
/opt/certbot/bin/certbot --nginx -d mastodon.yourdomain.com -d api.yourdomain.com

echo "✅ Certbot complete. SSL is enabled."
